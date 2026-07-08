#ifndef PERSISTENCE_DATABASE_H
#define PERSISTENCE_DATABASE_H

#include <QSqlDatabase>
#include <QString>

class Database
{
public:
    explicit Database(const QString &filePath);

    bool open();
    void close();
    bool isOpen() const;
    QString lastError() const;
    QSqlDatabase connection() const;

    bool initializeSchema();

private:
    bool migrateAssessmentTargetObjectColumn();
    bool migrateAssessmentDueDateColumn();
    bool migrateTargetObjectProtectionNeedColumn();
    bool migrateSchema();
    bool ensureIndexes();
    bool tableExists(const QString &table) const;
    bool tableHasColumn(const QString &table, const QString &column) const;

    QString m_filePath;
    QString m_lastError;
    QSqlDatabase m_db;
};

#endif
