#ifndef UI_BAUSTEINTREEMODEL_H
#define UI_BAUSTEINTREEMODEL_H

#include "domain/ApplicabilityStatus.h"
#include "domain/Baustein.h"

#include <QAbstractItemModel>
#include <QHash>
#include <QList>
#include <QSet>

class BausteinTreeModel : public QAbstractItemModel
{
    Q_OBJECT

public:
    enum Roles {
        BausteinIdRole = Qt::UserRole + 1,
        ExternalIdRole,
        IsGroupRole,
        ApplicabilityRole,
        RecommendedRole
    };

    explicit BausteinTreeModel(QObject *parent = nullptr);

    void setBausteine(const QList<Baustein> &bausteine);
    void setApplicabilityMap(const QHash<int, ApplicabilityStatus> &map);
    void setRecommendedBausteinIds(const QSet<int> &ids);
    void setHighlightRecommendations(bool highlight);
    void setHideNonApplicable(bool hide);

    QModelIndex index(int row, int column, const QModelIndex &parent = QModelIndex()) const override;
    QModelIndex parent(const QModelIndex &child) const override;
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    int columnCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    Qt::ItemFlags flags(const QModelIndex &index) const override;

    Baustein bausteinForIndex(const QModelIndex &index) const;

private:
    struct GroupNode {
        QString name;
        QList<Baustein> bausteine;
        QList<int> visibleIndices;
    };

    bool isBausteinVisible(const Baustein &baustein) const;
    void rebuildVisibleIndices();

    QList<GroupNode> m_groups;
    QHash<int, ApplicabilityStatus> m_applicability;
    QSet<int> m_recommendedIds;
    bool m_highlightRecommendations = true;
    bool m_hideNonApplicable = false;
};

#endif
