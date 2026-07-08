#ifndef SERVICES_BAUSTEINRECOMMENDATIONSERVICE_H
#define SERVICES_BAUSTEINRECOMMENDATIONSERVICE_H

#include "domain/Baustein.h"
#include "domain/BausteinRecommendation.h"
#include "domain/ProtectionNeed.h"
#include "domain/TargetObject.h"

#include <QList>
#include <QString>
#include <QStringList>

class BausteinRecommendationService
{
public:
    static QString bausteinPrefix(const QString &externalId);

    static QList<BausteinRecommendation> buildRecommendations(const QList<Baustein> &bausteine,
                                                              const TargetObject &targetObject);
    static QList<Baustein> filterRecommendedBausteine(const QList<Baustein> &bausteine,
                                                      const TargetObject &targetObject);
    static bool isRecommended(const Baustein &baustein, const TargetObject &targetObject);
    static QString recommendationHint(const TargetObject &targetObject);

private:
    static BausteinRecommendation recommendationForBaustein(const Baustein &baustein,
                                                            BausteinRecommendationTier tier,
                                                            ApplicabilityStatus suggestedStatus,
                                                            const QString &reason);
};

#endif
