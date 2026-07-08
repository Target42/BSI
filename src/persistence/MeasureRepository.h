#ifndef PERSISTENCE_MEASUREREPOSITORY_H
#define PERSISTENCE_MEASUREREPOSITORY_H

#include "domain/Measure.h"

#include <QHash>
#include <QList>
#include <QSqlDatabase>
#include <QString>

class MeasureRepository
{
public:
    explicit MeasureRepository(QSqlDatabase db);

    QList<Measure> loadMeasures(int projectId, int targetObjectId, int requirementDbId) const;
    QHash<int, int> measureCounts(int projectId, int targetObjectId) const;

    Measure createMeasure(const Measure &measure);
    bool updateMeasure(const Measure &measure);
    bool deleteMeasure(int measureId);

    QString lastError() const;

private:
    QSqlDatabase m_db;
    mutable QString m_lastError;
};

#endif
