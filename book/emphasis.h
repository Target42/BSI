#ifndef EMPHASIS_H
#define EMPHASIS_H

#include "basenode.h"

class Emphasis : public BaseNode
{
private:
    QString m_attr;
protected:
    virtual void generateHtml(QStringList& list ) override;
    virtual void generateHtmlPost(QStringList& list ) override;

public:
    Emphasis();

    void parse( QDomNode root ) override;
};
extern BaseNode* createEmphasisNode( void );

#endif // EMPHASIS_H
