#include "MainWindow.h"

#include "app/AppPaths.h"
#include "catalog/GrundschutzImporter.h"
#include "domain/AssessmentStatus.h"
#include "domain/Measure.h"
#include "domain/SaveResult.h"
#include "domain/ProtectionNeed.h"
#include "domain/Standard.h"
#include "domain/TargetObject.h"
#include "domain/TargetObjectType.h"
#include "ui/dialogs/BausteinRecommendationDialog.h"
#include "ui/dialogs/BausteinViewDialog.h"
#include "ui/dialogs/CatalogSearchDialog.h"
#include "services/BausteinRecommendationService.h"
#include "services/ReportService.h"
#include "ui/dialogs/MeasureDialog.h"
#include "ui/dialogs/ProjectOpenDialog.h"
#include "ui/dialogs/ProjectDialog.h"
#include "ui/dialogs/ProjectMembersDialog.h"
#include "ui/dialogs/ReportDialog.h"
#include "ui/dialogs/TargetObjectDialog.h"

#include <QAction>
#include <QCloseEvent>
#include <QCheckBox>
#include <QComboBox>
#include <QDate>
#include <QDateEdit>
#include <QDockWidget>
#include <QFileDialog>
#include <QHash>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QItemSelectionModel>
#include <QKeySequence>
#include <QLabel>
#include <QMenu>
#include <QMenuBar>
#include <QMessageBox>
#include <QProgressBar>
#include <QPushButton>
#include <QSet>
#include <QSettings>
#include <QSignalBlocker>
#include <QSplitter>
#include <QStatusBar>
#include <QTableView>
#include <QTimer>
#include <QTextEdit>
#include <QToolBar>
#include <QTreeView>
#include <QVBoxLayout>
#include <QWidget>
#include <QLineEdit>

#include <algorithm>

MainWindow::MainWindow(AppContext &context, QWidget *parent)
    : QMainWindow(parent)
    , m_context(context)
{
    setWindowTitle(QStringLiteral("ISMS Werkzeug"));
    resize(1400, 850);
    buildUi();
    reloadCatalog();
    updateProjectUiEnabled();
    configureRemoteSessionWatcher();
}

void MainWindow::configureRemoteSessionWatcher()
{
    if (m_context.isRemote()) {
        m_context.setReloginHandler([this]() { return m_context.promptRelogin(this); });

        if (m_sessionTimer == nullptr) {
            m_sessionTimer = new QTimer(this);
            m_sessionTimer->setInterval(60000);
            connect(m_sessionTimer, &QTimer::timeout, this, &MainWindow::checkRemoteSession);
        }
        m_sessionTimer->start();
        return;
    }

    m_context.setReloginHandler({});
    if (m_sessionTimer != nullptr)
        m_sessionTimer->stop();
}

void MainWindow::buildUi()
{
    m_targetObjectModel = new TargetObjectTreeModel(this);
    m_bausteinModel = new BausteinTreeModel(this);
    m_requirementModel = new RequirementTableModel(this);
    m_measureModel = new MeasureTableModel(this);

    m_targetObjectTree = new QTreeView(this);
    m_targetObjectTree->setModel(m_targetObjectModel);
    m_targetObjectTree->setHeaderHidden(true);
    m_targetObjectTree->setContextMenuPolicy(Qt::CustomContextMenu);
    connect(m_targetObjectTree->selectionModel(), &QItemSelectionModel::currentChanged, this,
            [this](const QModelIndex &current, const QModelIndex &) {
                onTargetObjectSelected(current);
            });
    connect(m_targetObjectTree, &QTreeView::customContextMenuRequested, this,
            &MainWindow::showTargetObjectContextMenu);

    m_projectProgressLabel = new QLabel(tr("Kein Projekt geöffnet"), this);
    m_projectProgressLabel->setWordWrap(true);
    m_projectProgressBar = new QProgressBar(this);
    m_projectProgressBar->setRange(0, 100);
    m_projectProgressBar->setTextVisible(true);
    m_projectProgressBar->setFormat(tr("%p% abgeschlossen"));
    m_projectProgressBar->setVisible(false);

    auto *targetPanel = new QWidget(this);
    auto *targetLayout = new QVBoxLayout(targetPanel);
    targetLayout->setContentsMargins(4, 4, 4, 4);
    targetLayout->addWidget(m_projectProgressLabel);
    targetLayout->addWidget(m_projectProgressBar);
    targetLayout->addWidget(m_targetObjectTree, 1);

    auto *targetDock = new QDockWidget(tr("Zielobjekte"), this);
    targetDock->setWidget(targetPanel);
    addDockWidget(Qt::LeftDockWidgetArea, targetDock);

    m_filterApplicableBox = new QCheckBox(tr("Nur anwendbare Bausteine"), this);
    m_filterApplicableBox->setToolTip(
        tr("Blendet Bausteine aus, die für das aktuelle Zielobjekt noch nicht per Rechtsklick "
           "als \"Benötigt\" oder \"Möglicherweise\" markiert wurden.\n\n"
           "Zum Markieren: Haken entfernen, Baustein wählen, Rechtsklick → \"Benötigt\"."));
    connect(m_filterApplicableBox, &QCheckBox::toggled, this, &MainWindow::toggleApplicableFilter);

    m_highlightRecommendationsBox = new QCheckBox(tr("Empfehlungen hervorheben"), this);
    m_highlightRecommendationsBox->setToolTip(tr("★ Kern-Empfehlung, ○ ergänzende Empfehlung"));
    m_highlightRecommendationsBox->setChecked(true);
    connect(m_highlightRecommendationsBox, &QCheckBox::toggled, this,
            &MainWindow::toggleRecommendationHighlight);

    m_bausteinSearchEdit = new QLineEdit(this);
    m_bausteinSearchEdit->setPlaceholderText(tr("Bausteine durchsuchen…"));
    m_bausteinSearchEdit->setClearButtonEnabled(true);
    m_bausteinSearchEdit->setToolTip(
        tr("Filtert die Bausteinliste.\nFür eine Volltextsuche über alle Anforderungen: "
           "Katalog → Volltextsuche… (Strg+Umschalt+F)"));
    connect(m_bausteinSearchEdit, &QLineEdit::textChanged, this,
            &MainWindow::applyBausteinSearchFilter);

    auto *bausteinPanel = new QWidget(this);
    auto *bausteinLayout = new QVBoxLayout(bausteinPanel);
    bausteinLayout->setContentsMargins(0, 0, 0, 0);
    bausteinLayout->addWidget(m_bausteinSearchEdit);
    bausteinLayout->addWidget(m_filterApplicableBox);
    bausteinLayout->addWidget(m_highlightRecommendationsBox);

    m_bausteinTree = new QTreeView(this);
    m_bausteinTree->setModel(m_bausteinModel);
    m_bausteinTree->setHeaderHidden(true);
    m_bausteinTree->setContextMenuPolicy(Qt::CustomContextMenu);
    connect(m_bausteinTree->selectionModel(), &QItemSelectionModel::currentChanged, this,
            [this](const QModelIndex &current, const QModelIndex &) {
                onBausteinSelected(current);
            });
    connect(m_bausteinTree, &QTreeView::customContextMenuRequested, this,
            &MainWindow::showBausteinContextMenu);
    connect(m_bausteinTree, &QTreeView::doubleClicked, this, [this](const QModelIndex &index) {
        if (!index.isValid() || index.data(BausteinTreeModel::IsGroupRole).toBool())
            return;
        viewSelectedBaustein();
    });
    bausteinLayout->addWidget(m_bausteinTree);

    auto *catalogDock = new QDockWidget(tr("IT-Grundschutz Bausteine"), this);
    catalogDock->setWidget(bausteinPanel);
    addDockWidget(Qt::LeftDockWidgetArea, catalogDock);

    m_requirementTable = new QTableView(this);
    m_requirementTable->setModel(m_requirementModel);
    m_requirementTable->setSelectionBehavior(QAbstractItemView::SelectRows);
    m_requirementTable->setSelectionMode(QAbstractItemView::SingleSelection);
    m_requirementTable->horizontalHeader()->setStretchLastSection(true);
    m_requirementTable->horizontalHeader()->setSectionResizeMode(RequirementTableModel::TitleColumn,
                                                                 QHeaderView::Stretch);
    m_requirementTable->setAlternatingRowColors(true);
    connect(m_requirementTable->selectionModel(), &QItemSelectionModel::currentChanged, this,
            [this](const QModelIndex &current, const QModelIndex &) {
                onRequirementSelected(current);
            });

    m_requirementText = new QTextEdit(this);
    m_requirementText->setReadOnly(true);

    m_assessmentNote = new QTextEdit(this);
    m_assessmentNote->setPlaceholderText(tr("Umsetzungsnotiz für die ausgewählte Anforderung"));
    connect(m_assessmentNote, &QTextEdit::textChanged, this, &MainWindow::saveAssessmentFields);

    m_responsibleEdit = new QLineEdit(this);
    m_responsibleEdit->setPlaceholderText(tr("Verantwortliche Person oder Rolle"));
    connect(m_responsibleEdit, &QLineEdit::editingFinished, this, &MainWindow::saveAssessmentFields);

    m_hasDueDateBox = new QCheckBox(tr("Frist setzen"), this);
    m_dueDateEdit = new QDateEdit(this);
    m_dueDateEdit->setCalendarPopup(true);
    m_dueDateEdit->setDisplayFormat(QStringLiteral("dd.MM.yyyy"));
    m_dueDateEdit->setEnabled(false);
    connect(m_hasDueDateBox, &QCheckBox::toggled, m_dueDateEdit, &QDateEdit::setEnabled);
    connect(m_hasDueDateBox, &QCheckBox::toggled, this, &MainWindow::saveAssessmentFields);
    connect(m_dueDateEdit, &QDateEdit::dateChanged, this, &MainWindow::saveAssessmentFields);

    m_measureTable = new QTableView(this);
    m_measureTable->setModel(m_measureModel);
    m_measureTable->setSelectionBehavior(QAbstractItemView::SelectRows);
    m_measureTable->setSelectionMode(QAbstractItemView::SingleSelection);
    m_measureTable->horizontalHeader()->setStretchLastSection(true);
    m_measureTable->horizontalHeader()->setSectionResizeMode(MeasureTableModel::TitleColumn,
                                                             QHeaderView::Stretch);
    m_measureTable->setAlternatingRowColors(true);
    connect(m_measureTable, &QTableView::doubleClicked, this, &MainWindow::editMeasure);

    m_addMeasureButton = new QPushButton(tr("Hinzufügen"), this);
    m_editMeasureButton = new QPushButton(tr("Bearbeiten"), this);
    m_deleteMeasureButton = new QPushButton(tr("Löschen"), this);
    connect(m_addMeasureButton, &QPushButton::clicked, this, &MainWindow::addMeasure);
    connect(m_editMeasureButton, &QPushButton::clicked, this, &MainWindow::editMeasure);
    connect(m_deleteMeasureButton, &QPushButton::clicked, this, &MainWindow::deleteMeasure);

    auto *detailPanel = new QWidget(this);
    auto *detailLayout = new QVBoxLayout(detailPanel);
    detailLayout->addWidget(new QLabel(tr("Anforderungstext"), detailPanel));
    detailLayout->addWidget(m_requirementText, 2);

    auto *statusRow = new QHBoxLayout();
    statusRow->addWidget(new QLabel(tr("Status"), detailPanel));
    m_statusBox = new QComboBox(detailPanel);
    m_statusBox->addItem(assessmentStatusToString(AssessmentStatus::Open),
                         static_cast<int>(AssessmentStatus::Open));
    m_statusBox->addItem(assessmentStatusToString(AssessmentStatus::Partial),
                         static_cast<int>(AssessmentStatus::Partial));
    m_statusBox->addItem(assessmentStatusToString(AssessmentStatus::Fulfilled),
                         static_cast<int>(AssessmentStatus::Fulfilled));
    m_statusBox->addItem(assessmentStatusToString(AssessmentStatus::NotApplicable),
                         static_cast<int>(AssessmentStatus::NotApplicable));
    connect(m_statusBox, &QComboBox::activated, this, &MainWindow::setAssessmentStatus);
    statusRow->addWidget(m_statusBox, 1);
    detailLayout->addLayout(statusRow);

    auto *responsibleRow = new QHBoxLayout();
    responsibleRow->addWidget(new QLabel(tr("Umsetzung durch"), detailPanel));
    responsibleRow->addWidget(m_responsibleEdit, 1);
    detailLayout->addLayout(responsibleRow);

    auto *dueDateRow = new QHBoxLayout();
    dueDateRow->addWidget(m_hasDueDateBox);
    dueDateRow->addWidget(m_dueDateEdit, 1);
    detailLayout->addLayout(dueDateRow);

    detailLayout->addWidget(new QLabel(tr("Umsetzung"), detailPanel));
    detailLayout->addWidget(m_assessmentNote, 1);

    detailLayout->addWidget(new QLabel(tr("Maßnahmen"), detailPanel));
    detailLayout->addWidget(m_measureTable, 2);
    auto *measureButtons = new QHBoxLayout();
    measureButtons->addWidget(m_addMeasureButton);
    measureButtons->addWidget(m_editMeasureButton);
    measureButtons->addWidget(m_deleteMeasureButton);
    measureButtons->addStretch();
    detailLayout->addLayout(measureButtons);

    m_targetProgressLabel = new QLabel(this);
    m_targetProgressLabel->setWordWrap(true);
    m_targetProgressBar = new QProgressBar(this);
    m_targetProgressBar->setRange(0, 100);
    m_targetProgressBar->setTextVisible(true);
    m_targetProgressBar->setFormat(tr("%p% abgeschlossen"));
    m_targetProgressBar->setVisible(false);

    auto *bausteinRow = new QHBoxLayout();
    bausteinRow->addWidget(new QLabel(tr("Baustein"), this));
    m_assignedBausteinBox = new QComboBox(this);
    m_assignedBausteinBox->setSizeAdjustPolicy(QComboBox::AdjustToMinimumContentsLengthWithIcon);
    m_assignedBausteinBox->setMinimumContentsLength(28);
    connect(m_assignedBausteinBox, QOverload<int>::of(&QComboBox::activated), this,
            &MainWindow::onAssignedBausteinActivated);
    bausteinRow->addWidget(m_assignedBausteinBox, 1);

    auto *requirementPanel = new QWidget(this);
    auto *requirementLayout = new QVBoxLayout(requirementPanel);
    requirementLayout->setContentsMargins(0, 0, 0, 0);
    requirementLayout->addWidget(m_targetProgressLabel);
    requirementLayout->addWidget(m_targetProgressBar);
    requirementLayout->addLayout(bausteinRow);
    requirementLayout->addWidget(m_requirementTable, 1);

    auto *centerSplitter = new QSplitter(Qt::Vertical, this);
    centerSplitter->addWidget(requirementPanel);
    centerSplitter->addWidget(detailPanel);
    centerSplitter->setStretchFactor(0, 3);
    centerSplitter->setStretchFactor(1, 2);
    setCentralWidget(centerSplitter);

    auto *fileMenu = menuBar()->addMenu(tr("Datei"));
    auto *importCatalogAction = fileMenu->addAction(tr("IT-Grundschutz XML importieren..."));
    connect(importCatalogAction, &QAction::triggered, this, &MainWindow::importCatalog);
    fileMenu->addSeparator();
    auto *newProjectAction = fileMenu->addAction(tr("Neues Projekt..."));
    connect(newProjectAction, &QAction::triggered, this, &MainWindow::createProject);
    auto *openProjectAction = fileMenu->addAction(tr("Projekt öffnen..."));
    connect(openProjectAction, &QAction::triggered, this, &MainWindow::openProject);
    m_closeProjectAction = fileMenu->addAction(tr("Projekt schließen"));
    m_closeProjectAction->setShortcut(QKeySequence::Close);
    connect(m_closeProjectAction, &QAction::triggered, this, &MainWindow::closeProject);
    fileMenu->addSeparator();
    fileMenu->addAction(tr("Beenden"), this, &QWidget::close);

    auto *projectMenu = menuBar()->addMenu(tr("Projekt"));
    m_editProjectAction = projectMenu->addAction(tr("Projekteigenschaften..."));
    connect(m_editProjectAction, &QAction::triggered, this, &MainWindow::editProject);
    m_deleteProjectAction = projectMenu->addAction(tr("Projekt löschen..."));
    connect(m_deleteProjectAction, &QAction::triggered, this, &MainWindow::deleteProject);
    m_manageMembersAction = projectMenu->addAction(tr("Projektmitglieder..."));
    connect(m_manageMembersAction, &QAction::triggered, this, &MainWindow::showProjectMembers);
    m_switchUserAction = projectMenu->addAction(tr("Abmelden / Benutzer wechseln..."));
    connect(m_switchUserAction, &QAction::triggered, this, &MainWindow::switchUserOrLogout);
    m_reloginAction = projectMenu->addAction(tr("Server-Sitzung erneuern..."));
    connect(m_reloginAction, &QAction::triggered, this, [this]() {
        if (m_context.isRemote())
            m_context.promptRelogin(this);
    });
    projectMenu->addSeparator();
    m_addTargetAction = projectMenu->addAction(tr("Zielobjekt hinzufügen..."));
    connect(m_addTargetAction, &QAction::triggered, this, &MainWindow::addTargetObject);
    m_editTargetAction = projectMenu->addAction(tr("Zielobjekt bearbeiten..."));
    connect(m_editTargetAction, &QAction::triggered, this, &MainWindow::editTargetObject);
    m_deleteTargetAction = projectMenu->addAction(tr("Zielobjekt löschen"));
    connect(m_deleteTargetAction, &QAction::triggered, this, &MainWindow::deleteTargetObject);
    projectMenu->addSeparator();
    m_applyRecommendationsAction =
        projectMenu->addAction(tr("Baustein-Empfehlungen übernehmen..."));
    connect(m_applyRecommendationsAction, &QAction::triggered, this,
            &MainWindow::applyBausteinRecommendations);

    auto *reportMenu = menuBar()->addMenu(tr("Berichte"));
    m_sollIstAction = reportMenu->addAction(tr("Soll-Ist-Übersicht..."));
    connect(m_sollIstAction, &QAction::triggered, this, &MainWindow::showSollIstReport);

    auto *catalogMenu = menuBar()->addMenu(tr("Katalog"));
    catalogMenu->addAction(tr("Baustein anzeigen..."), this, &MainWindow::viewSelectedBaustein);
    auto *catalogSearchAction = catalogMenu->addAction(tr("Volltextsuche..."));
    catalogSearchAction->setShortcut(QKeySequence(Qt::CTRL | Qt::SHIFT | Qt::Key_F));
    connect(catalogSearchAction, &QAction::triggered, this, &MainWindow::showCatalogSearch);

    auto *toolBar = addToolBar(tr("Projekt"));
    toolBar->addAction(newProjectAction);
    toolBar->addAction(openProjectAction);
    toolBar->addAction(m_addTargetAction);
    toolBar->addAction(importCatalogAction);

    m_contextLabel = new QLabel(this);
    statusBar()->addWidget(m_contextLabel, 1);
    m_statusLabel = new QLabel(this);
    statusBar()->addPermanentWidget(m_statusLabel);
}

