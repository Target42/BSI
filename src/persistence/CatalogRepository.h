#ifndef PERSISTENCE_CATALOGREPOSITORY_H
#define PERSISTENCE_CATALOGREPOSITORY_H

#include "ICatalogRepository.h"

#include <QSqlDatabase>

class CatalogRepository : public ICatalogRepository
{
public:
    explicit CatalogRepository(QSqlDatabase db);

    bool replaceGrundschutzCatalog(const GrundschutzImportResult &importResult) override;
    bool hasGrundschutzCatalog(const QString &catalogVersion) const override;

    QList<Baustein> loadBausteine(StandardType standard, const QString &catalogVersion) const override;
    QList<Requirement> loadRequirements(int bausteinDbId) const override;
    QList<Requirement> loadAllRequirements(StandardType standard, const QString &catalogVersion) const override;

    QString lastError() const override;

private:
    QSqlDatabase m_db;
    mutable QString m_lastError;
};

#endif
