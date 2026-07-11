#include "HttpTeamService.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

namespace {

ServerUser userFromJson(const QJsonObject &obj)
{
    ServerUser user;
    user.id = obj.value(QStringLiteral("id")).toInt();
    user.email = obj.value(QStringLiteral("email")).toString();
    user.displayName = obj.value(QStringLiteral("displayName")).toString();
    user.isAdmin = obj.value(QStringLiteral("isAdmin")).toBool();
    return user;
}

ProjectMember memberFromJson(const QJsonObject &obj)
{
    ProjectMember member;
    member.userId = obj.value(QStringLiteral("userId")).toInt();
    member.email = obj.value(QStringLiteral("email")).toString();
    member.displayName = obj.value(QStringLiteral("displayName")).toString();
    member.role = obj.value(QStringLiteral("role")).toString();
    return member;
}

QString readErrorMessage(const QJsonDocument &doc, const QString &fallback)
{
    if (!doc.isObject())
        return fallback;
    const QJsonObject obj = doc.object();
    if (obj.contains(QStringLiteral("error")))
        return obj.value(QStringLiteral("error")).toString(fallback);
    if (obj.contains(QStringLiteral("message")))
        return obj.value(QStringLiteral("message")).toString(fallback);
    return fallback;
}

} // namespace

HttpTeamService::HttpTeamService(ApiClient &client)
    : m_client(client)
{
}

bool HttpTeamService::fetchCurrentUser(ServerUser *user) const
{
    int status = 0;
    const QJsonDocument doc = m_client.get(QStringLiteral("/api/v1/auth/me"), &status);
    if (status != 200 || !doc.isObject()) {
        m_lastError = readErrorMessage(doc, m_client.lastError());
        return false;
    }
    if (user)
        *user = userFromJson(doc.object());
    return true;
}

QList<ServerUser> HttpTeamService::listUsers() const
{
    int status = 0;
    const QJsonDocument doc = m_client.get(QStringLiteral("/api/v1/admin/users"), &status);
    if (status != 200 || !doc.isArray()) {
        m_lastError = readErrorMessage(doc, m_client.lastError());
        return {};
    }

    QList<ServerUser> users;
    for (const QJsonValue &value : doc.array()) {
        if (value.isObject())
            users.append(userFromJson(value.toObject()));
    }
    return users;
}

ServerUser HttpTeamService::createUser(const QString &email, const QString &displayName,
                                         const QString &password, bool isAdmin) const
{
    QJsonObject body;
    body.insert(QStringLiteral("email"), email.trimmed());
    body.insert(QStringLiteral("displayName"), displayName.trimmed());
    body.insert(QStringLiteral("password"), password);
    body.insert(QStringLiteral("isAdmin"), isAdmin);

    int status = 0;
    const QJsonDocument doc = m_client.post(QStringLiteral("/api/v1/admin/users"), body, &status);
    if (status != 201 || !doc.isObject()) {
        m_lastError = readErrorMessage(doc, m_client.lastError());
        return {};
    }
    return userFromJson(doc.object());
}

QList<ProjectMember> HttpTeamService::listMembers(int projectId) const
{
    int status = 0;
    const QJsonDocument doc = m_client.get(
        QStringLiteral("/api/v1/projects/%1/members").arg(projectId), &status);
    if (status != 200 || !doc.isArray()) {
        m_lastError = readErrorMessage(doc, m_client.lastError());
        return {};
    }

    QList<ProjectMember> members;
    for (const QJsonValue &value : doc.array()) {
        if (value.isObject())
            members.append(memberFromJson(value.toObject()));
    }
    return members;
}

ProjectMember HttpTeamService::addMember(int projectId, const QString &email,
                                         const QString &role) const
{
    QJsonObject body;
    body.insert(QStringLiteral("email"), email.trimmed());
    body.insert(QStringLiteral("role"), role);

    int status = 0;
    const QJsonDocument doc = m_client.post(
        QStringLiteral("/api/v1/projects/%1/members").arg(projectId), body, &status);
    if (status != 201 || !doc.isObject()) {
        m_lastError = readErrorMessage(doc, m_client.lastError());
        return {};
    }
    return memberFromJson(doc.object());
}

ProjectMember HttpTeamService::updateMemberRole(int projectId, int userId,
                                                const QString &role) const
{
    QJsonObject body;
    body.insert(QStringLiteral("role"), role);

    int status = 0;
    const QJsonDocument doc = m_client.patch(
        QStringLiteral("/api/v1/projects/%1/members/%2").arg(projectId).arg(userId), body, &status);
    if (status != 200 || !doc.isObject()) {
        m_lastError = readErrorMessage(doc, m_client.lastError());
        return {};
    }
    return memberFromJson(doc.object());
}

bool HttpTeamService::removeMember(int projectId, int userId) const
{
    int status = 0;
    if (!m_client.del(QStringLiteral("/api/v1/projects/%1/members/%2").arg(projectId).arg(userId),
                      &status)) {
        m_lastError = m_client.lastError();
        return false;
    }
    if (status != 204) {
        m_lastError = QStringLiteral("HTTP %1").arg(status);
        return false;
    }
    return true;
}

QString HttpTeamService::lastError() const
{
    if (!m_lastError.isEmpty())
        return m_lastError;
    return m_client.lastError();
}
