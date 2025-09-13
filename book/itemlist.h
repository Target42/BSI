#ifndef ITEMLIST_H
#define ITEMLIST_H

#include "basenode.h"
#include <QList>

class ItemList : public BaseNode
{
protected:
    void generateHtml(QStringList& list ) override;
    void generateHtmlPost(QStringList& list ) override;

public:
    ItemList();

    void parse( QDomNode root ) override;    

};

extern BaseNode* createItemListNode( void );

#endif // ITEMLIST_H
