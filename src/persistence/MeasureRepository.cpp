#include "MeasureRepository.h"

#include "domain/MeasureStatus.h"

#include <QSqlError>
#include <QSqlQuery>

MeasureRepository::MeasureRepository(QSqlDatabase db)
    : m_db(std::move(db))
{
}

QList<Measure> MeasureRepository::loadMeasures(int projectId,
                                               int targetObjectId,
                                               int requirementDbId) const
{
    QList<Measure> measures;
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "SELECT id, title, description, responsible, due_date, status "
        "FROM measures "
        "WHERE project_id = ? AND target_object_id = ? AND requirement_id = ? "
        "ORDER BY due_date IS NULL, due_date, title"));
    query.addBindValue(projectId);
    query.addBindValue(targetObjectId);
    query.addBindValue(requirementDbId);

    if (!query.exec())
        return measures;

    while (query.next()) {
        Measure measure;
        measure.projectId = projectId;
        measure.targetObjectId = targetObjectId;
        measure.requirementDbId = requirementDbId;
        measure.id = query.value(0).toInt();
        measure.title = query.value(1).toString();
        measure.description = query.value(2).toString();
        measure.responsible = query.value(3).toString();
        const QString dueDate = query.value(4).toString();
        if (!dueDate.isEmpty())
            measure.dueDate = QDate::fromString(dueDate, Qt::ISODate);
        measure.status = measureStatusFromString(query.value(5).toString());
        measures.append(measure);
    }
    return measures;
}

QHash<int, int> MeasureRepository::measureCounts(int projectId, int targetObjectId) const
{
    QHash<int, int> counts;
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "SELECT requirement_id, COUNT(*) "
        "FROM measures "
        "WHERE project_id = ? AND target_object_id = ? "
        "GROUP BY requirement_id"));
    query.addBindValue(projectId);
    query.addBindValue(targetObjectId);

    if (!query.exec())
        return counts;

    while (query.next())
        counts.insert(query.value(0).toInt(), query.value(1).toInt());
    return counts;
}

Measure MeasureRepository::createMeasure(const Measure &measure)
{
    Measure created = measure;
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "INSERT INTO measures "
        "(project_id, target_object_id, requirement_id, title, description, responsible, due_date, status) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?)"));
    query.addBindValue(created.projectId);
    query.addBindValue(created.targetObjectId);
    query.addBindValue(created.requirementDbId);
    query.addBindValue(created.title);
    query.addBindValue(created.description);
    query.addBindValue(created.responsible);
    query.addBindValue(created.dueDate.isValid() ? created.dueDate.toString(Qt::ISODate) : QVariant());
    query.addBindValue(measureStatusToString(created.status));

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        return {};
    }

    created.id = query.lastInsertId().toInt();
    return created;
}

MeasureSaveResult MeasureRepository::updateMeasure(const Measure &measure)
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "UPDATE measures SET title = ?, description = ?, responsible = ?, due_date = ?, status = ? "
        "WHERE id = ?"));
    query.addBindValue(measure.title);
    query.addBindValue(measure.description);
    query.addBindValue(measure.responsible);
    query.addBindValue(measure.dueDate.isValid() ? measure.dueDate.toString(Qt::ISODate) : QVariant());
    query.addBindValue(measureStatusToString(measure.status));
    query.addBindValue(measure.id);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        return MeasureSaveResult::failed();
    }
    return MeasureSaveResult::ok(measure);
}

bool MeasureRepository::deleteMeasure(int measureId)
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral("DELETE FROM measures WHERE id = ?"));
    query.addBindValue(measureId);
    if (!query.exec()) {
        m_lastError = query.lastError().text();
        return false;
    }
    return true;
}

QString MeasureRepository::lastError() const
{
    return m_lastError;
}
