#ifndef BASENODE_H
#define BASENODE_H


#include <QObject>
#include <QDomElement>
#include <QList>
#include <QStringList>


class BaseNode : public QObject
{
    Q_OBJECT
public:
  typedef
        enum {tsUndefined = 0, tsIgnore = 1, tsNeeded = 2, tsPosible = 3}
    tTemplateState;

private:
    tTemplateState m_templateState;

    void parseLink( QDomNode root );
    void parseEMail(QDomNode root);
    void parseTable(QDomNode root);

    void replaceMarks( void );

protected:
    BaseNode*           m_parent;
    QString             m_name;
    QStringList         m_text;
    QList<BaseNode*>    m_childs;
    QStringList         m_words;

    virtual void generateHtml(QStringList& list );
    virtual void generateHtmlPost(QStringList& list );

    void buildWordList( void );

public:
    BaseNode();

    static QString templateStateToText( tTemplateState state );
    static tTemplateState TestToTemplateState( QString text );

    QString text();

    void addChild( BaseNode* child );

    const QList<BaseNode*> childs( void ) { return m_childs;}
    const QStringList words( void ) { return m_words; }

    virtual void parse( QDomNode root );

    QString name() const;
    void setName(const QString &newName);

    QString firstLine ( void );

    void toHtml( QStringList& list );

    BaseNode *parent() const;
    void setParent(BaseNode *newParent);

    virtual QString getTitle( void );
    virtual QString getID( void );

    int childCount( void );

    BaseNode* findChild( BaseNode* node );

    void fillWordList( QStringList& list );
    tTemplateState templateState() const;
    void setTemplateState(tTemplateState newTemplateState);
};

typedef BaseNode* (*nodeCreateFkt)( void );

extern BaseNode* createBaseNode( void );

#endif // BASENODE_H
