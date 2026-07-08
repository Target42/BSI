#ifndef DOMAIN_REQUIREMENTLEVEL_H
#define DOMAIN_REQUIREMENTLEVEL_H

#include <QString>

enum class RequirementLevel {
    Unknown = 0,
    Basis,
    Standard,
    Erhoeht
};

inline QString requirementLevelToString(RequirementLevel level)
{
    switch (level) {
    case RequirementLevel::Basis:
        return QStringLiteral("Basis");
    case RequirementLevel::Standard:
        return QStringLiteral("Standard");
    case RequirementLevel::Erhoeht:
        return QStringLiteral("Erhöht");
    case RequirementLevel::Unknown:
    default:
        return QStringLiteral("Unbekannt");
    }
}

inline RequirementLevel requirementLevelFromSectionTitle(const QString &title)
{
    if (title == QStringLiteral("Basis-Anforderungen"))
        return RequirementLevel::Basis;
    if (title == QStringLiteral("Standard-Anforderungen"))
        return RequirementLevel::Standard;
    if (title == QStringLiteral("Anforderungen bei erhöhtem Schutzbedarf"))
        return RequirementLevel::Erhoeht;
    return RequirementLevel::Unknown;
}

inline RequirementLevel requirementLevelFromMarker(QChar marker)
{
    switch (marker.toLatin1()) {
    case 'B':
        return RequirementLevel::Basis;
    case 'S':
        return RequirementLevel::Standard;
    case 'H':
        return RequirementLevel::Erhoeht;
    default:
        return RequirementLevel::Unknown;
    }
}

#endif
