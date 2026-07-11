#ifndef NET_HTTPMEASUREREPOSITORY_H
#define NET_HTTPMEASUREREPOSITORY_H

#include "net/ApiClient.h"
#include "persistence/IMeasureRepository.h"

class HttpMeasureRepository : public IMeasureRepository
{
public:
    explicit HttpMeasureRepository(ApiClient &client);

    QList<Measure> loadMeasures(int projectId, int targetObjectId, int requirementDbId) const override;
    QHash<int, int> measureCounts(int projectId, int targetObjectId) const override;

    Measure createMeasure(const Measure &measure) override;
    MeasureSaveResult updateMeasure(const Measure &measure) override;
    bool deleteMeasure(int measureId) override;

    QString lastError() const override;

private:
    ApiClient &m_client;
    mutable QString m_lastError;
};

#endif
