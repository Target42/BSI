#ifndef NET_APICLIENT_H
#define NET_APICLIENT_H

#include <QByteArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QString>
#include <QUrl>

class ApiClient
{
public:
    explicit ApiClient(const QString &baseUrl = {});

    void setBaseUrl(const QString &baseUrl);
    QString baseUrl() const;

    void setAccessToken(const QString &token);
    QString accessToken() const;

    bool hasValidConnection() const;

    bool login(const QString &email, const QString &password, QString *errorMessage = nullptr);
    bool validateSession(QString *errorMessage = nullptr) const;

    QJsonDocument get(const QString &path, int *statusCode = nullptr) const;
    QJsonDocument post(const QString &path, const QJsonObject &body, int *statusCode = nullptr) const;
    QJsonDocument put(const QString &path, const QJsonObject &body, int *statusCode = nullptr) const;
    QJsonDocument patch(const QString &path, const QJsonObject &body, int *statusCode = nullptr) const;
    bool del(const QString &path, int *statusCode = nullptr) const;
    QJsonDocument uploadFile(const QString &path, const QString &fieldName, const QString &filePath,
                             int *statusCode = nullptr) const;

    QString lastError() const;

private:
    QJsonDocument sendRequest(const QByteArray &method, const QString &path, const QByteArray &body,
                              const QString &contentType, int *statusCode) const;

    QUrl buildUrl(const QString &path) const;

    QString m_baseUrl;
    QString m_accessToken;
    mutable QString m_lastError;
};

#endif
