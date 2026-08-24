#ifndef UI_TABLEVIEWHELPER_H
#define UI_TABLEVIEWHELPER_H

#include <QHeaderView>
#include <QTableView>

inline void enableResizableColumns(QTableView *table)
{
    if (table == nullptr)
        return;

    QHeaderView *header = table->horizontalHeader();
    header->setSectionResizeMode(QHeaderView::Interactive);
    header->setStretchLastSection(true);
}

#endif
