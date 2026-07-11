#ifndef PERSISTENCE_ITARGETOBJECTREPOSITORY_H
#define PERSISTENCE_ITARGETOBJECTREPOSITORY_H

#include "domain/BausteinApplicability.h"
#include "domain/TargetObject.h"

#include <QHash>
#include <QList>
#include <QString>

class ITargetObjectRepository
{
public:
    virtual ~ITargetObjectRepository() = default;

    virtual QList<TargetObject> loadTargetObjects(int projectId) const = 0;
    virtual TargetObject createTargetObject(const TargetObject &targetObject) = 0;
    virtual bool updateTargetObject(const TargetObject &targetObject) = 0;
    virtual bool deleteTargetObject(int targetObjectId) = 0;

    virtual TargetObject createDefaultScope(int projectId, const QString &projectName) = 0;

    virtual QHash<int, ApplicabilityStatus> loadApplicabilityMap(int projectId, int targetObjectId) const = 0;
    virtual ApplicabilityStatus applicability(int projectId, int targetObjectId, int bausteinDbId) const = 0;
    virtual bool saveApplicability(const BausteinApplicability &applicability) = 0;

    virtual QString lastError() const = 0;
};

#endif
