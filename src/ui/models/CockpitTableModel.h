#ifndef UI_COCKPITTABLEMODEL_H
#define UI_COCKPITTABLEMODEL_H

#include "domain/CockpitItem.h"

#include <QAbstractTableModel>
#include <QList>

class CockpitTableModel : public QAbstractTableModel
{
    Q_OBJECT

public:
    enum Column {
        KindColumn = 0,
        TargetObjectColumn,
        BausteinColumn,
        RequirementColumn,
        TitleColumn,
        StatusColumn,
        ResponsibleColumn,
        DueDateColumn,
        ColumnCount
    };

    explicit CockpitTableModel(QObject *parent = nullptr);

    void setItems(const QList<CockpitItem> &items);
    CockpitItem itemAt(int row) const;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    int columnCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QVariant headerData(int section, Qt::Orientation orientation, int role) const override;

private:
    QList<CockpitItem> m_items;
};

#endif
