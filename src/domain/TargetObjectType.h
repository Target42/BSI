#ifndef DOMAIN_TARGETOBJECTTYPE_H
#define DOMAIN_TARGETOBJECTTYPE_H

#include <QList>
#include <QString>

enum class TargetObjectType {
    Scope,
    Process,
    Application,
    ITSystem,
    Network,
    Infrastructure
};

inline QString targetObjectTypeToString(TargetObjectType type)
{
    switch (type) {
    case TargetObjectType::Scope:
        return QStringLiteral("Informationsverbund");
    case TargetObjectType::Process:
        return QStringLiteral("Geschäftsprozess");
    case TargetObjectType::Application:
        return QStringLiteral("Anwendung");
    case TargetObjectType::ITSystem:
        return QStringLiteral("IT-System");
    case TargetObjectType::Network:
        return QStringLiteral("Netz");
    case TargetObjectType::Infrastructure:
        return QStringLiteral("Infrastruktur");
    }
    return QStringLiteral("Unbekannt");
}

inline TargetObjectType targetObjectTypeFromString(const QString &value)
{
    const QString normalized = value.trimmed();
    if (normalized == QStringLiteral("Informationsverbund")
        || normalized == QStringLiteral("Geltungsbereich"))
        return TargetObjectType::Scope;
    if (normalized == QStringLiteral("Geschäftsprozess"))
        return TargetObjectType::Process;
    if (normalized == QStringLiteral("Anwendung"))
        return TargetObjectType::Application;
    if (normalized == QStringLiteral("IT-System"))
        return TargetObjectType::ITSystem;
    if (normalized == QStringLiteral("Kommunikationsverbindung")
        || normalized == QStringLiteral("Netz")
        || normalized == QStringLiteral("Netze"))
        return TargetObjectType::Network;
    if (normalized == QStringLiteral("Infrastruktur"))
        return TargetObjectType::Infrastructure;
    return TargetObjectType::Scope;
}

inline QList<TargetObjectType> allowedChildTargetTypes(TargetObjectType parentType)
{
    switch (parentType) {
    case TargetObjectType::Scope:
        return {TargetObjectType::Process, TargetObjectType::Application, TargetObjectType::ITSystem,
                TargetObjectType::Network, TargetObjectType::Infrastructure};
    case TargetObjectType::Process:
        return {TargetObjectType::Process, TargetObjectType::Application};
    case TargetObjectType::ITSystem:
        return {TargetObjectType::Application, TargetObjectType::ITSystem, TargetObjectType::Network};
    case TargetObjectType::Infrastructure:
        return {TargetObjectType::ITSystem, TargetObjectType::Infrastructure, TargetObjectType::Network};
    case TargetObjectType::Application:
    case TargetObjectType::Network:
        break;
    }
    return {};
}

inline TargetObjectType defaultChildTargetType(TargetObjectType parentType)
{
    switch (parentType) {
    case TargetObjectType::Scope:
        return TargetObjectType::Process;
    case TargetObjectType::Process:
    case TargetObjectType::ITSystem:
        return TargetObjectType::Application;
    case TargetObjectType::Infrastructure:
        return TargetObjectType::ITSystem;
    case TargetObjectType::Application:
    case TargetObjectType::Network:
        break;
    }
    return TargetObjectType::Process;
}

inline bool canHaveChildTargetObjects(TargetObjectType parentType)
{
    return !allowedChildTargetTypes(parentType).isEmpty();
}

inline bool isAllowedChildTargetType(TargetObjectType parentType, TargetObjectType childType)
{
    return allowedChildTargetTypes(parentType).contains(childType);
}

inline QList<TargetObjectType> scopeLayerTypes()
{
    return {TargetObjectType::Process, TargetObjectType::Application, TargetObjectType::ITSystem,
            TargetObjectType::Network, TargetObjectType::Infrastructure};
}

inline QString targetObjectLayerGroupTitle(TargetObjectType type)
{
    switch (type) {
    case TargetObjectType::Process:
        return QStringLiteral("Geschäftsprozesse");
    case TargetObjectType::Application:
        return QStringLiteral("Anwendungen");
    case TargetObjectType::ITSystem:
        return QStringLiteral("IT-Systeme");
    case TargetObjectType::Network:
        return QStringLiteral("Netze");
    case TargetObjectType::Infrastructure:
        return QStringLiteral("Infrastruktur");
    case TargetObjectType::Scope:
        break;
    }
    return targetObjectTypeToString(type);
}

inline bool canInheritAssessments(TargetObjectType parentType, TargetObjectType childType)
{
    switch (parentType) {
    case TargetObjectType::ITSystem:
        return childType == TargetObjectType::ITSystem
            || childType == TargetObjectType::Application
            || childType == TargetObjectType::Network;
    case TargetObjectType::Process:
        return childType == TargetObjectType::Process
            || childType == TargetObjectType::Application;
    case TargetObjectType::Infrastructure:
        return childType == TargetObjectType::Infrastructure
            || childType == TargetObjectType::ITSystem
            || childType == TargetObjectType::Network;
    default:
        return false;
    }
}

#endif
