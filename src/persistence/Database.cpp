#include "Database.h"

#include <QSqlError>
#include <QSqlQuery>

Database::Database(const QString &filePath)
    : m_filePath(filePath)
{
}

bool Database::open()
{
    if (m_db.isOpen())
        return true;

    if (QSqlDatabase::contains(QStringLiteral("isms_main"))) {
        m_db = QSqlDatabase::database(QStringLiteral("isms_main"));
    } else {
        m_db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("isms_main"));
    }

    if (!QSqlDatabase::drivers().contains(QStringLiteral("QSQLITE"))) {
        m_lastError = QStringLiteral("SQLite-Treiber (QSQLITE) ist nicht verfügbar.");
        return false;
    }

    m_db.setDatabaseName(m_filePath);
    if (!m_db.open()) {
        m_lastError = QStringLiteral("Datei %1: %2").arg(m_filePath, m_db.lastError().text());
        return false;
    }

    QSqlQuery foreignKeys(m_db);
    foreignKeys.exec(QStringLiteral("PRAGMA foreign_keys = ON"));

    if (!initializeSchema()) {
        m_db.close();
        return false;
    }
    if (!migrateSchema()) {
        m_db.close();
        return false;
    }
    if (!ensureIndexes()) {
        m_db.close();
        return false;
    }

    return true;
}

void Database::close()
{
    if (m_db.isOpen())
        m_db.close();
}

bool Database::isOpen() const
{
    return m_db.isOpen();
}

QString Database::lastError() const
{
    if (!m_lastError.isEmpty())
        return m_lastError;
    return m_db.lastError().text();
}

QSqlDatabase Database::connection() const
{
    return m_db;
}

bool Database::tableExists(const QString &table) const
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?"));
    query.addBindValue(table);
    if (!query.exec())
        return false;
    return query.next();
}

bool Database::tableHasColumn(const QString &table, const QString &column) const
{
    if (!tableExists(table))
        return false;

    QSqlQuery query(m_db);
    if (!query.exec(QStringLiteral("PRAGMA table_info(%1)").arg(table)))
        return false;

    while (query.next()) {
        if (query.value(1).toString() == column)
            return true;
    }
    return false;
}

bool Database::migrateSchema()
{
    if (!migrateAssessmentTargetObjectColumn())
        return false;
    if (!migrateAssessmentDueDateColumn())
        return false;
    if (!migrateTargetObjectProtectionNeedColumn())
        return false;
    return true;
}

bool Database::migrateAssessmentTargetObjectColumn()
{
    if (tableHasColumn(QStringLiteral("requirement_assessments"), QStringLiteral("target_object_id")))
        return true;

    if (!tableExists(QStringLiteral("requirement_assessments")))
        return true;

    QSqlQuery query(m_db);

    if (tableExists(QStringLiteral("requirement_assessments_new"))) {
        query.exec(QStringLiteral("DROP TABLE requirement_assessments_new"));
    }

    if (!query.exec(QStringLiteral(
            "CREATE TABLE requirement_assessments_new ("
            "id INTEGER PRIMARY KEY AUTOINCREMENT,"
            "project_id INTEGER NOT NULL,"
            "target_object_id INTEGER NOT NULL DEFAULT 0,"
            "requirement_id INTEGER NOT NULL,"
            "status TEXT NOT NULL,"
            "note TEXT,"
            "responsible TEXT,"
            "FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE,"
            "FOREIGN KEY(requirement_id) REFERENCES requirements(id) ON DELETE CASCADE,"
            "UNIQUE(project_id, target_object_id, requirement_id)"
            ")"))) {
        m_lastError = QStringLiteral("Migration: %1").arg(query.lastError().text());
        return false;
    }

    if (!query.exec(QStringLiteral(
            "INSERT INTO requirement_assessments_new "
            "(id, project_id, target_object_id, requirement_id, status, note, responsible) "
            "SELECT id, project_id, 0, requirement_id, status, note, responsible "
            "FROM requirement_assessments"))) {
        m_lastError = QStringLiteral("Migration (Daten kopieren): %1").arg(query.lastError().text());
        return false;
    }

    if (!query.exec(QStringLiteral("DROP TABLE requirement_assessments"))) {
        m_lastError = QStringLiteral("Migration (alte Tabelle): %1").arg(query.lastError().text());
        return false;
    }

    if (!query.exec(QStringLiteral(
            "ALTER TABLE requirement_assessments_new RENAME TO requirement_assessments"))) {
        m_lastError = QStringLiteral("Migration (Umbenennen): %1").arg(query.lastError().text());
        return false;
    }

    return true;
}

