#ifndef DOMAIN_STANDARD_H
#define DOMAIN_STANDARD_H

#include <QString>

enum class StandardType {
    ITGrundschutz,
    ISO27001
};

inline QString standardTypeToString(StandardType type)
{
    switch (type) {
    case StandardType::ITGrundschutz:
        return QStringLiteral("IT-Grundschutz");
    case StandardType::ISO27001:
        return QStringLiteral("ISO 27001");
    }
    return QStringLiteral("Unbekannt");
}

inline StandardType standardTypeFromString(const QString &value)
{
    if (value == QStringLiteral("ISO 27001") || value == QStringLiteral("ISO27001"))
        return StandardType::ISO27001;
    return StandardType::ITGrundschutz;
}

#endif
