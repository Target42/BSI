#include "ReportDialog.h"

#include "services/ReportExporter.h"
#include "services/ReportService.h"

#include <QComboBox>
#include <QDialogButtonBox>
#include <QFileDialog>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QLabel>
#include <QMessageBox>
#include <QPushButton>
#include <QVBoxLayout>
#include <QTableView>

ReportDialog::ReportDialog(AppContext &context,
                           const Project &project,
                           const TargetObject &targetObject,
                           QWidget *parent)
    : QDialog(parent)
    , m_context(context)
    , m_project(project)
    , m_targetObject(targetObject)
{
    setWindowTitle(tr("Soll-Ist-Bericht"));
    resize(1100, 650);

    m_model = new ReportTableModel(this);
    m_table = new QTableView(this);
    m_table->setModel(m_model);
    m_table->setAlternatingRowColors(true);
    m_table->horizontalHeader()->setStretchLastSection(true);
    m_table->horizontalHeader()->setSectionResizeMode(ReportTableModel::RequirementColumn,
                                                      QHeaderView::Stretch);
    m_table->setSelectionBehavior(QAbstractItemView::SelectRows);

    m_scopeBox = new QComboBox(this);
    m_scopeBox->addItem(tr("Gesamtes Projekt"), 0);
    if (targetObject.id != 0) {
        m_scopeBox->addItem(tr("Aktuelles Zielobjekt: %1").arg(targetObject.name), targetObject.id);
        m_scopeBox->setCurrentIndex(1);
    }
    connect(m_scopeBox, QOverload<int>::of(&QComboBox::currentIndexChanged), this,
            [this](int) { refreshReport(); });

    m_summaryLabel = new QLabel(this);
    m_summaryLabel->setWordWrap(true);

    auto *refreshButton = new QPushButton(tr("Aktualisieren"), this);
    connect(refreshButton, &QPushButton::clicked, this, &ReportDialog::refreshReport);

    auto *csvButton = new QPushButton(tr("Als CSV exportieren..."), this);
    auto *pdfButton = new QPushButton(tr("Als PDF exportieren..."), this);
    connect(csvButton, &QPushButton::clicked, this, &ReportDialog::exportCsv);
    connect(pdfButton, &QPushButton::clicked, this, &ReportDialog::exportPdf);

    auto *scopeRow = new QHBoxLayout();
    scopeRow->addWidget(new QLabel(tr("Berichtsumfang"), this));
    scopeRow->addWidget(m_scopeBox, 1);
    scopeRow->addWidget(refreshButton);

    auto *exportRow = new QHBoxLayout();
    exportRow->addWidget(csvButton);
    exportRow->addWidget(pdfButton);
    exportRow->addStretch();

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Close, this);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);

    auto *layout = new QVBoxLayout(this);
    layout->addLayout(scopeRow);
    layout->addWidget(m_summaryLabel);
    layout->addWidget(m_table, 1);
    layout->addLayout(exportRow);
    layout->addWidget(buttons);

    refreshReport();
}

void ReportDialog::refreshReport()
{
    ReportService service(m_context.catalogRepository(),
                          m_context.projectRepository(),
                          m_context.targetObjectRepository(),
                          m_context.measureRepository());

    const int targetObjectId = m_scopeBox->currentData().toInt();
    m_rows = service.buildSollIstReport(m_project.id, targetObjectId, m_context.catalogVersion());
    m_summary = service.summarize(m_rows);

    m_model->setRows(m_rows);
    updateSummary(m_summary);
}

void ReportDialog::updateSummary(const ReportSummary &summary)
{
    m_summaryLabel->setText(
        tr("Anforderungen: %1 | Offen: %2 | Teilweise: %3 | Erfüllt: %4 | Entfällt: %5 | "
           "Überfällig: %6 | Maßnahmen: %7")
            .arg(summary.totalRequirements)
            .arg(summary.openCount)
            .arg(summary.partialCount)
            .arg(summary.fulfilledCount)
            .arg(summary.notApplicableCount)
            .arg(summary.overdueCount)
            .arg(summary.measureCount));
}

void ReportDialog::exportCsv()
{
    if (m_rows.isEmpty()) {
        QMessageBox::information(this, tr("Export"), tr("Keine Daten für den Export vorhanden."));
        return;
    }

    const QString filePath = QFileDialog::getSaveFileName(
        this,
        tr("CSV exportieren"),
        QStringLiteral("soll-ist-%1.csv").arg(m_project.name),
        tr("CSV Dateien (*.csv)"));
    if (filePath.isEmpty())
        return;

    QString errorMessage;
    if (!ReportExporter::exportCsv(filePath, m_rows, errorMessage)) {
        QMessageBox::critical(this, tr("Export fehlgeschlagen"), errorMessage);
        return;
    }

    QMessageBox::information(this, tr("Export"), tr("CSV wurde gespeichert:\n%1").arg(filePath));
}

void ReportDialog::exportPdf()
{
    if (m_rows.isEmpty()) {
        QMessageBox::information(this, tr("Export"), tr("Keine Daten für den Export vorhanden."));
        return;
    }

    const QString filePath = QFileDialog::getSaveFileName(
        this,
        tr("PDF exportieren"),
        QStringLiteral("soll-ist-%1.pdf").arg(m_project.name),
        tr("PDF Dateien (*.pdf)"));
    if (filePath.isEmpty())
        return;

    QString errorMessage;
    if (!ReportExporter::exportPdf(filePath, m_project, m_summary, m_rows, errorMessage)) {
        QMessageBox::critical(this, tr("Export fehlgeschlagen"), errorMessage);
        return;
    }

    QMessageBox::information(this, tr("Export"), tr("PDF wurde gespeichert:\n%1").arg(filePath));
}
