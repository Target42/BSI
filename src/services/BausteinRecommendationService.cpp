#include "BausteinRecommendationService.h"

#include <QHash>
#include <algorithm>

namespace {

struct PrefixRule {
    QString prefix;
    BausteinRecommendationTier tier;
    ApplicabilityStatus suggestedStatus;
    QString reason;
};

void addRule(QList<PrefixRule> &rules,
             const QString &prefix,
             BausteinRecommendationTier tier,
             ApplicabilityStatus suggestedStatus,
             const QString &reason)
{
    for (const PrefixRule &existing : rules) {
        if (existing.prefix == prefix)
            return;
    }

    PrefixRule rule;
    rule.prefix = prefix;
    rule.tier = tier;
    rule.suggestedStatus = suggestedStatus;
    rule.reason = reason;
    rules.append(rule);
}

void addCoreRules(QList<PrefixRule> &rules,
                  const QStringList &prefixes,
                  const QString &reason,
                  ApplicabilityStatus suggestedStatus = ApplicabilityStatus::Required)
{
    for (const QString &prefix : prefixes)
        addRule(rules, prefix, BausteinRecommendationTier::Core, suggestedStatus, reason);
}

void addSupplementaryRules(QList<PrefixRule> &rules,
                           const QStringList &prefixes,
                           const QString &reason,
                           ApplicabilityStatus suggestedStatus = ApplicabilityStatus::Possible)
{
    for (const QString &prefix : prefixes)
        addRule(rules, prefix, BausteinRecommendationTier::Supplementary, suggestedStatus, reason);
}

QList<PrefixRule> rulesForTarget(const TargetObject &targetObject)
{
    QList<PrefixRule> rules;
    const bool elevated = targetObject.protectionNeed == ProtectionNeed::Elevated;

    switch (targetObject.type) {
    case TargetObjectType::Scope:
        addCoreRules(rules,
                     {QStringLiteral("ISMS"), QStringLiteral("ORP"), QStringLiteral("CON")},
                     QStringLiteral("Organisationsweite Grundbausteine für den Informationsverbund"));
        addSupplementaryRules(rules,
                              {QStringLiteral("OPS")},
                              QStringLiteral("Betriebliche Querschnittsaspekte im Gesamtverbund"));
        if (elevated)
            addSupplementaryRules(rules,
                                  {QStringLiteral("DER")},
                                  QStringLiteral("Erkennung und Reaktion bei erhöhtem Schutzbedarf"),
                                  ApplicabilityStatus::Required);
        break;

    case TargetObjectType::Process:
        addCoreRules(rules,
                     {QStringLiteral("ORP"), QStringLiteral("OPS")},
                     QStringLiteral("Organisation, Personal und Betrieb für Geschäftsprozesse"));
        addSupplementaryRules(rules,
                              {QStringLiteral("CON")},
                              QStringLiteral("Übergreifende Konfiguration und Steuerung"));
        if (elevated)
            addSupplementaryRules(rules,
                                  {QStringLiteral("DER"), QStringLiteral("ISMS")},
                                  QStringLiteral("Zusätzliche Schutz- und Steuerungsaspekte bei erhöhtem Schutzbedarf"));
        break;

    case TargetObjectType::Application:
        addCoreRules(rules,
                     {QStringLiteral("APP")},
                     QStringLiteral("Anwendungsspezifische IT-Grundschutz-Bausteine"));
        addSupplementaryRules(rules,
                              {QStringLiteral("OPS"), QStringLiteral("CON")},
                              QStringLiteral("Betrieb und Konfiguration der Anwendungsumgebung"));
        if (elevated)
            addSupplementaryRules(rules,
                                  {QStringLiteral("DER"), QStringLiteral("SYS")},
                                  QStringLiteral("System- und Reaktionsaspekte bei erhöhtem Schutzbedarf"));
        break;

    case TargetObjectType::ITSystem:
        addCoreRules(rules,
                     {QStringLiteral("SYS"), QStringLiteral("OPS")},
                     QStringLiteral("System- und Betriebsbausteine für IT-Systeme"));
        addSupplementaryRules(rules,
                              {QStringLiteral("CON"), QStringLiteral("NET")},
                              QStringLiteral("Einbindung in Konfiguration und Netzwerk"));
        addSupplementaryRules(rules,
                              {QStringLiteral("IND")},
                              QStringLiteral("Industrielle oder spezialisierte Systemumgebungen"));
        if (elevated)
            addSupplementaryRules(rules,
                                  {QStringLiteral("DER")},
                                  QStringLiteral("Erkennung und Reaktion bei erhöhtem Schutzbedarf"),
                                  ApplicabilityStatus::Required);
        break;

    case TargetObjectType::Network:
        addCoreRules(rules,
                     {QStringLiteral("NET")},
                     QStringLiteral("Netz- und Kommunikationsbausteine"));
        addSupplementaryRules(rules,
                              {QStringLiteral("INF"), QStringLiteral("OPS"), QStringLiteral("CON")},
                              QStringLiteral("Infrastruktur, Betrieb und Konfiguration der Verbindung"));
        if (elevated)
            addSupplementaryRules(rules,
                                  {QStringLiteral("DER")},
                                  QStringLiteral("Überwachung und Reaktion bei erhöhtem Schutzbedarf"),
                                  ApplicabilityStatus::Required);
        break;

    case TargetObjectType::Infrastructure:
        addCoreRules(rules,
                     {QStringLiteral("INF")},
                     QStringLiteral("Infrastrukturbausteine für Räume, Gebäude und Anlagen"));
        addSupplementaryRules(rules,
                              {QStringLiteral("NET"), QStringLiteral("OPS"), QStringLiteral("IND")},
                              QStringLiteral("Anbindung, Betrieb und spezialisierte Infrastruktur"));
        if (elevated)
            addSupplementaryRules(rules,
                                  {QStringLiteral("DER"), QStringLiteral("CON")},
                                  QStringLiteral("Zusätzliche Schutz- und Steuerungsaspekte bei erhöhtem Schutzbedarf"));
        break;
    }

    return rules;
}

} // namespace

