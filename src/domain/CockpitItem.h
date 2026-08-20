#ifndef DOMAIN_COCKPITITEM_H
#define DOMAIN_COCKPITITEM_H

#include "AssessmentStatus.h"
#include "MeasureStatus.h"

#include <QDate>
#include <QString>

enum class CockpitKind {
    Assessment,
    Measure
};

enum class CockpitKindFilter {
    All,
    Assessments,
    Measures
};

enum class CockpitDueFilter {
    All,
    Overdue,
    ThisWeek,
    HasDate,
    NoDate
};

struct CockpitItem {
    CockpitKind kind = CockpitKind::Assessment;
    int targetObjectId = 0;
    QString targetObjectName;
    int bausteinDbId = 0;
    QString bausteinExternalId;
    int requirementDbId = 0;
    QString requirementExternalId;
    QString title;
    QString statusText;
    QString responsible;
    QDate dueDate;
    bool overdue = false;
    int measureId = 0;
    AssessmentStatus assessmentStatus = AssessmentStatus::Open;
    MeasureStatus measureStatus = MeasureStatus::Open;
};

struct CockpitFilter {
    CockpitKindFilter kind = CockpitKindFilter::All;
    CockpitDueFilter due = CockpitDueFilter::All;
    bool hideDone = true;
    bool mineOnly = false;
    QString currentUserName;
    QString currentUserEmail;
    QString responsibleNeedle;
};

struct CockpitSummary {
    int totalCount = 0;
    int assessmentCount = 0;
    int measureCount = 0;
    int overdueCount = 0;
    int dueThisWeekCount = 0;
};

inline QString cockpitKindToString(CockpitKind kind)
{
    if (kind == CockpitKind::Measure)
        return QStringLiteral("Maßnahme");
    return QStringLiteral("Bewertung");
}

inline bool cockpitItemIsDone(const CockpitItem &item)
{
    if (item.kind == CockpitKind::Measure)
        return item.measureStatus == MeasureStatus::Done;
    return item.assessmentStatus == AssessmentStatus::Fulfilled
        || item.assessmentStatus == AssessmentStatus::NotApplicable;
}

inline bool isDueThisWeek(const QDate &date)
{
    if (!date.isValid())
        return false;
    const QDate today = QDate::currentDate();
    return date >= today && date < today.addDays(7);
}

#endif
