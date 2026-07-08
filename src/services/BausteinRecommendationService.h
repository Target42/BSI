#ifndef SERVICES_BAUSTEINRECOMMENDATIONSERVICE_H
#define SERVICES_BAUSTEINRECOMMENDATIONSERVICE_H

#include "domain/Baustein.h"
#include "domain/TargetObjectType.h"

#include <QList>
#include <QStringList>

class BausteinRecommendationService
{
public:
    static QString bausteinPrefix(const QString &externalId);
    static QStringList recommendedPrefixes(TargetObjectType type);
    static QString recommendationHint(TargetObjectType type);

    static bool isRecommended(const Baustein &baustein, TargetObjectType type);
    static QList<Baustein> filterRecommended(const QList<Baustein> &bausteine, TargetObjectType type);
};

#endif
