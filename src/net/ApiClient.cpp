#include "ApiClient.h"

#include <QEventLoop>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSslError>
#include <QStringList>
#include <QTimeZone>

namespace {

constexpr int kExpirySkewSeconds = 60;

QString networkFailureMessage(const QString &errorString)
{
    if (errorString.contains(QLatin1String("Unable to write"), Qt::CaseInsensitive)
        || errorString.contains(QLatin1String("Connection closed"), Qt::CaseInsensitive)
        || errorString.contains(QLatin1String("Connection reset"), Qt::CaseInsensitive)) {
        return QStringLiteral(
            "Upload abgebrochen. Der Server hat die Verbindung geschlossen "
            "(häufig ein veralteter Prozess ohne Katalog-API). "
            "Bitte den ISMS-Server neu starten und den Import erneut versuchen.");
    }
    return QStringLiteral("Netzwerkfehler: %1").arg(errorString);
}

} // namespace

ApiClient::ApiClient(const QString &baseUrl)
{
    setBaseUrl(baseUrl);
}

void ApiClient::setBaseUrl(const QString &baseUrl)
{
    m_baseUrl = normalizeBaseUrl(baseUrl);
    m_baseUrlResolved = false;
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
        m_tokenExpiresAt.setTimeZone(QTimeZone::utc());

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
    Q_UNUSED(fieldName)
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        m_lastError = QStringLiteral("Datei konnte nicht geöffnet werden: %1").arg(filePath);
        if (statusCode)
            *statusCode = 0;
        return {};
    }
    const QByteArray xml = file.readAll();
    file.close();
    if (xml.isEmpty()) {
        m_lastError = QStringLiteral("Datei ist leer oder konnte nicht gelesen werden: %1").arg(filePath);
        if (statusCode)
            *statusCode = 0;
        return {};
    }
    return sendRequest(QByteArrayLiteral("POST"), path, xml, QStringLiteral("application/xml"),
                       statusCode, true);
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
    resolvePublicBaseUrlIfNeeded();
    QNetworkRequest request(buildUrl(path));
    if (!contentType.isEmpty())
        request.setHeader(QNetworkRequest::ContentTypeHeader, contentType);
    if (!m_accessToken.isEmpty())
        request.setRawHeader("Authorization", "Bearer " + m_accessToken.toUtf8());
#if QT_VERSION >= QT_VERSION_CHECK(5, 15, 0)
    request.setTransferTimeout(15 * 60 * 1000);
#endif

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
        m_lastError = networkFailureMessage(reply->errorString());
        m_lastAuthFailure = false;
    } else if (status == 404) {
        m_lastError = path.contains(QStringLiteral("/catalog"))
                          ? QStringLiteral("Katalog-API nicht gefunden (HTTP 404). "
                                           "Bitte den ISMS-Server neu bauen und neu starten.")
                          : readApiError(doc, QStringLiteral("HTTP 404"));
        m_lastAuthFailure = false;
    } else if (status >= 400) {
        m_lastError = readApiError(doc, QStringLiteral("HTTP %1").arg(status));
        m_lastAuthFailure = status == 401;
    } else {
        m_lastAuthFailure = false;
    }

    delete reply;

    if (allowRelogin && status == 401 && !isAuthEndpoint(path) && m_reloginHandler) {
        if (m_reloginHandler())
            return sendRequest(method, path, body, contentType, statusCode, false);
    }

    return doc;
}

QString ApiClient::normalizeBaseUrl(const QString &baseUrl)
{
    QString url = baseUrl.trimmed();
    while (url.endsWith(QLatin1Char('/')))
        url.chop(1);
    const int apiPos = url.toLower().indexOf(QLatin1String("/api/v1"));
    if (apiPos >= 0)
        url = url.left(apiPos);
    while (url.endsWith(QLatin1Char('/')))
        url.chop(1);
    return url;
}

bool ApiClient::endsWithPath(const QString &url, const QString &path)
{
    return !path.isEmpty() && url.endsWith(path, Qt::CaseInsensitive);
}

