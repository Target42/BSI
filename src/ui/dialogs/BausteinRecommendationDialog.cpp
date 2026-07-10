#include "BausteinRecommendationDialog.h"

#include "domain/ProtectionNeed.h"
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
    TierColumn,
    ReasonColumn,
    StatusColumn,
    ColumnCount
};

} // namespace

BausteinRecommendationDialog::BausteinRecommendationDialog(
    const QList<BausteinRecommendation> &recommendations,
    const QHash<int, ApplicabilityStatus> &currentApplicability,
    const TargetObject &targetObject,
    QWidget *parent)
    : QDialog(parent)
    , m_recommendations(recommendations)
    , m_currentApplicability(currentApplicability)
    , m_targetObject(targetObject)
{
    setWindowTitle(tr("Baustein-Empfehlungen übernehmen"));
    resize(920, 520);

    const QString hintText =
        tr("Zielobjekt \"%1\" (%2, %3)\n\n%4")
            .arg(m_targetObject.name,
                 targetObjectTypeToString(m_targetObject.type),
                 protectionNeedToString(m_targetObject.protectionNeed),
                 BausteinRecommendationService::recommendationHint(m_targetObject));

    auto *hint = new QLabel(hintText, this);
    hint->setWordWrap(true);

    m_table = new QTableWidget(this);
    m_table->setColumnCount(ColumnCount);
    m_table->setHorizontalHeaderLabels(
        {tr("Übernehmen"), tr("Baustein"), tr("Empfehlung"), tr("Begründung"), tr("Aktuell")});
    m_table->horizontalHeader()->setSectionResizeMode(BausteinColumn, QHeaderView::Stretch);
    m_table->horizontalHeader()->setSectionResizeMode(ReasonColumn, QHeaderView::Stretch);
    m_table->horizontalHeader()->setSectionResizeMode(SelectColumn, QHeaderView::ResizeToContents);
    m_table->horizontalHeader()->setSectionResizeMode(TierColumn, QHeaderView::ResizeToContents);
    m_table->horizontalHeader()->setSectionResizeMode(StatusColumn, QHeaderView::ResizeToContents);
    m_table->setSelectionMode(QAbstractItemView::NoSelection);
    m_table->setEditTriggers(QAbstractItemView::NoEditTriggers);
    populateTable();
    connect(m_table, &QTableWidget::cellDoubleClicked, this, [this](int row, int) {
        auto *checkBox = qobject_cast<QCheckBox *>(m_table->cellWidget(row, SelectColumn));
        if (checkBox != nullptr && checkBox->isEnabled())
            checkBox->setChecked(!checkBox->isChecked());
    });

    auto *statusRow = new QHBoxLayout();
    statusRow->addWidget(new QLabel(tr("Markieren als:"), this));
    m_statusBox = new QComboBox(this);
    m_statusBox->addItem(applicabilityStatusToString(ApplicabilityStatus::Possible),
                         static_cast<int>(ApplicabilityStatus::Possible));
    m_statusBox->addItem(applicabilityStatusToString(ApplicabilityStatus::Required),
                         static_cast<int>(ApplicabilityStatus::Required));
    statusRow->addWidget(m_statusBox, 1);
    m_statusBox->setCurrentIndex(m_statusBox->findData(static_cast<int>(ApplicabilityStatus::Required)));

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
    m_table->setRowCount(m_recommendations.size());

    for (int row = 0; row < m_recommendations.size(); ++row) {
        const BausteinRecommendation &recommendation = m_recommendations.at(row);
        const ApplicabilityStatus currentStatus =
            m_currentApplicability.value(recommendation.bausteinDbId, ApplicabilityStatus::Undefined);

        auto *checkBox = new QCheckBox(this);
        checkBox->setProperty("bausteinId", recommendation.bausteinDbId);
        checkBox->setProperty("suggestedStatus",
                              static_cast<int>(recommendation.suggestedStatus));
        if (currentStatus == ApplicabilityStatus::Undefined) {
            checkBox->setChecked(recommendation.tier == BausteinRecommendationTier::Core);
        } else {
            checkBox->setEnabled(false);
        }

        m_table->setCellWidget(row, SelectColumn, checkBox);
        m_table->setItem(row, BausteinColumn,
                         new QTableWidgetItem(
                             QStringLiteral("%1 %2").arg(recommendation.externalId, recommendation.title)));
        m_table->setItem(row, TierColumn,
                         new QTableWidgetItem(bausteinRecommendationTierToString(recommendation.tier)));
        m_table->setItem(row, ReasonColumn, new QTableWidgetItem(recommendation.reason));
        m_table->setItem(row, StatusColumn,
                         new QTableWidgetItem(applicabilityStatusToString(currentStatus)));
    }
}

QList<BausteinRecommendationSelection> BausteinRecommendationDialog::selections() const
{
    const auto defaultStatus = static_cast<ApplicabilityStatus>(m_statusBox->currentData().toInt());
    QList<BausteinRecommendationSelection> result;

    for (int row = 0; row < m_table->rowCount(); ++row) {
        const auto *checkBox = qobject_cast<const QCheckBox *>(m_table->cellWidget(row, SelectColumn));
        if (checkBox == nullptr || !checkBox->isChecked())
            continue;

        BausteinRecommendationSelection selection;
        selection.bausteinDbId = checkBox->property("bausteinId").toInt();
        selection.status = defaultStatus;
        result.append(selection);
    }

    return result;
}
