#ifndef PARA_H
#define PARA_H

#include "book/basenode.h"

#include <QDomElement>
#include <QStringList>

class Para : public BaseNode
{
protected:
    void generateHtml(QStringList& list ) override;
    void generateHtmlPost(QStringList& list ) override;

public:
    Para();

    void parse( QDomNode root ) override;
};

extern BaseNode* createParaNode( void );

#endif // PARA_H
