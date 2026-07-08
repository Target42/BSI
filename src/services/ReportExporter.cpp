#include "ReportExporter.h"

#include "domain/ApplicabilityStatus.h"
#include "domain/AssessmentStatus.h"

#include <QDateTime>
#include <QFile>
#include <QLocale>
#include <QPageLayout>
#include <QPrinter>
#include <QTextDocument>
#include <QTextStream>

namespace {

QString csvField(const QString &value)
{
    QString escaped = value;
    escaped.replace('"', QStringLiteral("\"\""));
    if (escaped.contains('"') || escaped.contains(';') || escaped.contains('\n'))
        return QStringLiteral("\"%1\"").arg(escaped);
    return escaped;
}

QString formatDate(const QDate &date)
{
    if (!date.isValid())
        return {};
    return QLocale().toString(date, QLocale::ShortFormat);
}

} // namespace

bool ReportExporter::exportCsv(const QString &filePath, const QList<ReportRow> &rows, QString &errorMessage)
{
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        errorMessage = file.errorString();
        return false;
    }

    QTextStream stream(&file);
    stream.setEncoding(QStringConverter::Utf8);
    stream << QStringLiteral("\xEF\xBB\xBF");
    stream << QStringLiteral("Zielobjekt;Baustein;Baustein-Titel;Anforderung;Titel;Stufe;Anwendbarkeit;Status;Verantwortlich;Frist;Maßnahmen;Überfällig\n");

    for (const ReportRow &row : rows) {
        stream << csvField(row.targetObjectName) << ';'
               << csvField(row.bausteinExternalId) << ';'
               << csvField(row.bausteinTitle) << ';'
               << csvField(row.requirementExternalId) << ';'
               << csvField(row.requirementTitle) << ';'
               << csvField(row.level) << ';'
               << csvField(applicabilityStatusToString(row.applicability)) << ';'
               << csvField(assessmentStatusToString(row.status)) << ';'
               << csvField(row.responsible) << ';'
               << csvField(formatDate(row.dueDate)) << ';'
               << row.measureCount << ';'
               << (row.overdue ? QStringLiteral("Ja") : QStringLiteral("Nein")) << '\n';
    }

    return true;
}

bool ReportExporter::exportPdf(const QString &filePath,
                               const Project &project,
                               const ReportSummary &summary,
                               const QList<ReportRow> &rows,
                               QString &errorMessage)
{
    QString html;
    html += QStringLiteral("<html><head><meta charset=\"utf-8\"><style>"
                           "body{font-family:Arial,sans-serif;font-size:10pt;}"
                           "h1{font-size:16pt;} table{border-collapse:collapse;width:100%;}"
                           "th,td{border:1px solid #888;padding:4px;text-align:left;}"
                           "th{background:#eee;} .overdue{color:red;}"
                           "</style></head><body>");
    html += QStringLiteral("<h1>Soll-Ist-Bericht</h1>");
    html += QStringLiteral("<p><b>Projekt:</b> %1<br><b>Erstellt:</b> %2</p>")
                .arg(project.name.toHtmlEscaped(),
                     QLocale().toString(QDateTime::currentDateTime(), QLocale::ShortFormat));

    html += QStringLiteral("<p>"
                           "Anforderungen gesamt: %1 &nbsp;|&nbsp; "
                           "Offen: %2 &nbsp;|&nbsp; "
                           "Teilweise: %3 &nbsp;|&nbsp; "
                           "Erfüllt: %4 &nbsp;|&nbsp; "
                           "Entfällt: %5 &nbsp;|&nbsp; "
                           "Überfällig: %6 &nbsp;|&nbsp; "
                           "Maßnahmen: %7"
                           "</p>")
                .arg(summary.totalRequirements)
                .arg(summary.openCount)
                .arg(summary.partialCount)
                .arg(summary.fulfilledCount)
                .arg(summary.notApplicableCount)
                .arg(summary.overdueCount)
                .arg(summary.measureCount);

    html += QStringLiteral("<table><thead><tr>"
                           "<th>Zielobjekt</th><th>Baustein</th><th>Anforderung</th>"
                           "<th>Stufe</th><th>Status</th><th>Verantwortlich</th>"
                           "<th>Frist</th><th>Maßn.</th>"
                           "</tr></thead><tbody>");

    for (const ReportRow &row : rows) {
        const QString rowClass = row.overdue ? QStringLiteral(" class=\"overdue\"") : QString();
        html += QStringLiteral("<tr%1>").arg(rowClass);
        html += QStringLiteral("<td>%1</td>").arg(row.targetObjectName.toHtmlEscaped());
        html += QStringLiteral("<td>%1</td>").arg(row.bausteinExternalId.toHtmlEscaped());
        html += QStringLiteral("<td>%1 – %2</td>")
                    .arg(row.requirementExternalId.toHtmlEscaped(), row.requirementTitle.toHtmlEscaped());
        html += QStringLiteral("<td>%1</td>").arg(row.level.toHtmlEscaped());
        html += QStringLiteral("<td>%1</td>").arg(assessmentStatusToString(row.status).toHtmlEscaped());
        html += QStringLiteral("<td>%1</td>").arg(row.responsible.toHtmlEscaped());
        html += QStringLiteral("<td>%1</td>").arg(formatDate(row.dueDate).toHtmlEscaped());
        html += QStringLiteral("<td>%1</td>").arg(row.measureCount);
        html += QStringLiteral("</tr>");
    }

    html += QStringLiteral("</tbody></table></body></html>");

    QTextDocument document;
    document.setHtml(html);

    QPrinter printer(QPrinter::HighResolution);
    printer.setOutputFormat(QPrinter::PdfFormat);
    printer.setPageOrientation(QPageLayout::Landscape);
    printer.setOutputFileName(filePath);

    if (!printer.isValid()) {
        errorMessage = QStringLiteral("PDF-Drucker konnte nicht initialisiert werden.");
        return false;
    }

    document.print(&printer);
    return true;
}
