#include "MainWindow.h"

#include "app/AppPaths.h"
#include "catalog/GrundschutzImporter.h"
#include "domain/AssessmentStatus.h"
#include "domain/Measure.h"
#include "domain/ProtectionNeed.h"
#include "domain/Standard.h"
#include "domain/TargetObject.h"
#include "domain/TargetObjectType.h"
#include "ui/dialogs/BausteinRecommendationDialog.h"
#include "services/BausteinRecommendationService.h"
#include "ui/dialogs/MeasureDialog.h"
#include "ui/dialogs/ProjectOpenDialog.h"
#include "ui/dialogs/ProjectDialog.h"
#include "ui/dialogs/ReportDialog.h"
#include "ui/dialogs/TargetObjectDialog.h"

#include <QAction>
#include <QCheckBox>
#include <QComboBox>
#include <QDate>
#include <QDateEdit>
#include <QDockWidget>
#include <QFileDialog>
#include <QHash>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QKeySequence>
#include <QLabel>
#include <QMenu>
#include <QMenuBar>
#include <QMessageBox>
#include <QPushButton>
#include <QSet>
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

MainWindow::MainWindow(AppContext &context, QWidget *parent)
    : QMainWindow(parent)
    , m_context(context)
{
    setWindowTitle(QStringLiteral("ISMS Werkzeug"));
    resize(1400, 850);
    buildUi();
    reloadCatalog();
    updateProjectUiEnabled();
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
    connect(m_targetObjectTree, &QTreeView::clicked, this, &MainWindow::onTargetObjectSelected);
    connect(m_targetObjectTree, &QTreeView::customContextMenuRequested, this,
            &MainWindow::showTargetObjectContextMenu);

    auto *targetDock = new QDockWidget(tr("Zielobjekte"), this);
    targetDock->setWidget(m_targetObjectTree);
    addDockWidget(Qt::LeftDockWidgetArea, targetDock);

    m_filterApplicableBox = new QCheckBox(tr("Nur anwendbare Bausteine"), this);
    connect(m_filterApplicableBox, &QCheckBox::toggled, this, &MainWindow::toggleApplicableFilter);

    m_highlightRecommendationsBox = new QCheckBox(tr("Empfehlungen hervorheben"), this);
    m_highlightRecommendationsBox->setChecked(true);
    connect(m_highlightRecommendationsBox, &QCheckBox::toggled, this,
            &MainWindow::toggleRecommendationHighlight);

    auto *bausteinPanel = new QWidget(this);
    auto *bausteinLayout = new QVBoxLayout(bausteinPanel);
    bausteinLayout->setContentsMargins(0, 0, 0, 0);
    bausteinLayout->addWidget(m_filterApplicableBox);
    bausteinLayout->addWidget(m_highlightRecommendationsBox);

    m_bausteinTree = new QTreeView(this);
    m_bausteinTree->setModel(m_bausteinModel);
    m_bausteinTree->setHeaderHidden(true);
    m_bausteinTree->setContextMenuPolicy(Qt::CustomContextMenu);
    connect(m_bausteinTree, &QTreeView::clicked, this, &MainWindow::onBausteinSelected);
    connect(m_bausteinTree, &QTreeView::customContextMenuRequested, this,
            &MainWindow::showBausteinContextMenu);
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
    connect(m_requirementTable, &QTableView::clicked, this, &MainWindow::onRequirementSelected);

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

    auto *centerSplitter = new QSplitter(Qt::Vertical, this);
    centerSplitter->addWidget(m_requirementTable);
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

    m_closeProjectAction->setEnabled(hasProject);
    m_editProjectAction->setEnabled(hasProject);
    m_deleteProjectAction->setEnabled(hasProject);
    m_addTargetAction->setEnabled(hasProject);
    m_editTargetAction->setEnabled(hasProject);
    m_deleteTargetAction->setEnabled(hasProject);
    m_applyRecommendationsAction->setEnabled(hasTargetObject);
    m_sollIstAction->setEnabled(hasProject);

    m_targetObjectTree->setEnabled(hasProject);
    m_filterApplicableBox->setEnabled(hasTargetObject);
    m_highlightRecommendationsBox->setEnabled(hasTargetObject);
    m_statusBox->setEnabled(hasTargetObject);
    m_assessmentNote->setEnabled(hasTargetObject);
    m_responsibleEdit->setEnabled(hasTargetObject);
    m_hasDueDateBox->setEnabled(hasTargetObject);
    m_dueDateEdit->setEnabled(hasTargetObject && m_hasDueDateBox->isChecked());
    m_measureTable->setEnabled(hasTargetObject);
    m_addMeasureButton->setEnabled(hasTargetObject);
    m_editMeasureButton->setEnabled(hasTargetObject);
    m_deleteMeasureButton->setEnabled(hasTargetObject);

    if (!hasProject) {
        m_contextLabel->setText(tr("Kein Projekt geöffnet"));
    } else if (m_activeTargetObject.id == 0) {
        m_contextLabel->setText(tr("Projekt \"%1\" – bitte Zielobjekt wählen").arg(m_activeProject.name));
    } else {
        m_contextLabel->setText(tr("Projekt \"%1\" – Zielobjekt: %2  (%3)")
                                    .arg(m_activeProject.name,
                                         m_activeTargetObject.name,
                                         protectionNeedToString(m_activeTargetObject.protectionNeed)));
    }
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
    const QList<Baustein> bausteine = m_context.catalogRepository().loadBausteine(
        StandardType::ITGrundschutz, m_context.catalogVersion());
    m_bausteinModel->setBausteine(bausteine);
    m_bausteinTree->expandAll();
    m_statusLabel->setText(tr("%1 Bausteine geladen").arg(bausteine.size()));
    reloadApplicabilityMarkers();
    reloadRecommendationMarkers();
    updateWindowTitle();
}

