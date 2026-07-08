#ifndef DOMAIN_BAUSTEIN_H
#define DOMAIN_BAUSTEIN_H

#include "Standard.h"

#include <QString>

struct Baustein {
    int id = 0;
    StandardType standard = StandardType::ITGrundschutz;
    QString externalId;
    QString title;
    QString groupName;
    QString catalogVersion;
};

#endif
