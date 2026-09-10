#include "HttpTargetObjectRepository.h"

#include "domain/ApplicabilityStatus.h"
#include "domain/BausteinReview.h"
#include "domain/ProtectionNeed.h"
#include "domain/TargetObjectType.h"
#include "net/HttpJson.h"
#include <QJsonArray>
#include <QJsonDocument>
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
    body.insert(QStringLiteral("confidentiality"), ciaLevelToString(targetObject.confidentiality));
    body.insert(QStringLiteral("integrity"), ciaLevelToString(targetObject.integrity));
    body.insert(QStringLiteral("availability"), ciaLevelToString(targetObject.availability));
    body.insert(QStringLiteral("inheritProtectionNeed"), targetObject.inheritProtectionNeed);
    body.insert(QStringLiteral("protectionNeedNote"), targetObject.protectionNeedNote);
    body.insert(QStringLiteral("name"), targetObject.name);
    body.insert(QStringLiteral("description"), targetObject.description);

    int status = 0;
    const QJsonDocument doc = m_client.post(
        QStringLiteral("/api/v1/projects/%1/target-objects").arg(targetObject.projectId), body, &status);
    if (status != 201 || !doc.isObject()) {
        if (status == 409 && doc.isObject() && isModelLockedJson(doc.object()))
            m_lastError = modelLockMessage();
        else
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
    body.insert(QStringLiteral("confidentiality"), ciaLevelToString(targetObject.confidentiality));
    body.insert(QStringLiteral("integrity"), ciaLevelToString(targetObject.integrity));
    body.insert(QStringLiteral("availability"), ciaLevelToString(targetObject.availability));
    body.insert(QStringLiteral("inheritProtectionNeed"), targetObject.inheritProtectionNeed);
    body.insert(QStringLiteral("protectionNeedNote"), targetObject.protectionNeedNote);
    body.insert(QStringLiteral("name"), targetObject.name);
    body.insert(QStringLiteral("description"), targetObject.description);
    body.insert(QStringLiteral("modelLocked"), targetObject.modelLocked);

    int status = 0;
    const QJsonDocument doc =
        m_client.patch(QStringLiteral("/api/v1/target-objects/%1").arg(targetObject.id), body, &status);
    if (status != 200) {
        if (status == 409 && doc.isObject() && isModelLockedJson(doc.object()))
            m_lastError = modelLockMessage();
        else if (status == 409 && doc.isObject() && isReviewLockedJson(doc.object()))
            m_lastError = reviewLockMessage();
        else
            m_lastError = m_client.lastError();
        return false;
    }
    return true;
}

bool HttpTargetObjectRepository::deleteTargetObject(int targetObjectId)
{
    int status = 0;
    if (!m_client.del(QStringLiteral("/api/v1/target-objects/%1").arg(targetObjectId), &status)) {
        if (m_client.lastError() == QStringLiteral("model_locked"))
            m_lastError = modelLockMessage();
        else
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
            if (m_client.lastError() == QStringLiteral("model_locked"))
                m_lastError = modelLockMessage();
            else if (m_client.lastError() == QStringLiteral("review_locked"))
                m_lastError = reviewLockMessage();
            else
                m_lastError = m_client.lastError();
            return false;
        }
        return status == 204;
    }

    QJsonObject body;
    body.insert(QStringLiteral("status"), applicabilityStatusToString(applicability.status));

    const QJsonDocument doc = m_client.put(path, body, &status);
    if (status != 200) {
        if (status == 409 && doc.isObject() && isModelLockedJson(doc.object()))
            m_lastError = modelLockMessage();
        else if (status == 409 && doc.isObject() && isReviewLockedJson(doc.object()))
            m_lastError = reviewLockMessage();
        else
            m_lastError = m_client.lastError();
        return false;
    }
    return true;
}

QString HttpTargetObjectRepository::loadDeviation(int projectId, int targetObjectId,
                                                 int bausteinDbId) const
{
    int status = 0;
    const QJsonDocument doc = m_client.get(
        QStringLiteral("/api/v1/projects/%1/target-objects/%2/bausteine/%3/deviation")
            .arg(projectId)
            .arg(targetObjectId)
            .arg(bausteinDbId),
        &status);
    if (status != 200 || !doc.isObject()) {
        m_lastError = m_client.lastError();
        return {};
    }
    return doc.object().value(QStringLiteral("note")).toString();
}

