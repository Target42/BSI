#include "CatalogSearchDialog.h"

#include "ui/dialogs/BausteinViewDialog.h"

#include <QDialogButtonBox>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QLabel>
#include <QLineEdit>
#include <QPushButton>
#include <QTableWidget>
#include <QTextEdit>
#include <QTimer>
#include <QVBoxLayout>

namespace {

enum ResultColumn {
    GroupColumn = 0,
    BausteinColumn,
    RequirementColumn,
    FieldColumn,
    SnippetColumn,
    ColumnCount
};

bool containsNeedle(const QString &haystack, const QString &needle)
{
    return haystack.contains(needle, Qt::CaseInsensitive);
}

int indexOfNeedle(const QString &haystack, const QString &needle)
{
    return haystack.indexOf(needle, 0, Qt::CaseInsensitive);
}

QString matchSnippet(const QString &text, const QString &needle, int contextChars = 90)
{
    if (text.isEmpty())
        return {};

    const int matchIndex = indexOfNeedle(text, needle);
    if (matchIndex < 0)
        return text.left(contextChars).trimmed() + (text.length() > contextChars ? QStringLiteral("…") : QString());

    const int start = qMax(0, matchIndex - contextChars / 2);
    const int end = qMin(text.length(), matchIndex + needle.length() + contextChars / 2);
    QString snippet = text.mid(start, end - start);
    snippet.replace(QChar::LineFeed, QChar::Space);
    snippet = snippet.simplified();
    if (start > 0)
        snippet.prepend(QStringLiteral("…"));
    if (end < text.length())
        snippet.append(QStringLiteral("…"));
    return snippet;
}

QString bausteinLabel(const Baustein &baustein)
{
    return QStringLiteral("%1 %2").arg(baustein.externalId, baustein.title);
}

QString requirementLabel(const Requirement &requirement)
{
    return QStringLiteral("%1 %2").arg(requirement.externalId, requirement.title);
}

} // namespace

CatalogSearchDialog::CatalogSearchDialog(const QList<Baustein> &bausteine,
                                         const QList<Requirement> &requirements,
                                         const QString &initialQuery,
                                         QWidget *parent)
    : QDialog(parent)
    , m_bausteine(bausteine)
    , m_requirements(requirements)
{
    for (const Baustein &baustein : bausteine)
        m_bausteinById.insert(baustein.id, baustein);

    setWindowTitle(tr("Katalog-Volltextsuche"));
    resize(1100, 680);

    auto *hint = new QLabel(
        tr("Durchsucht Baustein-Namen, Kapitel und alle Anforderungstexte im IT-Grundschutz-Katalog."),
        this);
    hint->setWordWrap(true);

    m_searchEdit = new QLineEdit(this);
    m_searchEdit->setPlaceholderText(tr("Suchbegriff eingeben, z. B. Intrusion, Backup, Firewall…"));
    m_searchEdit->setClearButtonEnabled(true);
    if (!initialQuery.isEmpty())
        m_searchEdit->setText(initialQuery);

    m_searchTimer = new QTimer(this);
    m_searchTimer->setSingleShot(true);
    m_searchTimer->setInterval(250);
    connect(m_searchTimer, &QTimer::timeout, this, &CatalogSearchDialog::runSearch);
    connect(m_searchEdit, &QLineEdit::textChanged, this, [this]() {
        m_searchTimer->start();
    });
    connect(m_searchEdit, &QLineEdit::returnPressed, this, &CatalogSearchDialog::runSearch);

    m_table = new QTableWidget(this);
    m_table->setColumnCount(ColumnCount);
    m_table->setHorizontalHeaderLabels(
        {tr("Kapitel"), tr("Baustein"), tr("Anforderung"), tr("Fundstelle"), tr("Auszug")});
    m_table->horizontalHeader()->setSectionResizeMode(GroupColumn, QHeaderView::ResizeToContents);
    m_table->horizontalHeader()->setSectionResizeMode(BausteinColumn, QHeaderView::ResizeToContents);
    m_table->horizontalHeader()->setSectionResizeMode(RequirementColumn, QHeaderView::ResizeToContents);
    m_table->horizontalHeader()->setSectionResizeMode(FieldColumn, QHeaderView::ResizeToContents);
    m_table->horizontalHeader()->setSectionResizeMode(SnippetColumn, QHeaderView::Stretch);
    m_table->setSelectionBehavior(QAbstractItemView::SelectRows);
    m_table->setSelectionMode(QAbstractItemView::SingleSelection);
    m_table->setEditTriggers(QAbstractItemView::NoEditTriggers);
    m_table->setAlternatingRowColors(true);
    m_table->setSortingEnabled(true);
    connect(m_table, &QTableWidget::currentCellChanged, this,
            [this](int currentRow, int, int, int) {
                showHitAt(currentRow);
            });
    connect(m_table, &QTableWidget::cellDoubleClicked, this,
            [this](int, int) {
                openSelectedHit();
            });

    m_preview = new QTextEdit(this);
    m_preview->setReadOnly(true);
    m_preview->setPlaceholderText(tr("Vorschau der ausgewählten Fundstelle"));

    auto *openButton = new QPushButton(tr("Baustein öffnen…"), this);
    connect(openButton, &QPushButton::clicked, this, &CatalogSearchDialog::openSelectedHit);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Close, this);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);

    auto *buttonRow = new QHBoxLayout();
    buttonRow->addWidget(openButton);
    buttonRow->addStretch();
    buttonRow->addWidget(buttons);

    auto *layout = new QVBoxLayout(this);
    layout->addWidget(hint);
    layout->addWidget(m_searchEdit);
    layout->addWidget(m_table, 3);
    layout->addWidget(m_preview, 2);
    layout->addLayout(buttonRow);

    runSearch();
    m_searchEdit->setFocus();
    if (!initialQuery.isEmpty())
        m_searchEdit->selectAll();
}

