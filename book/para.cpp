#include "para.h"

BaseNode* createParaNode( void )
{
    return new Para();
}

void Para::generateHtml(QStringList &list)
{
    list.append("<p>");
    list.append(m_text);
}

void Para::generateHtmlPost(QStringList &list)
{
    list.append("</p>");
}

Para::Para()
{

}

void Para::parse(QDomNode root)
{
    if (root.hasChildNodes() == true )
    {
        m_text.append(root.firstChild().toText().data());
    }
    BaseNode::parse(root);
}

