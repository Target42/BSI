#ifndef UI_TARGETOBJECTDIALOG_H
#define UI_TARGETOBJECTDIALOG_H

#include "domain/TargetObject.h"

#include <QDialog>

class QComboBox;
class QLineEdit;
class QTextEdit;

class TargetObjectDialog : public QDialog
{
    Q_OBJECT

public:
    explicit TargetObjectDialog(QWidget *parent = nullptr);

    void setTargetObject(const TargetObject &object);
    TargetObject targetObject() const;

private:
    QLineEdit *m_nameEdit = nullptr;
    QComboBox *m_typeBox = nullptr;
    QComboBox *m_protectionBox = nullptr;
    QTextEdit *m_descriptionEdit = nullptr;
    TargetObject m_object;
};

#endif
