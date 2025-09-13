#ifndef CHAPTER_H
#define CHAPTER_H

#include <QString>
#include <QDomElement>
#include <QList>

#include "basenode.h"

class Para;
class Section;


class Chapter : public BaseNode
{
private:
    QString m_id;
public:
    Chapter();

    void parse( QDomNode root ) override;

    QString getTitle( void ) override;
    QString getID( void ) override;

};

extern BaseNode* createChapterNode( void );

#endif // CHAPTER_H