void MainWindow::showTemporaryStatusMessage(const QString &message, int timeoutMs)
{
    const QString previousText = m_statusLabel->text();
    m_statusLabel->setText(message);
    QTimer::singleShot(timeoutMs, this, [this, previousText, message]() {
        if (m_statusLabel->text() == message)
            m_statusLabel->setText(previousText);
    });
}

void MainWindow::updateProjectUiEnabled()
{
    const bool hasProject = m_activeProject.id != 0;
    const bool hasTargetObject = hasProject && m_activeTargetObject.id != 0;
    const bool canEdit = canEditActiveProject();
    const bool canDelete = canDeleteActiveProject();
    const bool canManageMembers = canManageProjectMembers();

    m_closeProjectAction->setEnabled(hasProject);
    m_editProjectAction->setEnabled(hasProject && canEdit);
    m_deleteProjectAction->setEnabled(hasProject && canDelete);
    m_manageMembersAction->setEnabled(canManageMembers);
    m_switchUserAction->setEnabled(true);
    m_reloginAction->setEnabled(m_context.isRemote());
    m_addTargetAction->setEnabled(hasProject && canEdit);
    m_editTargetAction->setEnabled(hasProject && canEdit);
    m_deleteTargetAction->setEnabled(hasProject && canEdit);
    m_applyRecommendationsAction->setEnabled(hasTargetObject && canEdit);
    m_sollIstAction->setEnabled(hasProject);

    m_targetObjectTree->setEnabled(hasProject);
    m_filterApplicableBox->setEnabled(hasTargetObject);
    m_highlightRecommendationsBox->setEnabled(hasTargetObject);
    m_assignedBausteinBox->setEnabled(hasTargetObject && canEdit
                                      && m_assignedBausteinBox->count() > 0
                                      && m_assignedBausteinBox->currentData().toInt() != 0);
    m_statusBox->setEnabled(hasTargetObject && canEdit);
    m_assessmentNote->setEnabled(hasTargetObject && canEdit);
    m_assessmentNote->setReadOnly(hasTargetObject && !canEdit);
    m_responsibleEdit->setEnabled(hasTargetObject && canEdit);
    m_responsibleEdit->setReadOnly(hasTargetObject && !canEdit);
    m_hasDueDateBox->setEnabled(hasTargetObject && canEdit);
    m_dueDateEdit->setEnabled(hasTargetObject && canEdit && m_hasDueDateBox->isChecked());
    m_measureTable->setEnabled(hasTargetObject);
    m_addMeasureButton->setEnabled(hasTargetObject && canEdit);
    m_editMeasureButton->setEnabled(hasTargetObject);
    m_editMeasureButton->setText(canEdit ? tr("Bearbeiten") : tr("Anzeigen"));
    m_deleteMeasureButton->setEnabled(hasTargetObject && canEdit);

    if (!hasProject) {
        m_contextLabel->setText(tr("Kein Projekt geöffnet"));
    } else if (m_activeTargetObject.id == 0) {
        QString contextText =
            tr("Projekt \"%1\" – bitte Zielobjekt wählen").arg(m_activeProject.name);
        if (m_context.isRemote() && m_activeProject.role == QStringLiteral("viewer"))
            contextText += tr(" (Nur Lesen)");
        m_contextLabel->setText(contextText);
    } else {
        QString contextText = tr("Projekt \"%1\" – Zielobjekt: %2 – %3  (%4)")
                                  .arg(m_activeProject.name,
                                       targetObjectTypeToString(m_activeTargetObject.type),
                                       m_activeTargetObject.name,
                                       protectionNeedToString(m_activeTargetObject.protectionNeed));
        if (m_context.isRemote() && m_activeProject.role == QStringLiteral("viewer"))
            contextText += tr(" — Nur Lesen");
        m_contextLabel->setText(contextText);
    }
}

bool MainWindow::canEditActiveProject() const
{
    if (!m_context.isRemote() || m_activeProject.id == 0)
        return true;

    const QString &role = m_activeProject.role;
    return role == QStringLiteral("owner") || role == QStringLiteral("editor");
}

