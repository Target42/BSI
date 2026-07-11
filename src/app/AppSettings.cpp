#include "AppSettings.h"

#include <QSettings>
#include <QTimeZone>

namespace {

constexpr int kExpirySkewSeconds = 60;

QDateTime parseDateTimeSetting(const QVariant &value)
{
    const QDateTime parsed = QDateTime::fromString(value.toString(), Qt::ISODate);
    if (!parsed.isValid())
        return {};
    QDateTime utc = parsed;
    utc.setTimeZone(QTimeZone::utc());
    return utc;
}

} // namespace

AppSettings AppSettings::load()
{
    QSettings settings;
    AppSettings appSettings;
    appSettings.setUseRemote(settings.value(QStringLiteral("server/useRemote"), false).toBool());
    appSettings.setServerUrl(settings.value(QStringLiteral("server/url"),
                                             QStringLiteral("http://localhost:8080")).toString());
    appSettings.setAccessToken(settings.value(QStringLiteral("server/accessToken")).toString());
    appSettings.setTokenExpiresAt(
        parseDateTimeSetting(settings.value(QStringLiteral("server/tokenExpiresAt"))));
    appSettings.setUserEmail(settings.value(QStringLiteral("server/userEmail")).toString());
    appSettings.setInsecureSkipTlsVerify(
        settings.value(QStringLiteral("server/insecureSkipTlsVerify"), false).toBool());
    return appSettings;
}

void AppSettings::save() const
{
    QSettings settings;
    settings.setValue(QStringLiteral("server/useRemote"), m_useRemote);
    settings.setValue(QStringLiteral("server/url"), m_serverUrl);
    settings.setValue(QStringLiteral("server/accessToken"), m_accessToken);
    if (m_tokenExpiresAt.isValid())
        settings.setValue(QStringLiteral("server/tokenExpiresAt"),
                          m_tokenExpiresAt.toUTC().toString(Qt::ISODate));
    else
        settings.remove(QStringLiteral("server/tokenExpiresAt"));
    settings.setValue(QStringLiteral("server/userEmail"), m_userEmail);
    settings.setValue(QStringLiteral("server/insecureSkipTlsVerify"), m_insecureSkipTlsVerify);
}

bool AppSettings::isTokenExpired() const
{
    if (m_accessToken.isEmpty())
        return true;
    if (!m_tokenExpiresAt.isValid())
        return false;
    return QDateTime::currentDateTimeUtc().secsTo(m_tokenExpiresAt) <= kExpirySkewSeconds;
}

bool AppSettings::hasStoredRemoteSession() const
{
    return m_useRemote && !m_serverUrl.isEmpty() && !m_accessToken.isEmpty();
}
