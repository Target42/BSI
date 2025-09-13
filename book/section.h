#ifndef SECTION_H
#define SECTION_H

#include <QDomElement>
#include <QList>

#include "basenode.h"

class Section : public BaseNode
{
private:
    QString m_id;
public:
    Section();

    void parse( QDomNode root ) override;

    QString getTitle( void ) override;
    QString getID( void ) override;


};

extern BaseNode* createSectionNode( void );

#endif // SECTION_H
