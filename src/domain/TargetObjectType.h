#ifndef DOMAIN_TARGETOBJECTTYPE_H
#define DOMAIN_TARGETOBJECTTYPE_H

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
        return QStringLiteral("Kommunikationsverbindung");
    case TargetObjectType::Infrastructure:
        return QStringLiteral("Infrastruktur");
    }
    return QStringLiteral("Unbekannt");
}

inline TargetObjectType targetObjectTypeFromString(const QString &value)
{
    const QString normalized = value.trimmed();
    if (normalized == QStringLiteral("Geschäftsprozess"))
        return TargetObjectType::Process;
    if (normalized == QStringLiteral("Anwendung"))
        return TargetObjectType::Application;
    if (normalized == QStringLiteral("IT-System"))
        return TargetObjectType::ITSystem;
    if (normalized == QStringLiteral("Kommunikationsverbindung"))
        return TargetObjectType::Network;
    if (normalized == QStringLiteral("Infrastruktur"))
        return TargetObjectType::Infrastructure;
    return TargetObjectType::Scope;
}

#endif
