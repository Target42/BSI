#include "ApiClient.h"

#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QHttpMultiPart>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSslError>

namespace {

constexpr int kExpirySkewSeconds = 60;

} // namespace

ApiClient::ApiClient(const QString &baseUrl)
    : m_baseUrl(baseUrl)
{
}

void ApiClient::setBaseUrl(const QString &baseUrl)
{
    m_baseUrl = baseUrl.trimmed();
    while (m_baseUrl.endsWith(QLatin1Char('/')))
        m_baseUrl.chop(1);
}

QString ApiClient::baseUrl() const
{
    return m_baseUrl;
}

void ApiClient::setAccessToken(const QString &token)
{
    m_accessToken = token;
}

QString ApiClient::accessToken() const
{
    return m_accessToken;
}

void ApiClient::setTokenExpiresAt(const QDateTime &expiresAt)
{
    m_tokenExpiresAt = expiresAt;
}

QDateTime ApiClient::tokenExpiresAt() const
{
    return m_tokenExpiresAt;
}

void ApiClient::setInsecureSkipTlsVerify(bool skip)
{
    m_insecureSkipTlsVerify = skip;
}

bool ApiClient::insecureSkipTlsVerify() const
{
    return m_insecureSkipTlsVerify;
}

void ApiClient::setReloginHandler(ReloginHandler handler)
{
    m_reloginHandler = std::move(handler);
}

bool ApiClient::isTokenExpired() const
{
    if (m_accessToken.isEmpty())
        return true;
    if (!m_tokenExpiresAt.isValid())
        return false;
    return QDateTime::currentDateTimeUtc().secsTo(m_tokenExpiresAt) <= kExpirySkewSeconds;
}

bool ApiClient::applyFromSettings(const QString &baseUrl, const QString &accessToken,
                                  const QDateTime &tokenExpiresAt)
{
    setBaseUrl(baseUrl);
    setAccessToken(accessToken);
    setTokenExpiresAt(tokenExpiresAt);
    return !isTokenExpired() && validateSession(nullptr);
}

bool ApiClient::hasValidConnection() const
{
    if (isTokenExpired())
        return false;
    return validateSession(nullptr);
}

bool ApiClient::login(const QString &email, const QString &password, QString *errorMessage)
{
    QJsonObject body;
    body.insert(QStringLiteral("email"), email);
    body.insert(QStringLiteral("password"), password);

    int status = 0;
    const QJsonDocument response = sendRequest(QByteArrayLiteral("POST"),
                                               QStringLiteral("/api/v1/auth/login"),
                                               QJsonDocument(body).toJson(QJsonDocument::Compact),
                                               QStringLiteral("application/json"), &status, false);
    if (status != 200 || !response.isObject()) {
        m_lastError = readApiError(response, QStringLiteral("Login fehlgeschlagen."));
        if (errorMessage)
            *errorMessage = m_lastError;
        return false;
    }

    const QJsonObject obj = response.object();
    m_accessToken = obj.value(QStringLiteral("accessToken")).toString();
    m_tokenExpiresAt =
        QDateTime::fromString(obj.value(QStringLiteral("expiresAt")).toString(), Qt::ISODate);
    if (m_tokenExpiresAt.isValid())
        m_tokenExpiresAt.setTimeSpec(Qt::UTC);

    if (m_accessToken.isEmpty()) {
        m_lastError = QStringLiteral("Server lieferte kein Token.");
        if (errorMessage)
            *errorMessage = m_lastError;
        return false;
    }
    m_lastAuthFailure = false;
    return true;
}

bool ApiClient::validateSession(QString *errorMessage) const
{
    if (m_accessToken.isEmpty()) {
        m_lastError = QStringLiteral("Kein Zugriffstoken.");
        if (errorMessage)
            *errorMessage = m_lastError;
        return false;
    }
    if (isTokenExpired()) {
        m_lastError = QStringLiteral("token_expired");
        m_lastAuthFailure = true;
        if (errorMessage)
            *errorMessage = m_lastError;
        return false;
    }

    int status = 0;
    const QJsonDocument response = get(QStringLiteral("/api/v1/auth/me"), &status);
    if (status != 200) {
        m_lastError = readApiError(response, QStringLiteral("Sitzung ungültig."));
        m_lastAuthFailure = status == 401;
        if (errorMessage)
            *errorMessage = m_lastError;
        return false;
    }
    m_lastAuthFailure = false;
    return true;
}

QJsonDocument ApiClient::get(const QString &path, int *statusCode) const
{
    return sendRequest(QByteArrayLiteral("GET"), path, {}, {}, statusCode, true);
}

QJsonDocument ApiClient::post(const QString &path, const QJsonObject &body, int *statusCode) const
{
    return sendRequest(QByteArrayLiteral("POST"), path,
                       QJsonDocument(body).toJson(QJsonDocument::Compact),
                       QStringLiteral("application/json"), statusCode, true);
}

QJsonDocument ApiClient::put(const QString &path, const QJsonObject &body, int *statusCode) const
{
    return sendRequest(QByteArrayLiteral("PUT"), path,
                       QJsonDocument(body).toJson(QJsonDocument::Compact),
                       QStringLiteral("application/json"), statusCode, true);
}

QJsonDocument ApiClient::patch(const QString &path, const QJsonObject &body, int *statusCode) const
{
    return sendRequest(QByteArrayLiteral("PATCH"), path,
                       QJsonDocument(body).toJson(QJsonDocument::Compact),
                       QStringLiteral("application/json"), statusCode, true);
}

