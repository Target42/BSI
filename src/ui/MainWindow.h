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
#include <QSet>

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
class QTimer;
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

protected:
    void closeEvent(QCloseEvent *event) override;

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
    void showProjectMembers();
    void switchUserOrLogout();
    void checkRemoteSession();
    void onAssignedBausteinActivated(int index);
    void applyBausteinSearchFilter();
    void viewSelectedBaustein();
    void showCatalogSearch();

private:
    void buildUi();
    void reloadCatalog();
    void reloadTargetObjects();
    void reloadApplicabilityMarkers();
    void reloadRecommendationMarkers();
    void reloadBausteinMarkers();
    void reloadAssignedBausteinBox();
    void syncAssignedBausteinBoxSelection();
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
    bool saveAssessmentFor(int targetObjectId, int requirementDbId, bool notifyConflictDialog = false);
    bool saveCurrentAssessment(bool notifyConflictDialog = false);
    void applyAssessmentConflict(const RequirementAssessment &serverAssessment, int requirementDbId,
                                 bool showDialog);
    QString sessionSettingsGroup(int projectId) const;
    Requirement currentRequirement() const;
    void updateWindowTitle();
    void updateProjectUiEnabled();
    bool canEditActiveProject() const;
    bool canDeleteActiveProject() const;
    bool canManageProjectMembers() const;
    void notifySaveFailure(const QString &repositoryError, bool useDialog);
    void clearProjectSession();
    void clearRequirementView();
    void reloadActiveTargetContent();
    void restoreBausteinSelection(int bausteinId);
    void revertBausteinTreeSelection(int bausteinDbId);
    void persistSessionSelection();
    void persistAllTargetSelections();
    void loadStoredTargetSelections(int projectId);
    SessionSelection loadStoredSession(int projectId) const;
    void selectActiveTargetObjectInTree();
    void showTemporaryStatusMessage(const QString &message, int timeoutMs = 5000);
    void configureRemoteSessionWatcher();
    int activeTargetObjectId() const;
    bool hasActiveProjectContext() const;
    QSet<int> matchingBausteinIdsForSearch(const QString &query) const;
    void openBausteinViewDialog(const Baustein &baustein, const QString &initialSearch = {});

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
    int m_lastConflictNotifiedRequirementId = 0;
    bool m_suppressAssessmentSave = false;
    bool m_blockBausteinSelectionHandler = false;
    bool m_blockAssignedBausteinBoxHandler = false;
    QHash<int, int> m_lastBausteinByTarget;
    QHash<int, int> m_lastRequirementByTarget;
    QHash<int, SessionSelection> m_sessionByProject;

    QList<Baustein> m_catalogBausteine;
    QList<Requirement> m_catalogRequirements;

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
    QComboBox *m_assignedBausteinBox = nullptr;
    QCheckBox *m_filterApplicableBox = nullptr;
    QCheckBox *m_highlightRecommendationsBox = nullptr;
    QLineEdit *m_bausteinSearchEdit = nullptr;
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
    QAction *m_manageMembersAction = nullptr;
    QAction *m_switchUserAction = nullptr;
    QAction *m_reloginAction = nullptr;
    QAction *m_sollIstAction = nullptr;
    QTimer *m_sessionTimer = nullptr;
};

#endif
