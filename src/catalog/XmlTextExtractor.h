#ifndef CATALOG_XMLTEXTEXTRACTOR_H
#define CATALOG_XMLTEXTEXTRACTOR_H

#include <QDomNode>
#include <QString>
#include <QStringList>

class XmlTextExtractor
{
public:
    static QString elementTitle(const QDomNode &node);
    static QString sectionTitle(const QDomNode &sectionNode);
    static QString collectText(const QDomNode &node);
    static QStringList collectParagraphs(const QDomNode &node);
};

#endif
