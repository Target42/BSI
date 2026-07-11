#ifndef NET_HTTPPROJECTREPOSITORY_H
#define NET_HTTPPROJECTREPOSITORY_H

#include "net/ApiClient.h"
#include "persistence/IProjectRepository.h"

class HttpProjectRepository : public IProjectRepository
{
public:
    explicit HttpProjectRepository(ApiClient &client);

    QList<Project> loadProjects() const override;
    Project createProject(const QString &name, const QString &description, const QString &catalogVersion) override;
    bool updateProject(const Project &project) override;
    bool deleteProject(int projectId) override;

    RequirementAssessment loadAssessment(int projectId, int targetObjectId, int requirementDbId) const override;
    AssessmentSaveResult saveAssessment(const RequirementAssessment &assessment) override;

    QString lastError() const override;

private:
    ApiClient &m_client;
    mutable QString m_lastError;
};

#endif
