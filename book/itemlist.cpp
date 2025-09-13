#include "itemlist.h"

BaseNode* createItemListNode( void )
{
    return new ItemList();
}

ItemList::ItemList()
{

}

void ItemList::parse(QDomNode root)
{
    BaseNode::parse(root);
}

void ItemList::generateHtml(QStringList &list)
{
    list.append("<ul>");
    list.append(m_text);
}

void ItemList::generateHtmlPost(QStringList &list)
{
    list.append("</ul>");
}

