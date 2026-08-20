#include "CockpitTableModel.h"

#include <QBrush>
#include <QLocale>

CockpitTableModel::CockpitTableModel(QObject *parent)
    : QAbstractTableModel(parent)
{
}

void CockpitTableModel::setItems(const QList<CockpitItem> &items)
{
    beginResetModel();
    m_items = items;
    endResetModel();
}

CockpitItem CockpitTableModel::itemAt(int row) const
{
    if (row < 0 || row >= m_items.size())
        return {};
    return m_items.at(row);
}

int CockpitTableModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_items.size();
}

int CockpitTableModel::columnCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return ColumnCount;
}

QVariant CockpitTableModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid())
        return {};

    const CockpitItem &item = m_items.at(index.row());

    if (role == Qt::ForegroundRole && item.overdue)
        return QBrush(Qt::red);

    if (role != Qt::DisplayRole)
        return {};

    switch (index.column()) {
    case KindColumn:
        return cockpitKindToString(item.kind);
    case TargetObjectColumn:
        return item.targetObjectName;
    case BausteinColumn:
        return item.bausteinExternalId;
    case RequirementColumn:
        return item.requirementExternalId;
    case TitleColumn:
        return item.title;
    case StatusColumn:
        return item.statusText;
    case ResponsibleColumn:
        return item.responsible;
    case DueDateColumn:
        if (!item.dueDate.isValid())
            return {};
        return QLocale().toString(item.dueDate, QLocale::ShortFormat);
    default:
        return {};
    }
}

QVariant CockpitTableModel::headerData(int section, Qt::Orientation orientation, int role) const
{
    if (orientation != Qt::Horizontal || role != Qt::DisplayRole)
        return {};

    switch (section) {
    case KindColumn:
        return QStringLiteral("Art");
    case TargetObjectColumn:
        return QStringLiteral("Zielobjekt");
    case BausteinColumn:
        return QStringLiteral("Baustein");
    case RequirementColumn:
        return QStringLiteral("Anforderung");
    case TitleColumn:
        return QStringLiteral("Titel");
    case StatusColumn:
        return QStringLiteral("Status");
    case ResponsibleColumn:
        return QStringLiteral("Verantwortlich");
    case DueDateColumn:
        return QStringLiteral("Frist");
    default:
        return {};
    }
}
