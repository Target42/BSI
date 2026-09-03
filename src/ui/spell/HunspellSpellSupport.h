#ifndef UI_SPELL_HUNSPELLSPELLSUPPORT_H
#define UI_SPELL_HUNSPELLSPELLSUPPORT_H

#include <QSyntaxHighlighter>
#include <QTextEdit>
#include <QTextCharFormat>
#include <QTextCursor>
#include <QRegularExpression>
#include <QTextBlock>
#include <QStringList>
#include <QHash>
#include <QObject>

// Built with qmake: when the hunspell dev headers/libs are present,
// we define HAVE_HUNSPELL to enable the actual integration.
// Otherwise the implementation becomes a no-op.
#ifdef HAVE_HUNSPELL
#include <hunspell/hunspell.h>
#endif

namespace spell {

class HunspellSpellChecker
{
public:
    HunspellSpellChecker();
    ~HunspellSpellChecker();

    bool isAvailable() const { return m_enabled; }
    bool isCorrect(const QString &word);
    QStringList suggestions(const QString &word);

private:
    bool tryInit();

    void clearCaches();

#ifdef HAVE_HUNSPELL
    Hunhandle *m_handle = nullptr;
#endif

    bool m_enabled = false;
    QString m_dictionaryName;

    // Speed up repeated highlighting.
    QHash<QString, bool> m_correctCache;
    QHash<QString, QStringList> m_suggestionCache;
};

class HunspellHighlighter : public QSyntaxHighlighter
{
public:
    HunspellHighlighter(HunspellSpellChecker *checker, QTextDocument *doc);

protected:
    void highlightBlock(const QString &text) override;

private:
    HunspellSpellChecker *m_checker = nullptr;
    QRegularExpression m_wordRegex;
    QTextCharFormat m_misspelledFormat;
};

class HunspellSpellContextMenuFilter : public QObject
{
public:
    HunspellSpellContextMenuFilter(HunspellSpellChecker *checker, QTextEdit *textEdit);

protected:
    bool eventFilter(QObject *obj, QEvent *event) override;

private:
    HunspellSpellChecker *m_checker = nullptr;
    QTextEdit *m_textEdit = nullptr;
};

void attachSpellSupport(HunspellSpellChecker *checker, QTextEdit *textEdit);

} // namespace spell

#endif // UI_SPELL_HUNSPELLSPELLSUPPORT_H

