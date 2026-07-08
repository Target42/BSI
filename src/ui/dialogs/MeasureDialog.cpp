#include "MeasureDialog.h"

#include "domain/MeasureStatus.h"

#include <QComboBox>
#include <QDate>
#include <QDateEdit>
#include <QDialogButtonBox>
#include <QFormLayout>
#include <QLineEdit>
#include <QTextEdit>
#include <QVBoxLayout>

MeasureDialog::MeasureDialog(QWidget *parent)
    : QDialog(parent)
{
    setWindowTitle(tr("Maßnahme"));
    resize(460, 320);

    m_titleEdit = new QLineEdit(this);
    m_descriptionEdit = new QTextEdit(this);
    m_responsibleEdit = new QLineEdit(this);
    m_dueDateEdit = new QDateEdit(this);
    m_dueDateEdit->setCalendarPopup(true);
    m_dueDateEdit->setDisplayFormat(QStringLiteral("dd.MM.yyyy"));
    m_dueDateEdit->setSpecialValueText(tr("Keine Frist"));
    m_dueDateEdit->setMinimumDate(QDate(2000, 1, 1));

    m_statusBox = new QComboBox(this);
    m_statusBox->addItem(measureStatusToString(MeasureStatus::Open),
                         static_cast<int>(MeasureStatus::Open));
    m_statusBox->addItem(measureStatusToString(MeasureStatus::InProgress),
                         static_cast<int>(MeasureStatus::InProgress));
    m_statusBox->addItem(measureStatusToString(MeasureStatus::Done),
                         static_cast<int>(MeasureStatus::Done));

    auto *form = new QFormLayout();
    form->addRow(tr("Titel"), m_titleEdit);
    form->addRow(tr("Beschreibung"), m_descriptionEdit);
    form->addRow(tr("Verantwortlich"), m_responsibleEdit);
    form->addRow(tr("Frist"), m_dueDateEdit);
    form->addRow(tr("Status"), m_statusBox);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, this);
    connect(buttons, &QDialogButtonBox::accepted, this, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);

    auto *layout = new QVBoxLayout(this);
    layout->addLayout(form);
    layout->addWidget(buttons);
}

void MeasureDialog::setMeasure(const Measure &measure)
{
    m_measure = measure;
    m_titleEdit->setText(measure.title);
    m_descriptionEdit->setPlainText(measure.description);
    m_responsibleEdit->setText(measure.responsible);
    if (measure.dueDate.isValid()) {
        m_dueDateEdit->setDate(measure.dueDate);
    } else {
        m_dueDateEdit->setDate(m_dueDateEdit->minimumDate());
    }

    const int statusIndex = m_statusBox->findData(static_cast<int>(measure.status));
    if (statusIndex >= 0)
        m_statusBox->setCurrentIndex(statusIndex);
}

Measure MeasureDialog::measure() const
{
    Measure result = m_measure;
    result.title = m_titleEdit->text().trimmed();
    result.description = m_descriptionEdit->toPlainText().trimmed();
    result.responsible = m_responsibleEdit->text().trimmed();
    result.dueDate = m_dueDateEdit->date();
    if (result.dueDate == m_dueDateEdit->minimumDate())
        result.dueDate = {};
    result.status = static_cast<MeasureStatus>(m_statusBox->currentData().toInt());
    return result;
}
