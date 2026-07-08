#ifndef DOMAIN_REQUIREMENTASSESSMENT_H
#define DOMAIN_REQUIREMENTASSESSMENT_H

#include "AssessmentStatus.h"

#include <QDate>
#include <QString>

struct RequirementAssessment {
    int id = 0;
    int projectId = 0;
    int targetObjectId = 0;
    int requirementDbId = 0;
    AssessmentStatus status = AssessmentStatus::Open;
    QString note;
    QString responsible;
    QDate dueDate;
    int measureCount = 0;
};

#endif
