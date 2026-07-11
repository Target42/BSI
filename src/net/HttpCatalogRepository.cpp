#include "HttpCatalogRepository.h"

#include "domain/Standard.h"
#include "net/HttpJson.h"

#include <QJsonArray>
#include <QUrlQuery>

HttpCatalogRepository::HttpCatalogRepository(ApiClient &client)
    : m_client(client)
{
}

bool HttpCatalogRepository::replaceGrundschutzCatalog(const GrundschutzImportResult &importResult)
{
    Q_UNUSED(importResult)
    if (m_lastImportPath.isEmpty()) {
        m_lastError = QStringLiteral("Kein Importpfad gesetzt.");
        return false;
    }

    int status = 0;
    const QJsonDocument doc = m_client.uploadFile(
        QStringLiteral("/api/v1/admin/catalog/import"), QStringLiteral("file"), m_lastImportPath, &status);
    if (status != 200) {
        m_lastError = m_client.lastError();
        if (doc.isObject() && doc.object().contains(QStringLiteral("message")))
            m_lastError = doc.object().value(QStringLiteral("message")).toString();
        return false;
    }
    return true;
}

bool HttpCatalogRepository::hasGrundschutzCatalog(const QString &catalogVersion) const
{
    int status = 0;
    const QJsonDocument doc = m_client.get(QStringLiteral("/api/v1/catalog/versions"), &status);
    if (status != 200 || !doc.isArray()) {
        m_lastError = m_client.lastError();
        return false;
    }
    for (const QJsonValue &value : doc.array()) {
        if (value.toString() == catalogVersion)
            return true;
    }
    return false;
}

QList<Baustein> HttpCatalogRepository::loadBausteine(StandardType standard,
                                                     const QString &catalogVersion) const
{
    Q_UNUSED(standard)
    int status = 0;
    const QJsonDocument doc = m_client.get(
        QStringLiteral("/api/v1/catalog/%1/bausteine").arg(catalogVersion), &status);
    if (status != 200 || !doc.isArray()) {
        m_lastError = m_client.lastError();
        return {};
    }

    QList<Baustein> bausteine;
    for (const QJsonValue &value : doc.array()) {
        if (value.isObject())
            bausteine.append(bausteinFromJson(value.toObject()));
    }
    return bausteine;
}

QList<Requirement> HttpCatalogRepository::loadRequirements(int bausteinDbId) const
{
    int status = 0;
    const QJsonDocument doc = m_client.get(
        QStringLiteral("/api/v1/catalog/bausteine/%1/requirements").arg(bausteinDbId), &status);
    if (status != 200 || !doc.isArray()) {
        m_lastError = m_client.lastError();
        return {};
    }

    QList<Requirement> requirements;
    for (const QJsonValue &value : doc.array()) {
        if (value.isObject())
            requirements.append(requirementFromJson(value.toObject()));
    }
    return requirements;
}

QList<Requirement> HttpCatalogRepository::loadAllRequirements(StandardType standard,
                                                              const QString &catalogVersion) const
{
    QList<Requirement> allRequirements;
    const QList<Baustein> bausteine = loadBausteine(standard, catalogVersion);
    for (const Baustein &baustein : bausteine)
        allRequirements.append(loadRequirements(baustein.id));
    return allRequirements;
}

QString HttpCatalogRepository::lastError() const
{
    if (!m_lastError.isEmpty())
        return m_lastError;
    return m_client.lastError();
}
