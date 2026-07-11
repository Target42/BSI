#ifndef NET_HTTPTARGETOBJECTREPOSITORY_H
#define NET_HTTPTARGETOBJECTREPOSITORY_H

#include "net/ApiClient.h"
#include "persistence/ITargetObjectRepository.h"

class HttpTargetObjectRepository : public ITargetObjectRepository
{
public:
    explicit HttpTargetObjectRepository(ApiClient &client);

    QList<TargetObject> loadTargetObjects(int projectId) const override;
    TargetObject createTargetObject(const TargetObject &targetObject) override;
    bool updateTargetObject(const TargetObject &targetObject) override;
    bool deleteTargetObject(int targetObjectId) override;

    TargetObject createDefaultScope(int projectId, const QString &projectName) override;

    QHash<int, ApplicabilityStatus> loadApplicabilityMap(int projectId, int targetObjectId) const override;
    ApplicabilityStatus applicability(int projectId, int targetObjectId, int bausteinDbId) const override;
    bool saveApplicability(const BausteinApplicability &applicability) override;

    QString lastError() const override;

private:
    ApiClient &m_client;
    mutable QString m_lastError;
};

#endif