bool MainWindow::canDeleteActiveProject() const
{
    if (m_activeProject.id == 0)
        return false;
    if (!m_context.isRemote())
        return true;

    return m_activeProject.role == QStringLiteral("owner");
}

bool MainWindow::canManageProjectMembers() const
{
    return m_context.isRemote() && m_activeProject.id != 0
           && m_activeProject.role == QStringLiteral("owner");
}

void MainWindow::notifySaveFailure(const QString &repositoryError, bool useDialog)
{
    QString message = repositoryError;
    if (message == QStringLiteral("forbidden"))
        message = tr("Keine Berechtigung zum Speichern. Ihre Rolle erlaubt nur Lesen.");
    else if (message.isEmpty())
        message = tr("Speichern fehlgeschlagen.");

    if (useDialog)
        QMessageBox::warning(this, tr("Speichern"), message);
    else
        showTemporaryStatusMessage(tr("Speichern fehlgeschlagen: %1").arg(message), 8000);
}

bool MainWindow::hasActiveProjectContext() const
{
    return m_activeProject.id != 0 && m_activeTargetObject.id != 0;
}

int MainWindow::activeTargetObjectId() const
{
    return m_activeTargetObject.id;
}

void MainWindow::reloadCatalog()
{
    m_catalogBausteine = m_context.catalogRepository().loadBausteine(
        StandardType::ITGrundschutz, m_context.catalogVersion());
    m_catalogRequirements = m_context.catalogRepository().loadAllRequirements(
        StandardType::ITGrundschutz, m_context.catalogVersion());
    m_bausteinModel->setBausteine(m_catalogBausteine);
    applyBausteinSearchFilter();
    m_bausteinTree->expandAll();
    m_statusLabel->setText(tr("%1 Bausteine geladen").arg(m_catalogBausteine.size()));
    reloadApplicabilityMarkers();
    reloadRecommendationMarkers();
    updateWindowTitle();
}

void MainWindow::reloadRecommendationMarkers()
{
    if (!hasActiveProjectContext()) {
        m_bausteinModel->setRecommendedBausteinIds({});
        m_bausteinModel->setRecommendationTiers({});
        return;
    }

    const QList<Baustein> bausteine = m_context.catalogRepository().loadBausteine(
        StandardType::ITGrundschutz, m_context.catalogVersion());
    const QList<BausteinRecommendation> recommendations =
        BausteinRecommendationService::buildRecommendations(bausteine, m_activeTargetObject);

    QSet<int> recommendedIds;
    QHash<int, BausteinRecommendationTier> recommendationTiers;
    for (const BausteinRecommendation &recommendation : recommendations) {
        recommendedIds.insert(recommendation.bausteinDbId);
        recommendationTiers.insert(recommendation.bausteinDbId, recommendation.tier);
    }
    m_bausteinModel->setRecommendedBausteinIds(recommendedIds);
    m_bausteinModel->setRecommendationTiers(recommendationTiers);
}

void MainWindow::reloadBausteinMarkers()
{
    if (!hasActiveProjectContext()) {
        m_bausteinModel->updateTargetContext({}, {}, {});
        reloadAssignedBausteinBox();
        return;
    }

    const QHash<int, ApplicabilityStatus> applicability =
        m_context.targetObjectRepository().loadApplicabilityMap(m_activeProject.id,
                                                                m_activeTargetObject.id);

    const QList<Baustein> bausteine = m_context.catalogRepository().loadBausteine(
        StandardType::ITGrundschutz, m_context.catalogVersion());
    const QList<BausteinRecommendation> recommendations =
        BausteinRecommendationService::buildRecommendations(bausteine, m_activeTargetObject);

    QSet<int> recommendedIds;
    QHash<int, BausteinRecommendationTier> recommendationTiers;
    for (const BausteinRecommendation &recommendation : recommendations) {
        recommendedIds.insert(recommendation.bausteinDbId);
        recommendationTiers.insert(recommendation.bausteinDbId, recommendation.tier);
    }

    m_bausteinModel->updateTargetContext(applicability, recommendedIds, recommendationTiers);
    reloadAssignedBausteinBox();
}

void MainWindow::reloadAssignedBausteinBox()
{
    m_blockAssignedBausteinBoxHandler = true;
    QSignalBlocker blocker(m_assignedBausteinBox);
    m_assignedBausteinBox->clear();

    if (!hasActiveProjectContext()) {
        m_assignedBausteinBox->addItem(tr("— Kein Zielobjekt gewählt —"), 0);
        m_assignedBausteinBox->setEnabled(false);
        m_blockAssignedBausteinBoxHandler = false;
        return;
    }

    const QHash<int, ApplicabilityStatus> applicability =
        m_context.targetObjectRepository().loadApplicabilityMap(m_activeProject.id,
                                                                m_activeTargetObject.id);
    const QList<Baustein> bausteine = m_context.catalogRepository().loadBausteine(
        StandardType::ITGrundschutz, m_context.catalogVersion());
    QHash<int, Baustein> bausteinById;
    for (const Baustein &baustein : bausteine)
        bausteinById.insert(baustein.id, baustein);

    QList<int> assignedIds;
    for (auto it = applicability.constBegin(); it != applicability.constEnd(); ++it) {
        if (it.value() == ApplicabilityStatus::Required
            || it.value() == ApplicabilityStatus::Possible)
            assignedIds.append(it.key());
    }
    std::sort(assignedIds.begin(), assignedIds.end(), [&bausteinById](int a, int b) {
        return bausteinById.value(a).externalId < bausteinById.value(b).externalId;
    });

    if (assignedIds.isEmpty()) {
        m_assignedBausteinBox->addItem(tr("— Keine Bausteine zugewiesen —"), 0);
        m_assignedBausteinBox->setEnabled(false);
        m_blockAssignedBausteinBoxHandler = false;
        return;
    }

    for (int bausteinId : assignedIds) {
        const Baustein baustein = bausteinById.value(bausteinId);
        const QString label =
            QStringLiteral("%1 %2 (%3)")
                .arg(baustein.externalId,
                     baustein.title,
                     applicabilityStatusToString(applicability.value(bausteinId)));
        m_assignedBausteinBox->addItem(label, bausteinId);
    }

    m_assignedBausteinBox->setEnabled(true);
    syncAssignedBausteinBoxSelection();
    m_blockAssignedBausteinBoxHandler = false;
}

void MainWindow::syncAssignedBausteinBoxSelection()
{
    if (m_assignedBausteinBox->count() == 0
        || m_assignedBausteinBox->itemData(0).toInt() == 0)
        return;

    m_blockAssignedBausteinBoxHandler = true;
    QSignalBlocker blocker(m_assignedBausteinBox);

    if (m_activeBausteinId != 0) {
        const int index = m_assignedBausteinBox->findData(m_activeBausteinId);
        if (index >= 0)
            m_assignedBausteinBox->setCurrentIndex(index);
    }

    m_blockAssignedBausteinBoxHandler = false;
}

void MainWindow::onAssignedBausteinActivated(int index)
{
    if (m_blockAssignedBausteinBoxHandler || index < 0 || !hasActiveProjectContext())
        return;

    const int bausteinId = m_assignedBausteinBox->itemData(index).toInt();
    if (bausteinId == 0 || bausteinId == m_activeBausteinId)
        return;

    if (m_activeRequirementId != 0 && m_displayedAssessmentTargetId != 0)
        saveAssessmentFor(m_displayedAssessmentTargetId, m_activeRequirementId);

    restoreBausteinSelection(bausteinId);
    reloadActiveTargetContent();
    persistTargetSelection(m_activeTargetObject.id);
}

void MainWindow::reloadTargetObjects()
{
    if (m_activeProject.id == 0) {
        m_targetObjectModel->setTargetObjects({});
        m_activeTargetObject = {};
        updateProjectUiEnabled();
        reloadProgress();
        clearRequirementView();
        return;
    }

    const int previousActiveId = m_activeTargetObject.id;
    const QList<TargetObject> objects =
        m_context.targetObjectRepository().loadTargetObjects(m_activeProject.id);

    QSignalBlocker selectionBlocker(m_targetObjectTree->selectionModel());
    m_targetObjectModel->setTargetObjects(objects);
    m_targetObjectTree->expandAll();

    m_activeTargetObject = {};
    const int targetToRestore =
        previousActiveId != 0 ? previousActiveId : m_preferredTargetObjectId;
    if (targetToRestore != 0) {
        for (const TargetObject &object : objects) {
            if (object.id == targetToRestore) {
                m_activeTargetObject = object;
                break;
            }
        }
    }

    if (m_activeTargetObject.id == 0 && !objects.isEmpty()) {
        for (const TargetObject &object : objects) {
            if (object.parentId == 0) {
                m_activeTargetObject = object;
                break;
            }
        }
    }

    reloadBausteinMarkers();
    ensureApplicableFilterFeasible();
    updateProjectUiEnabled();

    if (m_activeTargetObject.id != 0) {
        const QModelIndex index =
            m_targetObjectModel->indexForTargetObjectId(m_activeTargetObject.id);
        if (index.isValid())
            m_targetObjectTree->setCurrentIndex(index);
    } else {
        m_targetObjectTree->setCurrentIndex({});
    }

    reloadProgress();

    const int bausteinToRestore = m_lastBausteinByTarget.value(m_activeTargetObject.id, 0);
    if (m_activeTargetObject.id != 0 && bausteinToRestore != 0) {
        m_blockBausteinSelectionHandler = true;
        QSignalBlocker bausteinSelectionBlocker(m_bausteinTree->selectionModel());
        if (m_restoreRequirementId == 0)
            m_restoreRequirementId = m_lastRequirementByTarget.value(m_activeTargetObject.id, 0);
        if (isBausteinApplicableForActiveTarget(bausteinToRestore))
            restoreBausteinSelection(bausteinToRestore);
        else
            m_bausteinTree->setCurrentIndex({});
        reloadActiveTargetContent();
        m_blockBausteinSelectionHandler = false;
    } else if (m_activeTargetObject.id == 0) {
        clearRequirementView();
    }
}

void MainWindow::reloadProgress()
{
    auto resetProgressUi = [this]() {
        m_projectProgressLabel->setText(tr("Kein Projekt geöffnet"));
        m_projectProgressBar->setValue(0);
        m_projectProgressBar->setVisible(false);
        m_targetProgressLabel->clear();
        m_targetProgressBar->setValue(0);
        m_targetProgressBar->setVisible(false);
        m_targetObjectModel->setProgressSummaries({});
    };

    if (m_activeProject.id == 0) {
        resetProgressUi();
        return;
    }

    ReportService service(m_context.catalogRepository(),
                          m_context.projectRepository(),
                          m_context.targetObjectRepository(),
                          m_context.measureRepository());

    const QList<ReportRow> projectRows =
        service.buildSollIstReport(m_activeProject.id, 0, m_context.catalogVersion());
    const ReportSummary projectSummary = service.summarize(projectRows);
    const QHash<int, ReportSummary> targetSummaries = service.summarizeByTargetObject(projectRows);

    m_targetObjectModel->setProgressSummaries(targetSummaries);

    m_projectProgressLabel->setText(
        tr("Projekt: %1").arg(ReportService::formatSummaryText(projectSummary)));
    m_projectProgressBar->setValue(ReportService::progressPercent(projectSummary));
    m_projectProgressBar->setVisible(projectSummary.totalRequirements > 0);

    if (m_activeTargetObject.id == 0) {
        m_targetProgressLabel->setText(tr("Bitte Zielobjekt wählen"));
        m_targetProgressBar->setValue(0);
        m_targetProgressBar->setVisible(false);
        return;
    }

    const ReportSummary targetSummary = targetSummaries.value(m_activeTargetObject.id);
    m_targetProgressLabel->setText(
        tr("Zielobjekt \"%1 – %2\": %3")
            .arg(targetObjectTypeToString(m_activeTargetObject.type),
                 m_activeTargetObject.name,
                 ReportService::formatSummaryText(targetSummary)));
    m_targetProgressBar->setValue(ReportService::progressPercent(targetSummary));
    m_targetProgressBar->setVisible(targetSummary.totalRequirements > 0);
}

