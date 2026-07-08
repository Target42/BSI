#include "CatalogRepository.h"

#include "domain/Standard.h"

#include <QMap>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariant>

CatalogRepository::CatalogRepository(QSqlDatabase db)
    : m_db(std::move(db))
{
}

bool CatalogRepository::replaceGrundschutzCatalog(const GrundschutzImportResult &importResult)
{
    if (!importResult.success)
        return false;

    if (!m_db.transaction()) {
        m_lastError = m_db.lastError().text();
        return false;
    }

    QSqlQuery clearRequirements(m_db);
    if (!clearRequirements.exec(QStringLiteral("DELETE FROM requirements"))) {
        m_lastError = clearRequirements.lastError().text();
        m_db.rollback();
        return false;
    }

    QSqlQuery clearBausteine(m_db);
    clearBausteine.prepare(
        QStringLiteral("DELETE FROM bausteine WHERE standard = ? AND catalog_version = ?"));
    clearBausteine.addBindValue(standardTypeToString(StandardType::ITGrundschutz));
    clearBausteine.addBindValue(importResult.catalogVersion);
    if (!clearBausteine.exec()) {
        m_lastError = clearBausteine.lastError().text();
        m_db.rollback();
        return false;
    }

    QMap<QString, int> bausteinIds;

    QSqlQuery insertBaustein(m_db);
    insertBaustein.prepare(
        QStringLiteral("INSERT INTO bausteine (standard, external_id, title, group_name, catalog_version) "
                       "VALUES (?, ?, ?, ?, ?)"));

    for (const Baustein &baustein : importResult.bausteine) {
        insertBaustein.addBindValue(standardTypeToString(baustein.standard));
        insertBaustein.addBindValue(baustein.externalId);
        insertBaustein.addBindValue(baustein.title);
        insertBaustein.addBindValue(baustein.groupName);
        insertBaustein.addBindValue(importResult.catalogVersion);
        if (!insertBaustein.exec()) {
            m_lastError = insertBaustein.lastError().text();
            m_db.rollback();
            return false;
        }
        bausteinIds.insert(baustein.externalId, insertBaustein.lastInsertId().toInt());
    }

    QSqlQuery insertRequirement(m_db);
    insertRequirement.prepare(
        QStringLiteral("INSERT INTO requirements "
                       "(baustein_id, standard, external_id, baustein_external_id, title, text, level, "
                       "responsible_role, withdrawn) "
                       "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"));

    for (const Requirement &requirement : importResult.requirements) {
        const int bausteinId = bausteinIds.value(requirement.bausteinExternalId, -1);
        if (bausteinId < 0)
            continue;

        insertRequirement.addBindValue(bausteinId);
        insertRequirement.addBindValue(standardTypeToString(requirement.standard));
        insertRequirement.addBindValue(requirement.externalId);
        insertRequirement.addBindValue(requirement.bausteinExternalId);
        insertRequirement.addBindValue(requirement.title);
        insertRequirement.addBindValue(requirement.text);
        insertRequirement.addBindValue(requirementLevelToString(requirement.level));
        insertRequirement.addBindValue(requirement.responsibleRole);
        insertRequirement.addBindValue(requirement.withdrawn ? 1 : 0);
        if (!insertRequirement.exec()) {
            m_lastError = insertRequirement.lastError().text();
            m_db.rollback();
            return false;
        }
    }

    QSqlQuery upsertMeta(m_db);
    upsertMeta.prepare(QStringLiteral(
        "INSERT INTO catalog_meta (key, value) VALUES (?, ?) "
        "ON CONFLICT(key) DO UPDATE SET value = excluded.value"));
    upsertMeta.addBindValue(QStringLiteral("grundschutz_version"));
    upsertMeta.addBindValue(importResult.catalogVersion);
    if (!upsertMeta.exec()) {
        m_lastError = upsertMeta.lastError().text();
        m_db.rollback();
        return false;
    }

    if (!m_db.commit())
        return false;

    return true;
}

