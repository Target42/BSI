#include "emphasis.h"

BaseNode* createEmphasisNode( void )
{
    return new Emphasis;
}

Emphasis::Emphasis()
{

}

void Emphasis::parse(QDomNode root)
{
    if  ( root.hasAttributes() == true )
    {
        m_attr = root.attributes().namedItem("role").nodeValue();
    }

    QDomNode child = root.firstChild();

    if (child.isNull() == false)
    {
        m_text.append( child.nodeValue());
    }
    BaseNode::parse(root);
}

void Emphasis::generateHtml(QStringList &list)
{
    if ( m_attr == "strong")
        list.append("<b>");
    if ( m_attr == "italics")
        list.append("<i>");
    if ( m_attr.indexOf("color") > -1 )
        list.append(QString("<span style=\"%1\">").arg(m_attr));


    list.append(m_text);
}

void Emphasis::generateHtmlPost(QStringList &list)
{
    if ( m_attr == "strong")
        list.append("</b>");
    if ( m_attr == "italics")
        list.append("</i>");
    if ( m_attr.indexOf("color") > -1 )
        list.append("</span>");
}
