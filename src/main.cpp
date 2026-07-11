#include "app/AppContext.h"
#include "app/AppPaths.h"
#include "app/AppSettings.h"
#include "ui/MainWindow.h"
#include "ui/dialogs/LoginDialog.h"

#include <QApplication>
#include <QMessageBox>

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    QApplication::setApplicationName(QStringLiteral("ISMS"));
    QApplication::setOrganizationName(QStringLiteral("BSI-Tools"));

    AppSettings settings = AppSettings::load();
    LoginDialog loginDialog(settings);
    if (loginDialog.exec() != QDialog::Accepted)
        return 0;

    settings = loginDialog.settings();
    settings.save();

    AppContext context;
    if (settings.useRemote()) {
        if (!context.initializeRemote(loginDialog.apiClient())) {
            QMessageBox::critical(nullptr,
                                  QObject::tr("Startfehler"),
                                  QObject::tr("Server-Verbindung fehlgeschlagen:\n%1")
                                      .arg(context.lastError()));
            return 1;
        }
    } else if (!context.initializeLocal()) {
        QMessageBox::critical(nullptr,
                              QObject::tr("Startfehler"),
                              QObject::tr("Datenbank konnte nicht geöffnet werden:\n%1\n\nDatei: %2")
                                  .arg(context.lastError(), AppPaths::databaseFile()));
        return 1;
    }

    if (!context.ensureGrundschutzCatalog(AppPaths::defaultGrundschutzXml())) {
        const QString hint = context.isRemote()
                                 ? QObject::tr("Bitte den Katalog als Admin über "
                                               "\"Datei → IT-Grundschutz XML importieren\" auf den Server laden.")
                                 : QObject::tr("Sie können den Katalog später über "
                                               "\"Datei → IT-Grundschutz XML importieren\" laden.");
        QMessageBox::warning(nullptr, QObject::tr("Katalog"),
                             QObject::tr("%1\n\n%2").arg(context.lastError(), hint));
    }

    MainWindow window(context);
    window.show();
    return app.exec();
}
