#ifndef CATALOG_REQUIREMENTTEXTFORMATTER_H
#define CATALOG_REQUIREMENTTEXTFORMATTER_H

#include <QString>

namespace RequirementTextFormatter {

QString formatEscaped(const QString &text);
QString toHtml(const QString &text);

} // namespace RequirementTextFormatter

#endif
