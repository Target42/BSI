#ifndef NET_HTTPTEAMSERVICE_H
#define NET_HTTPTEAMSERVICE_H

#include "domain/ServerUser.h"
#include "net/ApiClient.h"

#include <QList>

class HttpTeamService
{
public:
    explicit HttpTeamService(ApiClient &client);

    bool fetchCurrentUser(ServerUser *user) const;
    QList<ServerUser> listUsers() const;
    ServerUser createUser(const QString &email, const QString &displayName, const QString &password,
                          bool isAdmin) const;

    QList<ProjectMember> listMembers(int projectId) const;
    ProjectMember addMember(int projectId, const QString &email, const QString &role) const;
    ProjectMember updateMemberRole(int projectId, int userId, const QString &role) const;
    bool removeMember(int projectId, int userId) const;

    QString lastError() const;

private:
    ApiClient &m_client;
    mutable QString m_lastError;
};

#endif
