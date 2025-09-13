#include "title.h"

BaseNode* createTitleNode( void )
{
    return new Title();
}

void Title::countLevel()
{
    m_level = 1;
    BaseNode* node = m_parent;

    while( node != nullptr)
    {
        if ( node->name() == "section" )
            m_level++;
        node = node->parent();
    }
}

void Title::generateHtml(QStringList &list)
{        
    list.append(QString("<h%1>").arg(m_level));
    list.append(m_text);
    list.append(QString("</h%1>").arg(m_level));
}

Title::Title()
{
    m_level = 1;
}

void Title::parse(QDomNode root)
{
    countLevel();

    QDomNode child = root.firstChild();

    if (child.isNull() == false)
    {
        m_text.append( child.nodeValue());
    }    
}
