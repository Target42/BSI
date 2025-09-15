#include "mainwindow.h"

#include "book/indexnode.h"
#include "book/indexstore.h"
#include "ui_mainwindow.h"

#include <QDir>
#include <QFileDialog>
#include <QFileInfo>

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::MainWindow)
{
    ui->setupUi(this);
    this->setCentralWidget(ui->gridLayoutWidget);
    ui->groupBox->setLayout(ui->gridLayout_2);

    ui->treeWidget->setHeaderLabel("Titel");

    ui->treeWidget->setContextMenuPolicy(Qt::CustomContextMenu);
    connect(ui->treeWidget, &QTreeWidget::customContextMenuRequested, this, &MainWindow::showContextMenu);

    m_manager = new QNetworkAccessManager(this);
    m_index = nullptr;
    m_book = nullptr;
    setTemplateMode(false);

    m_xml = QDir::cleanPath(QDir::homePath() + QDir::separator() +"Dokumente" + QDir::separator() + "XML_Kompendium_2023.xml");

    if ( loadXML(m_xml) == false )
    {
        getXML();
    }

}

MainWindow::~MainWindow()
{
    delete m_manager;
    delete ui;
}

bool MainWindow::loadXML(QString fileName)
{
    QFile file(fileName);

    bool result = file.exists();

    if ( result == true )
    {
        m_book = new Book();
        m_book->load(fileName);

        buildIndex();

        m_words.run(m_book);

        UpdateTree();
    }

    return result;
}

void MainWindow::getXML()
{    
    connect(m_manager, &QNetworkAccessManager::finished, this, &MainWindow::onDownloadFinished);

    QNetworkRequest request(QUrl("https://www.bsi.bund.de/SharedDocs/Downloads/DE/BSI/Grundschutz/IT-GS-Kompendium/XML_Kompendium_2023.xml?__blob=publicationFile&v=4"));

    m_manager->get(request);
}

void MainWindow::UpdateTree()
{
    ui->treeWidget->clear();
    addTreeNode(ui->treeWidget->invisibleRootItem(), m_index);

}

void MainWindow::addTreeNode(QTreeWidgetItem *parent, IndexNode *node)
{
    QTreeWidgetItem* sub = new QTreeWidgetItem(parent);
    sub->setText(0, node->title());
    sub->setData(0, Qt::UserRole, QVariant::fromValue(reinterpret_cast<quintptr>(node)));

    foreach( IndexNode* child, node->childs())
    {
        addTreeNode(sub, child);
    }
    if ( parent == ui->treeWidget->invisibleRootItem())
    {
        ui->treeWidget->expandItem(sub);
    }
}

void MainWindow::buildIndex()
{    
    m_index = new IndexNode();
    m_index->setTitle("IT-Grundschutz-Bausteine Edition 2023");
    addNode(m_index, m_book);
}

void MainWindow::addNode(IndexNode *parent, BaseNode *node)
{
    if ( node->getID() != "")
    {
        IndexNode*  inx = new IndexNode();
        inx->setNode(node);
        parent->addChild(inx);
        parent = inx;
    }
    foreach (BaseNode* child, node->childs())
    {
        addNode(parent, child);
    }
}

void MainWindow::updateText(QTreeWidgetItem *item)
{
    if ( item == nullptr)
    {
        return;
    }
    QVariant variant = item->data(0, Qt::UserRole);
    quintptr ptr = variant.value<quintptr>();


    IndexNode* index = reinterpret_cast<IndexNode*>(ptr);

    if ( ( index != nullptr) && (index->node() != nullptr) )
    {
        switch(index->node()->templateState())
        {
            case BaseNode::tsUndefined:
                item->setForeground(0, Qt::black);
                break;
            case BaseNode::tsIgnore:
                item->setForeground(0, Qt::gray);
                break;
            case BaseNode::tsNeeded:
                item->setForeground(0, Qt::red);
                break;
            case BaseNode::tsPosible:
                item->setForeground(0, Qt::green);
                break;
        }
    }
    for (int i = 0; i < item->childCount(); ++i)
    {
        QTreeWidgetItem *child = item->child(i);
        updateText(child);
    }

}

