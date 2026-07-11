#ifndef PERSISTENCE_MEASUREREPOSITORY_H
#define PERSISTENCE_MEASUREREPOSITORY_H

#include "IMeasureRepository.h"

#include <QSqlDatabase>

class MeasureRepository : public IMeasureRepository
{
public:
    explicit MeasureRepository(QSqlDatabase db);

    QList<Measure> loadMeasures(int projectId, int targetObjectId, int requirementDbId) const override;
    QHash<int, int> measureCounts(int projectId, int targetObjectId) const override;

    Measure createMeasure(const Measure &measure) override;
    MeasureSaveResult updateMeasure(const Measure &measure) override;
    bool deleteMeasure(int measureId) override;

    QString lastError() const override;

private:
    QSqlDatabase m_db;
    mutable QString m_lastError;
};

#endif
