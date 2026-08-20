#ifndef UI_TARGETOBJECTDIALOG_H
#define UI_TARGETOBJECTDIALOG_H

#include "domain/TargetObject.h"

#include <QDialog>

class QCheckBox;
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
    void fillCiaBox(QComboBox *box);
    void setCiaBox(QComboBox *box, CiaLevel level);
    CiaLevel selectedCiaLevel(const QComboBox *box) const;
    void updateParentLabel();
    void updateCiaEnabled();
    void syncOverallLabel();

    QLabel *m_parentLabel = nullptr;
    QLineEdit *m_nameEdit = nullptr;
    QComboBox *m_typeBox = nullptr;
    QCheckBox *m_inheritCheck = nullptr;
    QComboBox *m_confidentialityBox = nullptr;
    QComboBox *m_integrityBox = nullptr;
    QComboBox *m_availabilityBox = nullptr;
    QLabel *m_overallLabel = nullptr;
    QTextEdit *m_protectionNoteEdit = nullptr;
    QTextEdit *m_descriptionEdit = nullptr;
    TargetObject m_object;
    TargetObject m_parent;
};

#endif
