#include "ProjectMembersDialog.h"

#include "net/HttpTeamService.h"
#include "ui/dialogs/CreateUserDialog.h"

#include <QComboBox>
#include <QCoreApplication>
#include <QDialogButtonBox>
#include <QFormLayout>
#include <QGroupBox>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QLabel>
#include <QLineEdit>
#include <QMessageBox>
#include <QPushButton>
#include <QSet>
#include <QTableWidget>
#include <QVBoxLayout>

namespace {

QStringList roleOptions()
{
    return {QStringLiteral("owner"), QStringLiteral("editor"), QStringLiteral("viewer")};
}

} // namespace

ProjectMembersDialog::ProjectMembersDialog(ApiClient &client, int projectId,
                                             const QString &projectName, bool canManageMembers,
                                             bool canCreateUsers, QWidget *parent)
    : QDialog(parent)
    , m_client(client)
    , m_projectId(projectId)
    , m_projectName(projectName)
    , m_canManageMembers(canManageMembers)
    , m_canCreateUsers(canCreateUsers)
{
    setWindowTitle(tr("Projektmitglieder – %1").arg(projectName));
    resize(720, 480);

    auto *intro = new QLabel(
        canManageMembers
            ? tr("Verwalten Sie, wer auf das Projekt \"%1\" zugreifen darf.").arg(projectName)
            : tr("Mitglieder des Projekts \"%1\" (nur Ansicht).").arg(projectName),
        this);
    intro->setWordWrap(true);

    m_table = new QTableWidget(0, 3, this);
    m_table->setHorizontalHeaderLabels({tr("Name"), tr("E-Mail"), tr("Rolle")});
    m_table->setSelectionBehavior(QAbstractItemView::SelectRows);
    m_table->setSelectionMode(QAbstractItemView::SingleSelection);
    m_table->setEditTriggers(QAbstractItemView::NoEditTriggers);
    m_table->horizontalHeader()->setStretchLastSection(true);
    m_table->horizontalHeader()->setSectionResizeMode(0, QHeaderView::Stretch);
    m_table->horizontalHeader()->setSectionResizeMode(1, QHeaderView::Stretch);
    connect(m_table, &QTableWidget::itemSelectionChanged, this,
            &ProjectMembersDialog::onSelectionChanged);

    auto *addGroup = new QGroupBox(tr("Mitglied hinzufügen"), this);
    m_emailEdit = new QLineEdit(addGroup);
    m_emailEdit->setPlaceholderText(QStringLiteral("kollege@example.com"));
    m_userPicker = new QComboBox(addGroup);
    m_userPicker->setToolTip(tr("Optional: vorhandenen Benutzer auswählen (nur für Administratoren)."));
    m_roleBox = new QComboBox(addGroup);
    for (const QString &role : roleOptions())
        m_roleBox->addItem(roleLabel(role), role);
    m_roleBox->setCurrentIndex(m_roleBox->findData(QStringLiteral("editor")));

    m_addButton = new QPushButton(tr("Hinzufügen"), addGroup);
    connect(m_addButton, &QPushButton::clicked, this, &ProjectMembersDialog::addMember);
    connect(m_userPicker, &QComboBox::currentIndexChanged, this, [this](int index) {
        if (index < 0)
            return;
        const QString email = m_userPicker->currentData(Qt::UserRole + 1).toString();
        if (!email.isEmpty())
            m_emailEdit->setText(email);
    });

    auto *addForm = new QFormLayout(addGroup);
    addForm->addRow(tr("E-Mail"), m_emailEdit);
    if (m_canCreateUsers)
        addForm->addRow(tr("Benutzer wählen"), m_userPicker);
    addForm->addRow(tr("Rolle"), m_roleBox);
    addForm->addRow(QString(), m_addButton);

    m_changeRoleButton = new QPushButton(tr("Rolle ändern..."), this);
    m_removeButton = new QPushButton(tr("Entfernen"), this);
    m_createUserButton = new QPushButton(tr("Neuen Benutzer anlegen..."), this);
    connect(m_changeRoleButton, &QPushButton::clicked, this, &ProjectMembersDialog::changeRole);
    connect(m_removeButton, &QPushButton::clicked, this, &ProjectMembersDialog::removeMember);
    connect(m_createUserButton, &QPushButton::clicked, this, &ProjectMembersDialog::createUser);

    auto *memberActions = new QHBoxLayout;
    memberActions->addWidget(m_changeRoleButton);
    memberActions->addWidget(m_removeButton);
    memberActions->addStretch();
    memberActions->addWidget(m_createUserButton);

    m_buttons = new QDialogButtonBox(QDialogButtonBox::Close, this);
    connect(m_buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);

    auto *layout = new QVBoxLayout(this);
    layout->addWidget(intro);
    layout->addWidget(m_table, 1);
    layout->addLayout(memberActions);
    layout->addWidget(addGroup);
    layout->addWidget(m_buttons);

    addGroup->setVisible(m_canManageMembers);
    m_changeRoleButton->setVisible(m_canManageMembers);
    m_removeButton->setVisible(m_canManageMembers);
    m_createUserButton->setVisible(m_canManageMembers && m_canCreateUsers);

    reloadMembers();
    if (m_canManageMembers)
        reloadUserPicker();
    updateButtons();
}

