#ifndef APP_APPSETTINGS_H
#define APP_APPSETTINGS_H

#include <QString>

class AppSettings
{
public:
    static AppSettings load();
    void save() const;

    bool useRemote() const { return m_useRemote; }
    void setUseRemote(bool value) { m_useRemote = value; }

    QString serverUrl() const { return m_serverUrl; }
    void setServerUrl(const QString &value) { m_serverUrl = value; }

    QString accessToken() const { return m_accessToken; }
    void setAccessToken(const QString &value) { m_accessToken = value; }

    QString userEmail() const { return m_userEmail; }
    void setUserEmail(const QString &value) { m_userEmail = value; }

private:
    bool m_useRemote = false;
    QString m_serverUrl = QStringLiteral("http://localhost:8080");
    QString m_accessToken;
    QString m_userEmail;
};

#endif
