#ifndef SERVICES_REPORTEXPORTER_H
#define SERVICES_REPORTEXPORTER_H

#include "domain/Project.h"
#include "domain/ReportRow.h"

#include <QString>

class ReportExporter
{
public:
    static bool exportCsv(const QString &filePath, const QList<ReportRow> &rows, QString &errorMessage);
    static bool exportPdf(const QString &filePath,
                          const Project &project,
                          const ReportSummary &summary,
                          const QList<ReportRow> &rows,
                          QString &errorMessage);
};

#endif
