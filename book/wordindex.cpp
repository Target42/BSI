#include "wordindex.h"

#include "book/basenode.h"
#include <QRegularExpression>

WordIndex::WordIndex()
{

}

void WordIndex::run(BaseNode *node)
{
    if ( m_words.count() == 0)
    {
        addNode(node);
    }
}

QList<BaseNode *>* WordIndex::search(QString text, bool regex)
{
    QList<BaseNode *>* result = new QList<BaseNode *>;    

    if ( regex == false )
    {
        text = text.toLower();

        QStringList words = text.split(" ", Qt::SkipEmptyParts);
        int wordCount = words.count();
        if ( wordCount == 1 )
        {
            auto it = m_words.find(text);

            if ( it != m_words.end())
            {
                copy( it.value(), result);
            }
        }
        else
        {
            QHash<BaseNode*, int> map;

            foreach (QString word, words)
            {
                auto it = m_words.find(word);

                if ( it != m_words.end())
                {
                    foreach (BaseNode* node, *it.value())
                    {
                        if (map.contains(node) == true )
                        {
                            map[node]++;
                        }
                        else
                        {
                            map.insert(node, 1);
                        }
                    }
                }
            }
            QHashIterator<BaseNode*, int> it(map);


            while(it.hasNext() == true)
            {
                it.next();

                if ( it.value() == wordCount)
                {
                    result->append(it.key());
                }
            }
        }
    }
    else
    {
        QRegularExpression regex(text, QRegularExpression::CaseInsensitiveOption);

        QMapIterator<QString, QList<BaseNode*>*>  i(m_words);

        while (i.hasNext() == true)
        {
            i.next();
            if (regex.match(i.key()).hasMatch()== true)
            {
                copy( i.value(), result);
            }
        }
    }

    return result;
}

void WordIndex::copy(QList<BaseNode *> *src, QList<BaseNode *> *dest)
{
    foreach( BaseNode* node, *src)
    {
        dest->append(node);
    }

}

void WordIndex::addNode(BaseNode *node)
{
    foreach(QString word, node->words())
    {
        auto it = m_words.find(word);
        if ( it == m_words.end())
        {
            QList<BaseNode*>* list = new QList<BaseNode*>;
            list->append(node);

            m_words[word] = list;

        }
        else
        {
            QList<BaseNode*>* list = it.value();

            if ( list->contains(node) == false)
            {
                list->append(node);
            }
        }
    }
    foreach (BaseNode* child, node->childs())
    {
        addNode(child);
    }
}
