#ifndef UI_DIALOGS_LOGINDIALOG_H
#define UI_DIALOGS_LOGINDIALOG_H

#include "app/AppSettings.h"
#include "net/ApiClient.h"

#include <QDialog>

class QCheckBox;
class QDialogButtonBox;
class QLineEdit;

class LoginDialog : public QDialog
{
    Q_OBJECT

public:
    explicit LoginDialog(AppSettings settings, QWidget *parent = nullptr);

    AppSettings settings() const;
    ApiClient apiClient() const;

private:
    void tryAccept();

    AppSettings m_settings;
    ApiClient m_client;

    QCheckBox *m_remoteBox = nullptr;
    QLineEdit *m_serverEdit = nullptr;
    QLineEdit *m_emailEdit = nullptr;
    QLineEdit *m_passwordEdit = nullptr;
    QDialogButtonBox *m_buttons = nullptr;
};

#endif
