#ifndef DOMAIN_MEASURE_H
#define DOMAIN_MEASURE_H

#include "MeasureStatus.h"

#include <QDate>
#include <QString>

struct Measure {
    int id = 0;
    int projectId = 0;
    int targetObjectId = 0;
    int requirementDbId = 0;
    QString title;
    QString description;
    QString responsible;
    QDate dueDate;
    MeasureStatus status = MeasureStatus::Open;
    int version = 0;
};

#endif
