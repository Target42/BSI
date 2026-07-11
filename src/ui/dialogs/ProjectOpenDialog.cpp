#include "ProjectOpenDialog.h"

#include <QDialogButtonBox>
#include <QLabel>
#include <QListWidget>
#include <QLocale>
#include <QVBoxLayout>
#include <QPushButton>

namespace {

QString roleLabel(const QString &role)
{
    if (role == QStringLiteral("owner"))
        return ProjectOpenDialog::tr("Besitzer");
    if (role == QStringLiteral("editor"))
        return ProjectOpenDialog::tr("Bearbeiter");
    if (role == QStringLiteral("viewer"))
        return ProjectOpenDialog::tr("Leser");
    return {};
}

} // namespace

ProjectOpenDialog::ProjectOpenDialog(const QList<Project> &projects, bool remoteMode,
                                     QWidget *parent)
    : QDialog(parent)
    , m_projects(projects)
{
    setWindowTitle(tr("Projekt öffnen"));
    resize(520, 360);

    m_list = new QListWidget(this);
    for (const Project &project : projects) {
        QString label =
            tr("%1  —  zuletzt bearbeitet: %2")
                .arg(project.name,
                     QLocale().toString(project.updatedAt.toLocalTime(), QLocale::ShortFormat));
        if (remoteMode) {
            const QString role = roleLabel(project.role);
            if (!role.isEmpty())
                label += QStringLiteral("  [%1]").arg(role);
        }
        auto *item = new QListWidgetItem(label, m_list);
        item->setData(Qt::UserRole, project.id);
    }
    if (m_list->count() > 0)
        m_list->setCurrentRow(0);
    connect(m_list, &QListWidget::itemActivated, this, &QDialog::accept);

    const QString hintText = remoteMode
                                 ? tr("Verfügbare IT-Grundschutz-Projekte auf dem Server.")
                                 : tr("IT-Grundschutz-Projekte in der lokalen Datenbank.");
    auto *hint = new QLabel(hintText, this);
    hint->setWordWrap(true);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, this);
    connect(buttons, &QDialogButtonBox::accepted, this, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);
    buttons->button(QDialogButtonBox::Ok)->setEnabled(!projects.isEmpty());

    auto *layout = new QVBoxLayout(this);
    layout->addWidget(hint);
    layout->addWidget(m_list, 1);
    layout->addWidget(buttons);
}

Project ProjectOpenDialog::selectedProject() const
{
    const QListWidgetItem *item = m_list->currentItem();
    if (item == nullptr)
        return {};

    const int projectId = item->data(Qt::UserRole).toInt();
    for (const Project &project : m_projects) {
        if (project.id == projectId)
            return project;
    }
    return {};
}
