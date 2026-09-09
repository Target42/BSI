#ifndef UI_PROJECTDIALOG_H
#define UI_PROJECTDIALOG_H

#include "domain/Project.h"

#include <QDialog>

class QCheckBox;
class QLineEdit;
class QTextEdit;

class ProjectDialog : public QDialog
{
    Q_OBJECT

public:
    explicit ProjectDialog(QWidget *parent = nullptr);

    void setProject(const Project &project);
    void setShowWorkflow(bool show);
    Project project() const;

private:
    QLineEdit *m_nameEdit = nullptr;
    QTextEdit *m_descriptionEdit = nullptr;
    QCheckBox *m_workflowBox = nullptr;
    Project m_project;
};

#endif
