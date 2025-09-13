#include "chapter.h"


BaseNode* createChapterNode( void )
{
    return new Chapter();
}
Chapter::Chapter()
{

}

void Chapter::parse(QDomNode root)
{    
    m_id = root.attributes().namedItem("xml:id").nodeValue();

    BaseNode::parse(root);
}

QString Chapter::getTitle()
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

QString Chapter::getID()
{
    return m_id;
}