bool Database::migrateAssessmentDueDateColumn()
{
    if (!tableExists(QStringLiteral("requirement_assessments")))
        return true;

    if (tableHasColumn(QStringLiteral("requirement_assessments"), QStringLiteral("due_date")))
        return true;

    QSqlQuery query(m_db);
    if (!query.exec(QStringLiteral("ALTER TABLE requirement_assessments ADD COLUMN due_date TEXT"))) {
        m_lastError = QStringLiteral("Migration (Frist): %1").arg(query.lastError().text());
        return false;
    }
    return true;
}

bool Database::migrateTargetObjectProtectionNeedColumn()
{
    if (!tableExists(QStringLiteral("target_objects")))
        return true;

    if (tableHasColumn(QStringLiteral("target_objects"), QStringLiteral("protection_need")))
        return true;

    QSqlQuery query(m_db);
    if (!query.exec(QStringLiteral(
            "ALTER TABLE target_objects ADD COLUMN protection_need TEXT NOT NULL "
            "DEFAULT 'Normal (Basis + Standard)'"))) {
        m_lastError = QStringLiteral("Migration (Schutzbedarf): %1").arg(query.lastError().text());
        return false;
    }
    return true;
}

bool Database::ensureIndexes()
{
    QSqlQuery query(m_db);

    const QStringList statements = {
        QStringLiteral(
            "CREATE INDEX IF NOT EXISTS idx_requirements_baustein "
            "ON requirements(baustein_id)"),
        QStringLiteral(
            "CREATE INDEX IF NOT EXISTS idx_assessments_project "
            "ON requirement_assessments(project_id)"),
        QStringLiteral(
            "CREATE INDEX IF NOT EXISTS idx_assessments_target "
            "ON requirement_assessments(project_id, target_object_id)"),
        QStringLiteral(
            "CREATE INDEX IF NOT EXISTS idx_target_objects_project "
            "ON target_objects(project_id)"),
        QStringLiteral(
            "CREATE INDEX IF NOT EXISTS idx_applicability_target "
            "ON baustein_applicability(project_id, target_object_id)"),
        QStringLiteral(
            "CREATE INDEX IF NOT EXISTS idx_measures_requirement "
            "ON measures(project_id, target_object_id, requirement_id)")
    };

    for (const QString &statement : statements) {
        if (!query.exec(statement)) {
            m_lastError = QStringLiteral("Index: %1").arg(query.lastError().text());
            return false;
        }
    }

    return true;
}

