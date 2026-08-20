#include "CockpitService.h"

#include "domain/AssessmentStatus.h"
#include "domain/Measure.h"
#include "domain/MeasureStatus.h"
#include "domain/Requirement.h"
#include "domain/Standard.h"
#include "domain/TargetObject.h"
#include "services/ReportService.h"

#include <QCoreApplication>
#include <QDate>
#include <QHash>
#include <QStringList>
#include <algorithm>

CockpitService::CockpitService(ICatalogRepository &catalog,
                               IProjectRepository &project,
                               ITargetObjectRepository &targetObjects,
                               IMeasureRepository &measures)
    : m_catalog(catalog)
    , m_project(project)
    , m_targetObjects(targetObjects)
    , m_measures(measures)
{
}

bool CockpitService::responsibleMatches(const QString &responsible, const QString &name,
                                        const QString &email, const QString &needle)
{
    const QString responsibleLower = responsible.trimmed().toLower();
    if (responsibleLower.isEmpty())
        return false;
    if (!needle.trimmed().isEmpty())
        return responsibleLower.contains(needle.trimmed().toLower());
    if (!name.trimmed().isEmpty() && responsibleLower.contains(name.trimmed().toLower()))
        return true;
    if (!email.trimmed().isEmpty() && responsibleLower.contains(email.trimmed().toLower()))
        return true;
    return false;
}

QList<CockpitItem> CockpitService::buildItems(int projectId, const QString &catalogVersion) const
{
    QList<CockpitItem> items;
    ReportService report(m_catalog, m_project, m_targetObjects, m_measures);
    const QList<ReportRow> rows = report.buildSollIstReport(projectId, 0, catalogVersion);

    QHash<QString, ReportRow> assessmentByKey;
    for (const ReportRow &row : rows) {
        CockpitItem item;
        item.kind = CockpitKind::Assessment;
        item.targetObjectId = row.targetObjectId;
        item.targetObjectName = row.targetObjectName;
        item.bausteinDbId = row.bausteinDbId;
        item.bausteinExternalId = row.bausteinExternalId;
        item.requirementDbId = row.requirementDbId;
        item.requirementExternalId = row.requirementExternalId;
        item.title = row.requirementTitle;
        item.statusText = assessmentStatusToString(row.status);
        item.responsible = row.responsible;
        item.dueDate = row.dueDate;
        item.overdue = row.overdue;
        item.assessmentStatus = row.status;
        items.append(item);
        assessmentByKey.insert(QStringLiteral("%1:%2").arg(row.targetObjectId).arg(row.requirementDbId),
                               row);
    }

    QHash<int, Requirement> requirementById;
    const QList<Requirement> requirements =
        m_catalog.loadAllRequirements(StandardType::ITGrundschutz, catalogVersion);
    for (const Requirement &requirement : requirements)
        requirementById.insert(requirement.id, requirement);

    QHash<int, QString> targetNameById;
    const QList<TargetObject> targets = m_targetObjects.loadTargetObjects(projectId);
    for (const TargetObject &target : targets)
        targetNameById.insert(target.id, target.name);

    const QList<Measure> measures = m_measures.loadProjectMeasures(projectId);
    for (const Measure &measure : measures) {
        CockpitItem item;
        item.kind = CockpitKind::Measure;
        item.measureId = measure.id;
        item.targetObjectId = measure.targetObjectId;
        item.targetObjectName = targetNameById.value(measure.targetObjectId,
                                                     QString::number(measure.targetObjectId));
        item.requirementDbId = measure.requirementDbId;
        const Requirement requirement = requirementById.value(measure.requirementDbId);
        if (requirement.id != 0) {
            item.bausteinDbId = requirement.bausteinDbId;
            item.bausteinExternalId = requirement.bausteinExternalId;
            item.requirementExternalId = requirement.externalId;
        }
        const QString key =
            QStringLiteral("%1:%2").arg(measure.targetObjectId).arg(measure.requirementDbId);
        if (assessmentByKey.contains(key)) {
            const ReportRow &linked = assessmentByKey.value(key);
            item.assessmentStatus = linked.status;
            if (item.bausteinDbId == 0) {
                item.bausteinDbId = linked.bausteinDbId;
                item.bausteinExternalId = linked.bausteinExternalId;
                item.requirementExternalId = linked.requirementExternalId;
            }
        }
        item.title = measure.title;
        item.statusText = measureStatusToString(measure.status);
        item.responsible = measure.responsible;
        item.dueDate = measure.dueDate;
        item.measureStatus = measure.status;
        item.overdue = measure.dueDate.isValid() && measure.dueDate < QDate::currentDate()
                       && measure.status != MeasureStatus::Done;
        items.append(item);
    }

    std::sort(items.begin(), items.end(), [](const CockpitItem &left, const CockpitItem &right) {
        if (left.overdue != right.overdue)
            return left.overdue;
        const QDate leftDue = left.dueDate.isValid() ? left.dueDate : QDate(9999, 12, 31);
        const QDate rightDue = right.dueDate.isValid() ? right.dueDate : QDate(9999, 12, 31);
        if (leftDue != rightDue)
            return leftDue < rightDue;
        if (left.targetObjectName != right.targetObjectName)
            return left.targetObjectName < right.targetObjectName;
        if (left.bausteinExternalId != right.bausteinExternalId)
            return left.bausteinExternalId < right.bausteinExternalId;
        if (static_cast<int>(left.kind) != static_cast<int>(right.kind))
            return static_cast<int>(left.kind) < static_cast<int>(right.kind);
        if (left.requirementExternalId != right.requirementExternalId)
            return left.requirementExternalId < right.requirementExternalId;
        return left.title < right.title;
    });

    return items;
}