bool CatalogRepository::hasGrundschutzCatalog(const QString &catalogVersion) const
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "SELECT COUNT(*) FROM bausteine WHERE standard = ? AND catalog_version = ?"));
    query.addBindValue(standardTypeToString(StandardType::ITGrundschutz));
    query.addBindValue(catalogVersion);
    if (!query.exec() || !query.next())
        return false;
    return query.value(0).toInt() > 0;
}

QList<Baustein> CatalogRepository::loadBausteine(StandardType standard, const QString &catalogVersion) const
{
    QList<Baustein> bausteine;
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "SELECT id, external_id, title, group_name, catalog_version "
        "FROM bausteine WHERE standard = ? AND catalog_version = ? "
        "ORDER BY external_id"));
    query.addBindValue(standardTypeToString(standard));
    query.addBindValue(catalogVersion);

    if (!query.exec())
        return bausteine;

    while (query.next()) {
        Baustein baustein;
        baustein.id = query.value(0).toInt();
        baustein.standard = standard;
        baustein.externalId = query.value(1).toString();
        baustein.title = query.value(2).toString();
        baustein.groupName = query.value(3).toString();
        baustein.catalogVersion = query.value(4).toString();
        bausteine.append(baustein);
    }
    return bausteine;
}

QList<Requirement> CatalogRepository::loadRequirements(int bausteinDbId) const
{
    QList<Requirement> requirements;
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "SELECT id, baustein_id, external_id, baustein_external_id, title, text, level, "
        "responsible_role, withdrawn "
        "FROM requirements WHERE baustein_id = ? ORDER BY external_id"));
    query.addBindValue(bausteinDbId);

    if (!query.exec())
        return requirements;

    while (query.next()) {
        Requirement requirement;
        requirement.id = query.value(0).toInt();
        requirement.bausteinDbId = query.value(1).toInt();
        requirement.standard = StandardType::ITGrundschutz;
        requirement.externalId = query.value(2).toString();
        requirement.bausteinExternalId = query.value(3).toString();
        requirement.title = query.value(4).toString();
        requirement.text = query.value(5).toString();
        requirement.level = RequirementLevel::Unknown;
        const QString levelText = query.value(6).toString();
        if (levelText == QStringLiteral("Basis"))
            requirement.level = RequirementLevel::Basis;
        else if (levelText == QStringLiteral("Standard"))
            requirement.level = RequirementLevel::Standard;
        else if (levelText == QStringLiteral("Erhöht"))
            requirement.level = RequirementLevel::Erhoeht;
        requirement.responsibleRole = query.value(7).toString();
        requirement.withdrawn = query.value(8).toInt() != 0;
        requirements.append(requirement);
    }
    return requirements;
}

QList<Requirement> CatalogRepository::loadAllRequirements(StandardType standard,
                                                          const QString &catalogVersion) const
{
    QList<Requirement> requirements;
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "SELECT r.id, r.baustein_id, r.external_id, r.baustein_external_id, r.title, r.text, r.level, "
        "r.responsible_role, r.withdrawn "
        "FROM requirements r "
        "JOIN bausteine b ON b.id = r.baustein_id "
        "WHERE b.standard = ? AND b.catalog_version = ? "
        "ORDER BY r.external_id"));
    query.addBindValue(standardTypeToString(standard));
    query.addBindValue(catalogVersion);

    if (!query.exec())
        return requirements;

    while (query.next()) {
        Requirement requirement;
        requirement.id = query.value(0).toInt();
        requirement.bausteinDbId = query.value(1).toInt();
        requirement.standard = standard;
        requirement.externalId = query.value(2).toString();
        requirement.bausteinExternalId = query.value(3).toString();
        requirement.title = query.value(4).toString();
        requirement.text = query.value(5).toString();
        const QString levelText = query.value(6).toString();
        if (levelText == QStringLiteral("Basis"))
            requirement.level = RequirementLevel::Basis;
        else if (levelText == QStringLiteral("Standard"))
            requirement.level = RequirementLevel::Standard;
        else if (levelText == QStringLiteral("Erhöht"))
            requirement.level = RequirementLevel::Erhoeht;
        requirement.responsibleRole = query.value(7).toString();
        requirement.withdrawn = query.value(8).toInt() != 0;
        requirements.append(requirement);
    }
    return requirements;
}

QString CatalogRepository::lastError() const
{
    return m_lastError;
}
