#include "HttpProjectRepository.h"

#include "domain/AssessmentStatus.h"
#include "net/HttpJson.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

HttpProjectRepository::HttpProjectRepository(ApiClient &client)
    : m_client(client)
{
}

QList<Project> HttpProjectRepository::loadProjects() const
{
    int status = 0;
    const QJsonDocument doc = m_client.get(QStringLiteral("/api/v1/projects"), &status);
    if (status != 200 || !doc.isArray()) {
        m_lastError = m_client.lastError();
        return {};
    }

    QList<Project> projects;
    for (const QJsonValue &value : doc.array()) {
        if (value.isObject())
            projects.append(projectFromJson(value.toObject()));
    }
    return projects;
}

Project HttpProjectRepository::createProject(const QString &name, const QString &description,
                                             const QString &catalogVersion)
{
    QJsonObject body;
    body.insert(QStringLiteral("name"), name);
    body.insert(QStringLiteral("description"), description);
    body.insert(QStringLiteral("catalogVersion"), catalogVersion);

    int status = 0;
    const QJsonDocument doc = m_client.post(QStringLiteral("/api/v1/projects"), body, &status);
    if (status != 201 || !doc.isObject()) {
        m_lastError = m_client.lastError();
        return {};
    }
    return projectFromJson(doc.object());
}

bool HttpProjectRepository::updateProject(const Project &project)
{
    QJsonObject body;
    body.insert(QStringLiteral("name"), project.name);
    body.insert(QStringLiteral("description"), project.description);

    int status = 0;
    m_client.patch(QStringLiteral("/api/v1/projects/%1").arg(project.id), body, &status);
    if (status != 200) {
        m_lastError = m_client.lastError();
        return false;
    }
    return true;
}

bool HttpProjectRepository::deleteProject(int projectId)
{
    int status = 0;
    if (!m_client.del(QStringLiteral("/api/v1/projects/%1").arg(projectId), &status)) {
        m_lastError = m_client.lastError();
        return false;
    }
    return status == 204;
}

RequirementAssessment HttpProjectRepository::loadAssessment(int projectId, int targetObjectId,
                                                          int requirementDbId) const
{
    int status = 0;
    const QJsonDocument doc = m_client.get(
        QStringLiteral("/api/v1/projects/%1/target-objects/%2/requirements/%3/assessment")
            .arg(projectId)
            .arg(targetObjectId)
            .arg(requirementDbId),
        &status);
    if (status != 200 || !doc.isObject()) {
        m_lastError = m_client.lastError();
        return {};
    }
    return assessmentFromJson(doc.object());
}

AssessmentSaveResult HttpProjectRepository::saveAssessment(const RequirementAssessment &assessment)
{
    QJsonObject body;
    body.insert(QStringLiteral("status"), assessmentStatusToString(assessment.status));
    body.insert(QStringLiteral("note"), assessment.note);
    body.insert(QStringLiteral("responsible"), assessment.responsible);
    if (assessment.dueDate.isValid())
        body.insert(QStringLiteral("dueDate"), assessment.dueDate.toString(Qt::ISODate));
    body.insert(QStringLiteral("version"), assessment.version);

    int status = 0;
    const QJsonDocument doc = m_client.put(
        QStringLiteral("/api/v1/projects/%1/target-objects/%2/requirements/%3/assessment")
            .arg(assessment.projectId)
            .arg(assessment.targetObjectId)
            .arg(assessment.requirementDbId),
        body, &status);
    if (status == 200 && doc.isObject())
        return AssessmentSaveResult::ok(assessmentFromJson(doc.object()));

    if (status == 409 && doc.isObject()) {
        const QJsonObject obj = doc.object();
        const QJsonValue current = obj.value(QStringLiteral("current"));
        if (current.isObject())
            return AssessmentSaveResult::conflict(assessmentFromJson(current.toObject()));
    }

    m_lastError = m_client.lastError();
    return AssessmentSaveResult::failed();
}

QString HttpProjectRepository::lastError() const
{
    if (!m_lastError.isEmpty())
        return m_lastError;
    return m_client.lastError();
}
