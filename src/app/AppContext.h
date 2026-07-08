#ifndef APP_APPCONTEXT_H
#define APP_APPCONTEXT_H

#include "persistence/CatalogRepository.h"
#include "persistence/Database.h"
#include "persistence/MeasureRepository.h"
#include "persistence/ProjectRepository.h"
#include "persistence/TargetObjectRepository.h"
#include "catalog/GrundschutzImporter.h"

#include <memory>

class AppContext
{
public:
    AppContext();

    bool initialize();
    QString lastError() const;

    CatalogRepository &catalogRepository();
    ProjectRepository &projectRepository();
    TargetObjectRepository &targetObjectRepository();
    MeasureRepository &measureRepository();

    bool ensureGrundschutzCatalog(const QString &xmlPath);
    QString catalogVersion() const;

private:
    std::unique_ptr<Database> m_database;
    std::unique_ptr<CatalogRepository> m_catalogRepository;
    std::unique_ptr<ProjectRepository> m_projectRepository;
    std::unique_ptr<TargetObjectRepository> m_targetObjectRepository;
    std::unique_ptr<MeasureRepository> m_measureRepository;
    GrundschutzImporter m_importer;
    QString m_catalogVersion;
    QString m_lastError;
};

#endif
