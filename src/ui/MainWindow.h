#ifndef UI_MAINWINDOW_H
#define UI_MAINWINDOW_H

#include "app/AppContext.h"
#include "domain/ApplicabilityStatus.h"
#include "domain/AssessmentStatus.h"
#include "domain/Project.h"
#include "domain/Requirement.h"
#include "domain/RequirementAssessment.h"
#include "domain/TargetObject.h"
#include "ui/models/BausteinTreeModel.h"
#include "ui/models/MeasureTableModel.h"
#include "ui/models/RequirementTableModel.h"
#include "ui/models/TargetObjectTreeModel.h"

#include <QHash>
#include <QMainWindow>

class QCheckBox;
class QComboBox;
class QDateEdit;
class QLabel;
class QLineEdit;
class QAction;
class QPushButton;
class QProgressBar;
class QTableView;
class QTextEdit;
class QTreeView;

struct SessionSelection {
    int targetObjectId = 0;
    int bausteinId = 0;
    int requirementId = 0;
};

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    explicit MainWindow(AppContext &context, QWidget *parent = nullptr);

private slots:
    void importCatalog();
    void createProject();
    void openProject();
    void closeProject();
    void editProject();
    void deleteProject();
    void onTargetObjectSelected(const QModelIndex &index);
    void onBausteinSelected(const QModelIndex &index);
    void onRequirementSelected(const QModelIndex &index);
    void setAssessmentStatus(int index);
    void saveAssessmentFields();
    void addMeasure();
    void editMeasure();
    void deleteMeasure();
    void addTargetObject();
    void editTargetObject();
    void deleteTargetObject();
    void showTargetObjectContextMenu(const QPoint &pos);
    void showBausteinContextMenu(const QPoint &pos);
    void setBausteinApplicability(ApplicabilityStatus status);
    void toggleApplicableFilter(bool enabled);
    void toggleRecommendationHighlight(bool enabled);
    void applyBausteinRecommendations();
    void showSollIstReport();

private:
    void buildUi();
    void reloadCatalog();
    void reloadTargetObjects();
    void reloadApplicabilityMarkers();
    void reloadRecommendationMarkers();
    void reloadBausteinMarkers();
    void reloadProgress();
    void loadRequirementsForBaustein(int bausteinDbId);
    void loadRequirementDetails(int row, bool forceReload = false);
    void refreshCurrentRequirementView();
    int activeBausteinIdFromTree() const;
    void persistTargetSelection(int targetObjectId);
    void restoreTargetSelection(int targetObjectId);
    bool isBausteinApplicableForActiveTarget(int bausteinDbId) const;
    bool hasApplicableBausteineForActiveTarget() const;
    void ensureApplicableFilterFeasible();
    void showBausteinNotApplicableMessage(int bausteinDbId, ApplicabilityStatus status);
    void refreshAssessmentColumn();
    void syncAssessmentUi(const RequirementAssessment &assessment);
    void loadMeasuresForCurrentRequirement();
    bool saveAssessmentFor(int targetObjectId, int requirementDbId);
    bool saveCurrentAssessment();
    Requirement currentRequirement() const;
    void updateWindowTitle();
    void updateProjectUiEnabled();
    void clearProjectSession();
    void clearRequirementView();
    void reloadActiveTargetContent();
    void restoreBausteinSelection(int bausteinId);
    void persistSessionSelection();
    SessionSelection loadStoredSession(int projectId) const;
    void selectActiveTargetObjectInTree();
    void showTemporaryStatusMessage(const QString &message, int timeoutMs = 5000);
    int activeTargetObjectId() const;
    bool hasActiveProjectContext() const;

    AppContext &m_context;
    Project m_activeProject;
    TargetObject m_activeTargetObject;
    int m_activeBausteinId = 0;
    int m_activeRequirementId = 0;
    int m_restoreRequirementId = 0;
    int m_displayedAssessmentTargetId = 0;
    int m_preferredTargetObjectId = 0;
    int m_preferredBausteinId = 0;
    int m_preferredRequirementId = 0;
    bool m_suppressAssessmentSave = false;
    bool m_blockBausteinSelectionHandler = false;
    QHash<int, int> m_lastBausteinByTarget;
    QHash<int, int> m_lastRequirementByTarget;
    QHash<int, SessionSelection> m_sessionByProject;

    TargetObjectTreeModel *m_targetObjectModel = nullptr;
    BausteinTreeModel *m_bausteinModel = nullptr;
    RequirementTableModel *m_requirementModel = nullptr;
    MeasureTableModel *m_measureModel = nullptr;

    QTreeView *m_targetObjectTree = nullptr;
    QTreeView *m_bausteinTree = nullptr;
    QTableView *m_requirementTable = nullptr;
    QTableView *m_measureTable = nullptr;
    QTextEdit *m_requirementText = nullptr;
    QTextEdit *m_assessmentNote = nullptr;
    QLineEdit *m_responsibleEdit = nullptr;
    QDateEdit *m_dueDateEdit = nullptr;
    QComboBox *m_statusBox = nullptr;
    QCheckBox *m_filterApplicableBox = nullptr;
    QCheckBox *m_highlightRecommendationsBox = nullptr;
    QCheckBox *m_hasDueDateBox = nullptr;
    QPushButton *m_addMeasureButton = nullptr;
    QPushButton *m_editMeasureButton = nullptr;
    QPushButton *m_deleteMeasureButton = nullptr;
    QLabel *m_statusLabel = nullptr;
    QLabel *m_contextLabel = nullptr;
    QLabel *m_projectProgressLabel = nullptr;
    QLabel *m_targetProgressLabel = nullptr;
    QProgressBar *m_projectProgressBar = nullptr;
    QProgressBar *m_targetProgressBar = nullptr;

    QAction *m_closeProjectAction = nullptr;
    QAction *m_editProjectAction = nullptr;
    QAction *m_deleteProjectAction = nullptr;
    QAction *m_addTargetAction = nullptr;
    QAction *m_editTargetAction = nullptr;
    QAction *m_deleteTargetAction = nullptr;
    QAction *m_applyRecommendationsAction = nullptr;
    QAction *m_sollIstAction = nullptr;
};

#endif
