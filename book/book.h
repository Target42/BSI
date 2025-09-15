#ifndef BOOK_H
#define BOOK_H

#include <QDomDocument>
#include <QString>
#include <QList>
#include "basenode.h"

class Chapter;

class Book : public BaseNode
{
private:    
public:
    Book();

    bool load( QString fileName );

    void parse( QDomNode root ) override;    
};

#endif // BOOK_H
