#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include "book/book.h"
#include "book/wordindex.h"

#include <QMainWindow>
#include <QTreeWidgetItem>
#include <QListWidgetItem>
#include <QNetworkReply>
#include <QNetworkAccessManager>

class IndexNode;

QT_BEGIN_NAMESPACE
namespace Ui {
class MainWindow;
}
QT_END_NAMESPACE

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    MainWindow(QWidget *parent = nullptr);
    ~MainWindow();

    bool loadXML( QString fileName );

    void getXML( void );

private slots:
    void on_pushButton_2_clicked();

    void on_listWidget_itemDoubleClicked(QListWidgetItem *item);

    void on_treeWidget_itemDoubleClicked(QTreeWidgetItem *item, int column);

    void showContextMenu(const QPoint &pos);

    void on_actionEnde_triggered();

    void on_actionNeu_triggered();

    void on_action_ffnen_triggered();

    void on_actionSpeichern_triggered();

    void on_actionSchlie_en_triggered();

    void on_treeWidget_currentItemChanged(QTreeWidgetItem *current, QTreeWidgetItem *previous);

    void onDownloadFinished(QNetworkReply *reply);

private:
    Ui::MainWindow *ui;
    QNetworkAccessManager* m_manager;
    QString     m_xml;
    Book*       m_book;
    IndexNode*  m_index;
    WordIndex   m_words;
    bool        m_templateMode;
    QString     m_home;

    void UpdateTree( void );
    void addTreeNode( QTreeWidgetItem* parent, IndexNode* node);

    void buildIndex( void );

    void addNode( IndexNode* parent, BaseNode* node);

    void updateText( QTreeWidgetItem *item);

    void setTemplateMode( bool flag );

    bool save( void );

    bool load( void );

};
#endif // MAINWINDOW_H
