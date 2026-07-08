#ifndef DOMAIN_ASSESSMENTSTATUS_H
#define DOMAIN_ASSESSMENTSTATUS_H

#include <QString>

enum class AssessmentStatus {
    Open,
    Partial,
    Fulfilled,
    NotApplicable
};

inline QString assessmentStatusToString(AssessmentStatus status)
{
    switch (status) {
    case AssessmentStatus::Open:
        return QStringLiteral("Offen");
    case AssessmentStatus::Partial:
        return QStringLiteral("Teilweise");
    case AssessmentStatus::Fulfilled:
        return QStringLiteral("Erfüllt");
    case AssessmentStatus::NotApplicable:
        return QStringLiteral("Entfällt");
    }
    return QStringLiteral("Offen");
}

inline AssessmentStatus assessmentStatusFromString(const QString &value)
{
    const QString normalized = value.trimmed();
    if (normalized == QStringLiteral("Teilweise"))
        return AssessmentStatus::Partial;
    if (normalized == QStringLiteral("Erfüllt"))
        return AssessmentStatus::Fulfilled;
    if (normalized == QStringLiteral("Entfällt"))
        return AssessmentStatus::NotApplicable;
    return AssessmentStatus::Open;
}

#endif