void MainWindow::setTemplateMode(bool flag)
{
    m_templateMode = flag;

    ui->widget->setEnabled(m_templateMode);

    if ( m_templateMode == true )
    {
        ui->widget->setHome(m_home);
    }
    else
    {
        if ( m_index != nullptr )
        {
            ui->widget->setHome("");
            foreach (IndexNode* child, m_index->childs())
            {
                if ( child->node() != nullptr)
                {
                    child->node()->setTemplateState(BaseNode::tsUndefined);
                }
            }
            updateText(ui->treeWidget->invisibleRootItem());
        }
    }
}

bool MainWindow::save()
{
    IndexStore store;

    store.setHome(m_home);
    store.setRoot(m_index);

    return store.save();
}

bool MainWindow::load()
{
    IndexStore store;

    store.setHome(m_home);
    store.setRoot(m_index);

    bool result = store.load();
    updateText(ui->treeWidget->invisibleRootItem());
    return result;
}


void MainWindow::on_pushButton_2_clicked()
{
    QString text = ui->lineEdit->text().trimmed();

    QList<BaseNode*>* result = m_words.search(text, ui->checkBox->isChecked());

    ui->label_3->setText(QString("Treffer: %1").arg(result->count()));
    ui->listWidget->clear();

    QList<IndexNode*> list;
    foreach (BaseNode* node, *result )
    {
        foreach (IndexNode* index, m_index->childs())
        {
            IndexNode* val = nullptr;

            val = index->findIndex(node);

            if ( val != nullptr)
            {
                if ( list.indexOf(val) == -1)
                {
                    list.append(val);
                }
                break;
            }
        }
    }
    delete result;


    foreach (IndexNode* index, list)
    {
        QListWidgetItem* item = new QListWidgetItem(index->title());
        item->setData(Qt::UserRole, QVariant::fromValue(reinterpret_cast<quintptr>(index)));
        ui->listWidget->addItem(item);
    }
}

QTreeWidgetItem* findItemByData(QTreeWidget* tree, const QVariant& value, int column = 0, int role = Qt::UserRole)
{
    std::function<QTreeWidgetItem*(QTreeWidgetItem*)> recurse;
    recurse = [&](QTreeWidgetItem* parent) -> QTreeWidgetItem* {
        if (parent->data(column, role) == value) {
            return parent;
        }
        for (int i = 0; i < parent->childCount(); ++i) {
            if (auto* found = recurse(parent->child(i)))
                return found;
        }
        return nullptr;
    };

    for (int i = 0; i < tree->topLevelItemCount(); ++i) {
        if (auto* found = recurse(tree->topLevelItem(i)))
            return found;
    }
    return nullptr;
}


void MainWindow::on_listWidget_itemDoubleClicked(QListWidgetItem *item)
{
    QVariant variant = item->data(Qt::UserRole);
    quintptr ptr = variant.value<quintptr>();

    // Schritt 2: Zurück zum Original-Zeigertyp casten

    IndexNode* index = reinterpret_cast<IndexNode*>(ptr);

    if ( index->node() != nullptr)
    {
        QStringList list;
        index->node()->toHtml(list);
        ui->textEdit->setHtml( list.join('\n'));
    }
    QTextCharFormat format;
    format.setBackground(Qt::yellow);

    // Erstellen Sie einen Cursor für das Textdokument
    QTextCursor cursor(ui->textEdit->document());
    QString text = ui->lineEdit->text();


    while (!cursor.isNull() && !cursor.atEnd())
    {
        cursor = ui->textEdit->document()->find(text, cursor);
        if (!cursor.isNull()) {
            cursor.mergeCharFormat(format); // Nur dieses Wort hervorheben
        }
    }

    QTreeWidgetItem* indexItem = findItemByData(ui->treeWidget, QVariant::fromValue(reinterpret_cast<quintptr>(index)));
    if (indexItem) {
        ui->treeWidget->setCurrentItem(indexItem);
        ui->treeWidget->scrollToItem(indexItem);
        ui->treeWidget->expandItem(indexItem->parent()); // sichtbar machen, falls eingeklappt
    }
}


void MainWindow::on_treeWidget_itemDoubleClicked(QTreeWidgetItem *item, int column)
{
    QVariant variant = item->data(column, Qt::UserRole);
    quintptr ptr = variant.value<quintptr>();

    IndexNode* index = reinterpret_cast<IndexNode*>(ptr);

    if ( index->node() != nullptr)
    {
        QStringList list;
        index->node()->toHtml(list);
        ui->textEdit->setHtml( list.join('\n'));
    }

}

