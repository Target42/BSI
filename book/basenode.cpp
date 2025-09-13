#include "basenode.h"
#include "nodefactory.h"

#include <QDomNode>
#include<QRegularExpression>

BaseNode* createBaseNode( void )
{
    return new BaseNode();
}

BaseNode::BaseNode()
{
    m_parent = nullptr;
    m_templateState = tsUndefined;
}

QString BaseNode::templateStateToText(tTemplateState state)
{
    QString result;

    switch(state)
    {
    case tsUndefined:
        result = "Undefiniert";
        break;

    case tsIgnore:
        result = "Keine relevanz";
        break;

    case tsNeeded:
        result = "Benötigt";
        break;

    case tsPosible:
        result = "Optional";
        break;
    default:
        result = "Undefiniert";
    }
    return result;
}

BaseNode::tTemplateState BaseNode::TestToTemplateState(QString text)
{
    tTemplateState result = tsUndefined;
    text = text.trimmed().toLower();

    if ( text == "undefiniert")
        result = tsUndefined;
    else if ( text == "keine relevanz")
        result = tsIgnore;
    else if ( text == "benötigt")
        result = tsNeeded;
    else if ( text == "optional")
        result = tsPosible;

    return result;
}

QString BaseNode::text()
{
    return m_text.join("\r");
}

void BaseNode::addChild(BaseNode *child)
{
    child->setParent(this);
    m_childs.append(child);
}

void BaseNode::parse(QDomNode root)
{
    if ( root.isNull() == true )
    {
        return;
    }

    NodeFactory* fac = NodeFactory::getInstance();

    m_name = root.nodeName();

    if ( m_name == "email")                 parseEMail(root);
    else if ( m_name == "link")             parseLink(root);
    else if ( m_name == "linebreak")        m_text.append("<br>");
    else if ( m_name == "informaltable")
    {
        parseTable(root);
        return;
    }

    for( int i = 0 ; i < root.childNodes().count() ; i++)
    {
        BaseNode* node;
        QDomNode sub;

        sub = root.childNodes().item(i);
        if ( sub.nodeName() != "#text")
        {
            node = fac->parse(sub, this);
            if ( node != nullptr )
            {
                node->setName(sub.nodeName());
                m_childs.append(node);
            }
        }
    }

    replaceMarks();
    buildWordList();
}


BaseNode::tTemplateState BaseNode::templateState() const
{
    return m_templateState;
}

void BaseNode::setTemplateState(tTemplateState newTemplateState)
{
    m_templateState = newTemplateState;
    foreach( BaseNode* child, m_childs)
    {
        child->setTemplateState(m_templateState);
    }
}

void BaseNode::parseLink(QDomNode root)
{
    QString ref = root.attributes().namedItem("xlink:href").nodeValue();
    QString text;

    if ( root.hasChildNodes() == true)
    {
        text = root.firstChild().toText().data();
    }
    m_text.append(QString("<a href=\"%1\">%2</a>").arg(ref).arg(text) );
}

void BaseNode::parseEMail(QDomNode root)
{
    if ( root.hasChildNodes() == true)
    {
        m_text.append(root.firstChild().toText().data());
    }
}

void BaseNode::parseTable(QDomNode root)
{
    // Angenommen, 'textNode' ist der QDomNode-Knoten für <text>
    QDomDocument newDoc;
    QDomNode importedNode = newDoc.importNode(root, true); // `true` für rekursiven Import aller Kinder
    newDoc.appendChild(importedNode);

    // Jetzt kannst du den String korrekt erzeugen
    QString resultString = newDoc.toString();
    m_text.append(resultString);
}

void BaseNode::replaceMarks()
{
    for( int i = 0 ; i < m_text.count() ; i++ )
    {
        QString s;

        s = m_text[i];

        s.replace("MUSS ", "<span style=\"color: red;\">MUSS </span>");
        s.replace("MÜSSEN ", "<span style=\"color: red;\">MÜSSEN </span>");

        s.replace("SOLLTEN ", "<span style=\"color: blue;\">SOLLTEN </span>");
        s.replace("SOLLTE ", "<span style=\"color: blue;\">SOLLTE </span>");


        m_text[i] = s;
    }
}

BaseNode *BaseNode::parent() const
{
    return m_parent;
}

void BaseNode::setParent(BaseNode *newParent)
{
    m_parent = newParent;
}

QString BaseNode::getTitle()
{
    return "";
}

QString BaseNode::getID()
{
    return "";
}

int BaseNode::childCount()
{
    int result = 1;

    foreach( BaseNode* child, m_childs)
    {
        result += child->childCount();
    }
    return result;
}

BaseNode *BaseNode::findChild(BaseNode *node)
{
    BaseNode * result = nullptr;

    if ( node == this )
    {
        result = this;
    }
    else
    {
        foreach (BaseNode* child, m_childs)
        {
            result = child->findChild(node);

            if ( result != nullptr)
            {
                break;
            }
        }
    }

    return result;
}

void BaseNode::fillWordList(QStringList &list)
{
    foreach (QString word, m_words)
    {
        if (list.indexOf(word) == -1 )
        {
            list.append(word);
        }
    }
}

void BaseNode::generateHtml(QStringList &list)
{
    if (m_name == "orderedlist")
        list.append("<ol>");

    list.append(m_text);
}

void BaseNode::generateHtmlPost(QStringList &list)
{
    if (m_name == "orderedlist")
        list.append("</ol>");
}

void BaseNode::buildWordList()
{
    QRegularExpression regex("[\\s+ ,:.]");
    QStringList split = m_text.join(" ").toLower().split(regex, Qt::SkipEmptyParts);

    m_words.clear();
    foreach( QString word, split)
    {
        if (m_words.indexOf(word) == -1)
            m_words.append(word);
    }

}

QString BaseNode::name() const
{
    return m_name;
}

void BaseNode::setName(const QString &newName)
{
    m_name = newName;
}

QString BaseNode::firstLine()
{
    QString result = m_name;

    if (result == "")
    {
        result = this->metaObject()->className();
    }

    if ( m_text.count() > 0)
    {
        result = m_text[0];
    }

    return result;
}

void BaseNode::toHtml(QStringList &list)
{
    generateHtml(list);

    foreach( BaseNode* child, m_childs)
    {
        child->toHtml(list);
    }
    generateHtmlPost(list);
}

