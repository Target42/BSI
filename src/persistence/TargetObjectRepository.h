#ifndef PERSISTENCE_TARGETOBJECTREPOSITORY_H
#define PERSISTENCE_TARGETOBJECTREPOSITORY_H

#include "domain/BausteinApplicability.h"
#include "domain/TargetObject.h"

#include <QHash>
#include <QList>
#include <QSqlDatabase>
#include <QString>

class TargetObjectRepository
{
public:
    explicit TargetObjectRepository(QSqlDatabase db);

    QList<TargetObject> loadTargetObjects(int projectId) const;
    TargetObject createTargetObject(const TargetObject &targetObject);
    bool updateTargetObject(const TargetObject &targetObject);
    bool deleteTargetObject(int targetObjectId);

    TargetObject createDefaultScope(int projectId, const QString &projectName);

    QHash<int, ApplicabilityStatus> loadApplicabilityMap(int projectId, int targetObjectId) const;
    ApplicabilityStatus applicability(int projectId, int targetObjectId, int bausteinDbId) const;
    bool saveApplicability(const BausteinApplicability &applicability);

    QString lastError() const;

private:
    void deleteTargetObjectSubtree(int targetObjectId);

    QSqlDatabase m_db;
    mutable QString m_lastError;
};

#endif