void MainWindow::selectActiveTargetObjectInTree()
{
    if (m_activeTargetObject.id == 0)
        return;

    const QModelIndex index =
        m_targetObjectModel->indexForTargetObjectId(m_activeTargetObject.id);
    if (!index.isValid())
        return;

    QSignalBlocker blocker(m_targetObjectTree->selectionModel());
    m_targetObjectTree->setCurrentIndex(index);
    onTargetObjectSelected(index);
}

void MainWindow::clearRequirementView()
{
    m_activeBausteinId = 0;
    m_activeRequirementId = 0;
    m_restoreRequirementId = 0;
    m_displayedAssessmentTargetId = 0;
    m_requirementModel->clearAssessments();
    m_requirementModel->setRequirements({});
    m_measureModel->setMeasures({});
    m_requirementText->clear();
    QSignalBlocker noteBlocker(m_assessmentNote);
    QSignalBlocker responsibleBlocker(m_responsibleEdit);
    QSignalBlocker dueDateEnabledBlocker(m_hasDueDateBox);
    QSignalBlocker dueDateBlocker(m_dueDateEdit);
    m_assessmentNote->clear();
    m_responsibleEdit->clear();
    m_hasDueDateBox->setChecked(false);
    m_dueDateEdit->clear();
    QSignalBlocker statusBlocker(m_statusBox);
    const int openStatusIndex = m_statusBox->findData(static_cast<int>(AssessmentStatus::Open));
    if (openStatusIndex >= 0)
        m_statusBox->setCurrentIndex(openStatusIndex);
}

void MainWindow::restoreBausteinSelection(int bausteinId)
{
    if (bausteinId == 0)
        return;

    const QModelIndex index = m_bausteinModel->indexForBausteinId(bausteinId);
    if (!index.isValid()) {
        m_activeBausteinId = 0;
        return;
    }

    QSignalBlocker blocker(m_bausteinTree->selectionModel());
    m_bausteinTree->setCurrentIndex(index);
    m_activeBausteinId = bausteinId;
}

void MainWindow::revertBausteinTreeSelection(int bausteinDbId)
{
    if (!hasActiveProjectContext() || bausteinDbId == 0
        || !isBausteinApplicableForActiveTarget(bausteinDbId)) {
        QSignalBlocker blocker(m_bausteinTree->selectionModel());
        m_bausteinTree->setCurrentIndex({});
        m_activeBausteinId = 0;
        clearRequirementView();
        syncAssignedBausteinBoxSelection();
        return;
    }

    m_blockBausteinSelectionHandler = true;
    restoreBausteinSelection(bausteinDbId);
    m_blockBausteinSelectionHandler = false;
    reloadActiveTargetContent();
}

void MainWindow::persistSessionSelection()
{
    if (m_activeProject.id == 0)
        return;

    persistTargetSelection(m_activeTargetObject.id);

    SessionSelection session;
    session.targetObjectId = m_activeTargetObject.id;
    session.bausteinId = m_activeBausteinId;
    session.requirementId = m_activeRequirementId;
    m_sessionByProject.insert(m_activeProject.id, session);
    m_preferredTargetObjectId = session.targetObjectId;
    m_preferredBausteinId = session.bausteinId;
    m_preferredRequirementId = session.requirementId;

    QSettings settings;
    settings.beginGroup(sessionSettingsGroup(m_activeProject.id));
    settings.setValue(QStringLiteral("targetObjectId"), session.targetObjectId);
    settings.setValue(QStringLiteral("bausteinId"), session.bausteinId);
    settings.setValue(QStringLiteral("requirementId"), session.requirementId);
    settings.endGroup();
    persistAllTargetSelections();
}

void MainWindow::persistAllTargetSelections()
{
    if (m_activeProject.id == 0)
        return;

    QSettings settings;
    settings.beginGroup(sessionSettingsGroup(m_activeProject.id));
    settings.remove(QStringLiteral("targets"));

    QSet<int> targetIds;
    for (auto it = m_lastBausteinByTarget.constBegin(); it != m_lastBausteinByTarget.constEnd(); ++it)
        targetIds.insert(it.key());
    for (auto it = m_lastRequirementByTarget.constBegin(); it != m_lastRequirementByTarget.constEnd(); ++it)
        targetIds.insert(it.key());

    settings.beginGroup(QStringLiteral("targets"));
    for (int targetId : targetIds) {
        settings.beginGroup(QString::number(targetId));
        if (m_lastBausteinByTarget.contains(targetId))
            settings.setValue(QStringLiteral("bausteinId"), m_lastBausteinByTarget.value(targetId));
        if (m_lastRequirementByTarget.contains(targetId))
            settings.setValue(QStringLiteral("requirementId"), m_lastRequirementByTarget.value(targetId));
        settings.endGroup();
    }
    settings.endGroup();
    settings.endGroup();
}

void MainWindow::loadStoredTargetSelections(int projectId)
{
    m_lastBausteinByTarget.clear();
    m_lastRequirementByTarget.clear();

    QSettings settings;
    settings.beginGroup(sessionSettingsGroup(projectId));
    settings.beginGroup(QStringLiteral("targets"));
    const QStringList groups = settings.childGroups();
    for (const QString &group : groups) {
        settings.beginGroup(group);
        const int targetId = group.toInt();
        if (targetId > 0) {
            const int bausteinId = settings.value(QStringLiteral("bausteinId"), 0).toInt();
            const int requirementId = settings.value(QStringLiteral("requirementId"), 0).toInt();
            if (bausteinId != 0)
                m_lastBausteinByTarget[targetId] = bausteinId;
            if (requirementId != 0)
                m_lastRequirementByTarget[targetId] = requirementId;
        }
        settings.endGroup();
    }
    settings.endGroup();
    settings.endGroup();
}

SessionSelection MainWindow::loadStoredSession(int projectId) const
{
    if (m_sessionByProject.contains(projectId))
        return m_sessionByProject.value(projectId);

    SessionSelection session;
    QSettings settings;
    settings.beginGroup(sessionSettingsGroup(projectId));
    session.targetObjectId = settings.value(QStringLiteral("targetObjectId"), 0).toInt();
    session.bausteinId = settings.value(QStringLiteral("bausteinId"), 0).toInt();
    session.requirementId = settings.value(QStringLiteral("requirementId"), 0).toInt();
    settings.endGroup();
    return session;
}

QString MainWindow::sessionSettingsGroup(int projectId) const
{
    if (m_context.isRemote()) {
        const QString userKey = m_context.remoteUser().email.trimmed().toLower();
        if (!userKey.isEmpty())
            return QStringLiteral("projectSessions/%1/%2").arg(userKey, QString::number(projectId));
    }
    return QStringLiteral("projectSessions/%1").arg(projectId);
}

void MainWindow::applyAssessmentConflict(const RequirementAssessment &serverAssessment,
                                         int requirementDbId, bool showDialog)
{
    RequirementAssessment refreshed = serverAssessment;
    refreshed.measureCount = m_context.measureRepository()
                                 .measureCounts(m_activeProject.id, serverAssessment.targetObjectId)
                                 .value(requirementDbId, 0);

    m_suppressAssessmentSave = true;
    if (m_activeTargetObject.id == serverAssessment.targetObjectId
        && m_activeRequirementId == requirementDbId) {
        syncAssessmentUi(refreshed);
    }
    m_suppressAssessmentSave = false;

    m_requirementModel->setAssessment(requirementDbId, refreshed);

    if (showDialog) {
        QMessageBox::warning(
            this,
            tr("Konflikt"),
            tr("Ein anderer Benutzer hat diese Bewertung zwischenzeitlich geändert. "
               "Die aktuelle Server-Version wurde geladen."));
        m_lastConflictNotifiedRequirementId = 0;
    } else if (m_lastConflictNotifiedRequirementId != requirementDbId) {
        showTemporaryStatusMessage(
            tr("Konflikt: Bewertung wurde von einem anderen Benutzer geändert und neu geladen."),
            10000);
        m_lastConflictNotifiedRequirementId = requirementDbId;
    }
}

int MainWindow::activeBausteinIdFromTree() const
{
    const QModelIndex index = m_bausteinTree->currentIndex();
    if (!index.isValid() || index.data(BausteinTreeModel::IsGroupRole).toBool())
        return 0;
    return m_bausteinModel->bausteinForIndex(index).id;
}

void MainWindow::persistTargetSelection(int targetObjectId)
{
    if (targetObjectId == 0)
        return;

    if (m_activeBausteinId != 0)
        m_lastBausteinByTarget[targetObjectId] = m_activeBausteinId;
    else
        m_lastBausteinByTarget.remove(targetObjectId);

    if (m_activeRequirementId != 0)
        m_lastRequirementByTarget[targetObjectId] = m_activeRequirementId;
    else
        m_lastRequirementByTarget.remove(targetObjectId);
}

void MainWindow::restoreTargetSelection(int targetObjectId)
{
    m_activeBausteinId = 0;
    m_activeRequirementId = 0;
    m_restoreRequirementId = m_lastRequirementByTarget.value(targetObjectId, 0);

    const int bausteinId = m_lastBausteinByTarget.value(targetObjectId, 0);
    if (bausteinId != 0 && isBausteinApplicableForActiveTarget(bausteinId))
        restoreBausteinSelection(bausteinId);
    else
        m_bausteinTree->setCurrentIndex({});
}

bool MainWindow::isBausteinApplicableForActiveTarget(int bausteinDbId) const
{
    if (!hasActiveProjectContext())
        return true;

    const ApplicabilityStatus status = m_context.targetObjectRepository().applicability(
        m_activeProject.id, m_activeTargetObject.id, bausteinDbId);
    return status == ApplicabilityStatus::Required || status == ApplicabilityStatus::Possible;
}

bool MainWindow::hasApplicableBausteineForActiveTarget() const
{
    if (!hasActiveProjectContext())
        return true;

    const QHash<int, ApplicabilityStatus> map =
        m_context.targetObjectRepository().loadApplicabilityMap(m_activeProject.id,
                                                                m_activeTargetObject.id);
    for (auto it = map.cbegin(); it != map.cend(); ++it) {
        if (it.value() == ApplicabilityStatus::Required
            || it.value() == ApplicabilityStatus::Possible)
            return true;
    }
    return false;
}

void MainWindow::ensureApplicableFilterFeasible()
{
    if (!m_filterApplicableBox->isChecked() || !hasActiveProjectContext())
        return;

    if (hasApplicableBausteineForActiveTarget())
        return;

    QSignalBlocker blocker(m_filterApplicableBox);
    m_filterApplicableBox->setChecked(false);
    m_bausteinModel->setHideNonApplicable(false);
    m_bausteinTree->expandAll();

    showTemporaryStatusMessage(
        tr("Filter deaktiviert: Für \"%1 – %2\" sind noch keine Bausteine markiert. "
           "Baustein wählen → Rechtsklick → \"Benötigt\" oder \"Möglicherweise\".")
            .arg(targetObjectTypeToString(m_activeTargetObject.type), m_activeTargetObject.name),
        8000);
}

