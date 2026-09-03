#include "HunspellSpellSupport.h"

#include <QContextMenuEvent>
#include <QMenu>

#include <algorithm>
#include <QFile>

namespace spell {

#ifdef HAVE_HUNSPELL
static QStringList buildHunspellPairsFromCandidates()
{
    return {
        QStringLiteral("hunspell:/usr/share/hunspell/de_DE"),
        QStringLiteral("myspell:/usr/share/myspell/dictionaries/de_DE"),
        QStringLiteral("hunspell:/usr/share/hunspell/de-DE"),
    };
}
#endif

HunspellSpellChecker::HunspellSpellChecker()
{
    m_dictionaryName = QStringLiteral("de_DE");
#ifdef HAVE_HUNSPELL
    tryInit();
#else
    m_enabled = false;
#endif
}

HunspellSpellChecker::~HunspellSpellChecker()
{
#ifdef HAVE_HUNSPELL
    if (m_handle != nullptr) {
        Hunspell_destroy(m_handle);
        m_handle = nullptr;
    }
#endif
}

bool HunspellSpellChecker::tryInit()
{
#ifdef HAVE_HUNSPELL
    if (m_handle != nullptr)
        return true;

    // Try a few standard dictionary locations.
    // hunspell_create expects: (affpath, dpath) where dpath is the .dic
    const QStringList pairBases = buildHunspellPairsFromCandidates();
    for (const QString &base : pairBases) {
        const QString affPath = base.section(':', 1, 1) + QStringLiteral(".aff");
        const QString dicPath = base.section(':', 1, 1) + QStringLiteral(".dic");

        if (!QFile::exists(affPath) || !QFile::exists(dicPath))
            continue;

        const QByteArray affUtf8 = affPath.toUtf8();
        const QByteArray dicUtf8 = dicPath.toUtf8();

        m_handle = Hunspell_create(affUtf8.constData(), dicUtf8.constData());
        if (m_handle != nullptr) {
            m_enabled = true;
            clearCaches();
            return true;
        }
    }

#endif
    m_enabled = false;
    return false;
}

void HunspellSpellChecker::clearCaches()
{
    m_correctCache.clear();
    m_suggestionCache.clear();
}

bool HunspellSpellChecker::isCorrect(const QString &word)
{
    if (!m_enabled)
        return true; // fail-open: no underline if checker isn't available.

    QString trimmed = word.trimmed();
    if (trimmed.isEmpty())
        return true;

    // Skip very short tokens (mostly: articles/prepositions).
    if (trimmed.size() < 3)
        return true;

    auto it = m_correctCache.constFind(trimmed);
    if (it != m_correctCache.cend())
        return it.value();

#ifdef HAVE_HUNSPELL
    QByteArray utf8 = trimmed.toUtf8();
    const int ok = Hunspell_spell(m_handle, utf8.constData());

    // Hunspell dictionaries are usually lower-case; check both forms.
    bool correct = ok != 0;
    if (!correct) {
        const QString lower = trimmed.toLower();
        if (lower != trimmed) {
            QByteArray lowerUtf8 = lower.toUtf8();
            correct = Hunspell_spell(m_handle, lowerUtf8.constData()) != 0;
        }
    }

    m_correctCache.insert(trimmed, correct);
    return correct;
#else
    return true;
#endif
}

QStringList HunspellSpellChecker::suggestions(const QString &word)
{
    if (!m_enabled)
        return {};

    QString trimmed = word.trimmed();
    if (trimmed.isEmpty() || trimmed.size() < 3)
        return {};

    auto it = m_suggestionCache.constFind(trimmed);
    if (it != m_suggestionCache.cend())
        return it.value();

#ifdef HAVE_HUNSPELL
    QByteArray utf8 = trimmed.toUtf8();
    char **slst = nullptr; // Hunspell will allocate *slst (char** list)
    int count = Hunspell_suggest(m_handle, &slst, utf8.constData());

    QStringList result;
    if (count > 0 && slst != nullptr) {
        const int limit = std::min(count, 10);
        for (int i = 0; i < limit; ++i) {
            // slst points to an array of char*, so we access slst[i].
            const char *s = slst[i];
            if (s != nullptr) {
                const QString sug = QString::fromUtf8(s);
                if (!sug.isEmpty())
                    result.push_back(sug);
            }
        }
        Hunspell_free_list(m_handle, &slst, count);
    }

    // Cache (even empty) so highlight/context menu stay fast.
    m_suggestionCache.insert(trimmed, result);
    return result;
#else
    return {};
#endif
}

HunspellHighlighter::HunspellHighlighter(HunspellSpellChecker *checker, QTextDocument *doc)
    : QSyntaxHighlighter(doc)
    , m_checker(checker)
{
    // Allow umlauts + ß, and optional hyphen compounds.
    m_wordRegex = QRegularExpression(
        QStringLiteral(R"(\b[A-Za-zÄÖÜäöüß]+(?:-[A-Za-zÄÖÜäöüß]+)?\b)"));

    m_misspelledFormat.setUnderlineStyle(QTextCharFormat::WaveUnderline);
    m_misspelledFormat.setUnderlineColor(Qt::red);
}

void HunspellHighlighter::highlightBlock(const QString &text)
{
    if (m_checker == nullptr || !m_checker->isAvailable())
        return;

    // If you want to avoid underlines in e.g. numbers/markup, extend this regex here.
    auto it = m_wordRegex.globalMatch(text);
    while (it.hasNext()) {
        const QRegularExpressionMatch match = it.next();
        const QString word = match.captured();
        if (word.isEmpty())
            continue;

        if (!m_checker->isCorrect(word)) {
            setFormat(match.capturedStart(), match.capturedLength(), m_misspelledFormat);
        }
    }
}

HunspellSpellContextMenuFilter::HunspellSpellContextMenuFilter(HunspellSpellChecker *checker,
                                                                QTextEdit *textEdit)
    : QObject(textEdit)
    , m_checker(checker)
    , m_textEdit(textEdit)
{
}

bool HunspellSpellContextMenuFilter::eventFilter(QObject *obj, QEvent *event)
{
    if (m_checker == nullptr || !m_checker->isAvailable())
        return QObject::eventFilter(obj, event);

    if (event->type() != QEvent::ContextMenu)
        return QObject::eventFilter(obj, event);

    auto *ce = static_cast<QContextMenuEvent *>(event);

    // We only show suggestions when the user right-clicks a misspelled word.
    // Note: the context menu event may arrive from the viewport; use globalPos()
    // to map into the QTextEdit coordinate system.
    const QPoint localPos = m_textEdit->mapFromGlobal(ce->globalPos());
    const QTextCursor cursor = m_textEdit->cursorForPosition(localPos);
    QTextCursor wcursor = cursor;
    wcursor.select(QTextCursor::WordUnderCursor);
    const QString word = wcursor.selectedText();

    if (word.trimmed().isEmpty())
        return QObject::eventFilter(obj, event);

    if (m_checker->isCorrect(word))
        return QObject::eventFilter(obj, event);

    const QStringList sugg = m_checker->suggestions(word);
    if (sugg.isEmpty())
        return QObject::eventFilter(obj, event);

    QMenu menu;

    // Provide common edit actions even when we handle the right-click ourselves.
    menu.addAction(tr("Kopieren"), m_textEdit, &QTextEdit::copy);
    if (!m_textEdit->isReadOnly())
        menu.addAction(tr("Ausschneiden"), m_textEdit, &QTextEdit::cut);
    menu.addAction(tr("Einfügen"), m_textEdit, &QTextEdit::paste);
    menu.addSeparator();

    for (const QString &s : sugg) {
        auto *act = menu.addAction(s);
        if (m_textEdit->isReadOnly()) {
            act->setEnabled(false);
            continue;
        }
        connect(act, &QAction::triggered, &menu, [this, wcursor, s]() mutable {
            QTextCursor replaceCursor = wcursor;
            replaceCursor.beginEditBlock();
            replaceCursor.insertText(s);
            replaceCursor.endEditBlock();
        });
    }

    menu.exec(ce->globalPos());
    return true;
}

void attachSpellSupport(HunspellSpellChecker *checker, QTextEdit *textEdit)
{
    if (checker == nullptr || textEdit == nullptr || !checker->isAvailable())
        return;

    new HunspellHighlighter(checker, textEdit->document());
    auto *filter = new HunspellSpellContextMenuFilter(checker, textEdit);
    textEdit->installEventFilter(filter);
    if (textEdit->viewport() != nullptr)
        textEdit->viewport()->installEventFilter(filter);
}

} // namespace spell

