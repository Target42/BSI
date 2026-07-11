#ifndef PERSISTENCE_IPROJECTREPOSITORY_H
#define PERSISTENCE_IPROJECTREPOSITORY_H

#include "domain/Project.h"
#include "domain/RequirementAssessment.h"
#include "domain/SaveResult.h"

#include <QList>
#include <QString>

class IProjectRepository
{
public:
    virtual ~IProjectRepository() = default;

    virtual QList<Project> loadProjects() const = 0;
    virtual Project createProject(const QString &name,
                                  const QString &description,
                                  const QString &catalogVersion) = 0;
    virtual bool updateProject(const Project &project) = 0;
    virtual bool deleteProject(int projectId) = 0;

    virtual RequirementAssessment loadAssessment(int projectId,
                                                 int targetObjectId,
                                                 int requirementDbId) const = 0;
    virtual AssessmentSaveResult saveAssessment(const RequirementAssessment &assessment) = 0;

    virtual QString lastError() const = 0;
};

#endif