void MainWindow::reloadRecommendationMarkers()
{
    if (!hasActiveProjectContext()) {
        m_bausteinModel->setRecommendedBausteinIds({});
        return;
    }

    const QList<Baustein> bausteine = m_context.catalogRepository().loadBausteine(
        StandardType::ITGrundschutz, m_context.catalogVersion());
    QSet<int> recommendedIds;
    for (const Baustein &baustein : bausteine) {
        if (BausteinRecommendationService::isRecommended(baustein, m_activeTargetObject.type))
            recommendedIds.insert(baustein.id);
    }
    m_bausteinModel->setRecommendedBausteinIds(recommendedIds);
}

void MainWindow::reloadTargetObjects()
{
    if (m_activeProject.id == 0) {
        m_targetObjectModel->setTargetObjects({});
        m_activeTargetObject = {};
        updateProjectUiEnabled();
        return;
    }

    const QList<TargetObject> objects =
        m_context.targetObjectRepository().loadTargetObjects(m_activeProject.id);
    m_targetObjectModel->setTargetObjects(objects);
    m_targetObjectTree->expandAll();

    if (m_activeTargetObject.id != 0) {
        bool stillExists = false;
        for (const TargetObject &object : objects) {
            if (object.id == m_activeTargetObject.id) {
                m_activeTargetObject = object;
                stillExists = true;
                break;
            }
        }
        if (!stillExists)
            m_activeTargetObject = {};
    }

    if (m_activeTargetObject.id == 0 && !objects.isEmpty()) {
        for (const TargetObject &object : objects) {
            if (object.parentId == 0) {
                m_activeTargetObject = object;
                break;
            }
        }
    }

    reloadApplicabilityMarkers();
    reloadRecommendationMarkers();
    updateProjectUiEnabled();
    selectActiveTargetObjectInTree();
}

void MainWindow::selectActiveTargetObjectInTree()
{
    if (m_activeTargetObject.id == 0)
        return;

    const QModelIndex index =
        m_targetObjectModel->indexForTargetObjectId(m_activeTargetObject.id);
    if (!index.isValid())
        return;

    m_targetObjectTree->setCurrentIndex(index);
    onTargetObjectSelected(index);
}