QString ProjectMembersDialog::roleLabel(const QString &role)
{
    if (role == QStringLiteral("owner"))
        return QCoreApplication::translate("ProjectMembersDialog", "Besitzer");
    if (role == QStringLiteral("editor"))
        return QCoreApplication::translate("ProjectMembersDialog", "Bearbeiter");
    if (role == QStringLiteral("viewer"))
        return QCoreApplication::translate("ProjectMembersDialog", "Leser");
    return role;
}

int ProjectMembersDialog::selectedUserId() const
{
    const int row = m_table->currentRow();
    if (row < 0 || row >= m_members.size())
        return 0;
    return m_members.at(row).userId;
}

void ProjectMembersDialog::reloadMembers()
{
    HttpTeamService service(m_client);
    m_members = service.listMembers(m_projectId);
    if (m_members.isEmpty() && !service.lastError().isEmpty()) {
        QMessageBox::critical(this, tr("Mitglieder"), service.lastError());
        return;
    }

    m_table->setRowCount(m_members.size());
    for (int row = 0; row < m_members.size(); ++row) {
        const ProjectMember &member = m_members.at(row);
        m_table->setItem(row, 0, new QTableWidgetItem(member.displayName));
        m_table->setItem(row, 1, new QTableWidgetItem(member.email));
        m_table->setItem(row, 2, new QTableWidgetItem(roleLabel(member.role)));
    }
    m_table->resizeColumnsToContents();
    updateButtons();
}

void ProjectMembersDialog::reloadUserPicker()
{
    m_userPicker->clear();
    m_userPicker->addItem(tr("(Manuell per E-Mail)"), 0);

    if (!m_canCreateUsers)
        return;

    HttpTeamService service(m_client);
    m_users = service.listUsers();
    if (m_users.isEmpty())
        return;

    QSet<int> memberIds;
    for (const ProjectMember &member : std::as_const(m_members))
        memberIds.insert(member.userId);

    for (const ServerUser &user : std::as_const(m_users)) {
        if (memberIds.contains(user.id))
            continue;
        m_userPicker->addItem(QStringLiteral("%1 <%2>").arg(user.displayName, user.email), user.id);
        const int index = m_userPicker->count() - 1;
        m_userPicker->setItemData(index, user.email, Qt::UserRole + 1);
    }
}

