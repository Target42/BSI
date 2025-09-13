#ifndef NODEFACTORY_H
#define NODEFACTORY_H

#include <QDomElement>
#include <QMap>

#include "basenode.h"

class NodeFactory
{
private:
    static NodeFactory* p_instance;
    QMap<QString,  nodeCreateFkt> m_map;

    NodeFactory();

    void setup( void );

public:
    static NodeFactory* getInstance( void );

    BaseNode* parse( QDomNode root, BaseNode* parent );
};

#endif // NODEFACTORY_H
