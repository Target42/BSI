#ifndef SERVICES_REPORTSERVICE_H
#define SERVICES_REPORTSERVICE_H

#include "domain/ReportRow.h"
#include "persistence/ICatalogRepository.h"
#include "persistence/IMeasureRepository.h"
#include "persistence/IProjectRepository.h"
#include "persistence/ITargetObjectRepository.h"

#include <QHash>
#include <QList>
#include <QString>

class ReportService
{
public:
    ReportService(ICatalogRepository &catalog,
                  IProjectRepository &project,
                  ITargetObjectRepository &targetObjects,
                  IMeasureRepository &measures);

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
    ICatalogRepository &m_catalog;
    IProjectRepository &m_project;
    ITargetObjectRepository &m_targetObjects;
    IMeasureRepository &m_measures;
};

#endif
