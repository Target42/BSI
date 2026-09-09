#ifndef DOMAIN_PROJECT_H
#define DOMAIN_PROJECT_H

#include <QString>
#include <QDateTime>

struct Project {
    int id = 0;
    QString name;
    QString description;
    QString catalogVersion;
    QString role;
    bool workflowEnabled = false;
    QDateTime createdAt;
    QDateTime updatedAt;
};

#endif
