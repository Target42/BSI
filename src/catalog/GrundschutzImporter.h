#ifndef CATALOG_GRUNDSCHUTZIMPORTER_H
#define CATALOG_GRUNDSCHUTZIMPORTER_H

#include "domain/Baustein.h"
#include "domain/Requirement.h"
#include "domain/RequirementLevel.h"

#include <QDomNode>
#include <QList>
#include <QString>

struct GrundschutzImportResult {
    QString catalogVersion;
    QList<Baustein> bausteine;
    QList<Requirement> requirements;
    QString errorMessage;
    bool success = false;
};

class GrundschutzImporter
{
public:
    GrundschutzImportResult importFromFile(const QString &filePath) const;

private:
    void walkNode(const QDomNode &node,
                  const QString &groupName,
                  int currentBausteinIndex,
                  RequirementLevel currentLevel,
                  GrundschutzImportResult &result) const;

    bool tryParseBaustein(const QString &title, const QString &groupName, Baustein &baustein) const;
    bool tryParseRequirement(const QString &title,
                             const Baustein &baustein,
                             RequirementLevel level,
                             const QDomNode &sectionNode,
                             Requirement &requirement) const;
};

#endif
