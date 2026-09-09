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

    QString loadDeviation(int projectId, int targetObjectId, int bausteinDbId) const override;
    bool saveDeviation(int projectId, int targetObjectId, int bausteinDbId,
                       const QString &note) override;

    QHash<int, BausteinReview> loadReviews(int projectId, int targetObjectId) const override;
    QList<BausteinReview> loadProjectReviews(int projectId) const override;
    ReviewSaveResult applyReview(int projectId, int targetObjectId, int bausteinId,
                                 const QString &action, const QString &note,
                                 const QList<int> &requirementIds = {}) override;

    QString lastError() const override;

private:
    ApiClient &m_client;
    mutable QString m_lastError;
};

#endif
