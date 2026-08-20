#include "TargetObjectTreeModel.h"

#include "domain/ProtectionNeed.h"
#include "domain/ReportRow.h"
#include "domain/TargetObject.h"
#include "domain/TargetObjectType.h"
#include "services/ReportService.h"

#include <QFont>
#include <QHash>

TargetObjectTreeModel::TargetObjectTreeModel(QObject *parent)
    : QAbstractItemModel(parent)
{
}

void TargetObjectTreeModel::insertLayerGroups(int scopeIndex)
{
    if (scopeIndex < 0 || scopeIndex >= m_nodes.size())
        return;

    QHash<int, int> groupIndexByType;
    for (const TargetObjectType type : scopeLayerTypes()) {
        Node group;
        group.isLayerGroup = true;
        group.object.type = type;
        group.parentNodeIndex = scopeIndex;
        groupIndexByType.insert(static_cast<int>(type), m_nodes.size());
        m_nodes.append(group);
    }

    const QList<int> previousChildren = m_nodes.at(scopeIndex).childNodeIndices;
    m_nodes[scopeIndex].childNodeIndices.clear();
    for (const TargetObjectType type : scopeLayerTypes())
        m_nodes[scopeIndex].childNodeIndices.append(groupIndexByType.value(static_cast<int>(type)));

    for (int childIndex : previousChildren) {
        if (childIndex < 0 || childIndex >= m_nodes.size())
            continue;
        const int typeKey = static_cast<int>(m_nodes.at(childIndex).object.type);
        const int groupIndex = groupIndexByType.value(typeKey, -1);
        if (groupIndex >= 0) {
            m_nodes[childIndex].parentNodeIndex = groupIndex;
            m_nodes[groupIndex].childNodeIndices.append(childIndex);
        } else {
            m_nodes[scopeIndex].childNodeIndices.append(childIndex);
        }
    }
}

void TargetObjectTreeModel::setTargetObjects(const QList<TargetObject> &objects)
{
    beginResetModel();
    m_nodes.clear();
    m_idToIndex.clear();
    m_progressSummaries.clear();

    for (const TargetObject &object : objects) {
        Node node;
        node.object = object;
        node.parentNodeIndex = -1;
        if (object.id > 0)
            m_idToIndex.insert(object.id, m_nodes.size());
        m_nodes.append(node);
    }

    for (int i = 0; i < m_nodes.size(); ++i) {
        const int parentId = m_nodes.at(i).object.parentId;
        if (parentId == 0)
            continue;

        const int parentNodeIndex = m_idToIndex.value(parentId, -1);
        if (parentNodeIndex < 0)
            continue;

        m_nodes[i].parentNodeIndex = parentNodeIndex;
        m_nodes[parentNodeIndex].childNodeIndices.append(i);
    }

    int scopeIndex = -1;
    for (int i = 0; i < m_nodes.size(); ++i) {
        if (isRootScopeTarget(m_nodes.at(i).object)) {
            scopeIndex = i;
            break;
        }
    }
    if (scopeIndex >= 0)
        insertLayerGroups(scopeIndex);

    endResetModel();
}

void TargetObjectTreeModel::setProgressSummaries(const QHash<int, ReportSummary> &summaries)
{
    m_progressSummaries = summaries;
    if (m_nodes.isEmpty())
        return;

    for (int i = 0; i < m_nodes.size(); ++i) {
        const QModelIndex modelIndex = indexForNode(i);
        if (modelIndex.isValid())
            emit dataChanged(modelIndex, modelIndex, {Qt::DisplayRole});
    }
}

QModelIndex TargetObjectTreeModel::index(int row, int column, const QModelIndex &parent) const
{
    if (!hasIndex(row, column, parent))
        return {};

    int nodeIndex = -1;
    if (!parent.isValid()) {
        int rootRow = 0;
        for (int i = 0; i < m_nodes.size(); ++i) {
            if (m_nodes.at(i).parentNodeIndex != -1)
                continue;
            if (rootRow == row) {
                nodeIndex = i;
                break;
            }
            ++rootRow;
        }
    } else {
        const int parentNodeIndex = int(parent.internalId()) - 1;
        if (parentNodeIndex < 0 || parentNodeIndex >= m_nodes.size())
            return {};
        if (row < 0 || row >= m_nodes.at(parentNodeIndex).childNodeIndices.size())
            return {};
        nodeIndex = m_nodes.at(parentNodeIndex).childNodeIndices.at(row);
    }

    if (nodeIndex < 0)
        return {};
    return createIndex(row, column, quintptr(nodeIndex + 1));
}

