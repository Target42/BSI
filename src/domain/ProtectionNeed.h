#ifndef DOMAIN_PROTECTIONNEED_H
#define DOMAIN_PROTECTIONNEED_H

#include "RequirementLevel.h"

#include <QString>

enum class ProtectionNeed {
    BasisOnly,
    Normal,
    Elevated
};

enum class CiaLevel {
    Normal,
    High,
    VeryHigh
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

inline QString ciaLevelToString(CiaLevel level)
{
    switch (level) {
    case CiaLevel::High:
        return QStringLiteral("hoch");
    case CiaLevel::VeryHigh:
        return QStringLiteral("sehr hoch");
    case CiaLevel::Normal:
        break;
    }
    return QStringLiteral("normal");
}

inline CiaLevel ciaLevelFromString(const QString &value)
{
    const QString normalized = value.trimmed().toLower();
    if (normalized == QStringLiteral("hoch") || normalized == QStringLiteral("high"))
        return CiaLevel::High;
    if (normalized == QStringLiteral("sehr hoch") || normalized == QStringLiteral("sehrhoch")
        || normalized == QStringLiteral("very high"))
        return CiaLevel::VeryHigh;
    return CiaLevel::Normal;
}

inline CiaLevel maxCiaLevel(CiaLevel left, CiaLevel right)
{
    return static_cast<int>(left) >= static_cast<int>(right) ? left : right;
}

inline ProtectionNeed protectionNeedFromCiaLevels(CiaLevel confidentiality, CiaLevel integrity,
                                                 CiaLevel availability)
{
    if (maxCiaLevel(maxCiaLevel(confidentiality, integrity), availability) > CiaLevel::Normal)
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