QList<CockpitItem> CockpitService::applyFilter(const QList<CockpitItem> &items,
                                               const CockpitFilter &filter)
{
    QList<CockpitItem> result;
    for (const CockpitItem &item : items) {
        if (filter.kind == CockpitKindFilter::Assessments && item.kind != CockpitKind::Assessment)
            continue;
        if (filter.kind == CockpitKindFilter::Measures && item.kind != CockpitKind::Measure)
            continue;
        if (filter.hideDone && cockpitItemIsDone(item))
            continue;
        switch (filter.due) {
        case CockpitDueFilter::Overdue:
            if (!item.overdue)
                continue;
            break;
        case CockpitDueFilter::ThisWeek:
            if (!isDueThisWeek(item.dueDate))
                continue;
            break;
        case CockpitDueFilter::HasDate:
            if (!item.dueDate.isValid())
                continue;
            break;
        case CockpitDueFilter::NoDate:
            if (item.dueDate.isValid())
                continue;
            break;
        case CockpitDueFilter::All:
            break;
        }
        if (filter.mineOnly) {
            if (!responsibleMatches(item.responsible, filter.currentUserName, filter.currentUserEmail,
                                    {}))
                continue;
        } else if (!filter.responsibleNeedle.trimmed().isEmpty()) {
            if (!responsibleMatches(item.responsible, {}, {}, filter.responsibleNeedle))
                continue;
        }
        result.append(item);
    }
    return result;
}

CockpitSummary CockpitService::summarize(const QList<CockpitItem> &items)
{
    CockpitSummary summary;
    summary.totalCount = items.size();
    for (const CockpitItem &item : items) {
        if (item.kind == CockpitKind::Assessment)
            ++summary.assessmentCount;
        else
            ++summary.measureCount;
        if (item.overdue)
            ++summary.overdueCount;
        if (isDueThisWeek(item.dueDate))
            ++summary.dueThisWeekCount;
    }
    return summary;
}

QString CockpitService::formatSummary(const CockpitSummary &summary)
{
    if (summary.totalCount == 0)
        return QCoreApplication::translate("CockpitService", "Keine offenen Aufgaben");

    QString text = QCoreApplication::translate("CockpitService", "%1 Einträge")
                       .arg(summary.totalCount);
    QStringList parts;
    if (summary.assessmentCount > 0)
        parts << QCoreApplication::translate("CockpitService", "%1 Bewertungen")
                     .arg(summary.assessmentCount);
    if (summary.measureCount > 0)
        parts << QCoreApplication::translate("CockpitService", "%1 Maßnahmen")
                     .arg(summary.measureCount);
    if (summary.overdueCount > 0)
        parts << QCoreApplication::translate("CockpitService", "%1 überfällig")
                     .arg(summary.overdueCount);
    if (summary.dueThisWeekCount > 0)
        parts << QCoreApplication::translate("CockpitService", "%1 diese Woche")
                     .arg(summary.dueThisWeekCount);
    if (!parts.isEmpty())
        text += QStringLiteral(" – ") + parts.join(QStringLiteral(", "));
    return text;
}
