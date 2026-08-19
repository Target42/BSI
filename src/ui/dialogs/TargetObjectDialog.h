#ifndef UI_TARGETOBJECTDIALOG_H
#define UI_TARGETOBJECTDIALOG_H

#include "domain/TargetObject.h"

#include <QDialog>

class QComboBox;
class QLabel;
class QLineEdit;
class QTextEdit;

class TargetObjectDialog : public QDialog
{
    Q_OBJECT

public:
    explicit TargetObjectDialog(QWidget *parent = nullptr);

    void setTargetObject(const TargetObject &object, const TargetObject &parent = {});
    TargetObject targetObject() const;

protected:
    void accept() override;

private:
    void fillTypeBox();
    void updateParentLabel();

    QLabel *m_parentLabel = nullptr;
    QLineEdit *m_nameEdit = nullptr;
    QComboBox *m_typeBox = nullptr;
    QComboBox *m_protectionBox = nullptr;
    QTextEdit *m_descriptionEdit = nullptr;
    TargetObject m_object;
    TargetObject m_parent;
};

#endif
