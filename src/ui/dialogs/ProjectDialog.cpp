#include "ProjectDialog.h"

#include <QCheckBox>
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
    m_workflowBox = new QCheckBox(tr("Prüfkreislauf (Einreichen und Abnehmen von Bausteinen)"), this);
    m_workflowBox->setToolTip(tr("Wenn eingeschaltet, müssen Bausteine eingereicht und abgenommen werden, "
                                 "bevor sie abgeschlossen sind. Ausgeschaltet bleibt der freie Bearbeitungsmodus."));
    m_workflowBox->setVisible(false);

    auto *form = new QFormLayout();
    form->addRow(tr("Name"), m_nameEdit);
    form->addRow(tr("Beschreibung"), m_descriptionEdit);
    form->addRow(QString(), m_workflowBox);

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
    m_workflowBox->setChecked(project.workflowEnabled);
}

void ProjectDialog::setShowWorkflow(bool show)
{
    m_workflowBox->setVisible(show);
    resize(480, show ? 300 : 260);
}

Project ProjectDialog::project() const
{
    Project project = m_project;
    project.name = m_nameEdit->text().trimmed();
    project.description = m_descriptionEdit->toPlainText().trimmed();
    if (m_workflowBox->isVisible())
        project.workflowEnabled = m_workflowBox->isChecked();
    return project;
}
