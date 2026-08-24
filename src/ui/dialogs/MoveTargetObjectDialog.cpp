#include "MoveTargetObjectDialog.h"

#include <QDialogButtonBox>
#include <QLabel>
#include <QListWidget>
#include <QMessageBox>
#include <QPushButton>
#include <QVBoxLayout>

MoveTargetObjectDialog::MoveTargetObjectDialog(const QList<TargetObject> &objects,
                                               const TargetObject &moving, QWidget *parent)
    : QDialog(parent)
    , m_destinations(possibleTargetMoveDestinations(objects, moving))
{
    setWindowTitle(tr("Zielobjekt verschieben"));
    resize(520, 380);

    auto *hint = new QLabel(
        tr("Neues übergeordnetes Ziel für „%1“ wählen. "
           "Die Schicht entspricht der Gruppe im Baum (z. B. Anwendungen).")
            .arg(targetObjectCaption(moving)),
        this);
    hint->setWordWrap(true);

    m_list = new QListWidget(this);
    for (const TargetMoveDestination &destination : m_destinations) {
        auto *item = new QListWidgetItem(destination.label, m_list);
        item->setData(Qt::UserRole, destination.parentId);
    }
    if (m_list->count() > 0)
        m_list->setCurrentRow(0);
    connect(m_list, &QListWidget::itemActivated, this, &QDialog::accept);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, this);
    connect(buttons, &QDialogButtonBox::accepted, this, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);
    buttons->button(QDialogButtonBox::Ok)->setEnabled(!m_destinations.isEmpty());

    auto *layout = new QVBoxLayout(this);
    layout->addWidget(hint);
    layout->addWidget(m_list, 1);
    layout->addWidget(buttons);
}

int MoveTargetObjectDialog::selectedParentId() const
{
    const QListWidgetItem *item = m_list->currentItem();
    if (item == nullptr)
        return 0;
    return item->data(Qt::UserRole).toInt();
}

bool MoveTargetObjectDialog::hasDestinations() const
{
    return !m_destinations.isEmpty();
}

void MoveTargetObjectDialog::accept()
{
    if (selectedParentId() <= 0) {
        QMessageBox::information(this, windowTitle(),
                                 tr("Bitte ein Ziel in der Liste wählen."));
        return;
    }
    QDialog::accept();
}
