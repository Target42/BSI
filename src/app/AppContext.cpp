#include "AppContext.h"
#include "AppPaths.h"

#include "app/AppSettings.h"
#include "net/HttpTeamService.h"
#include "ui/dialogs/LoginDialog.h"

#include <QFile>
#include <QJsonDocument>

AppContext::AppContext() = default;

bool AppContext::initializeLocal()
{
    m_remote = false;
    m_database = std::make_unique<Database>(AppPaths::databaseFile());
    if (AppPaths::databaseFile().isEmpty()) {
        m_lastError = QStringLiteral("Datenverzeichnis konnte nicht erstellt werden.");
        return false;
    }
    if (!m_database->open()) {
        m_lastError = m_database->lastError();
        return false;
    }

    m_catalogRepository = std::make_unique<CatalogRepository>(m_database->connection());
    m_projectRepository = std::make_unique<ProjectRepository>(m_database->connection());
    m_targetObjectRepository = std::make_unique<TargetObjectRepository>(m_database->connection());
    m_measureRepository = std::make_unique<MeasureRepository>(m_database->connection());
    m_catalogVersion = QStringLiteral("2023");
    return true;
}

bool AppContext::initializeRemote(const ApiClient &client)
{
    m_remote = true;
    m_apiClient = std::make_unique<ApiClient>(client);
    m_catalogRepository = std::make_unique<HttpCatalogRepository>(*m_apiClient);
    m_projectRepository = std::make_unique<HttpProjectRepository>(*m_apiClient);
    m_targetObjectRepository = std::make_unique<HttpTargetObjectRepository>(*m_apiClient);
    m_measureRepository = std::make_unique<HttpMeasureRepository>(*m_apiClient);
    m_catalogVersion = QStringLiteral("2023");

    HttpTeamService teamService(*m_apiClient);
    if (!teamService.fetchCurrentUser(&m_remoteUser)) {
        m_lastError = teamService.lastError();
        return false;
    }
    return true;
}

void AppContext::setReloginHandler(ApiClient::ReloginHandler handler)
{
    if (m_apiClient)
        m_apiClient->setReloginHandler(std::move(handler));
}

bool AppContext::promptRelogin(QWidget *parent)
{
    if (!m_remote || !m_apiClient)
        return false;

    AppSettings settings = AppSettings::load();
    settings.setUseRemote(true);

    LoginDialog dialog(settings, parent);
    dialog.setReloginMode(true);
    if (dialog.exec() != QDialog::Accepted)
        return false;

    return updateRemoteSession(dialog.apiClient(), dialog.settings());
}

bool AppContext::promptSwitchUser(QWidget *parent)
{
    AppSettings settings = AppSettings::load();
    settings.setAccessToken({});
    settings.setTokenExpiresAt({});

    LoginDialog dialog(settings, parent);
    dialog.setSwitchUserMode(true);
    if (dialog.exec() != QDialog::Accepted)
        return false;

    return applySession(dialog.settings(), dialog.apiClient());
}

bool AppContext::applySession(const AppSettings &settings, const ApiClient &client)
{
    const AppSettings previousSettings = AppSettings::load();

    resetRepositories();

    if (settings.useRemote()) {
        if (!initializeRemote(client)) {
            restoreSession(previousSettings);
            return false;
        }
    } else if (!initializeLocal()) {
        restoreSession(previousSettings);
        return false;
    }

    settings.save();
    return true;
}

bool AppContext::updateRemoteSession(const ApiClient &client, const AppSettings &settings)
{
    if (!m_remote || !m_apiClient)
        return false;

    m_apiClient->setBaseUrl(client.baseUrl());
    m_apiClient->setAccessToken(client.accessToken());
    m_apiClient->setTokenExpiresAt(client.tokenExpiresAt());
    m_apiClient->setInsecureSkipTlsVerify(client.insecureSkipTlsVerify());

    settings.save();

    HttpTeamService teamService(*m_apiClient);
    if (!teamService.fetchCurrentUser(&m_remoteUser)) {
        m_lastError = teamService.lastError();
        return false;
    }
    return true;
}

ApiClient &AppContext::apiClient()
{
    return *m_apiClient;
}

QString AppContext::lastError() const
{
    return m_lastError;
}

ICatalogRepository &AppContext::catalogRepository()
{
    return *m_catalogRepository;
}

IProjectRepository &AppContext::projectRepository()
{
    return *m_projectRepository;
}

ITargetObjectRepository &AppContext::targetObjectRepository()
{
    return *m_targetObjectRepository;
}

IMeasureRepository &AppContext::measureRepository()
{
    return *m_measureRepository;
}

bool AppContext::ensureGrundschutzCatalog(const QString &xmlPath)
{
    if (m_catalogRepository->hasGrundschutzCatalog(m_catalogVersion))
        return true;

    if (m_remote)
        return importCatalogFile(xmlPath);

    const QString sourcePath = QFile::exists(xmlPath) ? xmlPath : AppPaths::defaultGrundschutzXml();
    if (!QFile::exists(sourcePath)) {
        m_lastError = QStringLiteral(
            "Kein IT-Grundschutz-Katalog gefunden. Bitte XML unter %1 ablegen oder importieren.")
                          .arg(sourcePath);
        return false;
    }

    const GrundschutzImportResult importResult = m_importer.importFromFile(sourcePath);
    if (!importResult.success) {
        m_lastError = importResult.errorMessage;
        return false;
    }

    if (!m_catalogRepository->replaceGrundschutzCatalog(importResult)) {
        m_lastError = m_catalogRepository->lastError();
        return false;
    }

    return true;
}

bool AppContext::importCatalogFile(const QString &xmlPath)
{
    if (!m_remote || !m_apiClient) {
        m_lastError = QStringLiteral("Katalog-Upload nur im Server-Modus verfügbar.");
        return false;
    }
    if (!QFile::exists(xmlPath)) {
        m_lastError = QStringLiteral("Datei nicht gefunden: %1").arg(xmlPath);
        return false;
    }

    int status = 0;
    const QJsonDocument doc = m_apiClient->uploadFile(
        QStringLiteral("/api/v1/admin/catalog/import"), QStringLiteral("file"), xmlPath, &status);
    if (status != 200) {
        m_lastError = m_apiClient->lastError();
        if (doc.isObject() && doc.object().contains(QStringLiteral("message")))
            m_lastError = doc.object().value(QStringLiteral("message")).toString();
        return false;
    }
    return true;
}

QString AppContext::catalogVersion() const
{
    return m_catalogVersion;
}

void AppContext::resetRepositories()
{
    m_measureRepository.reset();
    m_targetObjectRepository.reset();
    m_projectRepository.reset();
    m_catalogRepository.reset();
    m_apiClient.reset();
    m_database.reset();
    m_remote = false;
    m_remoteUser = {};
    m_lastError.clear();
}

void AppContext::restoreSession(const AppSettings &settings)
{
    resetRepositories();

    if (settings.useRemote() && settings.hasStoredRemoteSession()) {
        ApiClient client(settings.serverUrl());
        client.setAccessToken(settings.accessToken());
        client.setTokenExpiresAt(settings.tokenExpiresAt());
        client.setInsecureSkipTlsVerify(settings.insecureSkipTlsVerify());
        initializeRemote(client);
        return;
    }

    initializeLocal();
}
