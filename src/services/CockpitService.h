#ifndef SERVICES_COCKPITSERVICE_H
#define SERVICES_COCKPITSERVICE_H

#include "domain/CockpitItem.h"
#include "persistence/ICatalogRepository.h"
#include "persistence/IMeasureRepository.h"
#include "persistence/IProjectRepository.h"
#include "persistence/ITargetObjectRepository.h"

#include <QList>
#include <QString>

class CockpitService
{
public:
    CockpitService(ICatalogRepository &catalog,
                   IProjectRepository &project,
                   ITargetObjectRepository &targetObjects,
                   IMeasureRepository &measures);

    QList<CockpitItem> buildItems(int projectId, const QString &catalogVersion) const;
    static QList<CockpitItem> applyFilter(const QList<CockpitItem> &items, const CockpitFilter &filter);
    static CockpitSummary summarize(const QList<CockpitItem> &items);
    static QString formatSummary(const CockpitSummary &summary);

private:
    static bool responsibleMatches(const QString &responsible, const QString &name,
                                   const QString &email, const QString &needle);

    ICatalogRepository &m_catalog;
    IProjectRepository &m_project;
    ITargetObjectRepository &m_targetObjects;
    IMeasureRepository &m_measures;
};

#endif
