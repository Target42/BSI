#ifndef INFO_H
#define INFO_H

#include "basenode.h"

class Info : public BaseNode
{
public:
    Info();

    void parse( QDomNode root ) override;
};
extern BaseNode* createInofNode( void );

#endif // INFO_H
