#ifndef UI_PROJECTDIALOG_H
#define UI_PROJECTDIALOG_H

#include "domain/Project.h"

#include <QDialog>

class QLineEdit;
class QTextEdit;

class ProjectDialog : public QDialog
{
    Q_OBJECT

public:
    explicit ProjectDialog(QWidget *parent = nullptr);

    void setProject(const Project &project);
    Project project() const;

private:
    QLineEdit *m_nameEdit = nullptr;
    QTextEdit *m_descriptionEdit = nullptr;
    Project m_project;
};

#endif
