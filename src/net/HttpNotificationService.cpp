#include "HttpNotificationService.h"

#include "net/HttpJson.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

namespace {

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

NotificationItem notificationFromJson(const QJsonObject &obj)
{
    NotificationItem item;
    item.id = obj.value(QStringLiteral("id")).toInt();
    item.userId = obj.value(QStringLiteral("userId")).toInt();
    item.projectId = obj.value(QStringLiteral("projectId")).toInt();
    item.projectName = obj.value(QStringLiteral("projectName")).toString();
    item.targetObjectId = obj.value(QStringLiteral("targetObjectId")).toInt();
    item.bausteinId = obj.value(QStringLiteral("bausteinId")).toInt();
    item.kind = obj.value(QStringLiteral("kind")).toString();
    item.title = obj.value(QStringLiteral("title")).toString();
    item.body = obj.value(QStringLiteral("body")).toString();
    item.linkPath = obj.value(QStringLiteral("linkPath")).toString();
    item.readAt = parseDateTime(obj.value(QStringLiteral("readAt")));
    item.createdAt = parseDateTime(obj.value(QStringLiteral("createdAt")));
    item.unread = item.readAt.isNull() || !item.readAt.isValid();
    return item;
}

} // namespace

HttpNotificationService::HttpNotificationService(ApiClient &client)
    : m_client(client)
{
}

QList<NotificationItem> HttpNotificationService::list() const
{
    int status = 0;
    const QJsonDocument doc = m_client.get(QStringLiteral("/api/v1/notifications"), &status);
    if (status != 200 || !doc.isArray()) {
        m_lastError = readErrorMessage(doc, m_client.lastError());
        return {};
    }
    m_lastError.clear();
    QList<NotificationItem> items;
    for (const QJsonValue &value : doc.array()) {
        if (value.isObject())
            items.append(notificationFromJson(value.toObject()));
    }
    return items;
}

bool HttpNotificationService::markRead(int notificationId) const
{
    if (notificationId <= 0)
        return false;
    int status = 0;
    const QJsonDocument doc = m_client.post(
        QStringLiteral("/api/v1/notifications/%1/read").arg(notificationId), {}, &status);
    if (status < 200 || status >= 300) {
        m_lastError = readErrorMessage(doc, m_client.lastError());
        return false;
    }
    m_lastError.clear();
    return true;
}

bool HttpNotificationService::markAllRead() const
{
    int status = 0;
    const QJsonDocument doc = m_client.post(QStringLiteral("/api/v1/notifications/read-all"), {}, &status);
    if (status < 200 || status >= 300) {
        m_lastError = readErrorMessage(doc, m_client.lastError());
        return false;
    }
    m_lastError.clear();
    return true;
}

QString HttpNotificationService::lastError() const
{
    return m_lastError.isEmpty() ? m_client.lastError() : m_lastError;
}
