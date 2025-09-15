#include "book.h"

#include <QFile>
#include <QDomDocument>


Book::Book() {}

bool Book::load(QString fileName)
{
    bool result = false;

    QFile file(fileName);
    if ( file.open((QFile::ReadOnly)) == false)
    {
        return result;
    }

    QDomDocument doc;
    if ( !doc.setContent(&file))
    {
        file.close();
        return result;
    }
    QDomElement root = doc.documentElement();
    QString name = root.nodeName();

    if ( name == "book")
    {
        BaseNode::parse( root );
        result = ( m_childs.count()> 0 );
    }
    return result;
}

void Book::parse(QDomNode root)
{
    Q_UNUSED(root)
}