bool ApiClient::del(const QString &path, int *statusCode) const
{
    sendRequest(QByteArrayLiteral("DELETE"), path, {}, {}, statusCode, true);
    return statusCode == nullptr || (*statusCode >= 200 && *statusCode < 300);
}

QJsonDocument ApiClient::uploadFile(const QString &path, const QString &fieldName,
                                    const QString &filePath, int *statusCode) const
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        m_lastError = QStringLiteral("Datei konnte nicht geöffnet werden: %1").arg(filePath);
        if (statusCode)
            *statusCode = 0;
        return {};
    }

    QHttpMultiPart *multiPart = new QHttpMultiPart(QHttpMultiPart::FormDataType);
    QHttpPart filePart;
    filePart.setHeader(QNetworkRequest::ContentDispositionHeader,
                       QStringLiteral("form-data; name=\"%1\"; filename=\"%2\"")
                           .arg(fieldName, QFileInfo(filePath).fileName()));
    filePart.setBodyDevice(&file);
    file.setParent(multiPart);
    multiPart->append(filePart);

    QNetworkAccessManager manager;
    QNetworkRequest request(buildUrl(path));
    if (!m_accessToken.isEmpty())
        request.setRawHeader("Authorization", "Bearer " + m_accessToken.toUtf8());

    QNetworkReply *reply = manager.post(request, multiPart);
    multiPart->setParent(reply);
    configureTls(reply);

    QEventLoop loop;
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (statusCode)
        *statusCode = status;

    QJsonDocument doc;
    const QByteArray payload = reply->readAll();
    if (!payload.isEmpty())
        doc = QJsonDocument::fromJson(payload);

    if (reply->error() && status == 0) {
        m_lastError = reply->errorString();
    } else if (status >= 400) {
        m_lastError = readApiError(doc, QStringLiteral("HTTP %1").arg(status));
        m_lastAuthFailure = status == 401;
    } else {
        m_lastAuthFailure = false;
    }

    reply->deleteLater();

    if (status == 401 && !isAuthEndpoint(path) && m_reloginHandler) {
        if (m_reloginHandler())
            return uploadFile(path, fieldName, filePath, statusCode);
    }

    return doc;
}

QJsonDocument ApiClient::sendRequest(const QByteArray &method, const QString &path,
                                     const QByteArray &body, const QString &contentType,
                                     int *statusCode, bool allowRelogin) const
{
    if (allowRelogin && !isAuthEndpoint(path) && !m_accessToken.isEmpty() && isTokenExpired()) {
        m_lastAuthFailure = true;
        m_lastError = QStringLiteral("token_expired");
        if (m_reloginHandler && m_reloginHandler())
            return sendRequest(method, path, body, contentType, statusCode, false);
        if (statusCode)
            *statusCode = 401;
        return {};
    }

    QNetworkAccessManager manager;
    QNetworkRequest request(buildUrl(path));
    if (!contentType.isEmpty())
        request.setHeader(QNetworkRequest::ContentTypeHeader, contentType);
    if (!m_accessToken.isEmpty())
        request.setRawHeader("Authorization", "Bearer " + m_accessToken.toUtf8());

    QNetworkReply *reply = nullptr;
    if (method == "GET")
        reply = manager.get(request);
    else if (method == "POST")
        reply = manager.post(request, body);
    else if (method == "PUT")
        reply = manager.put(request, body);
    else if (method == "PATCH")
        reply = manager.sendCustomRequest(request, method, body);
    else if (method == "DELETE")
        reply = manager.sendCustomRequest(request, method);

    if (!reply) {
        m_lastError = QStringLiteral("HTTP-Methode nicht unterstützt.");
        if (statusCode)
            *statusCode = 0;
        return {};
    }

    configureTls(reply);

    QEventLoop loop;
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (statusCode)
        *statusCode = status;

    const QByteArray payload = reply->readAll();
    QJsonDocument doc;
    if (!payload.isEmpty())
        doc = QJsonDocument::fromJson(payload);

    if (reply->error() && status == 0) {
        m_lastError = reply->errorString();
        m_lastAuthFailure = false;
    } else if (status >= 400) {
        m_lastError = readApiError(doc, QStringLiteral("HTTP %1").arg(status));
        m_lastAuthFailure = status == 401;
    } else {
        m_lastAuthFailure = false;
    }

    reply->deleteLater();

    if (allowRelogin && status == 401 && !isAuthEndpoint(path) && m_reloginHandler) {
        if (m_reloginHandler())
            return sendRequest(method, path, body, contentType, statusCode, false);
    }

    return doc;
}

void ApiClient::configureTls(QNetworkReply *reply) const
{
    if (!m_insecureSkipTlsVerify || !reply)
        return;
    QObject::connect(reply, &QNetworkReply::sslErrors, reply,
                     [reply](const QList<QSslError> &) { reply->ignoreSslErrors(); });
}

bool ApiClient::isAuthEndpoint(const QString &path) const
{
    return path.startsWith(QStringLiteral("/api/v1/auth/"));
}

QString ApiClient::readApiError(const QJsonDocument &doc, const QString &fallback)
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

QUrl ApiClient::buildUrl(const QString &path) const
{
    QString normalizedPath = path;
    if (!normalizedPath.startsWith(QLatin1Char('/')))
        normalizedPath.prepend(QLatin1Char('/'));
    return QUrl(m_baseUrl + normalizedPath);
}

QString ApiClient::lastError() const
{
    return m_lastError;
}

bool ApiClient::lastAuthFailure() const
{
    return m_lastAuthFailure;
}
