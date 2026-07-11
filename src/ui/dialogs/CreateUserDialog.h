#ifndef UI_CREATEUSERDIALOG_H
#define UI_CREATEUSERDIALOG_H

#include <QDialog>

class QCheckBox;
class QDialogButtonBox;
class QLineEdit;

class CreateUserDialog : public QDialog
{
    Q_OBJECT

public:
    explicit CreateUserDialog(QWidget *parent = nullptr);

    QString email() const;
    QString displayName() const;
    QString password() const;
    bool isAdmin() const;

private slots:
    void tryAccept();

private:
    QLineEdit *m_emailEdit = nullptr;
    QLineEdit *m_displayNameEdit = nullptr;
    QLineEdit *m_passwordEdit = nullptr;
    QLineEdit *m_confirmPasswordEdit = nullptr;
    QCheckBox *m_adminBox = nullptr;
    QDialogButtonBox *m_buttons = nullptr;
};

#endif
