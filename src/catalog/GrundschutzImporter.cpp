#include "GrundschutzImporter.h"
#include "XmlTextExtractor.h"

#include <QDomDocument>
#include <QFile>
#include <QRegularExpression>

namespace {

const QRegularExpression bausteinTitlePattern(
    QStringLiteral("^(?<id>[A-Z]{2,4}(?:\\.\\d+)+)\\s+(?<title>.+)$"));

const QRegularExpression requirementTitlePattern(
    QStringLiteral("^(?<id>[A-Z]{2,4}(?:\\.\\d+)+\\.A\\d+)\\s+(?<title>.+)$"));

const QRegularExpression levelMarkerPattern(QStringLiteral("\\(([BSH])\\)"));
const QRegularExpression rolePattern(QStringLiteral("\\[(?<role>[^\\]]+)\\]"));

QString stripMarkup(const QString &text)
{
    QString cleaned = text;
    cleaned.replace(QRegularExpression(QStringLiteral("<[^>]+>")), QString());
    return cleaned.simplified();
}

} // namespace

GrundschutzImportResult GrundschutzImporter::importFromFile(const QString &filePath) const
{
    GrundschutzImportResult result;
    result.catalogVersion = QStringLiteral("2023");

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        result.errorMessage = QStringLiteral("Datei konnte nicht geöffnet werden: %1").arg(filePath);
        return result;
    }

    QDomDocument doc;
    const QDomDocument::ParseResult parseResult = doc.setContent(&file);
    if (!parseResult) {
        result.errorMessage = QStringLiteral("XML-Fehler in %1:%2 (%3)")
                                  .arg(parseResult.errorLine)
                                  .arg(parseResult.errorColumn)
                                  .arg(parseResult.errorMessage);
        return result;
    }

    if (doc.documentElement().nodeName() != QStringLiteral("book")) {
        result.errorMessage = QStringLiteral("Unerwartete Wurzel: %1").arg(doc.documentElement().nodeName());
        return result;
    }

    walkNode(doc.documentElement(), {}, -1, RequirementLevel::Unknown, result);
    result.success = result.errorMessage.isEmpty();
    return result;
}

void GrundschutzImporter::walkNode(const QDomNode &node,
                                   const QString &groupName,
                                   int currentBausteinIndex,
                                   RequirementLevel currentLevel,
                                   GrundschutzImportResult &result) const
{
    if (node.isNull())
        return;

    QString activeGroup = groupName;
    int activeBausteinIndex = currentBausteinIndex;
    RequirementLevel activeLevel = currentLevel;

    if (node.nodeName() == QStringLiteral("chapter")) {
        const QString chapterTitle = XmlTextExtractor::elementTitle(node);
        if (!chapterTitle.isEmpty())
            activeGroup = chapterTitle;
    }

    if (node.nodeName() == QStringLiteral("section")) {
        const QString title = XmlTextExtractor::sectionTitle(node);

        Baustein parsedBaustein;
        if (tryParseBaustein(title, activeGroup, parsedBaustein)) {
            result.bausteine.append(parsedBaustein);
            activeBausteinIndex = result.bausteine.size() - 1;
            activeLevel = RequirementLevel::Unknown;
        } else if (title == QStringLiteral("Anforderungen")) {
            activeLevel = RequirementLevel::Unknown;
        } else {
            const RequirementLevel sectionLevel = requirementLevelFromSectionTitle(title);
            if (sectionLevel != RequirementLevel::Unknown)
                activeLevel = sectionLevel;

            Requirement parsedRequirement;
            if (activeBausteinIndex >= 0
                && tryParseRequirement(title,
                                       result.bausteine.at(activeBausteinIndex),
                                       activeLevel,
                                       node,
                                       parsedRequirement)) {
                result.requirements.append(parsedRequirement);
            }
        }
    }

    const QDomNodeList children = node.childNodes();
    for (int i = 0; i < children.count(); ++i) {
        walkNode(children.at(i), activeGroup, activeBausteinIndex, activeLevel, result);
    }
}

bool GrundschutzImporter::tryParseBaustein(const QString &title,
                                           const QString &groupName,
                                           Baustein &baustein) const
{
    if (requirementTitlePattern.match(title).hasMatch())
        return false;

    const QRegularExpressionMatch match = bausteinTitlePattern.match(title);
    if (!match.hasMatch())
        return false;

    baustein = {};
    baustein.standard = StandardType::ITGrundschutz;
    baustein.externalId = match.captured(QStringLiteral("id"));
    baustein.title = match.captured(QStringLiteral("title")).trimmed();
    baustein.groupName = groupName;
    baustein.catalogVersion = QStringLiteral("2023");
    return true;
}

bool GrundschutzImporter::tryParseRequirement(const QString &title,
                                             const Baustein &baustein,
                                             RequirementLevel level,
                                             const QDomNode &sectionNode,
                                             Requirement &requirement) const
{
    const QRegularExpressionMatch match = requirementTitlePattern.match(title);
    if (!match.hasMatch())
        return false;

    requirement = {};
    requirement.standard = StandardType::ITGrundschutz;
    requirement.externalId = match.captured(QStringLiteral("id"));
    requirement.bausteinExternalId = baustein.externalId;
    requirement.title = match.captured(QStringLiteral("title")).trimmed();
    requirement.text = stripMarkup(XmlTextExtractor::collectParagraphs(sectionNode).join(QStringLiteral("\n\n")));
    requirement.withdrawn = requirement.title.startsWith(QStringLiteral("ENTFALLEN"), Qt::CaseInsensitive);

    const QRegularExpressionMatch levelMatch = levelMarkerPattern.match(title);
    if (levelMatch.hasMatch())
        requirement.level = requirementLevelFromMarker(levelMatch.captured(1).at(0));
    else
        requirement.level = level;

    const QRegularExpressionMatch roleMatch = rolePattern.match(title);
    if (roleMatch.hasMatch())
        requirement.responsibleRole = roleMatch.captured(QStringLiteral("role")).trimmed();

    return true;
}
