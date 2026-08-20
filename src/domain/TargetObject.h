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

#endif
