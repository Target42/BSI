#include "ProjectDialog.h"

#include <QDialogButtonBox>
#include <QFormLayout>
#include <QLineEdit>
#include <QTextEdit>
#include <QVBoxLayout>

ProjectDialog::ProjectDialog(QWidget *parent)
    : QDialog(parent)
{
    setWindowTitle(tr("Projekt"));
    resize(480, 260);

    m_nameEdit = new QLineEdit(this);
    m_descriptionEdit = new QTextEdit(this);

    auto *form = new QFormLayout();
    form->addRow(tr("Name"), m_nameEdit);
    form->addRow(tr("Beschreibung"), m_descriptionEdit);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, this);
    connect(buttons, &QDialogButtonBox::accepted, this, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);

    auto *layout = new QVBoxLayout(this);
    layout->addLayout(form);
    layout->addWidget(buttons);
}

void ProjectDialog::setProject(const Project &project)
{
    m_project = project;
    m_nameEdit->setText(project.name);
    m_descriptionEdit->setPlainText(project.description);
}

Project ProjectDialog::project() const
{
    Project project = m_project;
    project.name = m_nameEdit->text().trimmed();
    project.description = m_descriptionEdit->toPlainText().trimmed();
    return project;
}
