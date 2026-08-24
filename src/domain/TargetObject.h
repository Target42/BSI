#ifndef DOMAIN_TARGETOBJECT_H
#define DOMAIN_TARGETOBJECT_H

#include "ProtectionNeed.h"
#include "TargetObjectType.h"

#include <QHash>
#include <QList>
#include <QString>

struct TargetObject {
    int id = 0;
    int projectId = 0;
    int parentId = 0;
    TargetObjectType type = TargetObjectType::Scope;
    ProtectionNeed protectionNeed = ProtectionNeed::Normal;
    CiaLevel confidentiality = CiaLevel::Normal;
    CiaLevel integrity = CiaLevel::Normal;
    CiaLevel availability = CiaLevel::Normal;
    bool inheritProtectionNeed = false;
    QString protectionNeedNote;
    QString name;
    QString description;
};

inline void applyCiaToProtectionNeed(TargetObject &target)
{
    const bool keepBasis = target.protectionNeed == ProtectionNeed::BasisOnly && !target.inheritProtectionNeed;
    const ProtectionNeed derived = protectionNeedFromCiaLevels(
        target.confidentiality, target.integrity, target.availability);
    if (keepBasis && derived == ProtectionNeed::Normal)
        target.protectionNeed = ProtectionNeed::BasisOnly;
    else
        target.protectionNeed = derived;
}

inline void copyProtectionNeedFromParent(TargetObject &child, const TargetObject &parent)
{
    child.confidentiality = parent.confidentiality;
    child.integrity = parent.integrity;
    child.availability = parent.availability;
    applyCiaToProtectionNeed(child);
}

inline void finalizeTargetObjectProtectionNeed(TargetObject &target, const TargetObject &parent)
{
    if (target.parentId <= 0)
        target.inheritProtectionNeed = false;
    else if (target.inheritProtectionNeed && parent.id > 0)
        copyProtectionNeedFromParent(target, parent);
    applyCiaToProtectionNeed(target);
}

inline QString protectionNeedSummary(const TargetObject &target)
{
    QString result = QStringLiteral("V %1, I %2, A %3")
                         .arg(ciaLevelToString(target.confidentiality),
                              ciaLevelToString(target.integrity),
                              ciaLevelToString(target.availability));
    if (target.inheritProtectionNeed)
        result += QStringLiteral(" – geerbt");
    return result;
}

inline void resolveInheritedProtectionNeeds(QList<TargetObject> &objects)
{
    QHash<int, int> byId;
    for (int i = 0; i < objects.size(); ++i) {
        if (objects[i].id > 0)
            byId.insert(objects[i].id, i);
    }
    for (int i = 0; i < objects.size(); ++i) {
        if (!objects[i].inheritProtectionNeed || objects[i].parentId <= 0) {
            applyCiaToProtectionNeed(objects[i]);
            continue;
        }
        TargetObject parent = objects[i];
        for (int guard = 0; parent.inheritProtectionNeed && parent.parentId > 0 && guard < 64; ++guard) {
            const auto it = byId.constFind(parent.parentId);
            if (it == byId.cend())
                break;
            parent = objects[*it];
        }
        copyProtectionNeedFromParent(objects[i], parent);
    }
}

inline QString targetObjectCaption(const TargetObject &object)
{
    return QStringLiteral("%1 – %2 [%3]")
        .arg(targetObjectTypeToString(object.type), object.name, protectionNeedSummary(object));
}

inline bool isRootScopeTarget(const TargetObject &object)
{
    return object.parentId == 0 && object.type == TargetObjectType::Scope;
}

inline TargetObject findTargetObjectById(const QList<TargetObject> &objects, int id)
{
    if (id <= 0)
        return {};
    for (const TargetObject &object : objects) {
        if (object.id == id)
            return object;
    }
    return {};
}

inline TargetObject findRootScopeTarget(const QList<TargetObject> &objects)
{
    for (const TargetObject &object : objects) {
        if (isRootScopeTarget(object))
            return object;
    }
    for (const TargetObject &object : objects) {
        if (object.parentId == 0)
            return object;
    }
    return {};
}

