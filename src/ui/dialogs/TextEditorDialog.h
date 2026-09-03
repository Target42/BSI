#ifndef UI_TEXTEDITORDIALOG_H
#define UI_TEXTEDITORDIALOG_H

#include <QDialog>
#include <QString>

class QTextEdit;

namespace spell {
class HunspellSpellChecker;
}

class TextEditorDialog : public QDialog
{
    Q_OBJECT

public:
    explicit TextEditorDialog(QWidget *parent = nullptr);

    void setEditorTitle(const QString &title);
    void setText(const QString &text);
    QString text() const;
    void setReadOnly(bool readOnly);
    void attachSpellChecker(spell::HunspellSpellChecker *checker);

    static bool editText(QWidget *parent, const QString &title, QString *text, bool readOnly,
                         spell::HunspellSpellChecker *checker = nullptr);

private:
    QTextEdit *m_editor = nullptr;
};

#endif
