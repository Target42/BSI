#ifndef UI_REQUIREMENTTABLEMODEL_H
#define UI_REQUIREMENTTABLEMODEL_H

#include "domain/Requirement.h"
#include "domain/RequirementAssessment.h"

#include <QAbstractTableModel>
#include <QList>

class RequirementTableModel : public QAbstractTableModel
{
    Q_OBJECT

public:
    enum Column {
        ExternalIdColumn = 0,
        TitleColumn,
        LevelColumn,
        RoleColumn,
        StatusColumn,
        ResponsibleColumn,
        DueDateColumn,
        MeasureCountColumn,
        ColumnCount
    };

    explicit RequirementTableModel(QObject *parent = nullptr);

    void setRequirements(const QList<Requirement> &requirements);
    void setAssessment(int requirementDbId, const RequirementAssessment &assessment);
    void clearAssessments();

    Requirement requirementAt(int row) const;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    int columnCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QVariant headerData(int section, Qt::Orientation orientation, int role) const override;
    Qt::ItemFlags flags(const QModelIndex &index) const override;

private:
    struct Row {
        Requirement requirement;
        RequirementAssessment assessment;
        bool hasAssessment = false;
    };

    QList<Row> m_rows;
};

#endif
