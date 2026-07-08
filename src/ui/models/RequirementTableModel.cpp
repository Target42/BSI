#include "RequirementTableModel.h"

#include "domain/AssessmentStatus.h"
#include "domain/RequirementLevel.h"

#include <QBrush>
#include <QDate>
#include <QLocale>

RequirementTableModel::RequirementTableModel(QObject *parent)
    : QAbstractTableModel(parent)
{
}

void RequirementTableModel::setRequirements(const QList<Requirement> &requirements)
{
    beginResetModel();
    m_rows.clear();
    for (const Requirement &requirement : requirements) {
        Row row;
        row.requirement = requirement;
        m_rows.append(row);
    }
    endResetModel();
}

void RequirementTableModel::setAssessment(int requirementDbId, const RequirementAssessment &assessment)
{
    for (int i = 0; i < m_rows.size(); ++i) {
        if (m_rows.at(i).requirement.id != requirementDbId)
            continue;
        m_rows[i].assessment = assessment;
        m_rows[i].hasAssessment = true;
        const QModelIndex topLeft = index(i, StatusColumn);
        const QModelIndex bottomRight = index(i, MeasureCountColumn);
        emit dataChanged(topLeft, bottomRight);
        return;
    }
}

void RequirementTableModel::clearAssessments()
{
    for (int i = 0; i < m_rows.size(); ++i)
        m_rows[i].hasAssessment = false;
    if (!m_rows.isEmpty()) {
        emit dataChanged(index(0, StatusColumn), index(m_rows.size() - 1, MeasureCountColumn));
    }
}

Requirement RequirementTableModel::requirementAt(int row) const
{
    if (row < 0 || row >= m_rows.size())
        return {};
    return m_rows.at(row).requirement;
}

int RequirementTableModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_rows.size();
}

int RequirementTableModel::columnCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return ColumnCount;
}

QVariant RequirementTableModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid())
        return {};

    const Row &row = m_rows.at(index.row());

    if (role == Qt::ForegroundRole && index.column() == DueDateColumn && row.hasAssessment
        && row.assessment.dueDate.isValid() && row.assessment.dueDate < QDate::currentDate()
        && row.assessment.status != AssessmentStatus::Fulfilled
        && row.assessment.status != AssessmentStatus::NotApplicable) {
        return QBrush(Qt::red);
    }

    if (role != Qt::DisplayRole)
        return {};

    switch (index.column()) {
    case ExternalIdColumn:
        return row.requirement.externalId;
    case TitleColumn:
        return row.requirement.title;
    case LevelColumn:
        return requirementLevelToString(row.requirement.level);
    case RoleColumn:
        return row.requirement.responsibleRole;
    case StatusColumn:
        if (!row.hasAssessment)
            return assessmentStatusToString(AssessmentStatus::Open);
        return assessmentStatusToString(row.assessment.status);
    case ResponsibleColumn:
        return row.hasAssessment ? row.assessment.responsible : QVariant();
    case DueDateColumn:
        if (!row.hasAssessment || !row.assessment.dueDate.isValid())
            return {};
        return QLocale().toString(row.assessment.dueDate, QLocale::ShortFormat);
    case MeasureCountColumn:
        if (!row.hasAssessment || row.assessment.measureCount == 0)
            return {};
        return row.assessment.measureCount;
    default:
        return {};
    }
}

QVariant RequirementTableModel::headerData(int section, Qt::Orientation orientation, int role) const
{
    if (orientation != Qt::Horizontal || role != Qt::DisplayRole)
        return {};

    switch (section) {
    case ExternalIdColumn:
        return QStringLiteral("ID");
    case TitleColumn:
        return QStringLiteral("Anforderung");
    case LevelColumn:
        return QStringLiteral("Stufe");
    case RoleColumn:
        return QStringLiteral("Rolle");
    case StatusColumn:
        return QStringLiteral("Status");
    case ResponsibleColumn:
        return QStringLiteral("Umsetzung durch");
    case DueDateColumn:
        return QStringLiteral("Frist");
    case MeasureCountColumn:
        return QStringLiteral("Maßnahmen");
    default:
        return {};
    }
}

Qt::ItemFlags RequirementTableModel::flags(const QModelIndex &index) const
{
    if (!index.isValid())
        return Qt::NoItemFlags;
    return Qt::ItemIsEnabled | Qt::ItemIsSelectable;
}