QModelIndex TargetObjectTreeModel::parent(const QModelIndex &child) const
{
    if (!child.isValid())
        return {};

    const int nodeIndex = int(child.internalId()) - 1;
    if (nodeIndex < 0 || nodeIndex >= m_nodes.size())
        return {};

    const int parentNodeIndex = m_nodes.at(nodeIndex).parentNodeIndex;
    if (parentNodeIndex < 0)
        return {};

    const int grandParentIndex = m_nodes.at(parentNodeIndex).parentNodeIndex;
    int row = 0;
    if (grandParentIndex < 0) {
        for (int i = 0; i < m_nodes.size(); ++i) {
            if (m_nodes.at(i).parentNodeIndex != -1)
                continue;
            if (i == parentNodeIndex)
                break;
            ++row;
        }
    } else {
        row = m_nodes.at(grandParentIndex).childNodeIndices.indexOf(parentNodeIndex);
    }

    return createIndex(row, 0, quintptr(parentNodeIndex + 1));
}

int TargetObjectTreeModel::rowCount(const QModelIndex &parent) const
{
    if (!parent.isValid()) {
        int roots = 0;
        for (const Node &node : m_nodes) {
            if (node.parentNodeIndex == -1)
                ++roots;
        }
        return roots;
    }

    const int nodeIndex = int(parent.internalId()) - 1;
    if (nodeIndex < 0 || nodeIndex >= m_nodes.size())
        return 0;
    return m_nodes.at(nodeIndex).childNodeIndices.size();
}

int TargetObjectTreeModel::columnCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent)
    return 1;
}

QVariant TargetObjectTreeModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid())
        return {};

    const int nodeIndex = int(index.internalId()) - 1;
    if (nodeIndex < 0 || nodeIndex >= m_nodes.size())
        return {};

    const Node &node = m_nodes.at(nodeIndex);
    const TargetObject &object = node.object;
    switch (role) {
    case Qt::DisplayRole: {
        if (node.isLayerGroup)
            return targetObjectLayerGroupTitle(object.type);
        QString text = QStringLiteral("%1 – %2  [%3]")
                           .arg(targetObjectTypeToString(object.type),
                                object.name,
                                protectionNeedSummary(object));
        const ReportSummary summary = m_progressSummaries.value(object.id);
        text += ReportService::formatTreeProgressSuffix(summary);
        return text;
    }
    case Qt::FontRole:
        if (node.isLayerGroup) {
            QFont font;
            font.setBold(true);
            return font;
        }
        return {};
    case TargetObjectIdRole:
        return object.id;
    case TargetObjectTypeRole:
        return static_cast<int>(object.type);
    case IsGroupRole:
        return node.isLayerGroup;
    default:
        return {};
    }
}

Qt::ItemFlags TargetObjectTreeModel::flags(const QModelIndex &index) const
{
    if (!index.isValid())
        return Qt::NoItemFlags;
    return Qt::ItemIsEnabled | Qt::ItemIsSelectable;
}

TargetObject TargetObjectTreeModel::targetObjectForIndex(const QModelIndex &index) const
{
    if (!index.isValid())
        return {};

    const int nodeIndex = int(index.internalId()) - 1;
    if (nodeIndex < 0 || nodeIndex >= m_nodes.size())
        return {};
    return m_nodes.at(nodeIndex).object;
}

bool TargetObjectTreeModel::isLayerGroup(const QModelIndex &index) const
{
    if (!index.isValid())
        return false;
    const int nodeIndex = int(index.internalId()) - 1;
    if (nodeIndex < 0 || nodeIndex >= m_nodes.size())
        return false;
    return m_nodes.at(nodeIndex).isLayerGroup;
}

QModelIndex TargetObjectTreeModel::indexForTargetObjectId(int targetObjectId) const
{
    return indexForNode(m_idToIndex.value(targetObjectId, -1));
}

QModelIndex TargetObjectTreeModel::indexForNode(int nodeIndex) const
{
    if (nodeIndex < 0 || nodeIndex >= m_nodes.size())
        return {};

    int row = 0;
    const int parentNodeIndex = m_nodes.at(nodeIndex).parentNodeIndex;
    if (parentNodeIndex < 0) {
        for (int i = 0; i < m_nodes.size(); ++i) {
            if (m_nodes.at(i).parentNodeIndex != -1)
                continue;
            if (i == nodeIndex)
                break;
            ++row;
        }
    } else {
        row = m_nodes.at(parentNodeIndex).childNodeIndices.indexOf(nodeIndex);
    }

    return createIndex(row, 0, quintptr(nodeIndex + 1));
}
