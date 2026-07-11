#include "ApiClient.h"

#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QHttpMultiPart>
#include <QJsonArray>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>

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

bool ApiClient::hasValidConnection() const
{
    return validateSession(nullptr);
}

bool ApiClient::login(const QString &email, const QString &password, QString *errorMessage)
{
    QJsonObject body;
    body.insert(QStringLiteral("email"), email);
    body.insert(QStringLiteral("password"), password);

    int status = 0;
    const QJsonDocument response = post(QStringLiteral("/api/v1/auth/login"), body, &status);
    if (status != 200 || !response.isObject()) {
        m_lastError = readErrorMessage(response, QStringLiteral("Login fehlgeschlagen."));
        if (errorMessage)
            *errorMessage = m_lastError;
        return false;
    }

    const QJsonObject obj = response.object();
    m_accessToken = obj.value(QStringLiteral("accessToken")).toString();
    if (m_accessToken.isEmpty()) {
        m_lastError = QStringLiteral("Server lieferte kein Token.");
        if (errorMessage)
            *errorMessage = m_lastError;
        return false;
    }
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

    int status = 0;
    const QJsonDocument response = get(QStringLiteral("/api/v1/auth/me"), &status);
    if (status != 200) {
        m_lastError = readErrorMessage(response, QStringLiteral("Sitzung ungültig."));
        if (errorMessage)
            *errorMessage = m_lastError;
        return false;
    }
    return true;
}

QJsonDocument ApiClient::get(const QString &path, int *statusCode) const
{
    return sendRequest(QByteArrayLiteral("GET"), path, {}, {}, statusCode);
}

QJsonDocument ApiClient::post(const QString &path, const QJsonObject &body, int *statusCode) const
{
    return sendRequest(QByteArrayLiteral("POST"), path,
                       QJsonDocument(body).toJson(QJsonDocument::Compact),
                       QStringLiteral("application/json"), statusCode);
}

QJsonDocument ApiClient::put(const QString &path, const QJsonObject &body, int *statusCode) const
{
    return sendRequest(QByteArrayLiteral("PUT"), path,
                       QJsonDocument(body).toJson(QJsonDocument::Compact),
                       QStringLiteral("application/json"), statusCode);
}

QJsonDocument ApiClient::patch(const QString &path, const QJsonObject &body, int *statusCode) const
{
    return sendRequest(QByteArrayLiteral("PATCH"), path,
                       QJsonDocument(body).toJson(QJsonDocument::Compact),
                       QStringLiteral("application/json"), statusCode);
}

bool ApiClient::del(const QString &path, int *statusCode) const
{
    sendRequest(QByteArrayLiteral("DELETE"), path, {}, {}, statusCode);
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

    QEventLoop loop;
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (statusCode)
        *statusCode = status;

    QJsonDocument doc;
    if (!reply->error()) {
        doc = QJsonDocument::fromJson(reply->readAll());
    } else {
        doc = QJsonDocument::fromJson(reply->readAll());
        m_lastError = readErrorMessage(doc, reply->errorString());
    }
    reply->deleteLater();
    return doc;
}

QJsonDocument ApiClient::sendRequest(const QByteArray &method, const QString &path,
                                     const QByteArray &body, const QString &contentType,
                                     int *statusCode) const
{
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
    } else if (status >= 400) {
        m_lastError = readErrorMessage(doc, QStringLiteral("HTTP %1").arg(status));
    }

    reply->deleteLater();
    return doc;
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
