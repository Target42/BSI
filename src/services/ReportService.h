#ifndef SERVICES_REPORTSERVICE_H
#define SERVICES_REPORTSERVICE_H

#include "domain/ReportRow.h"
#include "persistence/CatalogRepository.h"
#include "persistence/MeasureRepository.h"
#include "persistence/ProjectRepository.h"
#include "persistence/TargetObjectRepository.h"

#include <QHash>
#include <QList>
#include <QString>

class ReportService
{
public:
    ReportService(CatalogRepository &catalog,
                  ProjectRepository &project,
                  TargetObjectRepository &targetObjects,
                  MeasureRepository &measures);

    QList<ReportRow> buildSollIstReport(int projectId,
                                        int targetObjectId,
                                        const QString &catalogVersion) const;
    ReportSummary summarize(const QList<ReportRow> &rows) const;
    QHash<int, ReportSummary> summarizeByTargetObject(int projectId,
                                                      const QString &catalogVersion) const;
    QHash<int, ReportSummary> summarizeByTargetObject(const QList<ReportRow> &rows) const;

    static int progressPercent(const ReportSummary &summary);
    static QString formatSummaryText(const ReportSummary &summary);
    static QString formatTreeProgressSuffix(const ReportSummary &summary);

private:
    CatalogRepository &m_catalog;
    ProjectRepository &m_project;
    TargetObjectRepository &m_targetObjects;
    MeasureRepository &m_measures;
};

#endif
