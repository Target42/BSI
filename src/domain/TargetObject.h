#ifndef DOMAIN_TARGETOBJECT_H
#define DOMAIN_TARGETOBJECT_H

#include "ProtectionNeed.h"
#include "TargetObjectType.h"

#include <QString>

struct TargetObject {
    int id = 0;
    int projectId = 0;
    int parentId = 0;
    TargetObjectType type = TargetObjectType::Scope;
    ProtectionNeed protectionNeed = ProtectionNeed::Normal;
    QString name;
    QString description;
};

#endif