void CatalogSearchDialog::runSearch()
{
    m_searchTimer->stop();
    const QString needle = m_searchEdit->text().trimmed();
    m_hits.clear();

    if (!needle.isEmpty()) {
        QSet<int> bausteineWithRequirementHits;

        for (const Requirement &requirement : m_requirements) {
            QString matchField;
            QString snippetSource;

            if (containsNeedle(requirement.text, needle)) {
                matchField = tr("Anforderungstext");
                snippetSource = requirement.text;
            } else if (containsNeedle(requirement.title, needle)) {
                matchField = tr("Anforderungstitel");
                snippetSource = requirement.title;
            } else if (containsNeedle(requirement.externalId, needle)) {
                matchField = tr("Anforderungs-ID");
                snippetSource = requirement.externalId;
            } else if (containsNeedle(requirement.responsibleRole, needle)) {
                matchField = tr("Rolle");
                snippetSource = requirement.responsibleRole;
            }

            if (matchField.isEmpty())
                continue;

            bausteineWithRequirementHits.insert(requirement.bausteinDbId);
            const Baustein baustein = m_bausteinById.value(requirement.bausteinDbId);

            SearchHit hit;
            hit.bausteinDbId = requirement.bausteinDbId;
            hit.requirementId = requirement.id;
            hit.groupName = baustein.groupName;
            hit.bausteinLabel = bausteinLabel(baustein);
            hit.requirementLabel = requirementLabel(requirement);
            hit.matchField = matchField;
            hit.snippet = matchSnippet(snippetSource, needle);
            m_hits.append(hit);
        }

        for (const Baustein &baustein : m_bausteine) {
            QString matchField;
            QString snippetSource;

            if (containsNeedle(baustein.externalId, needle)) {
                matchField = tr("Baustein-ID");
                snippetSource = baustein.externalId;
            } else if (containsNeedle(baustein.title, needle)) {
                matchField = tr("Baustein-Titel");
                snippetSource = baustein.title;
            } else if (containsNeedle(baustein.groupName, needle)) {
                matchField = tr("Kapitel");
                snippetSource = baustein.groupName;
            }

            if (matchField.isEmpty() || bausteineWithRequirementHits.contains(baustein.id))
                continue;

            SearchHit hit;
            hit.bausteinDbId = baustein.id;
            hit.groupName = baustein.groupName;
            hit.bausteinLabel = bausteinLabel(baustein);
            hit.requirementLabel = QStringLiteral("—");
            hit.matchField = matchField;
            hit.snippet = matchSnippet(snippetSource, needle);
            m_hits.append(hit);
        }
    }

    const bool wasSorting = m_table->isSortingEnabled();
    m_table->setSortingEnabled(false);
    m_table->setRowCount(m_hits.size());
    for (int row = 0; row < m_hits.size(); ++row) {
        const SearchHit &hit = m_hits.at(row);
        m_table->setItem(row, GroupColumn, new QTableWidgetItem(hit.groupName));
        m_table->setItem(row, BausteinColumn, new QTableWidgetItem(hit.bausteinLabel));
        m_table->setItem(row, RequirementColumn, new QTableWidgetItem(hit.requirementLabel));
        m_table->setItem(row, FieldColumn, new QTableWidgetItem(hit.matchField));
        m_table->setItem(row, SnippetColumn, new QTableWidgetItem(hit.snippet));
    }
    m_table->setSortingEnabled(wasSorting);

    if (!m_hits.isEmpty()) {
        m_table->selectRow(0);
        showHitAt(0);
    } else {
        m_preview->clear();
        if (!needle.isEmpty())
            m_preview->setPlainText(tr("Keine Treffer für \"%1\".").arg(needle));
    }
}

void CatalogSearchDialog::showHitAt(int row)
{
    if (row < 0 || row >= m_hits.size()) {
        m_preview->clear();
        return;
    }

    const SearchHit &hit = m_hits.at(row);

    QString previewText = tr("Baustein: %1\nKapitel: %2\nFundstelle: %3\n")
                              .arg(hit.bausteinLabel, hit.groupName, hit.matchField);
    if (hit.requirementId != 0)
        previewText += tr("Anforderung: %1\n\n").arg(hit.requirementLabel);
    else
        previewText += QLatin1Char('\n');

    if (hit.requirementId != 0) {
        for (const Requirement &requirement : m_requirements) {
            if (requirement.id == hit.requirementId) {
                previewText += requirement.text;
                break;
            }
        }
    } else {
        previewText += tr("Treffer im Baustein selbst. „Baustein öffnen…“ zeigt alle Anforderungen.");
    }

    m_preview->setPlainText(previewText);
}

void CatalogSearchDialog::openSelectedHit()
{
    const int row = m_table->currentRow();
    if (row < 0 || row >= m_hits.size())
        return;

    const SearchHit &hit = m_hits.at(row);
    const Baustein baustein = m_bausteinById.value(hit.bausteinDbId);
    if (baustein.id == 0)
        return;

    QList<Requirement> requirements;
    for (const Requirement &requirement : m_requirements) {
        if (requirement.bausteinDbId == baustein.id)
            requirements.append(requirement);
    }

    BausteinViewDialog dialog(baustein, requirements, m_searchEdit->text().trimmed(),
                              hit.requirementId, this);
    dialog.exec();
}
