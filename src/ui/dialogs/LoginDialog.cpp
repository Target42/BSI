#include "LoginDialog.h"

#include <QCheckBox>
#include <QDialogButtonBox>
#include <QFormLayout>
#include <QLabel>
#include <QLineEdit>
#include <QMessageBox>
#include <QVBoxLayout>

LoginDialog::LoginDialog(AppSettings settings, QWidget *parent)
    : QDialog(parent)
    , m_settings(std::move(settings))
    , m_client(m_settings.serverUrl())
{
    setWindowTitle(tr("ISMS – Verbindung"));
    resize(460, 260);

    auto *intro = new QLabel(
        tr("Lokal arbeiten oder mit dem ISMS-Server verbinden (Team-Modus)."), this);
    intro->setWordWrap(true);

    m_remoteBox = new QCheckBox(tr("Mit Server verbinden"), this);
    m_remoteBox->setChecked(m_settings.useRemote());

    m_serverEdit = new QLineEdit(m_settings.serverUrl(), this);
    m_serverEdit->setPlaceholderText(QStringLiteral("http://localhost:8080"));

    m_emailEdit = new QLineEdit(m_settings.userEmail(), this);
    m_emailEdit->setPlaceholderText(QStringLiteral("admin@example.com"));

    m_passwordEdit = new QLineEdit(this);
    m_passwordEdit->setEchoMode(QLineEdit::Password);

    auto *form = new QFormLayout;
    form->addRow(tr("Server-URL"), m_serverEdit);
    form->addRow(tr("E-Mail"), m_emailEdit);
    form->addRow(tr("Passwort"), m_passwordEdit);

    m_buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, this);
    connect(m_buttons, &QDialogButtonBox::accepted, this, &LoginDialog::tryAccept);
    connect(m_buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);
    connect(m_remoteBox, &QCheckBox::toggled, this, [this](bool remote) {
        m_serverEdit->setEnabled(remote);
        m_emailEdit->setEnabled(remote);
        m_passwordEdit->setEnabled(remote);
    });
    m_serverEdit->setEnabled(m_remoteBox->isChecked());
    m_emailEdit->setEnabled(m_remoteBox->isChecked());
    m_passwordEdit->setEnabled(m_remoteBox->isChecked());

    auto *layout = new QVBoxLayout(this);
    layout->addWidget(intro);
    layout->addWidget(m_remoteBox);
    layout->addLayout(form);
    layout->addWidget(m_buttons);
}

AppSettings LoginDialog::settings() const
{
    return m_settings;
}

ApiClient LoginDialog::apiClient() const
{
    return m_client;
}

void LoginDialog::tryAccept()
{
    m_settings.setUseRemote(m_remoteBox->isChecked());
    m_settings.setServerUrl(m_serverEdit->text().trimmed());
    m_settings.setUserEmail(m_emailEdit->text().trimmed());

    if (!m_settings.useRemote()) {
        m_settings.setAccessToken({});
        accept();
        return;
    }

    if (m_settings.serverUrl().isEmpty() || m_settings.userEmail().isEmpty()
        || m_passwordEdit->text().isEmpty()) {
        QMessageBox::warning(this, tr("Verbindung"), tr("Bitte Server, E-Mail und Passwort angeben."));
        return;
    }

    m_client.setBaseUrl(m_settings.serverUrl());
    QString error;
    if (!m_client.login(m_settings.userEmail(), m_passwordEdit->text(), &error)) {
        QMessageBox::critical(this, tr("Login fehlgeschlagen"), error);
        return;
    }

    m_settings.setAccessToken(m_client.accessToken());
    accept();
}
