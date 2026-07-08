#ifndef UI_TARGETOBJECTTREEMODEL_H
#define UI_TARGETOBJECTTREEMODEL_H

#include "domain/TargetObject.h"

#include <QAbstractItemModel>
#include <QHash>
#include <QList>

class TargetObjectTreeModel : public QAbstractItemModel
{
    Q_OBJECT

public:
    enum Roles {
        TargetObjectIdRole = Qt::UserRole + 1,
        TargetObjectTypeRole,
        IsGroupRole
    };

    explicit TargetObjectTreeModel(QObject *parent = nullptr);

    void setTargetObjects(const QList<TargetObject> &objects);

    QModelIndex index(int row, int column, const QModelIndex &parent = QModelIndex()) const override;
    QModelIndex parent(const QModelIndex &child) const override;
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    int columnCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    Qt::ItemFlags flags(const QModelIndex &index) const override;

    TargetObject targetObjectForIndex(const QModelIndex &index) const;

private:
    struct Node {
        TargetObject object;
        int parentNodeIndex = -1;
        QList<int> childNodeIndices;
    };

    QList<Node> m_nodes;
    QHash<int, int> m_idToIndex;
};

#endif
