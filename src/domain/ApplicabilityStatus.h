#ifndef DOMAIN_APPLICABILITYSTATUS_H
#define DOMAIN_APPLICABILITYSTATUS_H

#include <QString>

enum class ApplicabilityStatus {
    Undefined = 0,
    Required,
    Possible,
    NotApplicable
};

inline QString applicabilityStatusToString(ApplicabilityStatus status)
{
    switch (status) {
    case ApplicabilityStatus::Undefined:
        return QStringLiteral("Undefiniert");
    case ApplicabilityStatus::Required:
        return QStringLiteral("Benötigt");
    case ApplicabilityStatus::Possible:
        return QStringLiteral("Möglicherweise");
    case ApplicabilityStatus::NotApplicable:
        return QStringLiteral("Nicht relevant");
    }
    return QStringLiteral("Undefiniert");
}

inline ApplicabilityStatus applicabilityStatusFromString(const QString &value)
{
    const QString normalized = value.trimmed();
    if (normalized == QStringLiteral("Benötigt"))
        return ApplicabilityStatus::Required;
    if (normalized == QStringLiteral("Möglicherweise"))
        return ApplicabilityStatus::Possible;
    if (normalized == QStringLiteral("Nicht relevant"))
        return ApplicabilityStatus::NotApplicable;
    return ApplicabilityStatus::Undefined;
}

#endif
