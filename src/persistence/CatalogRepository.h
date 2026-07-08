#ifndef PERSISTENCE_CATALOGREPOSITORY_H
#define PERSISTENCE_CATALOGREPOSITORY_H

#include "catalog/GrundschutzImporter.h"
#include "domain/Baustein.h"
#include "domain/Requirement.h"

#include <QSqlDatabase>
#include <QList>
#include <QString>

class CatalogRepository
{
public:
    explicit CatalogRepository(QSqlDatabase db);

    bool replaceGrundschutzCatalog(const GrundschutzImportResult &importResult);
    bool hasGrundschutzCatalog(const QString &catalogVersion) const;

    QList<Baustein> loadBausteine(StandardType standard, const QString &catalogVersion) const;
    QList<Requirement> loadRequirements(int bausteinDbId) const;
    QList<Requirement> loadAllRequirements(StandardType standard, const QString &catalogVersion) const;

    QString lastError() const;

private:
    QSqlDatabase m_db;
    mutable QString m_lastError;
};

#endif
