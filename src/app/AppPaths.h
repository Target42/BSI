#ifndef APP_APPPATHS_H
#define APP_APPPATHS_H

#include <QDir>
#include <QString>

class AppPaths
{
public:
    static QString dataDirectory();
    static QString databaseFile();
    static QString defaultGrundschutzXml();
};

#endif
