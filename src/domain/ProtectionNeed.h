#ifndef DOMAIN_PROTECTIONNEED_H
#define DOMAIN_PROTECTIONNEED_H

#include "RequirementLevel.h"

#include <QString>

// IT-Grundschutz: welche Anforderungsstufen für ein Zielobjekt gelten
enum class ProtectionNeed {
    BasisOnly,
    Normal,
    Elevated
};

inline QString protectionNeedToString(ProtectionNeed need)
{
    switch (need) {
    case ProtectionNeed::BasisOnly:
        return QStringLiteral("Basis-Anforderungen");
    case ProtectionNeed::Normal:
        return QStringLiteral("Normal (Basis + Standard)");
    case ProtectionNeed::Elevated:
        return QStringLiteral("Erhöht (Basis + Standard + Erhöht)");
    }
    return QStringLiteral("Normal (Basis + Standard)");
}

inline ProtectionNeed protectionNeedFromString(const QString &value)
{
    const QString normalized = value.trimmed();
    if (normalized == QStringLiteral("Basis-Anforderungen"))
        return ProtectionNeed::BasisOnly;
    if (normalized.startsWith(QStringLiteral("Erhöht")))
        return ProtectionNeed::Elevated;
    return ProtectionNeed::Normal;
}

inline bool requirementLevelApplies(RequirementLevel level, ProtectionNeed need)
{
    if (level == RequirementLevel::Unknown)
        return true;

    switch (need) {
    case ProtectionNeed::BasisOnly:
        return level == RequirementLevel::Basis;
    case ProtectionNeed::Normal:
        return level == RequirementLevel::Basis || level == RequirementLevel::Standard;
    case ProtectionNeed::Elevated:
        return level == RequirementLevel::Basis || level == RequirementLevel::Standard
               || level == RequirementLevel::Erhoeht;
    }
    return true;
}

#endif
