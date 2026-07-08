#include "ProjectRepository.h"

#include "domain/AssessmentStatus.h"

#include <QDateTime>
#include <QSqlError>
#include <QSqlQuery>

ProjectRepository::ProjectRepository(QSqlDatabase db)
    : m_db(std::move(db))
{
}

QList<Project> ProjectRepository::loadProjects() const
{
    QList<Project> projects;
    QSqlQuery query(m_db);
    if (!query.exec(QStringLiteral(
            "SELECT id, name, description, catalog_version, created_at, updated_at "
            "FROM projects ORDER BY updated_at DESC")))
        return projects;

    while (query.next()) {
        Project project;
        project.id = query.value(0).toInt();
        project.name = query.value(1).toString();
        project.description = query.value(2).toString();
        project.catalogVersion = query.value(3).toString();
        project.createdAt = QDateTime::fromString(query.value(4).toString(), Qt::ISODate);
        project.updatedAt = QDateTime::fromString(query.value(5).toString(), Qt::ISODate);
        projects.append(project);
    }
    return projects;
}

Project ProjectRepository::createProject(const QString &name,
                                       const QString &description,
                                       const QString &catalogVersion)
{
    Project project;
    project.name = name;
    project.description = description;
    project.catalogVersion = catalogVersion;
    project.createdAt = QDateTime::currentDateTimeUtc();
    project.updatedAt = project.createdAt;

    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "INSERT INTO projects (name, description, catalog_version, created_at, updated_at) "
        "VALUES (?, ?, ?, ?, ?)"));
    query.addBindValue(project.name);
    query.addBindValue(project.description);
    query.addBindValue(project.catalogVersion);
    query.addBindValue(project.createdAt.toString(Qt::ISODate));
    query.addBindValue(project.updatedAt.toString(Qt::ISODate));

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        return {};
    }

    project.id = query.lastInsertId().toInt();
    return project;
}

bool ProjectRepository::updateProject(const Project &project)
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "UPDATE projects SET name = ?, description = ?, updated_at = ? WHERE id = ?"));
    query.addBindValue(project.name);
    query.addBindValue(project.description);
    query.addBindValue(QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    query.addBindValue(project.id);

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        return false;
    }
    return true;
}

RequirementAssessment ProjectRepository::loadAssessment(int projectId,
                                                        int targetObjectId,
                                                        int requirementDbId) const
{
    RequirementAssessment assessment;
    assessment.projectId = projectId;
    assessment.targetObjectId = targetObjectId;
    assessment.requirementDbId = requirementDbId;

    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "SELECT id, status, note, responsible, due_date FROM requirement_assessments "
        "WHERE project_id = ? AND target_object_id = ? AND requirement_id = ?"));
    query.addBindValue(projectId);
    query.addBindValue(targetObjectId);
    query.addBindValue(requirementDbId);
    if (!query.exec() || !query.next())
        return assessment;

    assessment.id = query.value(0).toInt();
    assessment.status = assessmentStatusFromString(query.value(1).toString());
    assessment.note = query.value(2).toString();
    assessment.responsible = query.value(3).toString();
    const QString dueDate = query.value(4).toString();
    if (!dueDate.isEmpty())
        assessment.dueDate = QDate::fromString(dueDate, Qt::ISODate);
    return assessment;
}

bool ProjectRepository::saveAssessment(const RequirementAssessment &assessment)
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "INSERT INTO requirement_assessments "
        "(project_id, target_object_id, requirement_id, status, note, responsible, due_date) "
        "VALUES (?, ?, ?, ?, ?, ?, ?) "
        "ON CONFLICT(project_id, target_object_id, requirement_id) DO UPDATE SET "
        "status = excluded.status, note = excluded.note, responsible = excluded.responsible, "
        "due_date = excluded.due_date"));
    query.addBindValue(assessment.projectId);
    query.addBindValue(assessment.targetObjectId);
    query.addBindValue(assessment.requirementDbId);
    query.addBindValue(assessmentStatusToString(assessment.status));
    query.addBindValue(assessment.note);
    query.addBindValue(assessment.responsible);
    query.addBindValue(assessment.dueDate.isValid() ? assessment.dueDate.toString(Qt::ISODate)
                                                    : QVariant());

    if (!query.exec()) {
        m_lastError = query.lastError().text();
        return false;
    }

    QSqlQuery touchProject(m_db);
    touchProject.prepare(QStringLiteral("UPDATE projects SET updated_at = ? WHERE id = ?"));
    touchProject.addBindValue(QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    touchProject.addBindValue(assessment.projectId);
    touchProject.exec();
    return true;
}

QString ProjectRepository::lastError() const
{
    return m_lastError;
}
