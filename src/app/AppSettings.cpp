#include "AppSettings.h"

#include <QSettings>

AppSettings AppSettings::load()
{
    QSettings settings;
    AppSettings appSettings;
    appSettings.setUseRemote(settings.value(QStringLiteral("server/useRemote"), false).toBool());
    appSettings.setServerUrl(settings.value(QStringLiteral("server/url"),
                                             QStringLiteral("http://localhost:8080")).toString());
    appSettings.setAccessToken(settings.value(QStringLiteral("server/accessToken")).toString());
    appSettings.setUserEmail(settings.value(QStringLiteral("server/userEmail")).toString());
    return appSettings;
}

void AppSettings::save() const
{
    QSettings settings;
    settings.setValue(QStringLiteral("server/useRemote"), m_useRemote);
    settings.setValue(QStringLiteral("server/url"), m_serverUrl);
    settings.setValue(QStringLiteral("server/accessToken"), m_accessToken);
    settings.setValue(QStringLiteral("server/userEmail"), m_userEmail);
}
