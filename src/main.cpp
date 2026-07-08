#include "app/AppContext.h"
#include "app/AppPaths.h"
#include "ui/MainWindow.h"

#include <QApplication>
#include <QMessageBox>

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    QApplication::setApplicationName(QStringLiteral("ISMS"));
    QApplication::setOrganizationName(QStringLiteral("BSI-Tools"));

    AppContext context;
    if (!context.initialize()) {
        QMessageBox::critical(nullptr,
                              QObject::tr("Startfehler"),
                              QObject::tr("Datenbank konnte nicht geöffnet werden:\n%1\n\nDatei: %2")
                                  .arg(context.lastError(), AppPaths::databaseFile()));
        return 1;
    }

    if (!context.ensureGrundschutzCatalog(AppPaths::defaultGrundschutzXml())) {
        QMessageBox::warning(nullptr,
                             QObject::tr("Katalog"),
                             QObject::tr("%1\n\nSie können den Katalog später über "
                                         "\"Datei → IT-Grundschutz XML importieren\" laden.")
                                 .arg(context.lastError()));
    }

    MainWindow window(context);
    window.show();
    return app.exec();
}
