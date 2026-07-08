#ifndef DOMAIN_REPORTROW_H
#define DOMAIN_REPORTROW_H

#include "ApplicabilityStatus.h"
#include "AssessmentStatus.h"

#include <QDate>
#include <QString>
#include <QtGlobal>

struct ReportRow {
    int targetObjectId = 0;
    QString targetObjectName;
    QString bausteinExternalId;
    QString bausteinTitle;
    QString requirementExternalId;
    QString requirementTitle;
    QString level;
    ApplicabilityStatus applicability = ApplicabilityStatus::Undefined;
    AssessmentStatus status = AssessmentStatus::Open;
    QString responsible;
    QDate dueDate;
    int measureCount = 0;
    bool overdue = false;
};

struct ReportSummary {
    int totalRequirements = 0;
    int openCount = 0;
    int partialCount = 0;
    int fulfilledCount = 0;
    int notApplicableCount = 0;
    int overdueCount = 0;
    int measureCount = 0;
};

inline int reportProgressPercent(const ReportSummary &summary)
{
    if (summary.totalRequirements <= 0)
        return 0;
    const int completed = summary.fulfilledCount + summary.notApplicableCount;
    return qRound(completed * 100.0 / summary.totalRequirements);
}

#endif
