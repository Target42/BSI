#ifndef UI_CATALOGSEARCHDIALOG_H
#define UI_CATALOGSEARCHDIALOG_H

#include "domain/Baustein.h"
#include "domain/Requirement.h"

#include <QDialog>
#include <QHash>
#include <QList>
#include <QSet>

class QLineEdit;
class QTableWidget;
class QTextEdit;
class QTimer;

class CatalogSearchDialog : public QDialog
{
    Q_OBJECT

public:
    CatalogSearchDialog(const QList<Baustein> &bausteine,
                        const QList<Requirement> &requirements,
                        const QString &initialQuery = {},
                        QWidget *parent = nullptr);

private:
    struct SearchHit {
        int bausteinDbId = 0;
        int requirementId = 0;
        QString groupName;
        QString bausteinLabel;
        QString requirementLabel;
        QString matchField;
        QString snippet;
    };

    void runSearch();
    void showHitAt(int row);
    void openSelectedHit();

    QList<Baustein> m_bausteine;
    QList<Requirement> m_requirements;
    QHash<int, Baustein> m_bausteinById;
    QList<SearchHit> m_hits;

    QLineEdit *m_searchEdit = nullptr;
    QTableWidget *m_table = nullptr;
    QTextEdit *m_preview = nullptr;
    QTimer *m_searchTimer = nullptr;
};

#endif
