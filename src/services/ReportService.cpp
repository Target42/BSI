#include "ReportService.h"

#include "domain/AssessmentStatus.h"
#include "domain/Baustein.h"
#include "domain/Requirement.h"
#include "domain/ProtectionNeed.h"
#include "domain/RequirementLevel.h"
#include "domain/Standard.h"
#include "domain/TargetObject.h"

#include <QDate>
#include <QCoreApplication>
#include <QHash>
#include <algorithm>

namespace {

QString reportServiceTr(const char *text)
{
    return QCoreApplication::translate("ReportService", text);
}

} // namespace

ReportService::ReportService(ICatalogRepository &catalog,
                             IProjectRepository &project,
                             ITargetObjectRepository &targetObjects,
                             IMeasureRepository &measures)
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
                row.targetObjectId = targetObject.id;
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

QHash<int, ReportSummary> ReportService::summarizeByTargetObject(int projectId,
                                                                 const QString &catalogVersion) const
{
    return summarizeByTargetObject(buildSollIstReport(projectId, 0, catalogVersion));
}

QHash<int, ReportSummary> ReportService::summarizeByTargetObject(const QList<ReportRow> &rows) const
{
    QHash<int, QList<ReportRow>> grouped;
    for (const ReportRow &row : rows)
        grouped[row.targetObjectId].append(row);

    QHash<int, ReportSummary> summaries;
    for (auto it = grouped.constBegin(); it != grouped.constEnd(); ++it)
        summaries.insert(it.key(), summarize(it.value()));
    return summaries;
}

int ReportService::progressPercent(const ReportSummary &summary)
{
    return reportProgressPercent(summary);
}

QString ReportService::formatSummaryText(const ReportSummary &summary)
{
    if (summary.totalRequirements == 0)
        return reportServiceTr("Keine anwendbaren Anforderungen");

    const int percent = progressPercent(summary);
    QString text = reportServiceTr("%1% abgeschlossen (%2/%3 Anforderungen)")
                       .arg(percent)
                       .arg(summary.fulfilledCount + summary.notApplicableCount)
                       .arg(summary.totalRequirements);

    QStringList details;
    if (summary.openCount > 0)
        details << reportServiceTr("%1 offen").arg(summary.openCount);
    if (summary.partialCount > 0)
        details << reportServiceTr("%1 teilweise").arg(summary.partialCount);
    if (summary.overdueCount > 0)
        details << reportServiceTr("%1 überfällig").arg(summary.overdueCount);
    if (summary.measureCount > 0)
        details << reportServiceTr("%1 Maßnahmen").arg(summary.measureCount);

    if (!details.isEmpty())
        text += QStringLiteral(" — ") + details.join(QStringLiteral(", "));

    return text;
}

QString ReportService::formatTreeProgressSuffix(const ReportSummary &summary)
{
    if (summary.totalRequirements == 0)
        return {};

    QString suffix = QStringLiteral(" · %1%").arg(progressPercent(summary));
    if (summary.overdueCount > 0)
        suffix += reportServiceTr(", %1 überfällig").arg(summary.overdueCount);
    return suffix;
}