bool Database::initializeSchema()
{
    QSqlQuery query(m_db);

    const QStringList statements = {
        QStringLiteral(
            "CREATE TABLE IF NOT EXISTS catalog_meta ("
            "key TEXT PRIMARY KEY,"
            "value TEXT NOT NULL"
            ")"),
        QStringLiteral(
            "CREATE TABLE IF NOT EXISTS bausteine ("
            "id INTEGER PRIMARY KEY AUTOINCREMENT,"
            "standard TEXT NOT NULL,"
            "external_id TEXT NOT NULL,"
            "title TEXT NOT NULL,"
            "group_name TEXT,"
            "catalog_version TEXT NOT NULL,"
            "UNIQUE(standard, external_id, catalog_version)"
            ")"),
        QStringLiteral(
            "CREATE TABLE IF NOT EXISTS requirements ("
            "id INTEGER PRIMARY KEY AUTOINCREMENT,"
            "baustein_id INTEGER NOT NULL,"
            "standard TEXT NOT NULL,"
            "external_id TEXT NOT NULL,"
            "baustein_external_id TEXT NOT NULL,"
            "title TEXT NOT NULL,"
            "text TEXT,"
            "level TEXT NOT NULL,"
            "responsible_role TEXT,"
            "withdrawn INTEGER NOT NULL DEFAULT 0,"
            "FOREIGN KEY(baustein_id) REFERENCES bausteine(id) ON DELETE CASCADE,"
            "UNIQUE(standard, external_id, baustein_id)"
            ")"),
        QStringLiteral(
            "CREATE TABLE IF NOT EXISTS projects ("
            "id INTEGER PRIMARY KEY AUTOINCREMENT,"
            "name TEXT NOT NULL,"
            "description TEXT,"
            "catalog_version TEXT NOT NULL,"
            "created_at TEXT NOT NULL,"
            "updated_at TEXT NOT NULL"
            ")"),
        QStringLiteral(
            "CREATE TABLE IF NOT EXISTS target_objects ("
            "id INTEGER PRIMARY KEY AUTOINCREMENT,"
            "project_id INTEGER NOT NULL,"
            "parent_id INTEGER NOT NULL DEFAULT 0,"
            "type TEXT NOT NULL,"
            "protection_need TEXT NOT NULL DEFAULT 'Normal (Basis + Standard)',"
            "name TEXT NOT NULL,"
            "description TEXT,"
            "FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE"
            ")"),
        QStringLiteral(
            "CREATE TABLE IF NOT EXISTS baustein_applicability ("
            "id INTEGER PRIMARY KEY AUTOINCREMENT,"
            "project_id INTEGER NOT NULL,"
            "target_object_id INTEGER NOT NULL,"
            "baustein_id INTEGER NOT NULL,"
            "status TEXT NOT NULL,"
            "FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE,"
            "FOREIGN KEY(target_object_id) REFERENCES target_objects(id) ON DELETE CASCADE,"
            "FOREIGN KEY(baustein_id) REFERENCES bausteine(id) ON DELETE CASCADE,"
            "UNIQUE(project_id, target_object_id, baustein_id)"
            ")"),
        QStringLiteral(
            "CREATE TABLE IF NOT EXISTS requirement_assessments ("
            "id INTEGER PRIMARY KEY AUTOINCREMENT,"
            "project_id INTEGER NOT NULL,"
            "target_object_id INTEGER NOT NULL DEFAULT 0,"
            "requirement_id INTEGER NOT NULL,"
            "status TEXT NOT NULL,"
            "note TEXT,"
            "responsible TEXT,"
            "due_date TEXT,"
            "FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE,"
            "FOREIGN KEY(requirement_id) REFERENCES requirements(id) ON DELETE CASCADE,"
            "UNIQUE(project_id, target_object_id, requirement_id)"
            ")"),
        QStringLiteral(
            "CREATE TABLE IF NOT EXISTS measures ("
            "id INTEGER PRIMARY KEY AUTOINCREMENT,"
            "project_id INTEGER NOT NULL,"
            "target_object_id INTEGER NOT NULL,"
            "requirement_id INTEGER NOT NULL,"
            "title TEXT NOT NULL,"
            "description TEXT,"
            "responsible TEXT,"
            "due_date TEXT,"
            "status TEXT NOT NULL,"
            "FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE,"
            "FOREIGN KEY(target_object_id) REFERENCES target_objects(id) ON DELETE CASCADE,"
            "FOREIGN KEY(requirement_id) REFERENCES requirements(id) ON DELETE CASCADE"
            ")")
    };

    for (const QString &statement : statements) {
        if (!query.exec(statement)) {
            m_lastError = QStringLiteral("Schema: %1").arg(query.lastError().text());
            return false;
        }
    }

    return true;
}
