#ifndef NET_HTTPCATALOGREPOSITORY_H
#define NET_HTTPCATALOGREPOSITORY_H

#include "net/ApiClient.h"
#include "persistence/ICatalogRepository.h"

class HttpCatalogRepository : public ICatalogRepository
{
public:
    explicit HttpCatalogRepository(ApiClient &client);

    bool replaceGrundschutzCatalog(const GrundschutzImportResult &importResult) override;
    bool hasGrundschutzCatalog(const QString &catalogVersion) const override;

    QList<Baustein> loadBausteine(StandardType standard, const QString &catalogVersion) const override;
    QList<Requirement> loadRequirements(int bausteinDbId) const override;
    QList<Requirement> loadAllRequirements(StandardType standard, const QString &catalogVersion) const override;

    QString lastError() const override;

private:
    ApiClient &m_client;
    mutable QString m_lastError;
    mutable QString m_lastImportPath;
};

#endif
