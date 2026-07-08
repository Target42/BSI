#include "ReportService.h"

#include "domain/AssessmentStatus.h"
#include "domain/Baustein.h"
#include "domain/Requirement.h"
#include "domain/ProtectionNeed.h"
#include "domain/RequirementLevel.h"
#include "domain/Standard.h"
#include "domain/TargetObject.h"

#include <QDate>
#include <QHash>
#include <algorithm>

ReportService::ReportService(CatalogRepository &catalog,
                             ProjectRepository &project,
                             TargetObjectRepository &targetObjects,
                             MeasureRepository &measures)
    : m_catalog(catalog)
    , m_project(project)
    , m_targetObjects(targetObjects)
    , m_measures(measures)
{
}

QList<ReportRow> ReportService::buildSollIstReport(int projectId,
                                                   int targetObjectId,
                                                   const QString &catalogVersion) const
{
    QList<ReportRow> rows;

    const QList<Baustein> allBausteine =
        m_catalog.loadBausteine(StandardType::ITGrundschutz, catalogVersion);
    QHash<int, Baustein> bausteinById;
    for (const Baustein &baustein : allBausteine)
        bausteinById.insert(baustein.id, baustein);

    const QList<TargetObject> targetObjects = m_targetObjects.loadTargetObjects(projectId);
    for (const TargetObject &targetObject : targetObjects) {
        if (targetObjectId != 0 && targetObject.id != targetObjectId)
            continue;

        const QHash<int, ApplicabilityStatus> applicabilityMap =
            m_targetObjects.loadApplicabilityMap(projectId, targetObject.id);
        if (applicabilityMap.isEmpty())
            continue;

        const QHash<int, int> measureCounts = m_measures.measureCounts(projectId, targetObject.id);

        for (auto it = applicabilityMap.constBegin(); it != applicabilityMap.constEnd(); ++it) {
            if (it.value() != ApplicabilityStatus::Required
                && it.value() != ApplicabilityStatus::Possible) {
                continue;
            }

            const QList<Requirement> requirements = m_catalog.loadRequirements(it.key());
            for (const Requirement &requirement : requirements) {
                if (requirement.withdrawn)
                    continue;
                if (!requirementLevelApplies(requirement.level, targetObject.protectionNeed))
                    continue;

                ReportRow row;
                row.targetObjectName = targetObject.name;
                row.bausteinExternalId = requirement.bausteinExternalId;
                row.requirementExternalId = requirement.externalId;
                row.requirementTitle = requirement.title;
                row.level = requirementLevelToString(requirement.level);
                row.applicability = it.value();
                row.bausteinTitle = bausteinById.value(it.key()).title;

                const RequirementAssessment assessment = m_project.loadAssessment(
                    projectId, targetObject.id, requirement.id);
                row.status = assessment.status;
                row.responsible = assessment.responsible;
                row.dueDate = assessment.dueDate;
                row.measureCount = measureCounts.value(requirement.id, 0);
                row.overdue = assessment.dueDate.isValid()
                              && assessment.dueDate < QDate::currentDate()
                              && assessment.status != AssessmentStatus::Fulfilled
                              && assessment.status != AssessmentStatus::NotApplicable;

                rows.append(row);
            }
        }
    }

    std::sort(rows.begin(), rows.end(), [](const ReportRow &a, const ReportRow &b) {
        if (a.targetObjectName != b.targetObjectName)
            return a.targetObjectName < b.targetObjectName;
        if (a.bausteinExternalId != b.bausteinExternalId)
            return a.bausteinExternalId < b.bausteinExternalId;
        return a.requirementExternalId < b.requirementExternalId;
    });

    return rows;
}

ReportSummary ReportService::summarize(const QList<ReportRow> &rows) const
{
    ReportSummary summary;
    summary.totalRequirements = rows.size();

    for (const ReportRow &row : rows) {
        switch (row.status) {
        case AssessmentStatus::Open:
            ++summary.openCount;
            break;
        case AssessmentStatus::Partial:
            ++summary.partialCount;
            break;
        case AssessmentStatus::Fulfilled:
            ++summary.fulfilledCount;
            break;
        case AssessmentStatus::NotApplicable:
            ++summary.notApplicableCount;
            break;
        }
        if (row.overdue)
            ++summary.overdueCount;
        summary.measureCount += row.measureCount;
    }

    return summary;
}
