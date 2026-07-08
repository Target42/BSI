#include "MeasureTableModel.h"

#include "domain/MeasureStatus.h"

#include <QLocale>

MeasureTableModel::MeasureTableModel(QObject *parent)
    : QAbstractTableModel(parent)
{
}

void MeasureTableModel::setMeasures(const QList<Measure> &measures)
{
    beginResetModel();
    m_measures = measures;
    endResetModel();
}

Measure MeasureTableModel::measureAt(int row) const
{
    if (row < 0 || row >= m_measures.size())
        return {};
    return m_measures.at(row);
}

int MeasureTableModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_measures.size();
}

int MeasureTableModel::columnCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return ColumnCount;
}

QVariant MeasureTableModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || role != Qt::DisplayRole)
        return {};

    const Measure &measure = m_measures.at(index.row());
    switch (index.column()) {
    case TitleColumn:
        return measure.title;
    case ResponsibleColumn:
        return measure.responsible;
    case DueDateColumn:
        if (!measure.dueDate.isValid())
            return {};
        return QLocale().toString(measure.dueDate, QLocale::ShortFormat);
    case StatusColumn:
        return measureStatusToString(measure.status);
    default:
        return {};
    }
}

QVariant MeasureTableModel::headerData(int section, Qt::Orientation orientation, int role) const
{
    if (orientation != Qt::Horizontal || role != Qt::DisplayRole)
        return {};

    switch (section) {
    case TitleColumn:
        return QStringLiteral("Maßnahme");
    case ResponsibleColumn:
        return QStringLiteral("Verantwortlich");
    case DueDateColumn:
        return QStringLiteral("Frist");
    case StatusColumn:
        return QStringLiteral("Status");
    default:
        return {};
    }
}
