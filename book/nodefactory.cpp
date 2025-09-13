#include "nodefactory.h"

#include "book/emphasis.h"
#include "book/itemlist.h"
#include "book/listitem.h"
#include "book/para.h"
#include "book/section.h"
#include "chapter.h"
#include "info.h"
#include "title.h"


NodeFactory* NodeFactory::p_instance = nullptr;

NodeFactory::NodeFactory()
{
    setup();
}

void NodeFactory::setup()
{
    m_map["chapter"]        = createChapterNode;
    m_map["emphasis"]       = createEmphasisNode;
    m_map["info"]           = createInofNode;
    m_map["para"]           = createParaNode;
    m_map["section"]        =  createSectionNode;
    m_map["itemizedlist"]   = createItemListNode;
    m_map["orderedlist"]    = createItemListNode;
    m_map["listitem"]       = createListItemNode;
    m_map["simpara"]        = nullptr;
    m_map["title"]          = createTitleNode;
    m_map["email"]          = createBaseNode;
    m_map["link"]           = createBaseNode;
    m_map["linebreak"]      = createBaseNode;
    m_map["informaltable"]  = createBaseNode;
    m_map["index"]          = createBaseNode;
}

NodeFactory *NodeFactory::getInstance()
{
    if ( p_instance == nullptr)
    {
        p_instance = new NodeFactory();
    }

    return p_instance;
}

BaseNode *NodeFactory::parse(QDomNode root, BaseNode *parent)
{
    BaseNode* result = nullptr;
    QString name = root.nodeName();

    auto it = m_map.find(name);

    if ( it != m_map.end())
    {
        nodeCreateFkt fkt = it.value();

        if ( fkt != nullptr)
        {
            result = fkt();
            result->setParent(parent);
            result->parse(root);
        }
    }
    else
    {
        assert(name != "");
    }

    return result;
}
