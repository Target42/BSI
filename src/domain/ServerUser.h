#ifndef DOMAIN_SERVERUSER_H
#define DOMAIN_SERVERUSER_H

#include <QString>

struct ServerUser {
    int id = 0;
    QString email;
    QString displayName;
    bool isAdmin = false;
};

struct ProjectMember {
    int userId = 0;
    QString email;
    QString displayName;
    QString role;
};

#endif
