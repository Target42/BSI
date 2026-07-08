#ifndef SERVICES_REPORTSERVICE_H
#define SERVICES_REPORTSERVICE_H

#include "domain/ReportRow.h"
#include "persistence/CatalogRepository.h"
#include "persistence/MeasureRepository.h"
#include "persistence/ProjectRepository.h"
#include "persistence/TargetObjectRepository.h"

#include <QList>

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

private:
    CatalogRepository &m_catalog;
    ProjectRepository &m_project;
    TargetObjectRepository &m_targetObjects;
    MeasureRepository &m_measures;
};

#endif
