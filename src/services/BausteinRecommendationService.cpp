#include "BausteinRecommendationService.h"

QString BausteinRecommendationService::bausteinPrefix(const QString &externalId)
{
    const int dotIndex = externalId.indexOf('.');
    if (dotIndex <= 0)
        return externalId.trimmed().toUpper();
    return externalId.left(dotIndex).trimmed().toUpper();
}

QStringList BausteinRecommendationService::recommendedPrefixes(TargetObjectType type)
{
    switch (type) {
    case TargetObjectType::Scope:
        return {QStringLiteral("ISMS"), QStringLiteral("ORP"), QStringLiteral("CON")};
    case TargetObjectType::Process:
        return {QStringLiteral("ORP"), QStringLiteral("CON"), QStringLiteral("OPS")};
    case TargetObjectType::Application:
        return {QStringLiteral("APP")};
    case TargetObjectType::ITSystem:
        return {QStringLiteral("SYS"), QStringLiteral("OPS"), QStringLiteral("DER"),
                QStringLiteral("IND")};
    case TargetObjectType::Network:
        return {QStringLiteral("NET")};
    case TargetObjectType::Infrastructure:
        return {QStringLiteral("INF"), QStringLiteral("NET"), QStringLiteral("IND")};
    }
    return {};
}

QString BausteinRecommendationService::recommendationHint(TargetObjectType type)
{
    const QStringList prefixes = recommendedPrefixes(type);
    if (prefixes.isEmpty())
        return QString();

    return QStringLiteral("Empfohlene Baustein-Gruppen für %1: %2")
        .arg(targetObjectTypeToString(type), prefixes.join(QStringLiteral(", ")));
}

bool BausteinRecommendationService::isRecommended(const Baustein &baustein, TargetObjectType type)
{
    return recommendedPrefixes(type).contains(bausteinPrefix(baustein.externalId));
}

QList<Baustein> BausteinRecommendationService::filterRecommended(const QList<Baustein> &bausteine,
                                                                 TargetObjectType type)
{
    QList<Baustein> result;
    for (const Baustein &baustein : bausteine) {
        if (isRecommended(baustein, type))
            result.append(baustein);
    }
    return result;
}
