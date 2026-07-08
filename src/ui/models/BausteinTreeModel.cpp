#include "BausteinTreeModel.h"

#include <QBrush>
#include <QColor>
#include <QMap>

BausteinTreeModel::BausteinTreeModel(QObject *parent)
    : QAbstractItemModel(parent)
{
}

void BausteinTreeModel::setBausteine(const QList<Baustein> &bausteine)
{
    beginResetModel();
    m_groups.clear();

    QMap<QString, int> groupIndex;
    for (const Baustein &baustein : bausteine) {
        const QString groupName = baustein.groupName.isEmpty()
                                      ? QStringLiteral("Sonstige")
                                      : baustein.groupName;
        if (!groupIndex.contains(groupName)) {
            GroupNode group;
            group.name = groupName;
            m_groups.append(group);
            groupIndex.insert(groupName, m_groups.size() - 1);
        }
        m_groups[groupIndex.value(groupName)].bausteine.append(baustein);
    }
    rebuildVisibleIndices();
    endResetModel();
}

void BausteinTreeModel::setApplicabilityMap(const QHash<int, ApplicabilityStatus> &map)
{
    m_applicability = map;
    rebuildVisibleIndices();
    beginResetModel();
    endResetModel();
}

void BausteinTreeModel::setRecommendedBausteinIds(const QSet<int> &ids)
{
    m_recommendedIds = ids;
    if (ids.isEmpty())
        m_recommendationTiers.clear();
    beginResetModel();
    endResetModel();
}

void BausteinTreeModel::setRecommendationTiers(const QHash<int, BausteinRecommendationTier> &tiers)
{
    m_recommendationTiers = tiers;
    beginResetModel();
    endResetModel();
}

void BausteinTreeModel::setHighlightRecommendations(bool highlight)
{
    if (m_highlightRecommendations == highlight)
        return;
    m_highlightRecommendations = highlight;
    beginResetModel();
    endResetModel();
}

void BausteinTreeModel::setHideNonApplicable(bool hide)
{
    if (m_hideNonApplicable == hide)
        return;
    m_hideNonApplicable = hide;
    rebuildVisibleIndices();
    beginResetModel();
    endResetModel();
}

bool BausteinTreeModel::isBausteinVisible(const Baustein &baustein) const
{
    if (!m_hideNonApplicable)
        return true;

    const ApplicabilityStatus status = m_applicability.value(baustein.id, ApplicabilityStatus::Undefined);
    return status == ApplicabilityStatus::Required || status == ApplicabilityStatus::Possible;
}

void BausteinTreeModel::rebuildVisibleIndices()
{
    for (GroupNode &group : m_groups) {
        group.visibleIndices.clear();
        for (int i = 0; i < group.bausteine.size(); ++i) {
            if (isBausteinVisible(group.bausteine.at(i)))
                group.visibleIndices.append(i);
        }
    }
}

QModelIndex BausteinTreeModel::index(int row, int column, const QModelIndex &parent) const
{
    if (!hasIndex(row, column, parent))
        return {};

    if (!parent.isValid()) {
        int visibleGroupRow = 0;
        for (int i = 0; i < m_groups.size(); ++i) {
            if (m_hideNonApplicable && m_groups.at(i).visibleIndices.isEmpty())
                continue;
            if (visibleGroupRow == row)
                return createIndex(row, column, quintptr(0));
            ++visibleGroupRow;
        }
        return {};
    }

    if (parent.internalId() != quintptr(0))
        return {};

    const int groupRow = parent.row();
    int visibleGroupRow = 0;
    int groupIndex = -1;
    for (int i = 0; i < m_groups.size(); ++i) {
        if (m_hideNonApplicable && m_groups.at(i).visibleIndices.isEmpty())
            continue;
        if (visibleGroupRow == groupRow) {
            groupIndex = i;
            break;
        }
        ++visibleGroupRow;
    }
    if (groupIndex < 0)
        return {};

    if (row < 0 || row >= m_groups.at(groupIndex).visibleIndices.size())
        return {};

    return createIndex(row, column, quintptr(groupIndex + 1));
}

QModelIndex BausteinTreeModel::parent(const QModelIndex &child) const
{
    if (!child.isValid() || child.internalId() == quintptr(0))
        return {};

    const int groupIndex = int(child.internalId()) - 1;
    if (groupIndex < 0 || groupIndex >= m_groups.size())
        return {};

    int visibleGroupRow = 0;
    for (int i = 0; i < m_groups.size(); ++i) {
        if (m_hideNonApplicable && m_groups.at(i).visibleIndices.isEmpty())
            continue;
        if (i == groupIndex)
            return createIndex(visibleGroupRow, 0, quintptr(0));
        ++visibleGroupRow;
    }
    return {};
}

