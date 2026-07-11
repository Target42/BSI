#ifndef DOMAIN_SAVERESULT_H
#define DOMAIN_SAVERESULT_H

#include "domain/Measure.h"
#include "domain/RequirementAssessment.h"

struct AssessmentSaveResult {
    enum class Status { Ok, VersionConflict, Failed };

    Status status = Status::Failed;
    RequirementAssessment assessment;

    static AssessmentSaveResult ok(const RequirementAssessment &assessment)
    {
        AssessmentSaveResult result;
        result.status = Status::Ok;
        result.assessment = assessment;
        return result;
    }

    static AssessmentSaveResult conflict(const RequirementAssessment &assessment)
    {
        AssessmentSaveResult result;
        result.status = Status::VersionConflict;
        result.assessment = assessment;
        return result;
    }

    static AssessmentSaveResult failed()
    {
        return AssessmentSaveResult{};
    }
};

struct MeasureSaveResult {
    enum class Status { Ok, VersionConflict, Failed };

    Status status = Status::Failed;
    Measure measure;

    static MeasureSaveResult ok(const Measure &measure)
    {
        MeasureSaveResult result;
        result.status = Status::Ok;
        result.measure = measure;
        return result;
    }

    static MeasureSaveResult conflict(const Measure &measure)
    {
        MeasureSaveResult result;
        result.status = Status::VersionConflict;
        result.measure = measure;
        return result;
    }

    static MeasureSaveResult failed()
    {
        return MeasureSaveResult{};
    }
};

#endif
