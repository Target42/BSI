#include "info.h"

BaseNode* createInofNode( void )
{
    return new Info();
}
Info::Info()
{

}

void Info::parse(QDomNode root)
{
    QDomNode child = root.firstChild();

    if (child.isNull() == false)
    {
        m_text.append(child.firstChild().nodeValue());
    }
}
