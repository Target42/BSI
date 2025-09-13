#ifndef WORDINDEX_H
#define WORDINDEX_H

#include <QList>
#include <QMap>

class BaseNode;

class WordIndex
{
public:    
    WordIndex();

    void run( BaseNode* node);
    
    QList<BaseNode*>* search(QString text, bool regex);

    void copy(QList<BaseNode *>* src, QList<BaseNode *>* dest );

private:

    QMap<QString, QList<BaseNode*>*> m_words;

    void addNode( BaseNode* node);
};

#endif // WORDINDEX_H