void MainWindow::showContextMenu(const QPoint &pos)
{
    if (m_templateMode == false )
    {
        return;
    }
    QTreeWidgetItem *item = ui->treeWidget->itemAt(pos);

    if ( item == nullptr )
    {
        return;
    }
    QVariant variant = item->data(0, Qt::UserRole);
    quintptr ptr = variant.value<quintptr>();

    // Schritt 2: Zurück zum Original-Zeigertyp casten

    IndexNode* index = reinterpret_cast<IndexNode*>(ptr);

    if ( ( index == nullptr ) || ( index->node() == nullptr) )
    {
        return;
    }
    QMenu contextMenu(tr("Aktionsmenü"), this);

    QAction action1(tr("Nich relevant"), this);
    QAction action2(tr("Möglicherweise"), this);
    QAction action3(tr("Benötigt"), this);

    contextMenu.addAction(&action1);
    contextMenu.addAction(&action2);
    contextMenu.addAction(&action3);

    // Zeige das Menü an der globalen Position an
    // mapToGlobal wandelt die lokale Widget-Position in eine globale um
    QAction *selectedAction = contextMenu.exec(ui->treeWidget->viewport()->mapToGlobal(pos));
    if ( selectedAction == nullptr)
    {
        return;
    }

    BaseNode::tTemplateState state = BaseNode::tsUndefined;

    if ( selectedAction == &action1)
    {
        state = BaseNode::tsIgnore;
    }
    else if ( selectedAction == &action2)
    {
        state = BaseNode::tsPosible;
    }
    else
    {
        state = BaseNode::tsNeeded;
    }
    index->node()->setTemplateState(state);

    updateText( item );
}


void MainWindow::on_actionEnde_triggered()
{
    close();
}


void MainWindow::on_actionNeu_triggered()
{
    QString filePath = QFileDialog::getExistingDirectory(this,
                                                    tr("Datenverzeichnis anlegen"),
                                                    QDir::homePath()
                                                    );

    if (filePath.isEmpty() == false)
    {
        m_home = filePath;
        setTemplateMode(true);
        save();

        ui->actionNeu->setEnabled(false);
        ui->action_ffnen->setEnabled(false);

        ui->actionSchlie_en->setEnabled(true);
        ui->actionSpeichern->setEnabled(true);

    }
}


void MainWindow::on_action_ffnen_triggered()
{
    QString filePath = QFileDialog::getExistingDirectory(this,
                                                         tr("Datenverzeichnis öffnen"),
                                                         QDir::homePath()
                                                         );

    if (filePath.isEmpty() == false)
    {
        m_home = filePath;
        setTemplateMode(true);
        load();        

        ui->actionNeu->setEnabled(false);
        ui->action_ffnen->setEnabled(false);
        ui->actionSchlie_en->setEnabled(true);
        ui->actionSpeichern->setEnabled(true);

    }
}


void MainWindow::on_actionSpeichern_triggered()
{
    if (m_templateMode == true)
    {
        save();
    }
}


void MainWindow::on_actionSchlie_en_triggered()
{
    ui->actionNeu->setEnabled(true);
    ui->action_ffnen->setEnabled(true);
    ui->actionSchlie_en->setEnabled(false);
    ui->actionSpeichern->setEnabled(false);

    save();

    setTemplateMode(false);
}


void MainWindow::on_treeWidget_currentItemChanged(QTreeWidgetItem *current, QTreeWidgetItem *previous)
{
    Q_UNUSED(previous);

    if ( m_templateMode == false)
    {
        return;
    }
    QVariant variant = current->data(0, Qt::UserRole);
    quintptr ptr = variant.value<quintptr>();


    IndexNode* index = reinterpret_cast<IndexNode*>(ptr);

    if ( ( index == nullptr ) || ( index->node() == nullptr) )
    {
        return;
    }
    ui->widget->setId(index->id());
}

void MainWindow::onDownloadFinished(QNetworkReply *reply)
{
    auto error = reply->error();

    if ( error == QNetworkReply::NoError)
    {
        QFile file(m_xml);
        QFileInfo info( file );

        QDir dir(info.absolutePath());

        if ( dir.exists() == false)
        {
            dir.mkpath(info.absolutePath());
        }


        if (file.open(QIODevice::WriteOnly))
        {
            QByteArray data = reply->readAll();
            file.write(data);
            file.close();

            loadXML(m_xml);
        }
    }

    reply->deleteLater();
}