int BausteinTreeModel::rowCount(const QModelIndex &parent) const
{
    if (!parent.isValid()) {
        int count = 0;
        for (const GroupNode &group : m_groups) {
            if (m_hideNonApplicable && group.visibleIndices.isEmpty())
                continue;
            ++count;
        }
        return count;
    }

    if (parent.internalId() != quintptr(0))
        return 0;

    const int groupRow = parent.row();
    int visibleGroupRow = 0;
    for (const GroupNode &group : m_groups) {
        if (m_hideNonApplicable && group.visibleIndices.isEmpty())
            continue;
        if (visibleGroupRow == groupRow)
            return group.visibleIndices.size();
        ++visibleGroupRow;
    }
    return 0;
}

int BausteinTreeModel::columnCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent)
    return 1;
}

QVariant BausteinTreeModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid())
        return {};

    if (index.internalId() == quintptr(0)) {
        int visibleGroupRow = 0;
        for (int i = 0; i < m_groups.size(); ++i) {
            if (m_hideNonApplicable && m_groups.at(i).visibleIndices.isEmpty())
                continue;
            if (visibleGroupRow == index.row()) {
                if (role == Qt::DisplayRole)
                    return m_groups.at(i).name;
                if (role == IsGroupRole)
                    return true;
                return {};
            }
            ++visibleGroupRow;
        }
        return {};
    }

    const int groupIndex = int(index.internalId()) - 1;
    if (groupIndex < 0 || groupIndex >= m_groups.size())
        return {};
    if (index.row() < 0 || index.row() >= m_groups.at(groupIndex).visibleIndices.size())
        return {};

    const Baustein &baustein =
        m_groups.at(groupIndex).bausteine.at(m_groups.at(groupIndex).visibleIndices.at(index.row()));

    switch (role) {
    case Qt::DisplayRole: {
        QString label = QStringLiteral("%1 %2").arg(baustein.externalId, baustein.title);
        if (m_highlightRecommendations
            && m_recommendedIds.contains(baustein.id)
            && m_applicability.value(baustein.id, ApplicabilityStatus::Undefined)
                   == ApplicabilityStatus::Undefined) {
            const BausteinRecommendationTier tier =
                m_recommendationTiers.value(baustein.id, BausteinRecommendationTier::Core);
            const QString marker =
                tier == BausteinRecommendationTier::Core ? QStringLiteral("★ ")
                                                         : QStringLiteral("○ ");
            label = marker + label;
        }
        return label;
    }
    case BausteinIdRole:
        return baustein.id;
    case ExternalIdRole:
        return baustein.externalId;
    case IsGroupRole:
        return false;
    case ApplicabilityRole:
        return static_cast<int>(m_applicability.value(baustein.id, ApplicabilityStatus::Undefined));
    case RecommendedRole:
        return m_recommendedIds.contains(baustein.id);
    case Qt::ForegroundRole: {
        const ApplicabilityStatus applicability =
            m_applicability.value(baustein.id, ApplicabilityStatus::Undefined);
        if (m_highlightRecommendations
            && m_recommendedIds.contains(baustein.id)
            && applicability == ApplicabilityStatus::Undefined) {
            const BausteinRecommendationTier tier =
                m_recommendationTiers.value(baustein.id, BausteinRecommendationTier::Core);
            if (tier == BausteinRecommendationTier::Core)
                return QBrush(QColor(0, 102, 153));
            return QBrush(QColor(0, 128, 96));
        }
        switch (applicability) {
        case ApplicabilityStatus::Required:
            return QBrush(Qt::darkRed);
        case ApplicabilityStatus::Possible:
            return QBrush(Qt::darkGreen);
        case ApplicabilityStatus::NotApplicable:
            return QBrush(Qt::darkGray);
        case ApplicabilityStatus::Undefined:
        default:
            return QBrush(Qt::black);
        }
    }
    default:
        return {};
    }
}

Qt::ItemFlags BausteinTreeModel::flags(const QModelIndex &index) const
{
    if (!index.isValid())
        return Qt::NoItemFlags;
    return Qt::ItemIsEnabled | Qt::ItemIsSelectable;
}

Baustein BausteinTreeModel::bausteinForIndex(const QModelIndex &index) const
{
    if (!index.isValid() || index.internalId() == quintptr(0))
        return {};

    const int groupIndex = int(index.internalId()) - 1;
    if (groupIndex < 0 || groupIndex >= m_groups.size())
        return {};
    if (index.row() < 0 || index.row() >= m_groups.at(groupIndex).visibleIndices.size())
        return {};

    return m_groups.at(groupIndex)
        .bausteine.at(m_groups.at(groupIndex).visibleIndices.at(index.row()));
}