void MainWindow::showBausteinNotApplicableMessage(int bausteinDbId, ApplicabilityStatus status)
{
    Q_UNUSED(bausteinDbId)

    m_requirementModel->setRequirements({});
    m_activeRequirementId = 0;
    m_displayedAssessmentTargetId = 0;
    m_measureModel->setMeasures({});

    if (status == ApplicabilityStatus::NotApplicable) {
        m_requirementText->setPlainText(
            tr("Dieser Baustein ist für das Zielobjekt \"%1 – %2\" als \"Nicht relevant\" markiert.")
                .arg(targetObjectTypeToString(m_activeTargetObject.type), m_activeTargetObject.name));
    } else {
        m_requirementText->setPlainText(
            tr("Der Baustein ist für \"%1 – %2\" noch nicht als anwendbar markiert.\n\n"
               "Bitte zuerst per Rechtsklick auf den Baustein \"Benötigt\" oder \"Möglicherweise\" wählen. "
               "Erst dann können Anforderungen und Maßnahmen für dieses Zielobjekt bearbeitet werden.")
                .arg(targetObjectTypeToString(m_activeTargetObject.type), m_activeTargetObject.name));
    }

    QSignalBlocker noteBlocker(m_assessmentNote);
    QSignalBlocker responsibleBlocker(m_responsibleEdit);
    QSignalBlocker dueDateEnabledBlocker(m_hasDueDateBox);
    m_assessmentNote->clear();
    m_responsibleEdit->clear();
    m_hasDueDateBox->setChecked(false);
}

void MainWindow::refreshCurrentRequirementView()
{
    if (m_requirementModel->rowCount() == 0)
        return;

    refreshAssessmentColumn();

    int row = m_requirementTable->currentIndex().row();
    if (row < 0 && m_restoreRequirementId != 0) {
        for (int i = 0; i < m_requirementModel->rowCount(); ++i) {
            if (m_requirementModel->requirementAt(i).id == m_restoreRequirementId) {
                row = i;
                break;
            }
        }
    }
    if (row < 0 && m_activeRequirementId != 0) {
        for (int i = 0; i < m_requirementModel->rowCount(); ++i) {
            if (m_requirementModel->requirementAt(i).id == m_activeRequirementId) {
                row = i;
                break;
            }
        }
    }
    if (row < 0)
        row = 0;

    m_restoreRequirementId = 0;
    m_activeRequirementId = 0;
    m_displayedAssessmentTargetId = 0;
    loadRequirementDetails(row, true);
    if (m_requirementTable->currentIndex().row() != row)
        m_requirementTable->selectRow(row);
}

void MainWindow::reloadActiveTargetContent()
{
    m_suppressAssessmentSave = true;
    struct SaveGuard {
        MainWindow *window;
        ~SaveGuard()
        {
            if (window)
                window->m_suppressAssessmentSave = false;
        }
    } guard{this};

    if (!hasActiveProjectContext() || m_activeBausteinId == 0) {
        clearRequirementView();
        return;
    }

    const ApplicabilityStatus applicability = m_context.targetObjectRepository().applicability(
        m_activeProject.id, m_activeTargetObject.id, m_activeBausteinId);
    if (!isBausteinApplicableForActiveTarget(m_activeBausteinId)) {
        showBausteinNotApplicableMessage(m_activeBausteinId, applicability);
        return;
    }

    m_displayedAssessmentTargetId = 0;
    m_activeRequirementId = 0;
    loadRequirementsForBaustein(m_activeBausteinId);
    syncAssignedBausteinBoxSelection();
}

void MainWindow::clearProjectSession()
{
    m_activeProject = {};
    m_activeTargetObject = {};
    m_lastBausteinByTarget.clear();
    m_lastRequirementByTarget.clear();
    clearRequirementView();
    m_bausteinModel->setApplicabilityMap({});
    m_bausteinModel->setRecommendedBausteinIds({});
    m_bausteinTree->setCurrentIndex({});
    reloadTargetObjects();
    updateWindowTitle();
}

void MainWindow::reloadApplicabilityMarkers()
{
    if (!hasActiveProjectContext()) {
        m_bausteinModel->setApplicabilityMap({});
        return;
    }

    const QHash<int, ApplicabilityStatus> map =
        m_context.targetObjectRepository().loadApplicabilityMap(m_activeProject.id,
                                                                m_activeTargetObject.id);
    m_bausteinModel->setApplicabilityMap(map);
}

void MainWindow::checkRemoteSession()
{
    if (!m_context.isRemote())
        return;

    ApiClient &client = m_context.apiClient();
    if (!client.isTokenExpired())
        return;

    if (m_context.promptRelogin(this)) {
        showTemporaryStatusMessage(tr("Sitzung erneuert"));
        return;
    }

    QMessageBox::warning(
        this,
        tr("Sitzung abgelaufen"),
        tr("Die Server-Sitzung ist abgelaufen. Bitte melden Sie sich erneut an, bevor Sie weiterarbeiten."));
}

void MainWindow::showProjectMembers()
{
    if (!m_context.isRemote() || m_activeProject.id == 0)
        return;

    const bool canManage = m_activeProject.role == QStringLiteral("owner");
    ProjectMembersDialog dialog(m_context.apiClient(), m_activeProject.id, m_activeProject.name,
                                canManage, m_context.isRemoteAdmin(), this);
    dialog.exec();
}

void MainWindow::switchUserOrLogout()
{
    if (m_activeProject.id != 0) {
        QMessageBox::information(
            this,
            tr("Abmelden / Benutzer wechseln"),
            tr("Das aktuell geöffnete Projekt wird geschlossen."));
    }

    clearProjectSession();

    if (!m_context.promptSwitchUser(this)) {
        if (!m_context.lastError().isEmpty()) {
            QMessageBox::critical(this,
                                  tr("Verbindung"),
                                  tr("Verbindung konnte nicht hergestellt werden:\n%1")
                                      .arg(m_context.lastError()));
        }
        reloadCatalog();
        updateProjectUiEnabled();
        updateWindowTitle();
        configureRemoteSessionWatcher();
        return;
    }

    if (!m_context.ensureGrundschutzCatalog(AppPaths::defaultGrundschutzXml())) {
        const QString hint = m_context.isRemote()
                                 ? tr("Bitte den Katalog als Admin über "
                                      "\"Datei → IT-Grundschutz XML importieren\" auf den Server laden.")
                                 : tr("Sie können den Katalog später über "
                                      "\"Datei → IT-Grundschutz XML importieren\" laden.");
        QMessageBox::warning(this, tr("Katalog"),
                             tr("%1\n\n%2").arg(m_context.lastError(), hint));
    }

    reloadCatalog();
    updateProjectUiEnabled();
    updateWindowTitle();
    configureRemoteSessionWatcher();

    if (m_context.isRemote()) {
        showTemporaryStatusMessage(
            tr("Angemeldet als %1").arg(m_context.remoteUser().email), 8000);
    } else {
        showTemporaryStatusMessage(tr("Lokal-Modus aktiv"), 8000);
    }
}

void MainWindow::importCatalog()
{
    const QString filePath = QFileDialog::getOpenFileName(
        this,
        tr("IT-Grundschutz XML importieren"),
        AppPaths::defaultGrundschutzXml(),
        tr("XML Dateien (*.xml)"));
    if (filePath.isEmpty())
        return;

    if (m_context.isRemote()) {
        if (!m_context.importCatalogFile(filePath)) {
            QMessageBox::critical(this, tr("Import fehlgeschlagen"), m_context.lastError());
            return;
        }
    } else {
        GrundschutzImporter importer;
        const GrundschutzImportResult importResult = importer.importFromFile(filePath);
        if (!importResult.success) {
            QMessageBox::critical(this, tr("Import fehlgeschlagen"), importResult.errorMessage);
            return;
        }

        if (!m_context.catalogRepository().replaceGrundschutzCatalog(importResult)) {
            QMessageBox::critical(this, tr("Import fehlgeschlagen"), m_context.catalogRepository().lastError());
            return;
        }
    }

    reloadCatalog();
    showTemporaryStatusMessage(tr("Katalog importiert"));
}

void MainWindow::openProject()
{
    const QList<Project> projects = m_context.projectRepository().loadProjects();
    if (projects.isEmpty()) {
        QMessageBox::information(this, tr("Projekt öffnen"), tr("Es sind noch keine Projekte vorhanden."));
        return;
    }

    ProjectOpenDialog dialog(projects, m_context.isRemote(), this);
    if (dialog.exec() != QDialog::Accepted)
        return;

    if (m_activeRequirementId != 0 && m_displayedAssessmentTargetId != 0)
        saveAssessmentFor(m_displayedAssessmentTargetId, m_activeRequirementId);
    persistSessionSelection();

    m_activeProject = dialog.selectedProject();
    if (m_activeProject.id == 0)
        return;

    const SessionSelection session = loadStoredSession(m_activeProject.id);
    m_preferredTargetObjectId = session.targetObjectId;
    m_preferredBausteinId = session.bausteinId;
    m_preferredRequirementId = session.requirementId;
    m_restoreRequirementId = session.requirementId;
    loadStoredTargetSelections(m_activeProject.id);
    if (m_lastBausteinByTarget.isEmpty() && session.targetObjectId != 0) {
        if (session.bausteinId != 0)
            m_lastBausteinByTarget[session.targetObjectId] = session.bausteinId;
        if (session.requirementId != 0)
            m_lastRequirementByTarget[session.targetObjectId] = session.requirementId;
    }

    m_activeTargetObject = {};
    clearRequirementView();
    m_bausteinTree->setCurrentIndex({});
    reloadTargetObjects();
    updateWindowTitle();
    updateProjectUiEnabled();
    showTemporaryStatusMessage(tr("Projekt \"%1\" geöffnet").arg(m_activeProject.name));
}

void MainWindow::closeProject()
{
    if (m_activeProject.id == 0)
        return;

    if (m_activeRequirementId != 0 && m_displayedAssessmentTargetId != 0)
        saveAssessmentFor(m_displayedAssessmentTargetId, m_activeRequirementId);
    persistSessionSelection();

    const QString projectName = m_activeProject.name;
    clearProjectSession();
    showTemporaryStatusMessage(tr("Projekt \"%1\" geschlossen").arg(projectName));
}

void MainWindow::closeEvent(QCloseEvent *event)
{
    if (m_activeProject.id != 0) {
        if (m_activeRequirementId != 0 && m_displayedAssessmentTargetId != 0)
            saveAssessmentFor(m_displayedAssessmentTargetId, m_activeRequirementId);
        persistSessionSelection();
    }
    QMainWindow::closeEvent(event);
}

void MainWindow::editProject()
{
    if (m_activeProject.id == 0 || !canEditActiveProject())
        return;

    ProjectDialog dialog(this);
    dialog.setProject(m_activeProject);
    if (dialog.exec() != QDialog::Accepted)
        return;

    Project project = dialog.project();
    if (project.name.isEmpty()) {
        QMessageBox::warning(this, tr("Projekt"), tr("Bitte einen Projektnamen angeben."));
        return;
    }

    if (!m_context.projectRepository().updateProject(project)) {
        QMessageBox::critical(this, tr("Projekt"), m_context.projectRepository().lastError());
        return;
    }

    m_activeProject = project;
    updateWindowTitle();
    updateProjectUiEnabled();
    showTemporaryStatusMessage(tr("Projekteigenschaften gespeichert"));
}

void MainWindow::deleteProject()
{
    if (m_activeProject.id == 0 || !canDeleteActiveProject())
        return;

    const QMessageBox::StandardButton answer = QMessageBox::question(
        this,
        tr("Projekt löschen"),
        tr("Das Projekt \"%1\" und alle Zielobjekte, Bewertungen und Maßnahmen wirklich löschen?")
            .arg(m_activeProject.name));
    if (answer != QMessageBox::Yes)
        return;

    const QString projectName = m_activeProject.name;
    const int projectId = m_activeProject.id;
    if (!m_context.projectRepository().deleteProject(projectId)) {
        QMessageBox::critical(this, tr("Projekt"), m_context.projectRepository().lastError());
        return;
    }

    clearProjectSession();
    showTemporaryStatusMessage(tr("Projekt \"%1\" gelöscht").arg(projectName));
}

