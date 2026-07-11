#ifndef PERSISTENCE_IMEASUREREPOSITORY_H
#define PERSISTENCE_IMEASUREREPOSITORY_H

#include "domain/Measure.h"
#include "domain/SaveResult.h"

#include <QHash>
#include <QList>
#include <QString>

class IMeasureRepository
{
public:
    virtual ~IMeasureRepository() = default;

    virtual QList<Measure> loadMeasures(int projectId, int targetObjectId, int requirementDbId) const = 0;
    virtual QHash<int, int> measureCounts(int projectId, int targetObjectId) const = 0;

    virtual Measure createMeasure(const Measure &measure) = 0;
    virtual MeasureSaveResult updateMeasure(const Measure &measure) = 0;
    virtual bool deleteMeasure(int measureId) = 0;

    virtual QString lastError() const = 0;
};

#endif
