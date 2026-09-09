#ifndef PERSISTENCE_ITARGETOBJECTREPOSITORY_H
#define PERSISTENCE_ITARGETOBJECTREPOSITORY_H

#include "domain/BausteinApplicability.h"
#include "domain/BausteinReview.h"
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

    virtual QString loadDeviation(int projectId, int targetObjectId, int bausteinDbId) const = 0;
    virtual bool saveDeviation(int projectId, int targetObjectId, int bausteinDbId,
                               const QString &note) = 0;

    virtual QHash<int, BausteinReview> loadReviews(int projectId, int targetObjectId) const = 0;
    virtual QList<BausteinReview> loadProjectReviews(int projectId) const = 0;
    virtual ReviewSaveResult applyReview(int projectId, int targetObjectId, int bausteinId,
                                         const QString &action, const QString &note,
                                         const QList<int> &requirementIds = {}) = 0;

    virtual QString lastError() const = 0;
};

#endif
