#include "listitem.h"

BaseNode* createListItemNode( void )
{
    return new ListItem();
}


ListItem::ListItem()
{

}

void ListItem::parse(QDomNode root)
{
    BaseNode::parse(root);
}


void ListItem::generateHtml(QStringList &list)
{
    list.append("<li>");
    list.append(m_text);
}

void ListItem::generateHtmlPost(QStringList &list)
{
    list.append("</li>");
}
