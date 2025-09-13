#ifndef INDEXNODE_H
#define INDEXNODE_H

#include <QObject>

#include <QList>

class BaseNode;

class IndexNode : public QObject
{
    Q_OBJECT
public:
    explicit IndexNode(QObject *parent = nullptr);

    void addChild( IndexNode* node );
    QList<IndexNode*> & childs( void ) { return m_childs;}

    IndexNode *parent() const;
    void setParent(IndexNode *newParent);

    QString title() const;
    void setTitle(const QString &newTitle);

    QString id() const;
    void setId(const QString &newId);

    BaseNode *node() const;
    void setNode(BaseNode *newNode);

    bool hasNode( BaseNode* node);

    IndexNode* findIndex(BaseNode* node);

private:
    QList<IndexNode*>   m_childs;
    IndexNode*          m_parent;
    QString             m_title;
    QString             m_id;
    BaseNode*           m_node;
};


#endif // INDEXNODE_H