void MainWindow::createProject()
{
    Project draft;
    draft.name = tr("Neues ISMS-Projekt");

    ProjectDialog dialog(this);
    dialog.setProject(draft);
    if (dialog.exec() != QDialog::Accepted)
        return;

    const Project projectDraft = dialog.project();
    if (projectDraft.name.isEmpty()) {
        QMessageBox::warning(this, tr("Projekt"), tr("Bitte einen Projektnamen angeben."));
        return;
    }

    if (m_activeRequirementId != 0 && m_displayedAssessmentTargetId != 0)
        saveAssessmentFor(m_displayedAssessmentTargetId, m_activeRequirementId);
    if (m_activeProject.id != 0)
        persistSessionSelection();

    m_activeProject = m_context.projectRepository().createProject(
        projectDraft.name, projectDraft.description, m_context.catalogVersion());
    if (m_activeProject.id == 0) {
        QMessageBox::critical(this, tr("Projekt"), m_context.projectRepository().lastError());
        return;
    }

    m_activeTargetObject =
        m_context.targetObjectRepository().createDefaultScope(m_activeProject.id, m_activeProject.name);
    if (m_activeTargetObject.id == 0) {
        QMessageBox::warning(this,
                             tr("Projekt"),
                             tr("Projekt erstellt, aber der Informationsverbund konnte nicht angelegt werden: %1")
                                 .arg(m_context.targetObjectRepository().lastError()));
    }

    m_lastBausteinByTarget.clear();
    m_lastRequirementByTarget.clear();
    m_preferredTargetObjectId = 0;
    m_preferredBausteinId = 0;
    m_preferredRequirementId = 0;
    m_restoreRequirementId = 0;
    clearRequirementView();
    m_bausteinTree->setCurrentIndex({});
    reloadTargetObjects();
    updateWindowTitle();
    updateProjectUiEnabled();
    showTemporaryStatusMessage(tr("Projekt \"%1\" erstellt").arg(m_activeProject.name));
}

void MainWindow::onTargetObjectSelected(const QModelIndex &index)
{
    m_blockBausteinSelectionHandler = true;
    struct HandlerGuard {
        MainWindow *window = nullptr;
        ~HandlerGuard()
        {
            if (window)
                window->m_blockBausteinSelectionHandler = false;
        }
    } handlerGuard{this};
    QSignalBlocker bausteinSelectionBlocker(m_bausteinTree->selectionModel());

    const int previousTargetId = m_activeTargetObject.id;
    const int previousRequirementId = m_activeRequirementId;

    if (index.isValid()) {
        const TargetObject selected = m_targetObjectModel->targetObjectForIndex(index);
        if (selected.id != previousTargetId && previousRequirementId != 0 && previousTargetId != 0)
            saveAssessmentFor(previousTargetId, previousRequirementId);
    } else if (previousTargetId != 0 && previousRequirementId != 0) {
        saveAssessmentFor(previousTargetId, previousRequirementId);
    }

    if (previousTargetId != 0)
        persistTargetSelection(previousTargetId);

    if (!index.isValid()) {
        m_activeTargetObject = {};
        reloadBausteinMarkers();
        updateProjectUiEnabled();
        reloadProgress();
        clearRequirementView();
        return;
    }

    const TargetObject selected = m_targetObjectModel->targetObjectForIndex(index);
    m_activeRequirementId = 0;
    m_displayedAssessmentTargetId = 0;
    m_activeTargetObject = selected;
    reloadBausteinMarkers();
    ensureApplicableFilterFeasible();
    restoreTargetSelection(selected.id);
    updateProjectUiEnabled();
    reloadProgress();

    if (m_activeBausteinId == 0) {
        clearRequirementView();
        return;
    }

    reloadActiveTargetContent();
}

void MainWindow::onBausteinSelected(const QModelIndex &index)
{
    if (m_blockBausteinSelectionHandler)
        return;

    if (!index.isValid() || index.data(BausteinTreeModel::IsGroupRole).toBool()) {
        if (m_activeBausteinId != 0) {
            if (m_activeRequirementId != 0 && m_displayedAssessmentTargetId != 0)
                saveAssessmentFor(m_displayedAssessmentTargetId, m_activeRequirementId);
            m_activeBausteinId = 0;
            if (hasActiveProjectContext())
                persistTargetSelection(m_activeTargetObject.id);
            clearRequirementView();
        }
        return;
    }

    const Baustein baustein = m_bausteinModel->bausteinForIndex(index);
    if (baustein.id == 0)
        return;

    const int previousBausteinId = m_activeBausteinId;

    if (baustein.id != m_activeBausteinId) {
        if (m_activeRequirementId != 0 && m_displayedAssessmentTargetId != 0)
            saveAssessmentFor(m_displayedAssessmentTargetId, m_activeRequirementId);
        m_activeRequirementId = 0;
        m_displayedAssessmentTargetId = 0;
    }

    m_suppressAssessmentSave = true;
    struct SaveGuard {
        MainWindow *window = nullptr;
        ~SaveGuard()
        {
            if (window)
                window->m_suppressAssessmentSave = false;
        }
    } saveGuard{this};

    const ApplicabilityStatus applicability = hasActiveProjectContext()
        ? m_context.targetObjectRepository().applicability(
              m_activeProject.id, m_activeTargetObject.id, baustein.id)
        : ApplicabilityStatus::Undefined;
    if (!isBausteinApplicableForActiveTarget(baustein.id)) {
        showBausteinNotApplicableMessage(baustein.id, applicability);
        revertBausteinTreeSelection(previousBausteinId);
        showTemporaryStatusMessage(
            tr("Baustein \"%1 %2\" ist für dieses Zielobjekt noch nicht zugewiesen. "
               "Rechtsklick → \"Benötigt\" oder \"Möglicherweise\".")
                .arg(baustein.externalId, baustein.title),
            6000);
        return;
    }

    m_activeBausteinId = baustein.id;
    if (hasActiveProjectContext())
        persistTargetSelection(m_activeTargetObject.id);

    loadRequirementsForBaustein(baustein.id);
    syncAssignedBausteinBoxSelection();
}

void MainWindow::loadRequirementsForBaustein(int bausteinDbId)
{
    QList<Requirement> requirements = m_context.catalogRepository().loadRequirements(bausteinDbId);

    if (hasActiveProjectContext()) {
        QList<Requirement> filtered;
        for (const Requirement &requirement : requirements) {
            if (requirementLevelApplies(requirement.level, m_activeTargetObject.protectionNeed))
                filtered.append(requirement);
        }
        requirements = filtered;
    }

    m_requirementModel->setRequirements(requirements);
    refreshAssessmentColumn();

    if (!requirements.isEmpty()) {
        int rowToSelect = 0;
        if (m_restoreRequirementId != 0) {
            for (int row = 0; row < requirements.size(); ++row) {
                if (requirements.at(row).id == m_restoreRequirementId) {
                    rowToSelect = row;
                    break;
                }
            }
            m_restoreRequirementId = 0;
        }

        m_requirementTable->selectRow(rowToSelect);
        loadRequirementDetails(rowToSelect, true);
    } else {
        m_activeRequirementId = 0;
        m_displayedAssessmentTargetId = 0;
        m_requirementText->clear();
        m_assessmentNote->clear();
        m_responsibleEdit->clear();
        m_hasDueDateBox->setChecked(false);
        m_measureModel->setMeasures({});
    }
}

void MainWindow::refreshAssessmentColumn()
{
    if (!hasActiveProjectContext())
        return;

    const QHash<int, int> measureCounts = m_context.measureRepository().measureCounts(
        m_activeProject.id, m_activeTargetObject.id);

    for (int row = 0; row < m_requirementModel->rowCount(); ++row) {
        const Requirement requirement = m_requirementModel->requirementAt(row);
        RequirementAssessment assessment = m_context.projectRepository().loadAssessment(
            m_activeProject.id, m_activeTargetObject.id, requirement.id);
        assessment.measureCount = measureCounts.value(requirement.id, 0);
        m_requirementModel->setAssessment(requirement.id, assessment);
    }
}

void MainWindow::syncAssessmentUi(const RequirementAssessment &assessment)
{
    QSignalBlocker statusBlocker(m_statusBox);
    QSignalBlocker noteBlocker(m_assessmentNote);
    QSignalBlocker responsibleBlocker(m_responsibleEdit);
    QSignalBlocker dueDateEnabledBlocker(m_hasDueDateBox);
    QSignalBlocker dueDateBlocker(m_dueDateEdit);

    const int statusIndex = m_statusBox->findData(static_cast<int>(assessment.status));
    if (statusIndex >= 0)
        m_statusBox->setCurrentIndex(statusIndex);
    m_assessmentNote->setPlainText(assessment.note);
    m_responsibleEdit->setText(assessment.responsible);
    m_hasDueDateBox->setChecked(assessment.dueDate.isValid());
    if (assessment.dueDate.isValid())
        m_dueDateEdit->setDate(assessment.dueDate);
    else
        m_dueDateEdit->setDate(QDate::currentDate());
    m_dueDateEdit->setEnabled(m_hasDueDateBox->isChecked() && hasActiveProjectContext());
}

Requirement MainWindow::currentRequirement() const
{
    const QModelIndex tableIndex = m_requirementTable->currentIndex();
    if (!tableIndex.isValid())
        return {};
    return m_requirementModel->requirementAt(tableIndex.row());
}

void MainWindow::loadMeasuresForCurrentRequirement()
{
    if (!hasActiveProjectContext()) {
        m_measureModel->setMeasures({});
        return;
    }

    const Requirement requirement = currentRequirement();
    if (requirement.id == 0) {
        m_measureModel->setMeasures({});
        return;
    }

    const QList<Measure> measures = m_context.measureRepository().loadMeasures(
        m_activeProject.id, m_activeTargetObject.id, requirement.id);
    m_measureModel->setMeasures(measures);
}

bool MainWindow::saveAssessmentFor(int targetObjectId, int requirementDbId, bool notifyConflictDialog)
{
    if (m_suppressAssessmentSave || m_activeProject.id == 0)
        return false;
    if (!canEditActiveProject())
        return true;
    if (targetObjectId == 0 || requirementDbId == 0)
        return false;

    if (m_displayedAssessmentTargetId != 0) {
        if (m_displayedAssessmentTargetId != targetObjectId)
            return false;
    } else if (m_activeTargetObject.id != 0 && m_activeTargetObject.id != targetObjectId) {
        return false;
    }
    if (m_activeRequirementId != 0 && m_activeRequirementId != requirementDbId)
        return false;

    RequirementAssessment assessment = m_context.projectRepository().loadAssessment(
        m_activeProject.id, targetObjectId, requirementDbId);
    assessment.projectId = m_activeProject.id;
    assessment.targetObjectId = targetObjectId;
    assessment.requirementDbId = requirementDbId;
    assessment.status = static_cast<AssessmentStatus>(m_statusBox->currentData().toInt());
    assessment.note = m_assessmentNote->toPlainText();
    assessment.responsible = m_responsibleEdit->text().trimmed();
    assessment.dueDate = m_hasDueDateBox->isChecked() ? m_dueDateEdit->date() : QDate();
    assessment.measureCount = m_context.measureRepository()
                                  .measureCounts(m_activeProject.id, targetObjectId)
                                  .value(requirementDbId, 0);

    const AssessmentSaveResult result = m_context.projectRepository().saveAssessment(assessment);
    if (result.status == AssessmentSaveResult::Status::Ok) {
        if (m_activeTargetObject.id == targetObjectId && m_activeRequirementId == requirementDbId) {
            RequirementAssessment updated = result.assessment;
            updated.measureCount = assessment.measureCount;
            m_requirementModel->setAssessment(requirementDbId, updated);
        }
        if (m_lastConflictNotifiedRequirementId == requirementDbId)
            m_lastConflictNotifiedRequirementId = 0;
        return true;
    }
    if (result.status == AssessmentSaveResult::Status::VersionConflict) {
        applyAssessmentConflict(result.assessment, requirementDbId, notifyConflictDialog);
        return false;
    }
    if (result.status == AssessmentSaveResult::Status::Forbidden) {
        if (notifyConflictDialog)
            notifySaveFailure(m_context.projectRepository().lastError(), true);
        return false;
    }
    if (notifyConflictDialog)
        notifySaveFailure(m_context.projectRepository().lastError(), true);
    return false;
}

