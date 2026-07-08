#include "TargetObjectDialog.h"

#include "domain/ProtectionNeed.h"
#include "domain/TargetObjectType.h"

#include <QComboBox>
#include <QDialogButtonBox>
#include <QFormLayout>
#include <QLineEdit>
#include <QTextEdit>
#include <QVBoxLayout>

TargetObjectDialog::TargetObjectDialog(QWidget *parent)
    : QDialog(parent)
{
    setWindowTitle(tr("Zielobjekt"));
    resize(480, 300);

    m_nameEdit = new QLineEdit(this);
    m_typeBox = new QComboBox(this);
    m_protectionBox = new QComboBox(this);
    m_protectionBox->addItem(protectionNeedToString(ProtectionNeed::BasisOnly),
                             static_cast<int>(ProtectionNeed::BasisOnly));
    m_protectionBox->addItem(protectionNeedToString(ProtectionNeed::Normal),
                             static_cast<int>(ProtectionNeed::Normal));
    m_protectionBox->addItem(protectionNeedToString(ProtectionNeed::Elevated),
                             static_cast<int>(ProtectionNeed::Elevated));
    m_typeBox->addItem(targetObjectTypeToString(TargetObjectType::Scope),
                       static_cast<int>(TargetObjectType::Scope));
    m_typeBox->addItem(targetObjectTypeToString(TargetObjectType::Process),
                       static_cast<int>(TargetObjectType::Process));
    m_typeBox->addItem(targetObjectTypeToString(TargetObjectType::Application),
                       static_cast<int>(TargetObjectType::Application));
    m_typeBox->addItem(targetObjectTypeToString(TargetObjectType::ITSystem),
                       static_cast<int>(TargetObjectType::ITSystem));
    m_typeBox->addItem(targetObjectTypeToString(TargetObjectType::Network),
                       static_cast<int>(TargetObjectType::Network));
    m_typeBox->addItem(targetObjectTypeToString(TargetObjectType::Infrastructure),
                       static_cast<int>(TargetObjectType::Infrastructure));

    m_descriptionEdit = new QTextEdit(this);

    auto *form = new QFormLayout();
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

void TargetObjectDialog::setTargetObject(const TargetObject &object)
{
    m_object = object;
    m_nameEdit->setText(object.name);
    m_descriptionEdit->setPlainText(object.description);

    const int typeIndex = m_typeBox->findData(static_cast<int>(object.type));
    if (typeIndex >= 0)
        m_typeBox->setCurrentIndex(typeIndex);

    const int protectionIndex = m_protectionBox->findData(static_cast<int>(object.protectionNeed));
    if (protectionIndex >= 0)
        m_protectionBox->setCurrentIndex(protectionIndex);
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
