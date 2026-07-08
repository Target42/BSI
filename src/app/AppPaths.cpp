#include "AppPaths.h"

#include <QDir>
#include <QStandardPaths>

QString AppPaths::dataDirectory()
{
    const QString path = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (path.isEmpty())
        return path;

    QDir dir(path);
    if (!dir.exists() && !dir.mkpath(QStringLiteral(".")))
        return {};

    return path;
}

QString AppPaths::databaseFile()
{
    return QDir(AppPaths::dataDirectory()).filePath(QStringLiteral("isms.db"));
}

QString AppPaths::defaultGrundschutzXml()
{
    return QDir::cleanPath(QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation)
                           + QDir::separator() + QStringLiteral("XML_Kompendium_2023.xml"));
}