bool MainWindow::saveCurrentAssessment(bool notifyConflictDialog)
{
    if (!hasActiveProjectContext())
        return false;

    const int targetObjectId = m_displayedAssessmentTargetId != 0
                                   ? m_displayedAssessmentTargetId
                                   : m_activeTargetObject.id;
    int requirementDbId = m_activeRequirementId;
    if (requirementDbId == 0) {
        const Requirement requirement = currentRequirement();
        requirementDbId = requirement.id;
    }
    if (requirementDbId == 0)
        return false;

    if (m_displayedAssessmentTargetId != 0 && m_displayedAssessmentTargetId != m_activeTargetObject.id)
        return false;

    return saveAssessmentFor(targetObjectId, requirementDbId, notifyConflictDialog);
}

void MainWindow::onRequirementSelected(const QModelIndex &index)
{
    if (!index.isValid())
        return;

    loadRequirementDetails(index.row(), false);
}

void MainWindow::loadRequirementDetails(int row, bool forceReload)
{
    if (row < 0 || row >= m_requirementModel->rowCount())
        return;

    const Requirement requirement = m_requirementModel->requirementAt(row);
    if (!forceReload && requirement.id == m_activeRequirementId
        && m_activeTargetObject.id == m_displayedAssessmentTargetId)
        return;

    if (!forceReload && m_activeRequirementId != 0 && m_displayedAssessmentTargetId != 0)
        saveAssessmentFor(m_displayedAssessmentTargetId, m_activeRequirementId);

    m_activeRequirementId = requirement.id;
    m_displayedAssessmentTargetId = m_activeTargetObject.id;
    if (hasActiveProjectContext())
        persistTargetSelection(m_activeTargetObject.id);

    m_requirementText->setPlainText(requirement.text);

    if (!hasActiveProjectContext()) {
        m_assessmentNote->clear();
        m_responsibleEdit->clear();
        m_hasDueDateBox->setChecked(false);
        m_measureModel->setMeasures({});
        return;
    }

    RequirementAssessment assessment = m_context.projectRepository().loadAssessment(
        m_activeProject.id, m_activeTargetObject.id, requirement.id);
    assessment.measureCount = m_context.measureRepository()
                                  .loadMeasures(m_activeProject.id, m_activeTargetObject.id, requirement.id)
                                  .size();
    syncAssessmentUi(assessment);
    loadMeasuresForCurrentRequirement();
}

void MainWindow::setAssessmentStatus(int index)
{
    Q_UNUSED(index)

    if (saveCurrentAssessment(true))
        return;

    notifySaveFailure(m_context.projectRepository().lastError(), true);
}

void MainWindow::saveAssessmentFields()
{
    if (m_suppressAssessmentSave || !canEditActiveProject())
        return;

    if (saveCurrentAssessment(false))
        return;

    notifySaveFailure(m_context.projectRepository().lastError(), false);
}

void MainWindow::addMeasure()
{
    if (!hasActiveProjectContext() || !canEditActiveProject())
        return;

    const Requirement requirement = currentRequirement();
    if (requirement.id == 0)
        return;

    MeasureDialog dialog(this);
    Measure draft;
    draft.projectId = m_activeProject.id;
    draft.targetObjectId = m_activeTargetObject.id;
    draft.requirementDbId = requirement.id;
    draft.title = tr("Neue Maßnahme");
    draft.responsible = m_responsibleEdit->text().trimmed();
    if (m_hasDueDateBox->isChecked())
        draft.dueDate = m_dueDateEdit->date();
    dialog.setMeasure(draft);

    if (dialog.exec() != QDialog::Accepted)
        return;

    const Measure created = m_context.measureRepository().createMeasure(dialog.measure());
    if (created.id == 0) {
        QMessageBox::critical(this, tr("Maßnahme"), m_context.measureRepository().lastError());
        return;
    }

    loadMeasuresForCurrentRequirement();
    refreshAssessmentColumn();
    reloadProgress();
}

void MainWindow::editMeasure()
{
    const QModelIndex index = m_measureTable->currentIndex();
    if (!index.isValid() || !hasActiveProjectContext())
        return;

    const bool canEdit = canEditActiveProject();
    Measure measure = m_measureModel->measureAt(index.row());
    MeasureDialog dialog(this);
    dialog.setMeasure(measure);
    dialog.setReadOnly(!canEdit);
    if (dialog.exec() != QDialog::Accepted || !canEdit)
        return;

    measure = dialog.measure();
    const MeasureSaveResult result = m_context.measureRepository().updateMeasure(measure);
    if (result.status == MeasureSaveResult::Status::Ok) {
        loadMeasuresForCurrentRequirement();
        reloadProgress();
        return;
    }
    if (result.status == MeasureSaveResult::Status::VersionConflict) {
        QMessageBox::warning(
            this,
            tr("Konflikt"),
            tr("Ein anderer Benutzer hat diese Maßnahme zwischenzeitlich geändert. "
               "Die Liste wurde neu geladen."));
        loadMeasuresForCurrentRequirement();
        reloadProgress();
        return;
    }
    if (result.status == MeasureSaveResult::Status::Forbidden) {
        notifySaveFailure(m_context.measureRepository().lastError(), true);
        return;
    }

    QMessageBox::critical(this, tr("Maßnahme"), m_context.measureRepository().lastError());
}

void MainWindow::deleteMeasure()
{
    if (!canEditActiveProject())
        return;

    const QModelIndex index = m_measureTable->currentIndex();
    if (!index.isValid() || !hasActiveProjectContext())
        return;

    const Measure measure = m_measureModel->measureAt(index.row());
    const QMessageBox::StandardButton answer = QMessageBox::question(
        this, tr("Maßnahme löschen"), tr("Maßnahme \"%1\" wirklich löschen?").arg(measure.title));
    if (answer != QMessageBox::Yes)
        return;

    if (!m_context.measureRepository().deleteMeasure(measure.id)) {
        QMessageBox::critical(this, tr("Maßnahme"), m_context.measureRepository().lastError());
        return;
    }

    loadMeasuresForCurrentRequirement();
    refreshAssessmentColumn();
    reloadProgress();
}

void MainWindow::addTargetObject()
{
    if (m_activeProject.id == 0) {
        QMessageBox::information(this, tr("Projekt"), tr("Bitte zuerst ein Projekt anlegen."));
        return;
    }
    if (!canEditActiveProject())
        return;

    TargetObject parentObject = m_activeTargetObject;
    const QModelIndex currentIndex = m_targetObjectTree->currentIndex();
    if (currentIndex.isValid())
        parentObject = m_targetObjectModel->targetObjectForIndex(currentIndex);

    TargetObjectDialog dialog(this);
    TargetObject draft;
    draft.projectId = m_activeProject.id;
    draft.parentId = parentObject.id;
    draft.type = TargetObjectType::Process;
    draft.name = tr("Neues Zielobjekt");
    dialog.setTargetObject(draft);

    if (dialog.exec() != QDialog::Accepted)
        return;

    const TargetObject created = m_context.targetObjectRepository().createTargetObject(dialog.targetObject());
    if (created.id == 0) {
        QMessageBox::critical(this, tr("Zielobjekt"), m_context.targetObjectRepository().lastError());
        return;
    }

    m_activeTargetObject = created;
    reloadTargetObjects();
}

void MainWindow::editTargetObject()
{
    if (!canEditActiveProject())
        return;

    const QModelIndex index = m_targetObjectTree->currentIndex();
    if (!index.isValid() || m_activeProject.id == 0)
        return;

    TargetObject object = m_targetObjectModel->targetObjectForIndex(index);
    TargetObjectDialog dialog(this);
    dialog.setTargetObject(object);
    if (dialog.exec() != QDialog::Accepted)
        return;

    object = dialog.targetObject();
    if (!m_context.targetObjectRepository().updateTargetObject(object)) {
        QMessageBox::critical(this, tr("Zielobjekt"), m_context.targetObjectRepository().lastError());
        return;
    }

    if (m_activeTargetObject.id == object.id)
        m_activeTargetObject = object;
    reloadTargetObjects();
    reloadActiveTargetContent();
}

void MainWindow::deleteTargetObject()
{
    if (!canEditActiveProject())
        return;

    const QModelIndex index = m_targetObjectTree->currentIndex();
    if (!index.isValid() || m_activeProject.id == 0)
        return;

    const TargetObject object = m_targetObjectModel->targetObjectForIndex(index);
    const QMessageBox::StandardButton answer = QMessageBox::question(
        this,
        tr("Zielobjekt löschen"),
        tr("Das Zielobjekt \"%1\" und alle untergeordneten Objekte wirklich löschen?").arg(object.name));
    if (answer != QMessageBox::Yes)
        return;

    QSet<int> deletedTargetIds;
    const auto collectSubtreeIds = [this](const auto &self, const QModelIndex &parentIndex,
                                          QSet<int> *ids) -> void {
        const TargetObject target = m_targetObjectModel->targetObjectForIndex(parentIndex);
        if (target.id != 0)
            ids->insert(target.id);
        for (int row = 0; row < m_targetObjectModel->rowCount(parentIndex); ++row)
            self(self, m_targetObjectModel->index(row, 0, parentIndex), ids);
    };
    collectSubtreeIds(collectSubtreeIds, index, &deletedTargetIds);

    if (!m_context.targetObjectRepository().deleteTargetObject(object.id)) {
        QMessageBox::critical(this, tr("Zielobjekt"), m_context.targetObjectRepository().lastError());
        return;
    }

    for (int targetId : deletedTargetIds) {
        m_lastBausteinByTarget.remove(targetId);
        m_lastRequirementByTarget.remove(targetId);
    }
    persistAllTargetSelections();

    if (m_activeTargetObject.id == object.id
        || deletedTargetIds.contains(m_activeTargetObject.id))
        m_activeTargetObject = {};
    reloadTargetObjects();
}

void MainWindow::showTargetObjectContextMenu(const QPoint &pos)
{
    if (m_activeProject.id == 0)
        return;

    const QModelIndex index = m_targetObjectTree->indexAt(pos);
    if (index.isValid())
        m_targetObjectTree->setCurrentIndex(index);

    QMenu menu(this);
    if (canEditActiveProject()) {
        menu.addAction(tr("Zielobjekt hinzufügen..."), this, &MainWindow::addTargetObject);
        menu.addAction(tr("Bearbeiten..."), this, &MainWindow::editTargetObject);
        menu.addAction(tr("Löschen"), this, &MainWindow::deleteTargetObject);
        menu.addSeparator();
        menu.addAction(tr("Baustein-Empfehlungen übernehmen..."), this,
                       &MainWindow::applyBausteinRecommendations);
    }
    menu.exec(m_targetObjectTree->viewport()->mapToGlobal(pos));
}

