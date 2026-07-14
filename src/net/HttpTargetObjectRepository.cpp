#include "HttpTargetObjectRepository.h"

#include "domain/ApplicabilityStatus.h"
#include "domain/ProtectionNeed.h"
#include "domain/TargetObjectType.h"
#include "net/HttpJson.h"
#include "qjsonarray.h"

#include <QJsonObject>

HttpTargetObjectRepository::HttpTargetObjectRepository(ApiClient &client)
    : m_client(client)
{
}

QList<TargetObject> HttpTargetObjectRepository::loadTargetObjects(int projectId) const
{
    int status = 0;
    const QJsonDocument doc = m_client.get(
        QStringLiteral("/api/v1/projects/%1/target-objects").arg(projectId), &status);
    if (status != 200 || !doc.isArray()) {
        m_lastError = m_client.lastError();
        return {};
    }

    QList<TargetObject> objects;
    for (const QJsonValue &value : doc.array()) {
        if (value.isObject())
            objects.append(targetObjectFromJson(value.toObject()));
    }
    return objects;
}

TargetObject HttpTargetObjectRepository::createTargetObject(const TargetObject &targetObject)
{
    QJsonObject body;
    body.insert(QStringLiteral("parentId"), targetObject.parentId);
    body.insert(QStringLiteral("type"), targetObjectTypeToString(targetObject.type));
    body.insert(QStringLiteral("protectionNeed"), protectionNeedToString(targetObject.protectionNeed));
    body.insert(QStringLiteral("name"), targetObject.name);
    body.insert(QStringLiteral("description"), targetObject.description);

    int status = 0;
    const QJsonDocument doc = m_client.post(
        QStringLiteral("/api/v1/projects/%1/target-objects").arg(targetObject.projectId), body, &status);
    if (status != 201 || !doc.isObject()) {
        m_lastError = m_client.lastError();
        return {};
    }
    return targetObjectFromJson(doc.object());
}

bool HttpTargetObjectRepository::updateTargetObject(const TargetObject &targetObject)
{
    QJsonObject body;
    body.insert(QStringLiteral("parentId"), targetObject.parentId);
    body.insert(QStringLiteral("type"), targetObjectTypeToString(targetObject.type));
    body.insert(QStringLiteral("protectionNeed"), protectionNeedToString(targetObject.protectionNeed));
    body.insert(QStringLiteral("name"), targetObject.name);
    body.insert(QStringLiteral("description"), targetObject.description);

    int status = 0;
    m_client.patch(QStringLiteral("/api/v1/target-objects/%1").arg(targetObject.id), body, &status);
    if (status != 200) {
        m_lastError = m_client.lastError();
        return false;
    }
    return true;
}

bool HttpTargetObjectRepository::deleteTargetObject(int targetObjectId)
{
    int status = 0;
    if (!m_client.del(QStringLiteral("/api/v1/target-objects/%1").arg(targetObjectId), &status)) {
        m_lastError = m_client.lastError();
        return false;
    }
    return status == 204;
}

TargetObject HttpTargetObjectRepository::createDefaultScope(int projectId, const QString &projectName)
{
    Q_UNUSED(projectName)
    const QList<TargetObject> objects = loadTargetObjects(projectId);
    for (const TargetObject &object : objects) {
        if (object.type == TargetObjectType::Scope)
            return object;
    }

    TargetObject scope;
    scope.projectId = projectId;
    scope.type = TargetObjectType::Scope;
    scope.name = projectName;
    return createTargetObject(scope);
}

QHash<int, ApplicabilityStatus> HttpTargetObjectRepository::loadApplicabilityMap(int projectId,
                                                                               int targetObjectId) const
{
    int status = 0;
    const QJsonDocument doc = m_client.get(
        QStringLiteral("/api/v1/projects/%1/target-objects/%2/applicability")
            .arg(projectId)
            .arg(targetObjectId),
        &status);
    if (status != 200 || !doc.isObject()) {
        m_lastError = m_client.lastError();
        return {};
    }

    QHash<int, ApplicabilityStatus> map;
    const QJsonObject obj = doc.object();
    for (auto it = obj.begin(); it != obj.end(); ++it) {
        map.insert(it.key().toInt(), applicabilityStatusFromString(it.value().toString()));
    }
    return map;
}

ApplicabilityStatus HttpTargetObjectRepository::applicability(int projectId, int targetObjectId,
                                                              int bausteinDbId) const
{
    return loadApplicabilityMap(projectId, targetObjectId).value(bausteinDbId, ApplicabilityStatus::Undefined);
}

bool HttpTargetObjectRepository::saveApplicability(const BausteinApplicability &applicability)
{
    const QString path =
        QStringLiteral("/api/v1/projects/%1/target-objects/%2/bausteine/%3/applicability")
            .arg(applicability.projectId)
            .arg(applicability.targetObjectId)
            .arg(applicability.bausteinDbId);

    int status = 0;
    if (applicability.status == ApplicabilityStatus::Undefined) {
        if (!m_client.del(path, &status)) {
            m_lastError = m_client.lastError();
            return false;
        }
        return status == 204;
    }

    QJsonObject body;
    body.insert(QStringLiteral("status"), applicabilityStatusToString(applicability.status));

    m_client.put(path, body, &status);
    if (status != 200) {
        m_lastError = m_client.lastError();
        return false;
    }
    return true;
}

QString HttpTargetObjectRepository::lastError() const
{
    if (!m_lastError.isEmpty())
        return m_lastError;
    return m_client.lastError();
}
