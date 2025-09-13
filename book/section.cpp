#include "section.h"

BaseNode* createSectionNode( void )
{
    return new Section();
}

Section::Section()
{

}

void Section::parse(QDomNode root)
{
    if ( root.attributes().contains("xml:id") == true)
    {
        m_id = root.attributes().namedItem("xml:id").nodeValue();
    }

    BaseNode::parse(root);
}

QString Section::getTitle()
{
    QString result;

    foreach (BaseNode* child, m_childs)
    {
        if ( child->name() == "title")
        {
            result = child->firstLine();
            break;
        }
    }
    return result;
}

QString Section::getID()
{
    return m_id;
}

