#ifndef NET_HTTPJSON_H
#define NET_HTTPJSON_H

#include "domain/AssessmentStatus.h"
#include "domain/Baustein.h"
#include "domain/Measure.h"
#include "domain/MeasureStatus.h"
#include "domain/Project.h"
#include "domain/ProtectionNeed.h"
#include "domain/Requirement.h"
#include "domain/RequirementAssessment.h"
#include "domain/RequirementLevel.h"
#include "domain/TargetObject.h"
#include "domain/TargetObjectType.h"

#include <QDate>
#include <QDateTime>
#include <QJsonObject>

inline QDateTime parseDateTime(const QJsonValue &value)
{
    return QDateTime::fromString(value.toString(), Qt::ISODate);
}

inline QDate parseDate(const QJsonValue &value)
{
    return QDate::fromString(value.toString(), Qt::ISODate);
}

inline Project projectFromJson(const QJsonObject &obj)
{
    Project project;
    project.id = obj.value(QStringLiteral("id")).toInt();
    project.name = obj.value(QStringLiteral("name")).toString();
    project.description = obj.value(QStringLiteral("description")).toString();
    project.catalogVersion = obj.value(QStringLiteral("catalogVersion")).toString();
    project.role = obj.value(QStringLiteral("role")).toString();
    project.createdAt = parseDateTime(obj.value(QStringLiteral("createdAt")));
    project.updatedAt = parseDateTime(obj.value(QStringLiteral("updatedAt")));
    return project;
}

inline TargetObject targetObjectFromJson(const QJsonObject &obj)
{
    TargetObject target;
    target.id = obj.value(QStringLiteral("id")).toInt();
    target.projectId = obj.value(QStringLiteral("projectId")).toInt();
    target.parentId = obj.value(QStringLiteral("parentId")).toInt();
    target.type = targetObjectTypeFromString(obj.value(QStringLiteral("type")).toString());
    target.protectionNeed = protectionNeedFromString(obj.value(QStringLiteral("protectionNeed")).toString());
    target.name = obj.value(QStringLiteral("name")).toString();
    target.description = obj.value(QStringLiteral("description")).toString();
    return target;
}

inline Baustein bausteinFromJson(const QJsonObject &obj)
{
    Baustein baustein;
    baustein.id = obj.value(QStringLiteral("id")).toInt();
    baustein.standard = StandardType::ITGrundschutz;
    baustein.externalId = obj.value(QStringLiteral("externalId")).toString();
    baustein.title = obj.value(QStringLiteral("title")).toString();
    baustein.groupName = obj.value(QStringLiteral("groupName")).toString();
    baustein.catalogVersion = obj.value(QStringLiteral("catalogVersion")).toString();
    return baustein;
}

inline Requirement requirementFromJson(const QJsonObject &obj)
{
    Requirement requirement;
    requirement.id = obj.value(QStringLiteral("id")).toInt();
    requirement.bausteinDbId = obj.value(QStringLiteral("bausteinId")).toInt();
    requirement.standard = StandardType::ITGrundschutz;
    requirement.externalId = obj.value(QStringLiteral("externalId")).toString();
    requirement.bausteinExternalId = obj.value(QStringLiteral("bausteinExternalId")).toString();
    requirement.title = obj.value(QStringLiteral("title")).toString();
    requirement.text = obj.value(QStringLiteral("text")).toString();
    const QString level = obj.value(QStringLiteral("level")).toString();
    if (level == QStringLiteral("Basis"))
        requirement.level = RequirementLevel::Basis;
    else if (level == QStringLiteral("Standard"))
        requirement.level = RequirementLevel::Standard;
    else if (level == QStringLiteral("Erhöht"))
        requirement.level = RequirementLevel::Erhoeht;
    requirement.responsibleRole = obj.value(QStringLiteral("responsibleRole")).toString();
    requirement.withdrawn = obj.value(QStringLiteral("withdrawn")).toBool();
    return requirement;
}

inline RequirementAssessment assessmentFromJson(const QJsonObject &obj)
{
    RequirementAssessment assessment;
    assessment.id = obj.value(QStringLiteral("id")).toInt();
    assessment.projectId = obj.value(QStringLiteral("projectId")).toInt();
    assessment.targetObjectId = obj.value(QStringLiteral("targetObjectId")).toInt();
    assessment.requirementDbId = obj.value(QStringLiteral("requirementId")).toInt();
    assessment.status = assessmentStatusFromString(obj.value(QStringLiteral("status")).toString());
    assessment.note = obj.value(QStringLiteral("note")).toString();
    assessment.responsible = obj.value(QStringLiteral("responsible")).toString();
    const QDate dueDate = parseDate(obj.value(QStringLiteral("dueDate")));
    if (dueDate.isValid())
        assessment.dueDate = dueDate;
    assessment.version = obj.value(QStringLiteral("version")).toInt();
    return assessment;
}

inline Measure measureFromJson(const QJsonObject &obj)
{
    Measure measure;
    measure.id = obj.value(QStringLiteral("id")).toInt();
    measure.projectId = obj.value(QStringLiteral("projectId")).toInt();
    measure.targetObjectId = obj.value(QStringLiteral("targetObjectId")).toInt();
    measure.requirementDbId = obj.value(QStringLiteral("requirementId")).toInt();
    measure.title = obj.value(QStringLiteral("title")).toString();
    measure.description = obj.value(QStringLiteral("description")).toString();
    measure.responsible = obj.value(QStringLiteral("responsible")).toString();
    const QDate dueDate = parseDate(obj.value(QStringLiteral("dueDate")));
    if (dueDate.isValid())
        measure.dueDate = dueDate;
    measure.status = measureStatusFromString(obj.value(QStringLiteral("status")).toString());
    measure.version = obj.value(QStringLiteral("version")).toInt();
    return measure;
}

#endif
