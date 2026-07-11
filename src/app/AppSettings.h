#ifndef APP_APPSETTINGS_H
#define APP_APPSETTINGS_H

#include <QDateTime>
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

    QDateTime tokenExpiresAt() const { return m_tokenExpiresAt; }
    void setTokenExpiresAt(const QDateTime &value) { m_tokenExpiresAt = value; }

    QString userEmail() const { return m_userEmail; }
    void setUserEmail(const QString &value) { m_userEmail = value; }

    bool insecureSkipTlsVerify() const { return m_insecureSkipTlsVerify; }
    void setInsecureSkipTlsVerify(bool value) { m_insecureSkipTlsVerify = value; }

    bool isTokenExpired() const;
    bool hasStoredRemoteSession() const;

private:
    bool m_useRemote = false;
    QString m_serverUrl = QStringLiteral("http://localhost:8080");
    QString m_accessToken;
    QDateTime m_tokenExpiresAt;
    QString m_userEmail;
    bool m_insecureSkipTlsVerify = false;
};

#endif
