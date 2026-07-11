#ifndef UI_DIALOGS_LOGINDIALOG_H
#define UI_DIALOGS_LOGINDIALOG_H

#include "app/AppSettings.h"
#include "net/ApiClient.h"

#include <QDialog>

class QCheckBox;
class QDialogButtonBox;
class QLabel;
class QLineEdit;

class LoginDialog : public QDialog
{
    Q_OBJECT

public:
    explicit LoginDialog(AppSettings settings, QWidget *parent = nullptr);

    void setReloginMode(bool reloginMode);

    bool trySilentLogin();
    AppSettings settings() const;
    ApiClient apiClient() const;

private:
    void updateTlsOptionVisibility();
    void tryAccept();

    AppSettings m_settings;
    ApiClient m_client;
    bool m_reloginMode = false;

    QLabel *m_introLabel = nullptr;
    QCheckBox *m_remoteBox = nullptr;
    QCheckBox *m_insecureTlsBox = nullptr;
    QLineEdit *m_serverEdit = nullptr;
    QLineEdit *m_emailEdit = nullptr;
    QLineEdit *m_passwordEdit = nullptr;
    QDialogButtonBox *m_buttons = nullptr;
};

#endif
