#ifndef UI_MEASUREDIALOG_H
#define UI_MEASUREDIALOG_H

#include "domain/Measure.h"
#include "qdialogbuttonbox.h"

#include <QDialog>

class QComboBox;
class QDateEdit;
class QLineEdit;
class QTextEdit;

class MeasureDialog : public QDialog
{
    Q_OBJECT

public:
    explicit MeasureDialog(QWidget *parent = nullptr);

    void setMeasure(const Measure &measure);
    void setReadOnly(bool readOnly);
    Measure measure() const;

private:
    void applyReadOnlyUi();

    QLineEdit *m_titleEdit = nullptr;
    QTextEdit *m_descriptionEdit = nullptr;
    QLineEdit *m_responsibleEdit = nullptr;
    QDateEdit *m_dueDateEdit = nullptr;
    QComboBox *m_statusBox = nullptr;
    QDialogButtonBox *m_buttons = nullptr;
    Measure m_measure;
    bool m_readOnly = false;
};

#endif
