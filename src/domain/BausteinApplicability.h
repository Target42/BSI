#ifndef DOMAIN_BAUSTEINAPPLICABILITY_H
#define DOMAIN_BAUSTEINAPPLICABILITY_H

#include "ApplicabilityStatus.h"

struct BausteinApplicability {
    int id = 0;
    int projectId = 0;
    int targetObjectId = 0;
    int bausteinDbId = 0;
    ApplicabilityStatus status = ApplicabilityStatus::Undefined;
};

#endif
