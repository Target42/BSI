#ifndef DOMAIN_BAUSTEINRECOMMENDATION_H
#define DOMAIN_BAUSTEINRECOMMENDATION_H

#include "ApplicabilityStatus.h"

#include <QString>

enum class BausteinRecommendationTier {
    Core,
    Supplementary
};

inline QString bausteinRecommendationTierToString(BausteinRecommendationTier tier)
{
    switch (tier) {
    case BausteinRecommendationTier::Core:
        return QStringLiteral("Kern");
    case BausteinRecommendationTier::Supplementary:
        return QStringLiteral("Ergänzend");
    }
    return QStringLiteral("Kern");
}

struct BausteinRecommendation {
    int bausteinDbId = 0;
    QString externalId;
    QString title;
    QString groupName;
    BausteinRecommendationTier tier = BausteinRecommendationTier::Core;
    ApplicabilityStatus suggestedStatus = ApplicabilityStatus::Possible;
    QString reason;
};

#endif
