#ifndef NET_APICLIENT_H
#define NET_APICLIENT_H

#include <QByteArray>
#include <QDateTime>
#include <QJsonDocument>
#include <QJsonObject>
#include <QString>
#include <QUrl>

#include <functional>

class ApiClient
{
public:
    using ReloginHandler = std::function<bool()>;

    explicit ApiClient(const QString &baseUrl = {});

    void setBaseUrl(const QString &baseUrl);
    QString baseUrl() const;

    void setAccessToken(const QString &token);
    QString accessToken() const;

    void setTokenExpiresAt(const QDateTime &expiresAt);
    QDateTime tokenExpiresAt() const;

    void setInsecureSkipTlsVerify(bool skip);
    bool insecureSkipTlsVerify() const;

    void setReloginHandler(ReloginHandler handler);

    bool isTokenExpired() const;
    bool hasValidConnection() const;

    bool login(const QString &email, const QString &password, QString *errorMessage = nullptr);
    bool validateSession(QString *errorMessage = nullptr) const;
    bool applyFromSettings(const QString &baseUrl, const QString &accessToken,
                           const QDateTime &tokenExpiresAt);

    QJsonDocument get(const QString &path, int *statusCode = nullptr) const;
    QJsonDocument post(const QString &path, const QJsonObject &body, int *statusCode = nullptr) const;
    QJsonDocument put(const QString &path, const QJsonObject &body, int *statusCode = nullptr) const;
    QJsonDocument patch(const QString &path, const QJsonObject &body, int *statusCode = nullptr) const;
    bool del(const QString &path, int *statusCode = nullptr) const;
    QJsonDocument uploadFile(const QString &path, const QString &fieldName, const QString &filePath,
                             int *statusCode = nullptr) const;

    QString lastError() const;
    bool lastAuthFailure() const;

private:
    QJsonDocument sendRequest(const QByteArray &method, const QString &path, const QByteArray &body,
                              const QString &contentType, int *statusCode, bool allowRelogin) const;

    void configureTls(QNetworkReply *reply) const;
    bool isAuthEndpoint(const QString &path) const;
    static QString readApiError(const QJsonDocument &doc, const QString &fallback);

    QString m_baseUrl;
    QString m_accessToken;
    QDateTime m_tokenExpiresAt;
    bool m_insecureSkipTlsVerify = false;
    ReloginHandler m_reloginHandler;
    mutable QString m_lastError;
    mutable bool m_lastAuthFailure = false;
};

#endif
