#include "BausteinViewDialog.h"

#include "domain/RequirementLevel.h"

#include <QDialogButtonBox>
#include <QHeaderView>
#include <QLabel>
#include <QLineEdit>
#include <QTableWidget>
#include <QTextEdit>
#include <QVBoxLayout>

namespace {

enum RequirementColumn {
    IdColumn = 0,
    TitleColumn,
    LevelColumn,
    RoleColumn,
    ColumnCount
};

bool textContains(const QString &haystack, const QString &needle)
{
    return haystack.contains(needle, Qt::CaseInsensitive);
}

} // namespace

BausteinViewDialog::BausteinViewDialog(const Baustein &baustein,
                                       const QList<Requirement> &requirements,
                                       const QString &initialSearch,
                                       int initialRequirementId,
                                       QWidget *parent)
    : QDialog(parent)
    , m_baustein(baustein)
    , m_requirements(requirements)
{
    setWindowTitle(tr("%1 – %2").arg(baustein.externalId, baustein.title));
    resize(980, 640);

    const QString headerText =
        tr("<b>%1 %2</b><br>%3")
            .arg(baustein.externalId.toHtmlEscaped(),
                 baustein.title.toHtmlEscaped(),
                 baustein.groupName.toHtmlEscaped());
    auto *header = new QLabel(headerText, this);
    header->setWordWrap(true);
    header->setTextFormat(Qt::RichText);

    m_searchEdit = new QLineEdit(this);
    m_searchEdit->setPlaceholderText(tr("In Anforderungen suchen…"));
    m_searchEdit->setClearButtonEnabled(true);
    if (!initialSearch.isEmpty())
        m_searchEdit->setText(initialSearch);
    connect(m_searchEdit, &QLineEdit::textChanged, this, &BausteinViewDialog::applyRequirementSearch);

    m_table = new QTableWidget(this);
    m_table->setColumnCount(ColumnCount);
    m_table->setHorizontalHeaderLabels(
        {tr("Anforderung"), tr("Titel"), tr("Stufe"), tr("Rolle")});
    m_table->horizontalHeader()->setSectionResizeMode(IdColumn, QHeaderView::ResizeToContents);
    m_table->horizontalHeader()->setSectionResizeMode(TitleColumn, QHeaderView::Stretch);
    m_table->horizontalHeader()->setSectionResizeMode(LevelColumn, QHeaderView::ResizeToContents);
    m_table->horizontalHeader()->setSectionResizeMode(RoleColumn, QHeaderView::ResizeToContents);
    m_table->setSelectionBehavior(QAbstractItemView::SelectRows);
    m_table->setSelectionMode(QAbstractItemView::SingleSelection);
    m_table->setEditTriggers(QAbstractItemView::NoEditTriggers);
    m_table->setAlternatingRowColors(true);
    connect(m_table, &QTableWidget::currentCellChanged, this,
            [this](int currentRow, int, int, int) {
                showRequirementAt(currentRow);
            });

    m_text = new QTextEdit(this);
    m_text->setReadOnly(true);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Close, this);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);
    connect(buttons, &QDialogButtonBox::accepted, this, &QDialog::accept);

    auto *layout = new QVBoxLayout(this);
    layout->addWidget(header);
    layout->addWidget(m_searchEdit);
    layout->addWidget(m_table, 2);
    layout->addWidget(m_text, 3);
    layout->addWidget(buttons);

    populateRequirements();
    if (initialRequirementId != 0)
        selectRequirementById(initialRequirementId);
    else if (!initialSearch.isEmpty())
        applyRequirementSearch(initialSearch);
    else if (m_table->rowCount() > 0)
        m_table->selectRow(0);
}

void BausteinViewDialog::selectRequirementById(int requirementId)
{
    for (int row = 0; row < m_requirements.size(); ++row) {
        if (m_requirements.at(row).id != requirementId)
            continue;
        m_table->setRowHidden(row, false);
        m_table->selectRow(row);
        showRequirementAt(row);
        return;
    }
}

void BausteinViewDialog::populateRequirements()
{
    m_table->setRowCount(m_requirements.size());

    for (int row = 0; row < m_requirements.size(); ++row) {
        const Requirement &requirement = m_requirements.at(row);
        QString idLabel = requirement.externalId;
        if (requirement.withdrawn)
            idLabel += tr(" (zurückgezogen)");

        m_table->setItem(row, IdColumn, new QTableWidgetItem(idLabel));
        m_table->setItem(row, TitleColumn, new QTableWidgetItem(requirement.title));
        m_table->setItem(row, LevelColumn,
                         new QTableWidgetItem(requirementLevelToString(requirement.level)));
        m_table->setItem(row, RoleColumn, new QTableWidgetItem(requirement.responsibleRole));
        m_table->setRowHidden(row, false);
    }
}

void BausteinViewDialog::showRequirementAt(int row)
{
    if (row < 0 || row >= m_requirements.size()) {
        m_text->clear();
        return;
    }

    const Requirement &requirement = m_requirements.at(row);
    m_text->setPlainText(requirement.text);
}

void BausteinViewDialog::applyRequirementSearch(const QString &query)
{
    const QString needle = query.trimmed();
    int firstVisibleRow = -1;

    for (int row = 0; row < m_requirements.size(); ++row) {
        const Requirement &requirement = m_requirements.at(row);
        const bool visible = needle.isEmpty()
                             || textContains(requirement.externalId, needle)
                             || textContains(requirement.title, needle)
                             || textContains(requirement.text, needle)
                             || textContains(requirement.responsibleRole, needle);
        m_table->setRowHidden(row, !visible);
        if (visible && firstVisibleRow < 0)
            firstVisibleRow = row;
    }

    if (firstVisibleRow >= 0) {
        m_table->selectRow(firstVisibleRow);
    } else {
        m_table->clearSelection();
        m_text->clear();
    }
}
