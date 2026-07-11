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
    resize(480, 300);

    m_introLabel = new QLabel(
        tr("Lokal arbeiten oder mit dem ISMS-Server verbinden (Team-Modus)."), this);
    m_introLabel->setWordWrap(true);

    m_remoteBox = new QCheckBox(tr("Mit Server verbinden"), this);
    m_remoteBox->setChecked(m_settings.useRemote());

    m_serverEdit = new QLineEdit(m_settings.serverUrl(), this);
    m_serverEdit->setPlaceholderText(QStringLiteral("https://localhost:8443"));

    m_emailEdit = new QLineEdit(m_settings.userEmail(), this);
    m_emailEdit->setPlaceholderText(QStringLiteral("admin@example.com"));

    m_passwordEdit = new QLineEdit(this);
    m_passwordEdit->setEchoMode(QLineEdit::Password);

    m_insecureTlsBox =
        new QCheckBox(tr("Self-signed TLS-Zertifikat akzeptieren (nur Entwicklung)"), this);
    m_insecureTlsBox->setChecked(m_settings.insecureSkipTlsVerify());

    auto *form = new QFormLayout;
    form->addRow(tr("Server-URL"), m_serverEdit);
    form->addRow(tr("E-Mail"), m_emailEdit);
    form->addRow(tr("Passwort"), m_passwordEdit);
    form->addRow(QString(), m_insecureTlsBox);

    m_buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, this);
    connect(m_buttons, &QDialogButtonBox::accepted, this, &LoginDialog::tryAccept);
    connect(m_buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);
    connect(m_remoteBox, &QCheckBox::toggled, this, [this](bool remote) {
        m_serverEdit->setEnabled(remote);
        m_emailEdit->setEnabled(remote);
        m_passwordEdit->setEnabled(remote);
        updateTlsOptionVisibility();
    });
    connect(m_serverEdit, &QLineEdit::textChanged, this, [this](const QString &) {
        updateTlsOptionVisibility();
    });

    m_serverEdit->setEnabled(m_remoteBox->isChecked());
    m_emailEdit->setEnabled(m_remoteBox->isChecked());
    m_passwordEdit->setEnabled(m_remoteBox->isChecked());
    updateTlsOptionVisibility();

    auto *layout = new QVBoxLayout(this);
    layout->addWidget(m_introLabel);
    layout->addWidget(m_remoteBox);
    layout->addLayout(form);
    layout->addWidget(m_buttons);
}

void LoginDialog::setReloginMode(bool reloginMode)
{
    m_reloginMode = reloginMode;
    if (!m_reloginMode)
        return;

    setWindowTitle(tr("ISMS – Erneut anmelden"));
    m_introLabel->setText(tr("Ihre Sitzung ist abgelaufen. Bitte melden Sie sich erneut an."));
    m_remoteBox->setChecked(true);
    m_remoteBox->setEnabled(false);
    m_serverEdit->setEnabled(false);
    m_emailEdit->setEnabled(true);
    m_passwordEdit->setFocus();
    updateTlsOptionVisibility();
}

void LoginDialog::setSwitchUserMode(bool switchUserMode)
{
    m_switchUserMode = switchUserMode;
    if (!m_switchUserMode)
        return;

    setWindowTitle(tr("ISMS – Abmelden / Benutzer wechseln"));
    m_introLabel->setText(
        tr("Melden Sie sich erneut an, wechseln Sie den Benutzer oder arbeiten Sie lokal ohne Server."));
    m_passwordEdit->clear();
    m_passwordEdit->setFocus();
}

bool LoginDialog::trySilentLogin()
{
    if (!m_settings.hasStoredRemoteSession() || m_settings.isTokenExpired())
        return false;

    m_client.setBaseUrl(m_settings.serverUrl());
    m_client.setAccessToken(m_settings.accessToken());
    m_client.setTokenExpiresAt(m_settings.tokenExpiresAt());
    m_client.setInsecureSkipTlsVerify(m_settings.insecureSkipTlsVerify());

    QString error;
    if (!m_client.validateSession(&error))
        return false;

    accept();
    return true;
}

AppSettings LoginDialog::settings() const
{
    return m_settings;
}

ApiClient LoginDialog::apiClient() const
{
    return m_client;
}

void LoginDialog::updateTlsOptionVisibility()
{
    const bool https = m_serverEdit->text().trimmed().startsWith(QStringLiteral("https://"),
                                                                   Qt::CaseInsensitive);
    m_insecureTlsBox->setVisible(https && (m_remoteBox->isChecked() || m_reloginMode));
}

void LoginDialog::tryAccept()
{
    m_settings.setUseRemote(m_reloginMode || m_remoteBox->isChecked());
    m_settings.setServerUrl(m_serverEdit->text().trimmed());
    m_settings.setUserEmail(m_emailEdit->text().trimmed());
    m_settings.setInsecureSkipTlsVerify(m_insecureTlsBox->isChecked());

    if (!m_settings.useRemote()) {
        m_settings.setAccessToken({});
        m_settings.setTokenExpiresAt({});
        accept();
        return;
    }

    if (m_settings.serverUrl().isEmpty() || m_settings.userEmail().isEmpty()
        || m_passwordEdit->text().isEmpty()) {
        QMessageBox::warning(this, tr("Verbindung"), tr("Bitte Server, E-Mail und Passwort angeben."));
        return;
    }

    m_client.setBaseUrl(m_settings.serverUrl());
    m_client.setInsecureSkipTlsVerify(m_settings.insecureSkipTlsVerify());
    QString error;
    if (!m_client.login(m_settings.userEmail(), m_passwordEdit->text(), &error)) {
        QMessageBox::critical(this, tr("Login fehlgeschlagen"), error);
        return;
    }

    m_settings.setAccessToken(m_client.accessToken());
    m_settings.setTokenExpiresAt(m_client.tokenExpiresAt());
    accept();
}
