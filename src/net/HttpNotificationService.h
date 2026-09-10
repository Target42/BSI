#ifndef NET_HTTPNOTIFICATIONSERVICE_H
#define NET_HTTPNOTIFICATIONSERVICE_H

#include "domain/Notification.h"
#include "net/ApiClient.h"

#include <QList>

class HttpNotificationService
{
public:
    explicit HttpNotificationService(ApiClient &client);

    QList<NotificationItem> list() const;
    bool markRead(int notificationId) const;
    bool markAllRead() const;
    QString lastError() const;

private:
    ApiClient &m_client;
    mutable QString m_lastError;
};

#endif
