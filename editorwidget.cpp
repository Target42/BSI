#include "editorwidget.h"
#include "ui_editorwidget.h"

#include <QDir>
#include <QFile>

EditorWidget::EditorWidget(QWidget *parent)
    : QWidget(parent)
    , ui(new Ui::EditorWidget)
{
    ui->setupUi(this);
    this->setLayout(ui->gridLayout);
    m_changed = false;

    setEnabled(false);
}

EditorWidget::~EditorWidget()
{
    if ( ( m_id.isEmpty() == false) && (m_changed == true ) )
    {
        save();
    }
    delete ui;
}

QString EditorWidget::id() const
{
    return m_id;
}

void EditorWidget::setId(const QString &newId)
{
    m_id = newId;

    ui->textEdit->clear();

    QString fname = QDir::cleanPath( m_home + QDir::separator() + m_id+".md");

    QFile file(fname);
    if (file.exists() == true)
    {
        if (file.open(QIODevice::ReadOnly | QIODevice::Text))
        {
            // Lese den gesamten Inhalt der Datei
            QTextStream in(&file);
            QString content = in.readAll();
            file.close();

            // Setze den Text in das QTextEdit
            ui->checkBox->setChecked(true);
            ui->textEdit->setMarkdown(content);
        }
    }

    m_changed = false;
}

void EditorWidget::setMarkdownMode(bool flag)
{
    m_isMarkdownMode = flag;

    if (m_isMarkdownMode == true)
    {
        // Wechsel in den Markdown-Anzeigemodus
        QString plainTextContent = ui->textEdit->toPlainText();
        ui->textEdit->setMarkdown(plainTextContent);
        ui->textEdit->setReadOnly(true); // Deaktiviere die Bearbeitung
    }
    else
    {
        // Wechsel zurück in den Bearbeitungsmodus
        QString plainTextContent = ui->textEdit->toMarkdown();
        ui->textEdit->setPlainText(plainTextContent);
        ui->textEdit->setReadOnly(false);
    }
}

void EditorWidget::save()
{
    QString fname = QDir::cleanPath( m_home + QDir::separator() + m_id+".md");

    QFile file(fname);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text))
    {
        QTextStream out(&file);
        out << ui->textEdit->toMarkdown();
        file.close();
    }
    m_changed = false;
}

void EditorWidget::on_checkBox_clicked(bool checked)
{
    setMarkdownMode(checked);
}

bool EditorWidget::enabled() const
{
    return m_enabled;
}

void EditorWidget::setEnabled(bool newEnabled)
{
    m_enabled = newEnabled;
    ui->checkBox->setEnabled(m_enabled);
    ui->textEdit->setEnabled(m_enabled);
    ui->pushButton->setEnabled(m_enabled);
    ui->pushButton_2->setEnabled(m_enabled);
}

QString EditorWidget::home() const
{
    return m_home;
}

void EditorWidget::setHome(const QString &newHome)
{
    m_home = newHome;
}


void EditorWidget::on_pushButton_clicked()
{
    QString fname = QDir::cleanPath( m_home + QDir::separator() + m_id+".md");

    QFile file(fname);
    if (file.exists() == true)
    {
        file.remove();
        ui->textEdit->clear();
    }
}


void EditorWidget::on_textEdit_textChanged()
{
    m_changed = true;
}


void EditorWidget::on_pushButton_2_clicked()
{
    save();
}

