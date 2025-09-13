#ifndef INDEXSTORE_H
#define INDEXSTORE_H

#include <QString>
#include <QJsonArray>
#include <QMap>

#include "book/basenode.h"

class IndexNode;

class IndexStore
{
public:
    IndexStore();

    IndexNode *root() const;
    void setRoot(IndexNode *newRoot);

    QString home() const;
    void setHome(const QString &newHome);

    bool load( void );
    bool save( void );

private:
    IndexNode* m_root;
    QString m_home;


    void addIndex( QJsonArray& arr, IndexNode* node);

    void buildMap( QJsonArray& arr, QMap<QString, BaseNode::tTemplateState>& map );
    void setStates( IndexNode* root, QMap<QString, BaseNode::tTemplateState>& map );


};


#endif // INDEXSTORE_H
