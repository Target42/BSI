#ifndef UI_PROJECTMEMBERSDIALOG_H
#define UI_PROJECTMEMBERSDIALOG_H

#include "domain/ServerUser.h"
#include "net/ApiClient.h"

#include <QDialog>
#include <QList>

class QComboBox;
class QDialogButtonBox;
class QLineEdit;
class QPushButton;
class QTableWidget;

class ProjectMembersDialog : public QDialog
{
    Q_OBJECT

public:
    ProjectMembersDialog(ApiClient &client, int projectId, const QString &projectName,
                         bool canManageMembers, bool canCreateUsers, QWidget *parent = nullptr);

private slots:
    void reloadMembers();
    void reloadUserPicker();
    void addMember();
    void changeRole();
    void removeMember();
    void createUser();
    void onSelectionChanged();

private:
    static QString roleLabel(const QString &role);
    int selectedUserId() const;
    void updateButtons();

    ApiClient &m_client;
    int m_projectId;
    QString m_projectName;
    bool m_canManageMembers;
    bool m_canCreateUsers;

    QList<ProjectMember> m_members;
    QList<ServerUser> m_users;

    QTableWidget *m_table = nullptr;
    QLineEdit *m_emailEdit = nullptr;
    QComboBox *m_userPicker = nullptr;
    QComboBox *m_roleBox = nullptr;
    QPushButton *m_addButton = nullptr;
    QPushButton *m_changeRoleButton = nullptr;
    QPushButton *m_removeButton = nullptr;
    QPushButton *m_createUserButton = nullptr;
    QDialogButtonBox *m_buttons = nullptr;
};

#endif
