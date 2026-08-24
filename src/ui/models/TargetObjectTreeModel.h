#ifndef UI_TARGETOBJECTTREEMODEL_H
#define UI_TARGETOBJECTTREEMODEL_H

#include "domain/ReportRow.h"
#include "domain/TargetObject.h"

#include <QAbstractItemModel>
#include <QHash>
#include <QList>
#include <QMimeData>

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
    void setProgressSummaries(const QHash<int, ReportSummary> &summaries);

    QModelIndex index(int row, int column, const QModelIndex &parent = QModelIndex()) const override;
    QModelIndex parent(const QModelIndex &child) const override;
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    int columnCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    Qt::ItemFlags flags(const QModelIndex &index) const override;
    QStringList mimeTypes() const override;
    QMimeData *mimeData(const QModelIndexList &indexes) const override;
    bool canDropMimeData(const QMimeData *data, Qt::DropAction action, int row, int column,
                         const QModelIndex &parent) const override;
    bool dropMimeData(const QMimeData *data, Qt::DropAction action, int row, int column,
                      const QModelIndex &parent) override;
    Qt::DropActions supportedDropActions() const override;

    TargetObject targetObjectForIndex(const QModelIndex &index) const;
    QModelIndex indexForTargetObjectId(int targetObjectId) const;
    bool isLayerGroup(const QModelIndex &index) const;
    QList<TargetObject> targetObjects() const;

signals:
    void targetMoveRequested(int objectId, int newParentId);

private:
    QModelIndex indexForNode(int nodeIndex) const;
    void insertLayerGroups(int scopeIndex);
    struct Node {
        TargetObject object;
        bool isLayerGroup = false;
        int parentNodeIndex = -1;
        QList<int> childNodeIndices;
    };

    QList<TargetObject> m_objects;
    QList<Node> m_nodes;
    QHash<int, int> m_idToIndex;
    QHash<int, ReportSummary> m_progressSummaries;
};

#endif
