#include "TargetObjectDialog.h"

#include "domain/ProtectionNeed.h"
#include "domain/TargetObjectType.h"

#include <QCheckBox>
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
    resize(480, 560);

    m_parentLabel = new QLabel(this);
    m_parentLabel->setWordWrap(true);
    m_parentLabel->setStyleSheet(QStringLiteral("color: palette(mid);"));

    m_nameEdit = new QLineEdit(this);
    m_typeBox = new QComboBox(this);
    m_inheritCheck = new QCheckBox(tr("Schutzbedarf vom übergeordneten Objekt übernehmen"), this);
    m_confidentialityBox = new QComboBox(this);
    m_integrityBox = new QComboBox(this);
    m_availabilityBox = new QComboBox(this);
    fillCiaBox(m_confidentialityBox);
    fillCiaBox(m_integrityBox);
    fillCiaBox(m_availabilityBox);
    m_overallLabel = new QLabel(this);
    m_overallLabel->setWordWrap(true);
    m_protectionNoteEdit = new QTextEdit(this);
    m_protectionNoteEdit->setMaximumHeight(70);
    m_descriptionEdit = new QTextEdit(this);

    auto *form = new QFormLayout();
    form->addRow(m_parentLabel);
    form->addRow(tr("Name"), m_nameEdit);
    form->addRow(tr("Typ"), m_typeBox);
    form->addRow(m_inheritCheck);
    form->addRow(tr("Vertraulichkeit"), m_confidentialityBox);
    form->addRow(tr("Integrität"), m_integrityBox);
    form->addRow(tr("Verfügbarkeit"), m_availabilityBox);
    form->addRow(m_overallLabel);
    form->addRow(tr("Begründung"), m_protectionNoteEdit);
    form->addRow(tr("Beschreibung"), m_descriptionEdit);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, this);
    connect(buttons, &QDialogButtonBox::accepted, this, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);
    connect(m_inheritCheck, &QCheckBox::toggled, this, [this](bool) { updateCiaEnabled(); });
    connect(m_confidentialityBox, &QComboBox::currentIndexChanged, this, [this](int) { syncOverallLabel(); });
    connect(m_integrityBox, &QComboBox::currentIndexChanged, this, [this](int) { syncOverallLabel(); });
    connect(m_availabilityBox, &QComboBox::currentIndexChanged, this, [this](int) { syncOverallLabel(); });

    auto *layout = new QVBoxLayout(this);
    layout->addLayout(form);
    layout->addWidget(buttons);
}

void TargetObjectDialog::fillCiaBox(QComboBox *box)
{
    box->clear();
    box->addItem(ciaLevelToString(CiaLevel::Normal), static_cast<int>(CiaLevel::Normal));
    box->addItem(ciaLevelToString(CiaLevel::High), static_cast<int>(CiaLevel::High));
    box->addItem(ciaLevelToString(CiaLevel::VeryHigh), static_cast<int>(CiaLevel::VeryHigh));
}

void TargetObjectDialog::setCiaBox(QComboBox *box, CiaLevel level)
{
    const int index = box->findData(static_cast<int>(level));
    box->setCurrentIndex(index >= 0 ? index : 0);
}

CiaLevel TargetObjectDialog::selectedCiaLevel(const QComboBox *box) const
{
    return static_cast<CiaLevel>(box->currentData().toInt());
}

void TargetObjectDialog::setTargetObject(const TargetObject &object, const TargetObject &parent)
{
    m_object = object;
    m_parent = parent;
    m_nameEdit->setText(object.name);
    m_descriptionEdit->setPlainText(object.description);
    m_protectionNoteEdit->setPlainText(object.protectionNeedNote);
    m_inheritCheck->setChecked(object.inheritProtectionNeed && parent.id > 0);
    setCiaBox(m_confidentialityBox, object.confidentiality);
    setCiaBox(m_integrityBox, object.integrity);
    setCiaBox(m_availabilityBox, object.availability);
    fillTypeBox();
    updateParentLabel();
    updateCiaEnabled();
}

void TargetObjectDialog::fillTypeBox()
{
    QList<TargetObjectType> types;
    const bool editingRoot = m_object.id != 0 && isRootScopeTarget(m_object);
    if (editingRoot) {
        types = {TargetObjectType::Scope};
        m_typeBox->setEnabled(false);
        m_inheritCheck->setVisible(false);
        m_inheritCheck->setChecked(false);
    } else if (m_parent.id > 0) {
        types = allowedChildTargetTypes(m_parent.type);
        if (!types.contains(m_object.type))
            types.append(m_object.type);
        m_typeBox->setEnabled(true);
        m_inheritCheck->setVisible(true);
    } else {
        types = scopeLayerTypes();
        m_typeBox->setEnabled(true);
        m_inheritCheck->setVisible(false);
        m_inheritCheck->setChecked(false);
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

void TargetObjectDialog::updateCiaEnabled()
{
    const bool inherit = m_inheritCheck->isVisible() && m_inheritCheck->isChecked();
    m_confidentialityBox->setEnabled(!inherit);
    m_integrityBox->setEnabled(!inherit);
    m_availabilityBox->setEnabled(!inherit);
    if (inherit && m_parent.id > 0) {
        setCiaBox(m_confidentialityBox, m_parent.confidentiality);
        setCiaBox(m_integrityBox, m_parent.integrity);
        setCiaBox(m_availabilityBox, m_parent.availability);
    }
    syncOverallLabel();
}

void TargetObjectDialog::syncOverallLabel()
{
    const ProtectionNeed need = protectionNeedFromCiaLevels(
        selectedCiaLevel(m_confidentialityBox), selectedCiaLevel(m_integrityBox),
        selectedCiaLevel(m_availabilityBox));
    m_overallLabel->setText(tr("Gesamt nach Maximumprinzip: %1").arg(protectionNeedToString(need)));
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
    object.inheritProtectionNeed = m_inheritCheck->isVisible() && m_inheritCheck->isChecked();
    object.confidentiality = selectedCiaLevel(m_confidentialityBox);
    object.integrity = selectedCiaLevel(m_integrityBox);
    object.availability = selectedCiaLevel(m_availabilityBox);
    object.protectionNeedNote = m_protectionNoteEdit->toPlainText().trimmed();
    object.description = m_descriptionEdit->toPlainText().trimmed();
    finalizeTargetObjectProtectionNeed(object, m_parent);
    return object;
}
