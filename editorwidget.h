#ifndef EDITORWIDGET_H
#define EDITORWIDGET_H

#include <QWidget>

namespace Ui {
class EditorWidget;
}

class EditorWidget : public QWidget
{
    Q_OBJECT

public:
    explicit EditorWidget(QWidget *parent = nullptr);
    ~EditorWidget();

    bool loadText( void );
    bool saveText(void);

    QString id() const;
    void setId(const QString &newId);

    QString home() const;
    void setHome(const QString &newHome);

    bool enabled() const;
    void setEnabled(bool newEnabled);

private slots:
    void on_checkBox_checkStateChanged(const Qt::CheckState &arg1);

    void on_checkBox_clicked(bool checked);

    void on_pushButton_clicked();

    void on_textEdit_textChanged();

    void on_pushButton_2_clicked();

private:
    Ui::EditorWidget *ui;
    QString m_id;
    bool m_isMarkdownMode;
    QString m_home;
    bool m_enabled;
    bool m_changed;

    void setMarkdownMode( bool flag );

    void save( void );
};

#endif // EDITORWIDGET_H
