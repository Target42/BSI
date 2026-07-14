#include "RequirementTextFormatter.h"

#include <QRegularExpression>

namespace {

struct HighlightRule {
    const char *word;
    const char *color;
    bool bold;
    bool italic;
};

// Longer phrases first so e.g. SOLLTE is not split into SOLL + TE.
constexpr HighlightRule kRules[] = {
    {"MUSS NICHT", "#b71c1c", true, false},
    {"SOLL NICHT", "#e65100", true, false},
    {"DARF NICHT", "#2e7d32", true, false},
    {"KÖNNEN NICHT", "#616161", false, true},
    {"KANN NICHT", "#616161", false, true},
    {"MÜSSEN", "#c62828", true, false},
    {"MUSSTEN", "#c62828", true, false},
    {"MUSSTE", "#c62828", true, false},
    {"SOLLTEN", "#e65100", true, false},
    {"SOLLTE", "#e65100", true, false},
    {"SOLLEN", "#e65100", true, false},
    {"KÖNNEN", "#616161", false, true},
    {"KONNTEN", "#616161", false, true},
    {"KONNTE", "#616161", false, true},
    {"DÜRFEN", "#2e7d32", true, false},
    {"DURFTEN", "#2e7d32", true, false},
    {"DURFTE", "#2e7d32", true, false},
    {"MUSS", "#c62828", true, false},
    {"SOLL", "#e65100", true, false},
    {"KANN", "#616161", false, true},
    {"DARF", "#2e7d32", true, false},
};

QString wordPattern(const QString &word)
{
    return QStringLiteral("(?<![A-Za-zÄÖÜäöüß])(%1)(?![A-Za-zÄÖÜäöüß])")
        .arg(QRegularExpression::escape(word));
}

QString replacementFor(const HighlightRule &rule)
{
    QString style = QStringLiteral("color:%1").arg(QString::fromUtf8(rule.color));
    if (rule.bold)
        style += QStringLiteral(";font-weight:bold");
    if (rule.italic)
        style += QStringLiteral(";font-style:italic");
    return QStringLiteral(R"(<span style="%1">\1</span>)").arg(style);
}

} // namespace

namespace RequirementTextFormatter {

QString formatEscaped(const QString &text)
{
    QString html = text.toHtmlEscaped();
    html.replace(QLatin1Char('\n'), QStringLiteral("<br>"));

    for (const HighlightRule &rule : kRules) {
        const QString word = QString::fromUtf8(rule.word);
        QRegularExpression expression(wordPattern(word),
                                      QRegularExpression::CaseInsensitiveOption);
        html.replace(expression, replacementFor(rule));
    }

    return html;
}

QString toHtml(const QString &text)
{
    return QStringLiteral("<html><body style=\"font-family:'Segoe UI',sans-serif;\">%1</body></html>")
        .arg(formatEscaped(text));
}

} // namespace RequirementTextFormatter
