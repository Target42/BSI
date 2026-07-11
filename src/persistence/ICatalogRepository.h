#ifndef PERSISTENCE_ICATALOGREPOSITORY_H
#define PERSISTENCE_ICATALOGREPOSITORY_H

#include "catalog/GrundschutzImporter.h"
#include "domain/Baustein.h"
#include "domain/Requirement.h"

#include <QList>
#include <QString>

class ICatalogRepository
{
public:
    virtual ~ICatalogRepository() = default;

    virtual bool replaceGrundschutzCatalog(const GrundschutzImportResult &importResult) = 0;
    virtual bool hasGrundschutzCatalog(const QString &catalogVersion) const = 0;

    virtual QList<Baustein> loadBausteine(StandardType standard, const QString &catalogVersion) const = 0;
    virtual QList<Requirement> loadRequirements(int bausteinDbId) const = 0;
    virtual QList<Requirement> loadAllRequirements(StandardType standard, const QString &catalogVersion) const = 0;

    virtual QString lastError() const = 0;
};

#endif
