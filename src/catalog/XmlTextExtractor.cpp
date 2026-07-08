#include "XmlTextExtractor.h"

#include <QDomElement>

QString XmlTextExtractor::elementTitle(const QDomNode &node)
{
    if (node.isNull())
        return {};

    const QString nodeName = node.nodeName();
    if (nodeName != QStringLiteral("section") && nodeName != QStringLiteral("chapter"))
        return {};

    const QDomNodeList children = node.childNodes();
    for (int i = 0; i < children.count(); ++i) {
        const QDomNode child = children.at(i);
        if (child.nodeName() == QStringLiteral("title"))
            return child.toElement().text().trimmed();
    }
    return {};
}

QString XmlTextExtractor::sectionTitle(const QDomNode &sectionNode)
{
    return elementTitle(sectionNode);
}

QString XmlTextExtractor::collectText(const QDomNode &node)
{
    if (node.isNull())
        return {};

    if (node.isText())
        return node.nodeValue().simplified();

    if (node.nodeName() == QStringLiteral("linebreak"))
        return QStringLiteral("\n");

    QString result;
    const QDomNodeList children = node.childNodes();
    for (int i = 0; i < children.count(); ++i) {
        const QString part = collectText(children.at(i));
        if (part.isEmpty())
            continue;

        if (!result.isEmpty() && !part.startsWith('\n') && !result.endsWith('\n'))
            result += QChar(' ');
        result += part;
    }
    return result.simplified();
}

QStringList XmlTextExtractor::collectParagraphs(const QDomNode &node)
{
    QStringList paragraphs;

    if (node.isNull())
        return paragraphs;

    if (node.nodeName() == QStringLiteral("para")) {
        const QString text = collectText(node);
        if (!text.isEmpty())
            paragraphs.append(text);
        return paragraphs;
    }

    const QDomNodeList children = node.childNodes();
    for (int i = 0; i < children.count(); ++i) {
        paragraphs.append(collectParagraphs(children.at(i)));
    }
    return paragraphs;
}
