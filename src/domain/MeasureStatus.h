#ifndef DOMAIN_MEASURESTATUS_H
#define DOMAIN_MEASURESTATUS_H

#include <QString>

enum class MeasureStatus {
    Open,
    InProgress,
    Done
};

inline QString measureStatusToString(MeasureStatus status)
{
    switch (status) {
    case MeasureStatus::Open:
        return QStringLiteral("Offen");
    case MeasureStatus::InProgress:
        return QStringLiteral("In Bearbeitung");
    case MeasureStatus::Done:
        return QStringLiteral("Erledigt");
    }
    return QStringLiteral("Offen");
}

inline MeasureStatus measureStatusFromString(const QString &value)
{
    const QString normalized = value.trimmed();
    if (normalized == QStringLiteral("In Bearbeitung"))
        return MeasureStatus::InProgress;
    if (normalized == QStringLiteral("Erledigt"))
        return MeasureStatus::Done;
    return MeasureStatus::Open;
}

#endif
