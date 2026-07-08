#include "TargetObjectRepository.h"

#include "domain/ApplicabilityStatus.h"
#include "domain/ProtectionNeed.h"
#include "domain/TargetObjectType.h"

#include <QSqlError>
#include <QSqlQuery>

TargetObjectRepository::TargetObjectRepository(QSqlDatabase db)
    : m_db(std::move(db))
{
}

QList<TargetObject> TargetObjectRepository::loadTargetObjects(int projectId) const
{
    QList<TargetObject> objects;
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "SELECT id, project_id, parent_id, type, protection_need, name, description "
        "FROM target_objects WHERE project_id = ? ORDER BY parent_id, name"));
    query.addBindValue(projectId);
    if (!query.exec())
        return objects;

    while (query.next()) {
        TargetObject object;
        object.id = query.value(0).toInt();
        object.projectId = query.value(1).toInt();
        object.parentId = query.value(2).toInt();
        object.type = targetObjectTypeFromString(query.value(3).toString());
        object.protectionNeed = protectionNeedFromString(query.value(4).toString());
        object.name = query.value(5).toString();
        object.description = query.value(6).toString();
        objects.append(object);
    }
    return objects;
}

TargetObject TargetObjectRepository::createTargetObject(const TargetObject &targetObject)
{
    TargetObject object = targetObject;
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "INSERT INTO target_objects (project_id, parent_id, type, protection_need, name, description) "
        "VALUES (?, ?, ?, ?, ?, ?)"));
    query.addBindValue(object.projectId);
    query.addBindValue(object.parentId);
    query.addBindValue(targetObjectTypeToString(object.type));
    query.addBindValue(protectionNeedToString(object.protectionNeed));
    query.addBindValue(object.name);
    query.addBindValue(object.description);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        return {};
    }

    object.id = query.lastInsertId().toInt();
    return object;
}

bool TargetObjectRepository::updateTargetObject(const TargetObject &targetObject)
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "UPDATE target_objects SET parent_id = ?, type = ?, protection_need = ?, name = ?, "
        "description = ? WHERE id = ?"));
    query.addBindValue(targetObject.parentId);
    query.addBindValue(targetObjectTypeToString(targetObject.type));
    query.addBindValue(protectionNeedToString(targetObject.protectionNeed));
    query.addBindValue(targetObject.name);
    query.addBindValue(targetObject.description);
    query.addBindValue(targetObject.id);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        return false;
    }
    return true;
}

void TargetObjectRepository::deleteTargetObjectSubtree(int targetObjectId)
{
    QSqlQuery children(m_db);
    children.prepare(QStringLiteral("SELECT id FROM target_objects WHERE parent_id = ?"));
    children.addBindValue(targetObjectId);
    if (children.exec()) {
        while (children.next())
            deleteTargetObjectSubtree(children.value(0).toInt());
    }

    QSqlQuery deleteApplicability(m_db);
    deleteApplicability.prepare(QStringLiteral("DELETE FROM baustein_applicability WHERE target_object_id = ?"));
    deleteApplicability.addBindValue(targetObjectId);
    deleteApplicability.exec();

    QSqlQuery deleteAssessments(m_db);
    deleteAssessments.prepare(
        QStringLiteral("DELETE FROM requirement_assessments WHERE target_object_id = ?"));
    deleteAssessments.addBindValue(targetObjectId);
    deleteAssessments.exec();

    QSqlQuery deleteMeasures(m_db);
    deleteMeasures.prepare(QStringLiteral("DELETE FROM measures WHERE target_object_id = ?"));
    deleteMeasures.addBindValue(targetObjectId);
    deleteMeasures.exec();

    QSqlQuery deleteObject(m_db);
    deleteObject.prepare(QStringLiteral("DELETE FROM target_objects WHERE id = ?"));
    deleteObject.addBindValue(targetObjectId);
    deleteObject.exec();
}

bool TargetObjectRepository::deleteTargetObject(int targetObjectId)
{
    if (!m_db.transaction()) {
        m_lastError = m_db.lastError().text();
        return false;
    }

    deleteTargetObjectSubtree(targetObjectId);

    if (!m_db.commit()) {
        m_lastError = m_db.lastError().text();
        m_db.rollback();
        return false;
    }
    return true;
}

TargetObject TargetObjectRepository::createDefaultScope(int projectId, const QString &projectName)
{
    TargetObject scope;
    scope.projectId = projectId;
    scope.parentId = 0;
    scope.type = TargetObjectType::Scope;
    scope.protectionNeed = ProtectionNeed::Normal;
    scope.name = projectName;
    scope.description = QStringLiteral("Geltungsbereich / Informationsverbund");
    return createTargetObject(scope);
}

QHash<int, ApplicabilityStatus> TargetObjectRepository::loadApplicabilityMap(int projectId,
                                                                              int targetObjectId) const
{
    QHash<int, ApplicabilityStatus> map;
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "SELECT baustein_id, status FROM baustein_applicability "
        "WHERE project_id = ? AND target_object_id = ?"));
    query.addBindValue(projectId);
    query.addBindValue(targetObjectId);
    if (!query.exec())
        return map;

    while (query.next()) {
        map.insert(query.value(0).toInt(),
                   applicabilityStatusFromString(query.value(1).toString()));
    }
    return map;
}

ApplicabilityStatus TargetObjectRepository::applicability(int projectId,
                                                        int targetObjectId,
                                                        int bausteinDbId) const
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "SELECT status FROM baustein_applicability "
        "WHERE project_id = ? AND target_object_id = ? AND baustein_id = ?"));
    query.addBindValue(projectId);
    query.addBindValue(targetObjectId);
    query.addBindValue(bausteinDbId);
    if (!query.exec() || !query.next())
        return ApplicabilityStatus::Undefined;
    return applicabilityStatusFromString(query.value(0).toString());
}

bool TargetObjectRepository::saveApplicability(const BausteinApplicability &applicability)
{
    if (applicability.status == ApplicabilityStatus::Undefined) {
        QSqlQuery remove(m_db);
        remove.prepare(QStringLiteral(
            "DELETE FROM baustein_applicability "
            "WHERE project_id = ? AND target_object_id = ? AND baustein_id = ?"));
        remove.addBindValue(applicability.projectId);
        remove.addBindValue(applicability.targetObjectId);
        remove.addBindValue(applicability.bausteinDbId);
        if (!remove.exec()) {
            m_lastError = remove.lastError().text();
            return false;
        }
        return true;
    }

    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "INSERT INTO baustein_applicability (project_id, target_object_id, baustein_id, status) "
        "VALUES (?, ?, ?, ?) "
        "ON CONFLICT(project_id, target_object_id, baustein_id) DO UPDATE SET "
        "status = excluded.status"));
    query.addBindValue(applicability.projectId);
    query.addBindValue(applicability.targetObjectId);
    query.addBindValue(applicability.bausteinDbId);
    query.addBindValue(applicabilityStatusToString(applicability.status));

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        return false;
    }
    return true;
}

QString TargetObjectRepository::lastError() const
{
    return m_lastError;
}
