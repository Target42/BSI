#ifndef SERVICES_INHERITANCE_H
#define SERVICES_INHERITANCE_H

#include "domain/ApplicabilityStatus.h"
#include "domain/TargetObject.h"
#include "domain/TargetObjectType.h"

#include <QHash>
#include <QList>
#include <QString>

struct InheritedBaustein {
    int bausteinDbId = 0;
    ApplicabilityStatus status = ApplicabilityStatus::Undefined;
    int sourceTargetId = 0;
    QString sourceCaption;
};

namespace Inheritance {

inline TargetObject findById(const QList<TargetObject> &objects, int id)
{
    for (const TargetObject &object : objects) {
        if (object.id == id)
            return object;
    }
    return {};
}

inline QList<TargetObject> ancestorChain(const QList<TargetObject> &objects, const TargetObject &target)
{
    QList<TargetObject> result;
    TargetObject current = target;
    int guard = 0;
    while (current.parentId > 0 && guard < 64) {
        ++guard;
        const TargetObject parent = findById(objects, current.parentId);
        if (parent.id == 0)
            break;
        if (!canInheritAssessments(parent.type, current.type))
            break;
        result.append(parent);
        current = parent;
    }
    return result;
}

inline QHash<int, InheritedBaustein> collectInherited(
    const QList<TargetObject> &objects,
    const TargetObject &target,
    const QHash<int, ApplicabilityStatus> &ownMap,
    const QHash<int, QHash<int, ApplicabilityStatus>> &parentMaps)
{
    QHash<int, InheritedBaustein> inherited;
    const QList<TargetObject> ancestors = ancestorChain(objects, target);
    for (const TargetObject &parent : ancestors) {
        const QHash<int, ApplicabilityStatus> map = parentMaps.value(parent.id);
        for (auto it = map.constBegin(); it != map.constEnd(); ++it) {
            if (it.value() != ApplicabilityStatus::Required
                && it.value() != ApplicabilityStatus::Possible)
                continue;
            if (ownMap.contains(it.key()) || inherited.contains(it.key()))
                continue;
            InheritedBaustein item;
            item.bausteinDbId = it.key();
            item.status = it.value();
            item.sourceTargetId = parent.id;
            item.sourceCaption = targetObjectCaption(parent);
            inherited.insert(it.key(), item);
        }
    }
    return inherited;
}

inline QHash<int, ApplicabilityStatus> mergeApplicability(
    QHash<int, ApplicabilityStatus> ownMap, const QHash<int, InheritedBaustein> &inherited)
{
    for (auto it = inherited.constBegin(); it != inherited.constEnd(); ++it) {
        if (!ownMap.contains(it.key()))
            ownMap.insert(it.key(), it.value().status);
    }
    return ownMap;
}

} // namespace Inheritance

#endif