void MainWindow::clearProjectSession()
{
    m_activeProject = {};
    m_activeTargetObject = {};
    m_requirementModel->clearAssessments();
    m_requirementModel->setRequirements({});
    m_measureModel->setMeasures({});
    m_requirementText->clear();
    m_assessmentNote->clear();
    m_responsibleEdit->clear();
    m_hasDueDateBox->setChecked(false);
    m_dueDateEdit->clear();
    m_bausteinModel->setApplicabilityMap({});
    m_bausteinModel->setRecommendedBausteinIds({});
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

void MainWindow::importCatalog()
{
    const QString filePath = QFileDialog::getOpenFileName(
        this,
        tr("IT-Grundschutz XML importieren"),
        AppPaths::defaultGrundschutzXml(),
        tr("XML Dateien (*.xml)"));
    if (filePath.isEmpty())
        return;

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

    ProjectOpenDialog dialog(projects, this);
    if (dialog.exec() != QDialog::Accepted)
        return;

    m_activeProject = dialog.selectedProject();
    if (m_activeProject.id == 0)
        return;

    m_activeTargetObject = {};
    m_requirementModel->clearAssessments();
    m_requirementModel->setRequirements({});
    m_measureModel->setMeasures({});
    reloadTargetObjects();
    updateWindowTitle();
    updateProjectUiEnabled();
    showTemporaryStatusMessage(tr("Projekt \"%1\" geöffnet").arg(m_activeProject.name));
}

void MainWindow::closeProject()
{
    if (m_activeProject.id == 0)
        return;

    const QString projectName = m_activeProject.name;
    clearProjectSession();
    showTemporaryStatusMessage(tr("Projekt \"%1\" geschlossen").arg(projectName));
}

void MainWindow::editProject()
{
    if (m_activeProject.id == 0)
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
    if (m_activeProject.id == 0)
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

    m_requirementModel->clearAssessments();
    m_requirementModel->setRequirements({});
    m_requirementText->clear();
    m_assessmentNote->clear();
    reloadTargetObjects();
    updateWindowTitle();
    updateProjectUiEnabled();
    showTemporaryStatusMessage(tr("Projekt \"%1\" erstellt").arg(m_activeProject.name));
}

void MainWindow::onTargetObjectSelected(const QModelIndex &index)
{
    if (!index.isValid())
        return;

    m_activeTargetObject = m_targetObjectModel->targetObjectForIndex(index);
    reloadApplicabilityMarkers();
    reloadRecommendationMarkers();
    updateProjectUiEnabled();

    const QModelIndex bausteinIndex = m_bausteinTree->currentIndex();
    if (bausteinIndex.isValid())
        onBausteinSelected(bausteinIndex);
}

void MainWindow::onBausteinSelected(const QModelIndex &index)
{
    if (!index.isValid() || index.data(BausteinTreeModel::IsGroupRole).toBool())
        return;

    const Baustein baustein = m_bausteinModel->bausteinForIndex(index);
    if (baustein.id == 0)
        return;

    if (hasActiveProjectContext()) {
        const ApplicabilityStatus applicability = m_context.targetObjectRepository().applicability(
            m_activeProject.id, m_activeTargetObject.id, baustein.id);
        if (applicability == ApplicabilityStatus::NotApplicable) {
            m_requirementModel->setRequirements({});
            m_requirementText->setPlainText(
                tr("Dieser Baustein ist für das ausgewählte Zielobjekt als \"Nicht relevant\" markiert."));
            m_assessmentNote->clear();
            return;
        }
    }

    loadRequirementsForBaustein(baustein.id);
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
        m_requirementTable->selectRow(0);
        onRequirementSelected(m_requirementModel->index(0, 0));
    } else {
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

bool MainWindow::saveCurrentAssessment()
{
    if (!hasActiveProjectContext())
        return false;

    const Requirement requirement = currentRequirement();
    if (requirement.id == 0)
        return false;

    RequirementAssessment assessment = m_context.projectRepository().loadAssessment(
        m_activeProject.id, m_activeTargetObject.id, requirement.id);
    assessment.projectId = m_activeProject.id;
    assessment.targetObjectId = m_activeTargetObject.id;
    assessment.requirementDbId = requirement.id;
    assessment.status = static_cast<AssessmentStatus>(m_statusBox->currentData().toInt());
    assessment.note = m_assessmentNote->toPlainText();
    assessment.responsible = m_responsibleEdit->text().trimmed();
    assessment.dueDate = m_hasDueDateBox->isChecked() ? m_dueDateEdit->date() : QDate();
    assessment.measureCount = m_measureModel->rowCount();

    if (!m_context.projectRepository().saveAssessment(assessment))
        return false;

    m_requirementModel->setAssessment(requirement.id, assessment);
    return true;
}

void MainWindow::onRequirementSelected(const QModelIndex &index)
{
    if (!index.isValid())
        return;

    const Requirement requirement = m_requirementModel->requirementAt(index.row());
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

    if (!saveCurrentAssessment()) {
        QMessageBox::warning(this, tr("Speichern"), m_context.projectRepository().lastError());
    }
}

void MainWindow::saveAssessmentFields()
{
    saveCurrentAssessment();
}

void MainWindow::addMeasure()
{
    if (!hasActiveProjectContext())
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
}

void MainWindow::editMeasure()
{
    const QModelIndex index = m_measureTable->currentIndex();
    if (!index.isValid() || !hasActiveProjectContext())
        return;

    Measure measure = m_measureModel->measureAt(index.row());
    MeasureDialog dialog(this);
    dialog.setMeasure(measure);
    if (dialog.exec() != QDialog::Accepted)
        return;

    measure = dialog.measure();
    if (!m_context.measureRepository().updateMeasure(measure)) {
        QMessageBox::critical(this, tr("Maßnahme"), m_context.measureRepository().lastError());
        return;
    }

    loadMeasuresForCurrentRequirement();
}

void MainWindow::deleteMeasure()
{
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
}

void MainWindow::addTargetObject()
{
    if (m_activeProject.id == 0) {
        QMessageBox::information(this, tr("Projekt"), tr("Bitte zuerst ein Projekt anlegen."));
        return;
    }

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

    const QModelIndex bausteinIndex = m_bausteinTree->currentIndex();
    if (bausteinIndex.isValid())
        onBausteinSelected(bausteinIndex);
}

void MainWindow::deleteTargetObject()
{
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

    if (!m_context.targetObjectRepository().deleteTargetObject(object.id)) {
        QMessageBox::critical(this, tr("Zielobjekt"), m_context.targetObjectRepository().lastError());
        return;
    }

    if (m_activeTargetObject.id == object.id)
        m_activeTargetObject = {};
    reloadTargetObjects();
}

void MainWindow::showTargetObjectContextMenu(const QPoint &pos)
{
    if (m_activeProject.id == 0)
        return;

    QMenu menu(this);
    menu.addAction(tr("Zielobjekt hinzufügen..."), this, &MainWindow::addTargetObject);
    menu.addAction(tr("Bearbeiten..."), this, &MainWindow::editTargetObject);
    menu.addAction(tr("Löschen"), this, &MainWindow::deleteTargetObject);
    menu.addSeparator();
    menu.addAction(tr("Baustein-Empfehlungen übernehmen..."), this,
                   &MainWindow::applyBausteinRecommendations);
    menu.exec(m_targetObjectTree->viewport()->mapToGlobal(pos));
}

void MainWindow::showBausteinContextMenu(const QPoint &pos)
{
    if (!hasActiveProjectContext())
        return;

    const QModelIndex index = m_bausteinTree->indexAt(pos);
    if (!index.isValid() || index.data(BausteinTreeModel::IsGroupRole).toBool())
        return;

    QMenu menu(this);
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
    menu.exec(m_bausteinTree->viewport()->mapToGlobal(pos));
}

void MainWindow::setBausteinApplicability(ApplicabilityStatus status)
{
    const QModelIndex index = m_bausteinTree->currentIndex();
    if (!index.isValid() || !hasActiveProjectContext())
        return;

    const Baustein baustein = m_bausteinModel->bausteinForIndex(index);
    if (baustein.id == 0)
        return;

    BausteinApplicability applicability;
    applicability.projectId = m_activeProject.id;
    applicability.targetObjectId = m_activeTargetObject.id;
    applicability.bausteinDbId = baustein.id;
    applicability.status = status;

    if (!m_context.targetObjectRepository().saveApplicability(applicability)) {
        QMessageBox::warning(this, tr("Anwendbarkeit"), m_context.targetObjectRepository().lastError());
        return;
    }

    reloadApplicabilityMarkers();

    if (status == ApplicabilityStatus::NotApplicable && m_bausteinTree->currentIndex() == index)
        onBausteinSelected(index);
}

void MainWindow::toggleApplicableFilter(bool enabled)
{
    m_bausteinModel->setHideNonApplicable(enabled);
    m_bausteinTree->expandAll();
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

    const QList<Baustein> allBausteine = m_context.catalogRepository().loadBausteine(
        StandardType::ITGrundschutz, m_context.catalogVersion());
    const QList<Baustein> recommended = BausteinRecommendationService::filterRecommended(
        allBausteine, m_activeTargetObject.type);
    if (recommended.isEmpty()) {
        QMessageBox::information(this,
                               tr("Baustein-Empfehlungen"),
                               tr("Für den Zielobjekt-Typ \"%1\" sind keine Baustein-Empfehlungen hinterlegt.")
                                   .arg(targetObjectTypeToString(m_activeTargetObject.type)));
        return;
    }

    const QHash<int, ApplicabilityStatus> applicabilityMap =
        m_context.targetObjectRepository().loadApplicabilityMap(m_activeProject.id,
                                                                m_activeTargetObject.id);

    BausteinRecommendationDialog dialog(recommended, applicabilityMap, m_activeTargetObject, this);
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

    reloadApplicabilityMarkers();

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

void MainWindow::updateWindowTitle()
{
    const int requirementCount = m_context.catalogRepository()
                                     .loadAllRequirements(StandardType::ITGrundschutz,
                                                          m_context.catalogVersion())
                                     .size();
    QString title = tr("ISMS Werkzeug – IT-Grundschutz %1").arg(m_context.catalogVersion());
    if (m_activeProject.id != 0)
        title += tr(" – Projekt: %1").arg(m_activeProject.name);
    title += tr(" (%1 Anforderungen im Katalog)").arg(requirementCount);
    setWindowTitle(title);
}
