#ifndef UI_REPORTDIALOG_H
#define UI_REPORTDIALOG_H

#include "app/AppContext.h"
#include "domain/Project.h"
#include "domain/ReportRow.h"
#include "domain/TargetObject.h"
#include "ui/models/ReportTableModel.h"

#include <QDialog>

class QComboBox;
class QLabel;
class QTableView;

class ReportDialog : public QDialog
{
    Q_OBJECT

public:
    ReportDialog(AppContext &context, const Project &project, const TargetObject &targetObject, QWidget *parent = nullptr);

private slots:
    void refreshReport();
    void exportCsv();
    void exportPdf();

private:
    void updateSummary(const ReportSummary &summary);

    AppContext &m_context;
    Project m_project;
    TargetObject m_targetObject;

    QList<ReportRow> m_rows;
    ReportSummary m_summary;

    ReportTableModel *m_model = nullptr;
    QTableView *m_table = nullptr;
    QLabel *m_summaryLabel = nullptr;
    QComboBox *m_scopeBox = nullptr;
};

#endif