void MainWindow::showBausteinContextMenu(const QPoint &pos)
{
    const QModelIndex index = m_bausteinTree->indexAt(pos);
    if (!index.isValid() || index.data(BausteinTreeModel::IsGroupRole).toBool())
        return;

    const int previousBausteinId = m_activeBausteinId;
    QSignalBlocker selectionBlocker(m_bausteinTree->selectionModel());
    m_bausteinTree->setCurrentIndex(index);

    QMenu menu(this);
    menu.addAction(tr("Baustein anzeigen..."), this, &MainWindow::viewSelectedBaustein);
    if (hasActiveProjectContext() && canEditActiveProject()) {
        menu.addSeparator();
        menu.addAction(tr("Benötigt"), this, [this]() {
            setBausteinApplicability(ApplicabilityStatus::Required);
        });
        menu.addAction(tr("Möglicherweise"), this, [this]() {
            setBausteinApplicability(ApplicabilityStatus::Possible);
        });
        menu.addAction(tr("Nicht relevant"), this, [this]() {
            setBausteinApplicability(ApplicabilityStatus::NotApplicable);
        });
        menu.addSeparator();
        menu.addAction(tr("Zurücksetzen"), this, [this]() {
            setBausteinApplicability(ApplicabilityStatus::Undefined);
        });
    }
    if (menu.exec(m_bausteinTree->viewport()->mapToGlobal(pos)) == nullptr)
        revertBausteinTreeSelection(previousBausteinId);
}

void MainWindow::setBausteinApplicability(ApplicabilityStatus status)
{
    if (!canEditActiveProject())
        return;

    const QModelIndex index = m_bausteinTree->currentIndex();
    if (!index.isValid() || !hasActiveProjectContext())
        return;

    const Baustein baustein = m_bausteinModel->bausteinForIndex(index);
    if (baustein.id == 0)
        return;

    if (status == ApplicabilityStatus::Undefined) {
        const QMessageBox::StandardButton answer = QMessageBox::question(
            this,
            tr("Zuweisung zurücksetzen"),
            tr("Die Zuweisung von \"%1 %2\" zum Zielobjekt \"%3 – %4\" wirklich entfernen?")
                .arg(baustein.externalId,
                     baustein.title,
                     targetObjectTypeToString(m_activeTargetObject.type),
                     m_activeTargetObject.name));
        if (answer != QMessageBox::Yes) {
            revertBausteinTreeSelection(m_activeBausteinId);
            return;
        }
    }

    BausteinApplicability applicability;
    applicability.projectId = m_activeProject.id;
    applicability.targetObjectId = m_activeTargetObject.id;
    applicability.bausteinDbId = baustein.id;
    applicability.status = status;

    if (!m_context.targetObjectRepository().saveApplicability(applicability)) {
        QMessageBox::warning(this, tr("Anwendbarkeit"), m_context.targetObjectRepository().lastError());
        revertBausteinTreeSelection(m_activeBausteinId);
        return;
    }

    if (status == ApplicabilityStatus::Required || status == ApplicabilityStatus::Possible) {
        m_activeBausteinId = baustein.id;
        persistTargetSelection(m_activeTargetObject.id);
        reloadBausteinMarkers();
        reloadProgress();
        restoreBausteinSelection(baustein.id);
        reloadActiveTargetContent();
    } else if (m_bausteinTree->currentIndex() == index) {
        if (m_lastBausteinByTarget.value(m_activeTargetObject.id) == baustein.id) {
            m_lastBausteinByTarget.remove(m_activeTargetObject.id);
            m_lastRequirementByTarget.remove(m_activeTargetObject.id);
        }

        int fallbackBausteinId = 0;
        const QHash<int, ApplicabilityStatus> map =
            m_context.targetObjectRepository().loadApplicabilityMap(m_activeProject.id,
                                                                    m_activeTargetObject.id);
        for (auto it = map.constBegin(); it != map.constEnd(); ++it) {
            if (it.key() == baustein.id)
                continue;
            if (it.value() == ApplicabilityStatus::Required
                || it.value() == ApplicabilityStatus::Possible) {
                fallbackBausteinId = it.key();
                break;
            }
        }

        if (fallbackBausteinId != 0 && isBausteinApplicableForActiveTarget(fallbackBausteinId))
            m_activeBausteinId = fallbackBausteinId;
        else
            m_activeBausteinId = 0;

        reloadBausteinMarkers();
        reloadProgress();
        revertBausteinTreeSelection(fallbackBausteinId);
    }
}

void MainWindow::toggleApplicableFilter(bool enabled)
{
    const int previousBausteinId = m_activeBausteinId;

    if (enabled && hasActiveProjectContext() && !hasApplicableBausteineForActiveTarget()) {
        QSignalBlocker blocker(m_filterApplicableBox);
        m_filterApplicableBox->setChecked(false);
        QMessageBox::information(
            this,
            tr("Nur anwendbare Bausteine"),
            tr("Für \"%1 – %2\" sind noch keine Bausteine als anwendbar markiert.\n\n"
               "So geht's:\n"
               "1. Haken bei \"Nur anwendbare Bausteine\" entfernt lassen\n"
               "2. Baustein in der Liste auswählen\n"
               "3. Rechtsklick → \"Benötigt\" oder \"Möglicherweise\"\n"
               "4. Danach kann der Filter aktiviert werden")
                .arg(targetObjectTypeToString(m_activeTargetObject.type), m_activeTargetObject.name));
        return;
    }

    m_bausteinModel->setHideNonApplicable(enabled);
    m_bausteinTree->expandAll();
    restoreBausteinSelection(previousBausteinId);
    reloadActiveTargetContent();
}

void MainWindow::toggleRecommendationHighlight(bool enabled)
{
    m_bausteinModel->setHighlightRecommendations(enabled);
}

void MainWindow::applyBausteinRecommendations()
{
    if (!hasActiveProjectContext()) {
        QMessageBox::information(this,
                               tr("Baustein-Empfehlungen"),
                               tr("Bitte zuerst ein Projekt und ein Zielobjekt wählen."));
        return;
    }
    if (!canEditActiveProject())
        return;

    const QList<Baustein> allBausteine = m_context.catalogRepository().loadBausteine(
        StandardType::ITGrundschutz, m_context.catalogVersion());
    const QList<BausteinRecommendation> recommendations =
        BausteinRecommendationService::buildRecommendations(allBausteine, m_activeTargetObject);
    if (recommendations.isEmpty()) {
        QMessageBox::information(this,
                               tr("Baustein-Empfehlungen"),
                               tr("Für Zielobjekt \"%1\" (%2, %3) sind keine Baustein-Empfehlungen hinterlegt.")
                                   .arg(m_activeTargetObject.name,
                                        targetObjectTypeToString(m_activeTargetObject.type),
                                        protectionNeedToString(m_activeTargetObject.protectionNeed)));
        return;
    }

    const QHash<int, ApplicabilityStatus> applicabilityMap =
        m_context.targetObjectRepository().loadApplicabilityMap(m_activeProject.id,
                                                                m_activeTargetObject.id);

    BausteinRecommendationDialog dialog(recommendations, applicabilityMap, m_activeTargetObject, this);
    if (dialog.exec() != QDialog::Accepted)
        return;

    const QList<BausteinRecommendationSelection> selections = dialog.selections();
    if (selections.isEmpty()) {
        showTemporaryStatusMessage(tr("Keine Baustein-Empfehlungen übernommen"), 4000);
        return;
    }

    int appliedCount = 0;
    for (const BausteinRecommendationSelection &selection : selections) {
        BausteinApplicability applicability;
        applicability.projectId = m_activeProject.id;
        applicability.targetObjectId = m_activeTargetObject.id;
        applicability.bausteinDbId = selection.bausteinDbId;
        applicability.status = selection.status;

        if (!m_context.targetObjectRepository().saveApplicability(applicability))
            continue;
        ++appliedCount;
    }

    reloadBausteinMarkers();
    reloadProgress();

    const QModelIndex bausteinIndex = m_bausteinTree->currentIndex();
    if (bausteinIndex.isValid())
        onBausteinSelected(bausteinIndex);

    showTemporaryStatusMessage(tr("%1 Baustein-Empfehlungen übernommen").arg(appliedCount));
}

void MainWindow::showSollIstReport()
{
    if (m_activeProject.id == 0) {
        QMessageBox::information(this, tr("Berichte"), tr("Bitte zuerst ein Projekt anlegen."));
        return;
    }

    ReportDialog dialog(m_context, m_activeProject, m_activeTargetObject, this);
    dialog.exec();
}

QSet<int> MainWindow::matchingBausteinIdsForSearch(const QString &query) const
{
    QSet<int> matches;
    const QString needle = query.trimmed();
    if (needle.isEmpty())
        return matches;

    for (const Baustein &baustein : m_catalogBausteine) {
        if (baustein.externalId.contains(needle, Qt::CaseInsensitive)
            || baustein.title.contains(needle, Qt::CaseInsensitive)
            || baustein.groupName.contains(needle, Qt::CaseInsensitive)) {
            matches.insert(baustein.id);
        }
    }

    for (const Requirement &requirement : m_catalogRequirements) {
        if (requirement.externalId.contains(needle, Qt::CaseInsensitive)
            || requirement.title.contains(needle, Qt::CaseInsensitive)
            || requirement.text.contains(needle, Qt::CaseInsensitive)
            || requirement.responsibleRole.contains(needle, Qt::CaseInsensitive)) {
            matches.insert(requirement.bausteinDbId);
        }
    }

    return matches;
}

void MainWindow::applyBausteinSearchFilter()
{
    const QString query = m_bausteinSearchEdit != nullptr ? m_bausteinSearchEdit->text() : QString();
    m_bausteinModel->setSearchFilter(query, matchingBausteinIdsForSearch(query));
    if (m_bausteinTree != nullptr)
        m_bausteinTree->expandAll();
}

void MainWindow::openBausteinViewDialog(const Baustein &baustein, const QString &initialSearch)
{
    if (baustein.id == 0)
        return;

    QList<Requirement> requirements = m_context.catalogRepository().loadRequirements(baustein.id);
    BausteinViewDialog dialog(baustein, requirements, initialSearch, 0, this);
    dialog.exec();
}

void MainWindow::viewSelectedBaustein()
{
    const QModelIndex index = m_bausteinTree->currentIndex();
    if (!index.isValid() || index.data(BausteinTreeModel::IsGroupRole).toBool()) {
        QMessageBox::information(this, tr("Baustein anzeigen"),
                                 tr("Bitte zuerst einen Baustein in der Bausteinliste auswählen."));
        return;
    }

    const Baustein baustein = m_bausteinModel->bausteinForIndex(index);
    const QString initialSearch = m_bausteinSearchEdit != nullptr ? m_bausteinSearchEdit->text().trimmed()
                                                                : QString();
    openBausteinViewDialog(baustein, initialSearch);
}

void MainWindow::showCatalogSearch()
{
    const QString initialQuery =
        m_bausteinSearchEdit != nullptr ? m_bausteinSearchEdit->text().trimmed() : QString();
    CatalogSearchDialog dialog(m_catalogBausteine, m_catalogRequirements, initialQuery, this);
    dialog.exec();
}

void MainWindow::updateWindowTitle()
{
    const int requirementCount = m_catalogRequirements.size();
    QString title = tr("ISMS Werkzeug – IT-Grundschutz %1").arg(m_context.catalogVersion());
    if (m_activeProject.id != 0)
        title += tr(" – Projekt: %1").arg(m_activeProject.name);
    title += tr(" (%1 Anforderungen im Katalog)").arg(requirementCount);
    setWindowTitle(title);
}
