#ifndef UI_MEASUREDIALOG_H
#define UI_MEASUREDIALOG_H

#include "domain/Measure.h"

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
    Measure measure() const;

private:
    QLineEdit *m_titleEdit = nullptr;
    QTextEdit *m_descriptionEdit = nullptr;
    QLineEdit *m_responsibleEdit = nullptr;
    QDateEdit *m_dueDateEdit = nullptr;
    QComboBox *m_statusBox = nullptr;
    Measure m_measure;
};

#endif
