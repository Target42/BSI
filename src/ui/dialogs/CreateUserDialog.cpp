#include "CreateUserDialog.h"

#include <QCheckBox>
#include <QDialogButtonBox>
#include <QFormLayout>
#include <QLabel>
#include <QLineEdit>
#include <QMessageBox>
#include <QVBoxLayout>

CreateUserDialog::CreateUserDialog(QWidget *parent)
    : QDialog(parent)
{
    setWindowTitle(tr("Neuen Benutzer anlegen"));
    resize(460, 280);

    auto *intro = new QLabel(
        tr("Legt einen Server-Benutzer an, der anschließend Projekten zugewiesen werden kann."),
        this);
    intro->setWordWrap(true);

    m_emailEdit = new QLineEdit(this);
    m_emailEdit->setPlaceholderText(QStringLiteral("kollege@example.com"));

    m_displayNameEdit = new QLineEdit(this);
    m_displayNameEdit->setPlaceholderText(tr("Anzeigename"));

    m_passwordEdit = new QLineEdit(this);
    m_passwordEdit->setEchoMode(QLineEdit::Password);

    m_confirmPasswordEdit = new QLineEdit(this);
    m_confirmPasswordEdit->setEchoMode(QLineEdit::Password);

    m_adminBox = new QCheckBox(tr("Server-Administrator"), this);

    auto *form = new QFormLayout;
    form->addRow(tr("E-Mail"), m_emailEdit);
    form->addRow(tr("Anzeigename"), m_displayNameEdit);
    form->addRow(tr("Passwort"), m_passwordEdit);
    form->addRow(tr("Passwort bestätigen"), m_confirmPasswordEdit);
    form->addRow(QString(), m_adminBox);

    m_buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, this);
    connect(m_buttons, &QDialogButtonBox::accepted, this, &CreateUserDialog::tryAccept);
    connect(m_buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);

    auto *layout = new QVBoxLayout(this);
    layout->addWidget(intro);
    layout->addLayout(form);
    layout->addWidget(m_buttons);
}

QString CreateUserDialog::email() const
{
    return m_emailEdit->text().trimmed();
}

QString CreateUserDialog::displayName() const
{
    return m_displayNameEdit->text().trimmed();
}

QString CreateUserDialog::password() const
{
    return m_passwordEdit->text();
}

bool CreateUserDialog::isAdmin() const
{
    return m_adminBox->isChecked();
}

void CreateUserDialog::tryAccept()
{
    if (email().isEmpty() || displayName().isEmpty() || password().isEmpty()) {
        QMessageBox::warning(this, tr("Benutzer"), tr("Bitte alle Felder ausfüllen."));
        return;
    }
    if (password().length() < 8) {
        QMessageBox::warning(this, tr("Benutzer"), tr("Das Passwort muss mindestens 8 Zeichen lang sein."));
        return;
    }
    if (password() != m_confirmPasswordEdit->text()) {
        QMessageBox::warning(this, tr("Benutzer"), tr("Die Passwörter stimmen nicht überein."));
        return;
    }
    accept();
}
