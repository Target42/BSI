#ifndef UI_BAUSTEINVIEWDIALOG_H
#define UI_BAUSTEINVIEWDIALOG_H

#include "domain/Baustein.h"
#include "domain/Requirement.h"

#include <QDialog>
#include <QList>

class QLineEdit;
class QTableWidget;
class QTextEdit;

class BausteinViewDialog : public QDialog
{
    Q_OBJECT

public:
    BausteinViewDialog(const Baustein &baustein,
                       const QList<Requirement> &requirements,
                       const QString &initialSearch = {},
                       int initialRequirementId = 0,
                       QWidget *parent = nullptr);

private:
    void populateRequirements();
    void showRequirementAt(int row);
    void applyRequirementSearch(const QString &query);
    void selectRequirementById(int requirementId);

    Baustein m_baustein;
    QList<Requirement> m_requirements;
    QTableWidget *m_table = nullptr;
    QTextEdit *m_text = nullptr;
    QLineEdit *m_searchEdit = nullptr;
};

#endif
