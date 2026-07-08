#ifndef PERSISTENCE_PROJECTREPOSITORY_H
#define PERSISTENCE_PROJECTREPOSITORY_H

#include "domain/Project.h"
#include "domain/RequirementAssessment.h"

#include <QList>
#include <QSqlDatabase>
#include <QString>

class ProjectRepository
{
public:
    explicit ProjectRepository(QSqlDatabase db);

    QList<Project> loadProjects() const;
    Project createProject(const QString &name, const QString &description, const QString &catalogVersion);
    bool updateProject(const Project &project);
    bool deleteProject(int projectId);

    RequirementAssessment loadAssessment(int projectId, int targetObjectId, int requirementDbId) const;
    bool saveAssessment(const RequirementAssessment &assessment);

    QString lastError() const;

private:
    QSqlDatabase m_db;
    mutable QString m_lastError;
};

#endif
