#ifndef UI_MEASURETABLEMODEL_H
#define UI_MEASURETABLEMODEL_H

#include "domain/Measure.h"

#include <QAbstractTableModel>
#include <QList>

class MeasureTableModel : public QAbstractTableModel
{
    Q_OBJECT

public:
    enum Column {
        TitleColumn = 0,
        ResponsibleColumn,
        DueDateColumn,
        StatusColumn,
        ColumnCount
    };

    explicit MeasureTableModel(QObject *parent = nullptr);

    void setMeasures(const QList<Measure> &measures);
    Measure measureAt(int row) const;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    int columnCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QVariant headerData(int section, Qt::Orientation orientation, int role) const override;

private:
    QList<Measure> m_measures;
};

#endif
