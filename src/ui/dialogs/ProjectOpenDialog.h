#ifndef UI_PROJECTOPENDIALOG_H
#define UI_PROJECTOPENDIALOG_H

#include "domain/Project.h"

#include <QDialog>

class QListWidget;

class ProjectOpenDialog : public QDialog
{
    Q_OBJECT

public:
    explicit ProjectOpenDialog(const QList<Project> &projects, bool remoteMode,
                                 QWidget *parent = nullptr);

    Project selectedProject() const;

private:
    QList<Project> m_projects;
    QListWidget *m_list = nullptr;
};

#endif
