#ifndef PERSISTENCE_TARGETOBJECTREPOSITORY_H
#define PERSISTENCE_TARGETOBJECTREPOSITORY_H

#include "ITargetObjectRepository.h"

#include <QSqlDatabase>
#include <QSqlQuery>

class TargetObjectRepository : public ITargetObjectRepository
{
public:
    explicit TargetObjectRepository(QSqlDatabase db);

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
    ReviewSaveResult assignReviewer(int projectId, int targetObjectId, int bausteinId,
                                    int assignedReviewerId) override;
    QList<BausteinReviewEvent> loadReviewHistory(int projectId, int targetObjectId,
                                                 int bausteinId) const override;

    QString lastError() const override;

private:
    void deleteTargetObjectSubtree(int targetObjectId);
    QList<TargetObject> loadTargetObjectsRaw(int projectId) const;
    void persistInheritedProtectionNeeds(int projectId);
    TargetObject readTargetObject(const QSqlQuery &query) const;
    void bindProtectionNeed(QSqlQuery &query, const TargetObject &targetObject) const;

    QSqlDatabase m_db;
    mutable QString m_lastError;
};

#endif
