#include "indexnode.h"
#include "book/basenode.h"

IndexNode::IndexNode(QObject *parent)
    : QObject{parent}
{
    m_parent = nullptr;
    m_node   = nullptr;
}

void IndexNode::addChild(IndexNode *node)
{
    node->setParent(this);
    m_childs.append(node);
}

IndexNode *IndexNode::parent() const
{
    return m_parent;
}

void IndexNode::setParent(IndexNode *newParent)
{
    m_parent = newParent;
}

QString IndexNode::title() const
{
    return m_title;
}

void IndexNode::setTitle(const QString &newTitle)
{
    m_title = newTitle;
}

QString IndexNode::id() const
{
    return m_id;
}

void IndexNode::setId(const QString &newId)
{
    m_id = newId;
}

BaseNode *IndexNode::node() const
{
    return m_node;
}

void IndexNode::setNode(BaseNode *newNode)
{
    m_node = newNode;
    if ( newNode != nullptr)
    {
        m_id   = m_node->getID();
        m_title= m_node->getTitle();
    }
}

bool IndexNode::hasNode(BaseNode *node)
{
    bool result = (node == m_node);

    if ((result == false ) || ( m_node != nullptr))
    {
        result = m_node->findChild(node);
    }

    return result;
}

IndexNode *IndexNode::findIndex(BaseNode *node)
{
    IndexNode * result = nullptr;

    if ( m_node != nullptr )
    {
        if (m_node->findChild(node) != nullptr)
        {
            result = this;
        }
        foreach( IndexNode* child, m_childs)
        {
            IndexNode* val = nullptr;

            val = child->findIndex(node);
            if ( val != nullptr)
            {
                result = val;
            }
        }
    }

    return result;
}
