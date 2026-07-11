#ifndef PERSISTENCE_TARGETOBJECTREPOSITORY_H
#define PERSISTENCE_TARGETOBJECTREPOSITORY_H

#include "ITargetObjectRepository.h"

#include <QSqlDatabase>

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

    QString lastError() const override;

private:
    void deleteTargetObjectSubtree(int targetObjectId);

    QSqlDatabase m_db;
    mutable QString m_lastError;
};

#endif
