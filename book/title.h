#ifndef TITLE_H
#define TITLE_H

#include "basenode.h"

class Title : public BaseNode
{
private:
    void countLevel( void );

protected:
    int m_level;
    void generateHtml(QStringList& list ) override;
public:
    Title();

    void parse( QDomNode root ) override;
};

extern BaseNode* createTitleNode( void );

#endif // TITLE_H
