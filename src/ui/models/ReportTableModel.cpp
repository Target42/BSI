#include "ReportTableModel.h"

#include "domain/ApplicabilityStatus.h"
#include "domain/AssessmentStatus.h"

#include <QBrush>
#include <QLocale>

ReportTableModel::ReportTableModel(QObject *parent)
    : QAbstractTableModel(parent)
{
}

void ReportTableModel::setRows(const QList<ReportRow> &rows)
{
    beginResetModel();
    m_rows = rows;
    endResetModel();
}

int ReportTableModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_rows.size();
}

int ReportTableModel::columnCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return ColumnCount;
}

QVariant ReportTableModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid())
        return {};

    const ReportRow &row = m_rows.at(index.row());

    if (role == Qt::ForegroundRole && row.overdue)
        return QBrush(Qt::red);

    if (role != Qt::DisplayRole)
        return {};

    switch (index.column()) {
    case TargetObjectColumn:
        return row.targetObjectName;
    case BausteinColumn:
        return row.bausteinExternalId;
    case RequirementColumn:
        return QStringLiteral("%1 – %2").arg(row.requirementExternalId, row.requirementTitle);
    case LevelColumn:
        return row.level;
    case ApplicabilityColumn:
        return applicabilityStatusToString(row.applicability);
    case StatusColumn:
        return assessmentStatusToString(row.status);
    case ResponsibleColumn:
        return row.responsible;
    case DueDateColumn:
        if (!row.dueDate.isValid())
            return {};
        return QLocale().toString(row.dueDate, QLocale::ShortFormat);
    case MeasureCountColumn:
        return row.measureCount > 0 ? QVariant(row.measureCount) : QVariant();
    default:
        return {};
    }
}

QVariant ReportTableModel::headerData(int section, Qt::Orientation orientation, int role) const
{
    if (orientation != Qt::Horizontal || role != Qt::DisplayRole)
        return {};

    switch (section) {
    case TargetObjectColumn:
        return QStringLiteral("Zielobjekt");
    case BausteinColumn:
        return QStringLiteral("Baustein");
    case RequirementColumn:
        return QStringLiteral("Anforderung");
    case LevelColumn:
        return QStringLiteral("Stufe");
    case ApplicabilityColumn:
        return QStringLiteral("Anwendbarkeit");
    case StatusColumn:
        return QStringLiteral("Status");
    case ResponsibleColumn:
        return QStringLiteral("Verantwortlich");
    case DueDateColumn:
        return QStringLiteral("Frist");
    case MeasureCountColumn:
        return QStringLiteral("Maßnahmen");
    default:
        return {};
    }
}
