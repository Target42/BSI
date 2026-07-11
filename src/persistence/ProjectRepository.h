#ifndef PERSISTENCE_PROJECTREPOSITORY_H
#define PERSISTENCE_PROJECTREPOSITORY_H

#include "IProjectRepository.h"

#include <QSqlDatabase>

class ProjectRepository : public IProjectRepository
{
public:
    explicit ProjectRepository(QSqlDatabase db);

    QList<Project> loadProjects() const override;
    Project createProject(const QString &name, const QString &description, const QString &catalogVersion) override;
    bool updateProject(const Project &project) override;
    bool deleteProject(int projectId) override;

    RequirementAssessment loadAssessment(int projectId, int targetObjectId, int requirementDbId) const override;
    AssessmentSaveResult saveAssessment(const RequirementAssessment &assessment) override;

    QString lastError() const override;

private:
    QSqlDatabase m_db;
    mutable QString m_lastError;
};

#endif
