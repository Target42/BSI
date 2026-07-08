#ifndef UI_BAUSTEINRECOMMENDATIONDIALOG_H
#define UI_BAUSTEINRECOMMENDATIONDIALOG_H

#include "domain/ApplicabilityStatus.h"
#include "domain/BausteinRecommendation.h"
#include "domain/TargetObject.h"

#include <QDialog>
#include <QHash>
#include <QList>

struct BausteinRecommendationSelection {
    int bausteinDbId = 0;
    ApplicabilityStatus status = ApplicabilityStatus::Possible;
};

class QComboBox;
class QTableWidget;

class BausteinRecommendationDialog : public QDialog
{
    Q_OBJECT

public:
    BausteinRecommendationDialog(const QList<BausteinRecommendation> &recommendations,
                                 const QHash<int, ApplicabilityStatus> &currentApplicability,
                                 const TargetObject &targetObject,
                                 QWidget *parent = nullptr);

    QList<BausteinRecommendationSelection> selections() const;

private:
    void populateTable();

    QList<BausteinRecommendation> m_recommendations;
    QHash<int, ApplicabilityStatus> m_currentApplicability;
    TargetObject m_targetObject;
    QTableWidget *m_table = nullptr;
    QComboBox *m_statusBox = nullptr;
};

#endif