QString BausteinRecommendationService::bausteinPrefix(const QString &externalId)
{
    const int dotIndex = externalId.indexOf('.');
    if (dotIndex <= 0)
        return externalId.trimmed().toUpper();
    return externalId.left(dotIndex).trimmed().toUpper();
}

BausteinRecommendation BausteinRecommendationService::recommendationForBaustein(
    const Baustein &baustein,
    BausteinRecommendationTier tier,
    ApplicabilityStatus suggestedStatus,
    const QString &reason)
{
    BausteinRecommendation recommendation;
    recommendation.bausteinDbId = baustein.id;
    recommendation.externalId = baustein.externalId;
    recommendation.title = baustein.title;
    recommendation.groupName = baustein.groupName;
    recommendation.tier = tier;
    recommendation.suggestedStatus = suggestedStatus;
    recommendation.reason = reason;
    if (!baustein.groupName.isEmpty())
        recommendation.reason = QStringLiteral("%1 (%2)").arg(reason, baustein.groupName);
    return recommendation;
}

QList<BausteinRecommendation> BausteinRecommendationService::buildRecommendations(
    const QList<Baustein> &bausteine,
    const TargetObject &targetObject)
{
    const QList<PrefixRule> rules = rulesForTarget(targetObject);
    QHash<QString, PrefixRule> bestRuleByPrefix;
    for (const PrefixRule &rule : rules)
        bestRuleByPrefix.insert(rule.prefix, rule);

    QHash<int, BausteinRecommendation> recommendations;
    for (const Baustein &baustein : bausteine) {
        const PrefixRule rule = bestRuleByPrefix.value(bausteinPrefix(baustein.externalId));
        if (rule.prefix.isEmpty())
            continue;

        BausteinRecommendation recommendation =
            recommendationForBaustein(baustein, rule.tier, rule.suggestedStatus, rule.reason);
        const BausteinRecommendation existing = recommendations.value(baustein.id);
        if (existing.bausteinDbId == 0
            || (existing.tier == BausteinRecommendationTier::Supplementary
                && recommendation.tier == BausteinRecommendationTier::Core)) {
            recommendations.insert(baustein.id, recommendation);
        }
    }

    QList<BausteinRecommendation> result = recommendations.values();
    std::sort(result.begin(), result.end(), [](const BausteinRecommendation &a,
                                               const BausteinRecommendation &b) {
        if (a.tier != b.tier)
            return a.tier == BausteinRecommendationTier::Core;
        return a.externalId < b.externalId;
    });
    return result;
}

QList<Baustein> BausteinRecommendationService::filterRecommendedBausteine(
    const QList<Baustein> &bausteine,
    const TargetObject &targetObject)
{
    const QList<BausteinRecommendation> recommendations = buildRecommendations(bausteine, targetObject);
    QHash<int, Baustein> bausteinById;
    for (const Baustein &baustein : bausteine)
        bausteinById.insert(baustein.id, baustein);

    QList<Baustein> result;
    for (const BausteinRecommendation &recommendation : recommendations) {
        const Baustein baustein = bausteinById.value(recommendation.bausteinDbId);
        if (baustein.id != 0)
            result.append(baustein);
    }
    return result;
}

bool BausteinRecommendationService::isRecommended(const Baustein &baustein,
                                                  const TargetObject &targetObject)
{
    const QList<PrefixRule> rules = rulesForTarget(targetObject);
    const QString prefix = bausteinPrefix(baustein.externalId);
    for (const PrefixRule &rule : rules) {
        if (rule.prefix == prefix)
            return true;
    }
    return false;
}

QString BausteinRecommendationService::recommendationHint(const TargetObject &targetObject)
{
    const QList<PrefixRule> rules = rulesForTarget(targetObject);
    if (rules.isEmpty())
        return QString();

    QStringList corePrefixes;
    QStringList supplementaryPrefixes;
    for (const PrefixRule &rule : rules) {
        if (rule.tier == BausteinRecommendationTier::Core) {
            if (!corePrefixes.contains(rule.prefix))
                corePrefixes.append(rule.prefix);
        } else if (!supplementaryPrefixes.contains(rule.prefix)) {
            supplementaryPrefixes.append(rule.prefix);
        }
    }

    QString hint = QStringLiteral("Kern-Bausteine: %1").arg(corePrefixes.join(QStringLiteral(", ")));
    if (!supplementaryPrefixes.isEmpty()) {
        hint += QStringLiteral("\nErgänzende Bausteine: %1")
                    .arg(supplementaryPrefixes.join(QStringLiteral(", ")));
    }
    hint += QStringLiteral("\nSchutzbedarf: %1").arg(protectionNeedToString(targetObject.protectionNeed));
    if (targetObject.protectionNeed == ProtectionNeed::Elevated) {
        hint += QStringLiteral("\nBei erhöhtem Schutzbedarf werden zusätzliche Bausteine (z. B. DER) empfohlen.");
    }
    return hint;
}
