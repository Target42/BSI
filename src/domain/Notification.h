#ifndef DOMAIN_NOTIFICATION_H
#define DOMAIN_NOTIFICATION_H

#include <QDateTime>
#include <QString>

struct NotificationItem {
    int id = 0;
    int userId = 0;
    int projectId = 0;
    QString projectName;
    int targetObjectId = 0;
    int bausteinId = 0;
    QString kind;
    QString title;
    QString body;
    QString linkPath;
    QDateTime readAt;
    QDateTime createdAt;
    bool unread = true;
};

inline QString notificationKindLabel(const QString &kind)
{
    if (kind == QLatin1String("review_submitted"))
        return QStringLiteral("Zur Prüfung");
    if (kind == QLatin1String("review_returned"))
        return QStringLiteral("Zurückgegeben");
    if (kind == QLatin1String("review_accepted"))
        return QStringLiteral("Abgenommen");
    return kind;
}

#endif
