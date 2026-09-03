#include "TextEditorDialog.h"

#include "ui/spell/HunspellSpellSupport.h"

#include <QDialogButtonBox>
#include <QTextEdit>
#include <QVBoxLayout>

TextEditorDialog::TextEditorDialog(QWidget *parent)
    : QDialog(parent)
{
    setWindowTitle(tr("Texteditor"));
    resize(720, 480);
    setSizeGripEnabled(true);

    m_editor = new QTextEdit(this);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, this);
    connect(buttons, &QDialogButtonBox::accepted, this, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);

    auto *layout = new QVBoxLayout(this);
    layout->addWidget(m_editor, 1);
    layout->addWidget(buttons);
}

void TextEditorDialog::setEditorTitle(const QString &title)
{
    if (!title.isEmpty())
        setWindowTitle(title);
}

void TextEditorDialog::setText(const QString &text)
{
    m_editor->setPlainText(text);
}

QString TextEditorDialog::text() const
{
    return m_editor->toPlainText();
}

void TextEditorDialog::setReadOnly(bool readOnly)
{
    m_editor->setReadOnly(readOnly);
}

void TextEditorDialog::attachSpellChecker(spell::HunspellSpellChecker *checker)
{
    spell::attachSpellSupport(checker, m_editor);
}

bool TextEditorDialog::editText(QWidget *parent, const QString &title, QString *text, bool readOnly,
                                spell::HunspellSpellChecker *checker)
{
    if (text == nullptr)
        return false;

    TextEditorDialog dialog(parent);
    dialog.setEditorTitle(title);
    dialog.setText(*text);
    dialog.setReadOnly(readOnly);
    dialog.attachSpellChecker(checker);
    if (dialog.exec() != QDialog::Accepted)
        return false;
    if (readOnly)
        return false;
    *text = dialog.text();
    return true;
}
