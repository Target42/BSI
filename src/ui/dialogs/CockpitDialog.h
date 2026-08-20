#ifndef UI_COCKPITDIALOG_H
#define UI_COCKPITDIALOG_H

#include "app/AppContext.h"
#include "domain/CockpitItem.h"
#include "domain/Project.h"

#include <QDialog>

class QCheckBox;
class QComboBox;
class QLabel;
class QLineEdit;
class QTableView;
class CockpitTableModel;

class CockpitDialog : public QDialog
{
    Q_OBJECT

public:
    CockpitDialog(AppContext &context, const Project &project, const QString &userName,
                  const QString &userEmail, QWidget *parent = nullptr);

    CockpitItem selectedItem() const { return m_selected; }

private slots:
    void applyFilter();
    void acceptSelection();

private:
    AppContext &m_context;
    Project m_project;
    CockpitFilter m_filter;
    QList<CockpitItem> m_allItems;
    CockpitItem m_selected;

    CockpitTableModel *m_model = nullptr;
    QTableView *m_table = nullptr;
    QComboBox *m_kindBox = nullptr;
    QComboBox *m_dueBox = nullptr;
    QCheckBox *m_hideDoneBox = nullptr;
    QCheckBox *m_mineBox = nullptr;
    QLineEdit *m_personEdit = nullptr;
    QLabel *m_summaryLabel = nullptr;
};

#endif