inline bool wouldCreateTargetParentCycle(const QList<TargetObject> &objects, int objectId,
                                         int newParentId)
{
    if (objectId <= 0 || newParentId <= 0)
        return false;
    int currentId = newParentId;
    for (int guard = 0; currentId > 0 && guard < 64; ++guard) {
        if (currentId == objectId)
            return true;
        const TargetObject current = findTargetObjectById(objects, currentId);
        if (current.id == 0)
            return false;
        currentId = current.parentId;
    }
    return false;
}

inline QString targetMoveRejectedReason(const QList<TargetObject> &objects, const TargetObject &moving,
                                        int newParentId)
{
    if (moving.id <= 0)
        return QStringLiteral("Kein Zielobjekt ausgewählt.");
    if (isRootScopeTarget(moving))
        return QStringLiteral("Der Informationsverbund kann nicht verschoben werden.");
    if (newParentId <= 0)
        return QStringLiteral("Bitte ein übergeordnetes Zielobjekt wählen.");
    if (wouldCreateTargetParentCycle(objects, moving.id, newParentId))
        return QStringLiteral("Ein Zielobjekt kann nicht unter ein eigenes Unterobjekt verschoben werden.");
    const TargetObject parent = findTargetObjectById(objects, newParentId);
    if (parent.id == 0)
        return QStringLiteral("Übergeordnetes Zielobjekt wurde nicht gefunden.");
    if (!isAllowedChildTargetType(parent.type, moving.type)) {
        return QStringLiteral("Dieser Zielobjekt-Typ ist unter %1 nicht zulässig.")
            .arg(targetObjectTypeToString(parent.type));
    }
    return {};
}

inline bool canMoveTargetObject(const QList<TargetObject> &objects, const TargetObject &moving,
                                int newParentId, QString *error = nullptr)
{
    const QString reason = targetMoveRejectedReason(objects, moving, newParentId);
    if (reason.isEmpty())
        return true;
    if (error != nullptr)
        *error = reason;
    return false;
}

inline int moveDestinationParentId(const QList<TargetObject> &objects, const TargetObject &dropTarget,
                                   bool dropIsLayerGroup)
{
    if (dropIsLayerGroup)
        return findRootScopeTarget(objects).id;
    return dropTarget.id;
}

inline QString targetMoveRejectedReasonForDrop(const QList<TargetObject> &objects,
                                               const TargetObject &moving,
                                               const TargetObject &dropTarget, bool dropIsLayerGroup)
{
    if (dropIsLayerGroup && dropTarget.type != moving.type) {
        return QStringLiteral("Dieses Zielobjekt gehört in die Schicht „%1“.")
            .arg(targetObjectLayerGroupTitle(moving.type));
    }
    return targetMoveRejectedReason(objects, moving,
                                    moveDestinationParentId(objects, dropTarget, dropIsLayerGroup));
}

struct TargetMoveDestination {
    int parentId = 0;
    QString label;
};

inline QList<TargetMoveDestination> possibleTargetMoveDestinations(const QList<TargetObject> &objects,
                                                                   const TargetObject &moving)
{
    QList<TargetMoveDestination> destinations;
    if (moving.id <= 0 || isRootScopeTarget(moving))
        return destinations;

    const TargetObject scope = findRootScopeTarget(objects);
    if (scope.id > 0 && scope.id != moving.parentId
        && canMoveTargetObject(objects, moving, scope.id)) {
        TargetMoveDestination layer;
        layer.parentId = scope.id;
        layer.label = QStringLiteral("Schicht: %1").arg(targetObjectLayerGroupTitle(moving.type));
        destinations.append(layer);
    }

    for (const TargetObject &candidate : objects) {
        if (candidate.id == moving.id || candidate.id == moving.parentId)
            continue;
        if (candidate.id == scope.id)
            continue;
        if (!canMoveTargetObject(objects, moving, candidate.id))
            continue;
        TargetMoveDestination destination;
        destination.parentId = candidate.id;
        destination.label = targetObjectCaption(candidate);
        destinations.append(destination);
    }
    return destinations;
}

#endif