QString ApiClient::baseUrlFromHealthUrl(const QUrl &url)
{
    QString resolved = normalizeBaseUrl(
        url.toString(QUrl::RemoveQuery | QUrl::RemoveFragment | QUrl::StripTrailingSlash));
    if (endsWithPath(resolved, QStringLiteral("/health")))
        resolved.chop(QStringLiteral("/health").size());
    return normalizeBaseUrl(resolved);
}

bool ApiClient::rawGet(const QUrl &url, int *status, QByteArray *payload, QUrl *finalUrl) const
{
    if (status)
        *status = 0;
    if (payload)
        payload->clear();
    if (finalUrl)
        *finalUrl = url;

    QNetworkAccessManager manager;
    QNetworkRequest request(url);
    request.setRawHeader("Accept", "application/json");
#if QT_VERSION >= QT_VERSION_CHECK(5, 15, 0)
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(15000);
#elif QT_VERSION >= QT_VERSION_CHECK(5, 6, 0)
    request.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);
#endif

    QNetworkReply *reply = manager.get(request);
    if (!reply)
        return false;
    configureTls(reply);

    QEventLoop loop;
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    const int code = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (status)
        *status = code;
    if (payload)
        *payload = reply->readAll();
    if (finalUrl)
        *finalUrl = reply->url();

    const bool networkOk = !(reply->error() && code == 0);
    delete reply;
    return networkOk;
}

bool ApiClient::probeHealth(const QString &base, QString *resolvedBase, bool *unreachable) const
{
    if (resolvedBase)
        *resolvedBase = base;
    if (unreachable)
        *unreachable = false;

    int status = 0;
    QByteArray payload;
    QUrl finalUrl;
    if (!rawGet(QUrl(base + QStringLiteral("/health")), &status, &payload, &finalUrl)) {
        if (unreachable)
            *unreachable = true;
        return false;
    }
    if (status != 200)
        return false;

    const QJsonDocument doc = QJsonDocument::fromJson(payload);
    if (!doc.isObject())
        return false;
    if (doc.object().value(QStringLiteral("status")).toString() != QLatin1String("ok"))
        return false;

    const QString resolved = baseUrlFromHealthUrl(finalUrl);
    if (resolvedBase)
        *resolvedBase = resolved.isEmpty() ? base : resolved;
    return true;
}

bool ApiClient::probeApiRoot(const QString &base, bool *unreachable) const
{
    if (unreachable)
        *unreachable = false;

    int status = 0;
    QByteArray payload;
    QUrl finalUrl;
    if (!rawGet(QUrl(base + QStringLiteral("/api/v1/auth/login")), &status, &payload, &finalUrl)) {
        if (unreachable)
            *unreachable = true;
        return false;
    }
    Q_UNUSED(payload)
    Q_UNUSED(finalUrl)
    return status == 400 || status == 401 || status == 405 || status == 415 || status == 422;
}

bool ApiClient::ismsReachableAt(const QString &base, QString *resolvedBase, bool *unreachable) const
{
    if (probeHealth(base, resolvedBase, unreachable))
        return true;
    if (unreachable && *unreachable)
        return false;
    if (resolvedBase)
        *resolvedBase = base;
    return probeApiRoot(base, unreachable);
}

void ApiClient::resolvePublicBaseUrlIfNeeded() const
{
    if (m_baseUrlResolved)
        return;
    m_baseUrlResolved = true;
    if (m_baseUrl.trimmed().isEmpty())
        return;

    QString resolved;
    bool unreachable = false;
    if (ismsReachableAt(m_baseUrl, &resolved, &unreachable)) {
        m_baseUrl = resolved;
        return;
    }
    if (unreachable)
        return;

    static const QStringList kProxyPrefixes{QStringLiteral("/isms")};
    for (const QString &prefix : kProxyPrefixes) {
        if (endsWithPath(m_baseUrl, prefix))
            continue;
        const QString candidate = m_baseUrl + prefix;
        if (ismsReachableAt(candidate, &resolved, &unreachable)) {
            m_baseUrl = resolved;
            return;
        }
        if (unreachable)
            return;
    }
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