void ProjectMembersDialog::addMember()
{
    const QString email = m_emailEdit->text().trimmed();
    if (email.isEmpty()) {
        QMessageBox::warning(this, tr("Mitglied hinzufügen"), tr("Bitte eine E-Mail-Adresse angeben."));
        return;
    }

    HttpTeamService service(m_client);
    const ProjectMember member =
        service.addMember(m_projectId, email, m_roleBox->currentData().toString());
    if (member.userId == 0) {
        QMessageBox::critical(this, tr("Mitglied hinzufügen"), service.lastError());
        return;
    }

    m_emailEdit->clear();
    reloadMembers();
    reloadUserPicker();
}

void ProjectMembersDialog::changeRole()
{
    const int userId = selectedUserId();
    if (userId <= 0)
        return;

    const ProjectMember *current = nullptr;
    for (const ProjectMember &member : std::as_const(m_members)) {
        if (member.userId == userId) {
            current = &member;
            break;
        }
    }
    if (!current)
        return;

    QDialog dialog(this);
    dialog.setWindowTitle(tr("Rolle ändern"));
    auto *roleBox = new QComboBox(&dialog);
    for (const QString &role : roleOptions())
        roleBox->addItem(roleLabel(role), role);
    roleBox->setCurrentIndex(roleBox->findData(current->role));

    auto *form = new QFormLayout;
    form->addRow(tr("Benutzer"), new QLabel(current->displayName, &dialog));
    form->addRow(tr("Neue Rolle"), roleBox);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, &dialog);
    connect(buttons, &QDialogButtonBox::accepted, &dialog, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, &dialog, &QDialog::reject);

    auto *layout = new QVBoxLayout(&dialog);
    layout->addLayout(form);
    layout->addWidget(buttons);

    if (dialog.exec() != QDialog::Accepted)
        return;

    HttpTeamService service(m_client);
    const ProjectMember updated =
        service.updateMemberRole(m_projectId, userId, roleBox->currentData().toString());
    if (updated.userId == 0) {
        QMessageBox::critical(this, tr("Rolle ändern"), service.lastError());
        return;
    }

    reloadMembers();
}

void ProjectMembersDialog::removeMember()
{
    const int userId = selectedUserId();
    if (userId <= 0)
        return;

    const ProjectMember *current = nullptr;
    for (const ProjectMember &member : std::as_const(m_members)) {
        if (member.userId == userId) {
            current = &member;
            break;
        }
    }
    if (!current)
        return;

    const auto answer = QMessageBox::question(
        this,
        tr("Mitglied entfernen"),
        tr("Soll \"%1\" (%2) wirklich aus dem Projekt entfernt werden?")
            .arg(current->displayName, current->email));
    if (answer != QMessageBox::Yes)
        return;

    HttpTeamService service(m_client);
    if (!service.removeMember(m_projectId, userId)) {
        QMessageBox::critical(this, tr("Mitglied entfernen"), service.lastError());
        return;
    }

    reloadMembers();
    reloadUserPicker();
}

void ProjectMembersDialog::createUser()
{
    CreateUserDialog dialog(this);
    if (dialog.exec() != QDialog::Accepted)
        return;

    HttpTeamService service(m_client);
    const ServerUser user = service.createUser(dialog.email(), dialog.displayName(),
                                               dialog.password(), dialog.isAdmin());
    if (user.id == 0) {
        QMessageBox::critical(this, tr("Benutzer anlegen"), service.lastError());
        return;
    }

    QMessageBox::information(
        this,
        tr("Benutzer angelegt"),
        tr("Der Benutzer \"%1\" wurde angelegt. Sie können ihn jetzt dem Projekt hinzufügen.")
            .arg(user.displayName));

    reloadUserPicker();
}

void ProjectMembersDialog::onSelectionChanged()
{
    updateButtons();
}

void ProjectMembersDialog::updateButtons()
{
    const bool hasSelection = selectedUserId() > 0;
    m_changeRoleButton->setEnabled(m_canManageMembers && hasSelection);
    m_removeButton->setEnabled(m_canManageMembers && hasSelection);
}
