#ifndef LISTITEM_H
#define LISTITEM_H

#include "basenode.h"

class ListItem : public BaseNode
{
protected:
    void generateHtml(QStringList& list ) override;
    void generateHtmlPost(QStringList& list ) override;

public:
    ListItem();

    void parse( QDomNode root ) override;

};

extern BaseNode* createListItemNode( void );

#endif // LISTITEM_H
