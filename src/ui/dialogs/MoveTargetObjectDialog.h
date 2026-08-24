#ifndef UI_MOVETARGETOBJECTDIALOG_H
#define UI_MOVETARGETOBJECTDIALOG_H

#include "domain/TargetObject.h"

#include <QDialog>
#include <QList>

class QListWidget;

class MoveTargetObjectDialog : public QDialog
{
    Q_OBJECT

public:
    MoveTargetObjectDialog(const QList<TargetObject> &objects, const TargetObject &moving,
                           QWidget *parent = nullptr);

    int selectedParentId() const;
    bool hasDestinations() const;

protected:
    void accept() override;

private:
    QList<TargetMoveDestination> m_destinations;
    QListWidget *m_list = nullptr;
};

#endif