bool HttpTargetObjectRepository::saveDeviation(int projectId, int targetObjectId, int bausteinDbId,
                                               const QString &note)
{
    QJsonObject body;
    body.insert(QStringLiteral("note"), note);
    int status = 0;
    const QJsonDocument doc =
        m_client.put(QStringLiteral("/api/v1/projects/%1/target-objects/%2/bausteine/%3/deviation")
                         .arg(projectId)
                         .arg(targetObjectId)
                         .arg(bausteinDbId),
                     body, &status);
    if (status != 200) {
        if (status == 409 && doc.isObject() && isModelLockedJson(doc.object()))
            m_lastError = modelLockMessage();
        else if (status == 409 && doc.isObject() && isReviewLockedJson(doc.object()))
            m_lastError = reviewLockMessage();
        else
            m_lastError = m_client.lastError();
        return false;
    }
    return true;
}

QHash<int, BausteinReview> HttpTargetObjectRepository::loadReviews(int projectId, int targetObjectId) const
{
    int status = 0;
    const QJsonDocument doc = m_client.get(
        QStringLiteral("/api/v1/projects/%1/target-objects/%2/reviews").arg(projectId).arg(targetObjectId),
        &status);
    if (status != 200 || !doc.isArray()) {
        m_lastError = m_client.lastError();
        return {};
    }

    QHash<int, BausteinReview> reviews;
    for (const QJsonValue &value : doc.array()) {
        if (!value.isObject())
            continue;
        const BausteinReview review = bausteinReviewFromJson(value.toObject());
        if (review.bausteinId > 0)
            reviews.insert(review.bausteinId, review);
    }
    return reviews;
}

QList<BausteinReview> HttpTargetObjectRepository::loadProjectReviews(int projectId) const
{
    int status = 0;
    const QJsonDocument doc = m_client.get(
        QStringLiteral("/api/v1/projects/%1/reviews").arg(projectId), &status);
    if (status != 200 || !doc.isArray()) {
        m_lastError = m_client.lastError();
        return {};
    }

    QList<BausteinReview> reviews;
    for (const QJsonValue &value : doc.array()) {
        if (!value.isObject())
            continue;
        const BausteinReview review = bausteinReviewFromJson(value.toObject());
        if (review.bausteinId > 0)
            reviews.append(review);
    }
    return reviews;
}

ReviewSaveResult HttpTargetObjectRepository::applyReview(int projectId, int targetObjectId, int bausteinId,
                                                         const QString &action, const QString &note,
                                                         const QList<int> &requirementIds)
{
    QJsonObject body;
    body.insert(QStringLiteral("action"), action);
    body.insert(QStringLiteral("note"), note);
    if (!requirementIds.isEmpty()) {
        QJsonArray ids;
        for (int id : requirementIds)
            ids.append(id);
        body.insert(QStringLiteral("requirementIds"), ids);
    }

    int status = 0;
    const QJsonDocument doc = m_client.post(
        QStringLiteral("/api/v1/projects/%1/target-objects/%2/bausteine/%3/review")
            .arg(projectId)
            .arg(targetObjectId)
            .arg(bausteinId),
        body, &status);
    if (status == 200 && doc.isObject())
        return ReviewSaveResult::ok(bausteinReviewFromJson(doc.object()));

    const QString code = doc.isObject() ? jsonErrorCode(doc.object()) : QString();
    if (!code.isEmpty())
        m_lastError = reviewClientErrorMessage(code);
    else
        m_lastError = m_client.lastError();

    if (status == 403)
        return ReviewSaveResult::failed(ReviewSaveResult::Status::Forbidden);
    if (code == QStringLiteral("review_note_required"))
        return ReviewSaveResult::failed(ReviewSaveResult::Status::NoteRequired);
    if (code == QStringLiteral("invalid_review_transition")
        || code == QStringLiteral("baustein_not_applicable")
        || code == QStringLiteral("workflow_disabled")
        || code == QStringLiteral("invalid_returned_requirements"))
        return ReviewSaveResult::failed(ReviewSaveResult::Status::Invalid);
    return ReviewSaveResult::failed();
}

QString HttpTargetObjectRepository::lastError() const
{
    if (!m_lastError.isEmpty())
        return m_lastError;
    return m_client.lastError();
}
