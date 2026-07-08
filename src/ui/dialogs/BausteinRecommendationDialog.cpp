#include "BausteinRecommendationDialog.h"

#include "services/BausteinRecommendationService.h"

#include <QCheckBox>
#include <QComboBox>
#include <QDialogButtonBox>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QLabel>
#include <QTableWidget>
#include <QVBoxLayout>

namespace {

enum TableColumn {
    SelectColumn = 0,
    BausteinColumn,
    StatusColumn,
    ColumnCount
};

} // namespace

BausteinRecommendationDialog::BausteinRecommendationDialog(
    const QList<Baustein> &recommendedBausteine,
    const QHash<int, ApplicabilityStatus> &currentApplicability,
    const TargetObject &targetObject,
    QWidget *parent)
    : QDialog(parent)
    , m_bausteine(recommendedBausteine)
    , m_currentApplicability(currentApplicability)
    , m_targetObject(targetObject)
{
    setWindowTitle(tr("Baustein-Empfehlungen übernehmen"));
    resize(760, 480);

    const QString hintText =
        tr("Für Zielobjekt \"%1\" (%2) werden folgende IT-Grundschutz-Bausteine empfohlen.\n%3")
            .arg(m_targetObject.name,
                 targetObjectTypeToString(m_targetObject.type),
                 BausteinRecommendationService::recommendationHint(m_targetObject.type));

    auto *hint = new QLabel(hintText, this);
    hint->setWordWrap(true);

    m_table = new QTableWidget(this);
    m_table->setColumnCount(ColumnCount);
    m_table->setHorizontalHeaderLabels({tr("Übernehmen"), tr("Baustein"), tr("Aktuell")});
    m_table->horizontalHeader()->setSectionResizeMode(BausteinColumn, QHeaderView::Stretch);
    m_table->horizontalHeader()->setSectionResizeMode(SelectColumn, QHeaderView::ResizeToContents);
    m_table->horizontalHeader()->setSectionResizeMode(StatusColumn, QHeaderView::ResizeToContents);
    m_table->setSelectionMode(QAbstractItemView::NoSelection);
    m_table->setEditTriggers(QAbstractItemView::NoEditTriggers);
    populateTable();

    auto *statusRow = new QHBoxLayout();
    statusRow->addWidget(new QLabel(tr("Markieren als:"), this));
    m_statusBox = new QComboBox(this);
    m_statusBox->addItem(applicabilityStatusToString(ApplicabilityStatus::Possible),
                         static_cast<int>(ApplicabilityStatus::Possible));
    m_statusBox->addItem(applicabilityStatusToString(ApplicabilityStatus::Required),
                         static_cast<int>(ApplicabilityStatus::Required));
    statusRow->addWidget(m_statusBox, 1);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, this);
    connect(buttons, &QDialogButtonBox::accepted, this, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);

    auto *layout = new QVBoxLayout(this);
    layout->addWidget(hint);
    layout->addWidget(m_table, 1);
    layout->addLayout(statusRow);
    layout->addWidget(buttons);
}

void BausteinRecommendationDialog::populateTable()
{
    m_table->setRowCount(m_bausteine.size());

    for (int row = 0; row < m_bausteine.size(); ++row) {
        const Baustein &baustein = m_bausteine.at(row);
        const ApplicabilityStatus currentStatus =
            m_currentApplicability.value(baustein.id, ApplicabilityStatus::Undefined);

        auto *checkBox = new QCheckBox(this);
        checkBox->setProperty("bausteinId", baustein.id);
        if (currentStatus == ApplicabilityStatus::Undefined)
            checkBox->setChecked(true);
        else
            checkBox->setEnabled(false);

        m_table->setCellWidget(row, SelectColumn, checkBox);
        m_table->setItem(row, BausteinColumn,
                         new QTableWidgetItem(QStringLiteral("%1 %2").arg(baustein.externalId, baustein.title)));
        m_table->setItem(row, StatusColumn,
                         new QTableWidgetItem(applicabilityStatusToString(currentStatus)));
    }
}

QList<BausteinRecommendationSelection> BausteinRecommendationDialog::selections() const
{
    const auto status = static_cast<ApplicabilityStatus>(m_statusBox->currentData().toInt());
    QList<BausteinRecommendationSelection> result;

    for (int row = 0; row < m_table->rowCount(); ++row) {
        const auto *checkBox = qobject_cast<const QCheckBox *>(m_table->cellWidget(row, SelectColumn));
        if (checkBox == nullptr || !checkBox->isChecked())
            continue;

        BausteinRecommendationSelection selection;
        selection.bausteinDbId = checkBox->property("bausteinId").toInt();
        selection.status = status;
        result.append(selection);
    }

    return result;
}
