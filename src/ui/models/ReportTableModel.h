#ifndef UI_REPORTTABLEMODEL_H
#define UI_REPORTTABLEMODEL_H

#include "domain/ReportRow.h"

#include <QAbstractTableModel>
#include <QList>

class ReportTableModel : public QAbstractTableModel
{
    Q_OBJECT

public:
    enum Column {
        TargetObjectColumn = 0,
        BausteinColumn,
        RequirementColumn,
        LevelColumn,
        ApplicabilityColumn,
        StatusColumn,
        ResponsibleColumn,
        DueDateColumn,
        MeasureCountColumn,
        ColumnCount
    };

    explicit ReportTableModel(QObject *parent = nullptr);

    void setRows(const QList<ReportRow> &rows);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    int columnCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QVariant headerData(int section, Qt::Orientation orientation, int role) const override;

private:
    QList<ReportRow> m_rows;
};

#endif
