#ifndef APP_APPCONTEXT_H
#define APP_APPCONTEXT_H

#include "persistence/ICatalogRepository.h"
#include "persistence/IMeasureRepository.h"
#include "persistence/IProjectRepository.h"
#include "persistence/ITargetObjectRepository.h"
#include "catalog/GrundschutzImporter.h"
#include "domain/ServerUser.h"
#include "net/ApiClient.h"
#include "net/HttpCatalogRepository.h"
#include "net/HttpMeasureRepository.h"
#include "net/HttpProjectRepository.h"
#include "net/HttpTargetObjectRepository.h"
#include "persistence/CatalogRepository.h"
#include "persistence/Database.h"
#include "persistence/MeasureRepository.h"
#include "persistence/ProjectRepository.h"
#include "persistence/TargetObjectRepository.h"

#include <memory>

class AppContext
{
public:
    AppContext();

    bool initializeLocal();
    bool initializeRemote(const ApiClient &client);
    QString lastError() const;

    bool isRemote() const { return m_remote; }
    bool isRemoteAdmin() const { return m_remoteUser.isAdmin; }
    const ServerUser &remoteUser() const { return m_remoteUser; }
    ApiClient &apiClient();

    ICatalogRepository &catalogRepository();
    IProjectRepository &projectRepository();
    ITargetObjectRepository &targetObjectRepository();
    IMeasureRepository &measureRepository();

    bool ensureGrundschutzCatalog(const QString &xmlPath);
    bool importCatalogFile(const QString &xmlPath);
    QString catalogVersion() const;

private:
    bool m_remote = false;
    std::unique_ptr<Database> m_database;
    std::unique_ptr<ApiClient> m_apiClient;
    std::unique_ptr<ICatalogRepository> m_catalogRepository;
    std::unique_ptr<IProjectRepository> m_projectRepository;
    std::unique_ptr<ITargetObjectRepository> m_targetObjectRepository;
    std::unique_ptr<IMeasureRepository> m_measureRepository;
    GrundschutzImporter m_importer;
    QString m_catalogVersion;
    ServerUser m_remoteUser;
    QString m_lastError;
};

#endif
