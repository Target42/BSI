#include "TargetObjectDialog.h"

#include "domain/ProtectionNeed.h"
#include "domain/TargetObjectType.h"

#include <QComboBox>
#include <QDialogButtonBox>
#include <QFormLayout>
#include <QLabel>
#include <QLineEdit>
#include <QMessageBox>
#include <QTextEdit>
#include <QVBoxLayout>

TargetObjectDialog::TargetObjectDialog(QWidget *parent)
    : QDialog(parent)
{
    setWindowTitle(tr("Zielobjekt"));
    resize(480, 340);

    m_parentLabel = new QLabel(this);
    m_parentLabel->setWordWrap(true);
    m_parentLabel->setStyleSheet(QStringLiteral("color: palette(mid);"));

    m_nameEdit = new QLineEdit(this);
    m_typeBox = new QComboBox(this);
    m_protectionBox = new QComboBox(this);
    m_protectionBox->addItem(protectionNeedToString(ProtectionNeed::BasisOnly),
                             static_cast<int>(ProtectionNeed::BasisOnly));
    m_protectionBox->addItem(protectionNeedToString(ProtectionNeed::Normal),
                             static_cast<int>(ProtectionNeed::Normal));
    m_protectionBox->addItem(protectionNeedToString(ProtectionNeed::Elevated),
                             static_cast<int>(ProtectionNeed::Elevated));

    m_descriptionEdit = new QTextEdit(this);

    auto *form = new QFormLayout();
    form->addRow(m_parentLabel);
    form->addRow(tr("Name"), m_nameEdit);
    form->addRow(tr("Typ"), m_typeBox);
    form->addRow(tr("Schutzbedarf (IT-Grundschutz)"), m_protectionBox);
    form->addRow(tr("Beschreibung"), m_descriptionEdit);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, this);
    connect(buttons, &QDialogButtonBox::accepted, this, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);

    auto *layout = new QVBoxLayout(this);
    layout->addLayout(form);
    layout->addWidget(buttons);
}

void TargetObjectDialog::setTargetObject(const TargetObject &object, const TargetObject &parent)
{
    m_object = object;
    m_parent = parent;
    m_nameEdit->setText(object.name);
    m_descriptionEdit->setPlainText(object.description);

    const int protectionIndex = m_protectionBox->findData(static_cast<int>(object.protectionNeed));
    if (protectionIndex >= 0)
        m_protectionBox->setCurrentIndex(protectionIndex);

    fillTypeBox();
    updateParentLabel();
}

void TargetObjectDialog::fillTypeBox()
{
    QList<TargetObjectType> types;
    const bool editingRoot = m_object.id != 0 && isRootScopeTarget(m_object);
    if (editingRoot) {
        types = {TargetObjectType::Scope};
        m_typeBox->setEnabled(false);
    } else if (m_parent.id > 0) {
        types = allowedChildTargetTypes(m_parent.type);
        if (!types.contains(m_object.type))
            types.append(m_object.type);
        m_typeBox->setEnabled(true);
    } else {
        types = scopeLayerTypes();
        m_typeBox->setEnabled(true);
    }

    m_typeBox->clear();
    for (const TargetObjectType type : types)
        m_typeBox->addItem(targetObjectTypeToString(type), static_cast<int>(type));

    const int typeIndex = m_typeBox->findData(static_cast<int>(m_object.type));
    if (typeIndex >= 0)
        m_typeBox->setCurrentIndex(typeIndex);
}

void TargetObjectDialog::updateParentLabel()
{
    if (m_object.id != 0 && isRootScopeTarget(m_object))
        m_parentLabel->setText(tr("Wurzel des Informationsverbunds"));
    else if (m_parent.id > 0 && m_object.id == 0)
        m_parentLabel->setText(tr("Wird angelegt unter: %1").arg(targetObjectCaption(m_parent)));
    else if (m_parent.id > 0)
        m_parentLabel->setText(tr("Übergeordnet: %1").arg(targetObjectCaption(m_parent)));
    else
        m_parentLabel->clear();
}

void TargetObjectDialog::accept()
{
    if (m_nameEdit->text().trimmed().isEmpty()) {
        QMessageBox::warning(this, tr("Zielobjekt"), tr("Bitte einen Namen eingeben."));
        return;
    }
    QDialog::accept();
}

TargetObject TargetObjectDialog::targetObject() const
{
    TargetObject object = m_object;
    object.name = m_nameEdit->text().trimmed();
    object.type = static_cast<TargetObjectType>(m_typeBox->currentData().toInt());
    object.protectionNeed = static_cast<ProtectionNeed>(m_protectionBox->currentData().toInt());
    object.description = m_descriptionEdit->toPlainText().trimmed();
    return object;
}
