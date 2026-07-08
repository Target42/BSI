#ifndef DOMAIN_REQUIREMENT_H
#define DOMAIN_REQUIREMENT_H

#include "RequirementLevel.h"
#include "Standard.h"

#include <QString>

struct Requirement {
    int id = 0;
    int bausteinDbId = 0;
    StandardType standard = StandardType::ITGrundschutz;
    QString externalId;
    QString bausteinExternalId;
    QString title;
    QString text;
    RequirementLevel level = RequirementLevel::Unknown;
    QString responsibleRole;
    bool withdrawn = false;
};

#endif
