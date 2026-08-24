#include "CockpitDialog.h"

#include "services/CockpitService.h"
#include "ui/models/CockpitTableModel.h"
#include "ui/TableViewHelper.h"

#include <QCheckBox>
#include <QComboBox>
#include <QDialogButtonBox>
#include <QHBoxLayout>
#include <QLabel>
#include <QLineEdit>
#include <QMessageBox>
#include <QPushButton>
#include <QTableView>
#include <QVBoxLayout>

CockpitDialog::CockpitDialog(AppContext &context, const Project &project, const QString &userName,
                             const QString &userEmail, QWidget *parent)
    : QDialog(parent)
    , m_context(context)
    , m_project(project)
{
    setWindowTitle(tr("Aufgaben-Cockpit"));
    resize(1100, 650);

    m_filter.hideDone = true;
    m_filter.currentUserName = userName;
    m_filter.currentUserEmail = userEmail;

    m_kindBox = new QComboBox(this);
    m_kindBox->addItem(tr("Alle"), static_cast<int>(CockpitKindFilter::All));
    m_kindBox->addItem(tr("Bewertungen"), static_cast<int>(CockpitKindFilter::Assessments));
    m_kindBox->addItem(tr("Maßnahmen"), static_cast<int>(CockpitKindFilter::Measures));

    m_dueBox = new QComboBox(this);
    m_dueBox->addItem(tr("Alle Fristen"), static_cast<int>(CockpitDueFilter::All));
    m_dueBox->addItem(tr("Überfällig"), static_cast<int>(CockpitDueFilter::Overdue));
    m_dueBox->addItem(tr("Diese Woche"), static_cast<int>(CockpitDueFilter::ThisWeek));
    m_dueBox->addItem(tr("Mit Frist"), static_cast<int>(CockpitDueFilter::HasDate));
    m_dueBox->addItem(tr("Ohne Frist"), static_cast<int>(CockpitDueFilter::NoDate));

    m_hideDoneBox = new QCheckBox(tr("Erledigte ausblenden"), this);
    m_hideDoneBox->setChecked(true);
    m_mineBox = new QCheckBox(tr("Nur meine"), this);
    m_mineBox->setEnabled(!userName.trimmed().isEmpty() || !userEmail.trimmed().isEmpty());
    m_personEdit = new QLineEdit(this);
    m_summaryLabel = new QLabel(this);
    m_summaryLabel->setWordWrap(true);

    m_model = new CockpitTableModel(this);
    m_table = new QTableView(this);
    m_table->setModel(m_model);
    m_table->setAlternatingRowColors(true);
    m_table->setSelectionBehavior(QAbstractItemView::SelectRows);
    m_table->setSelectionMode(QAbstractItemView::SingleSelection);
    enableResizableColumns(m_table);

    connect(m_kindBox, QOverload<int>::of(&QComboBox::currentIndexChanged), this,
            &CockpitDialog::applyFilter);
    connect(m_dueBox, QOverload<int>::of(&QComboBox::currentIndexChanged), this,
            &CockpitDialog::applyFilter);
    connect(m_hideDoneBox, &QCheckBox::toggled, this, &CockpitDialog::applyFilter);
    connect(m_mineBox, &QCheckBox::toggled, this, &CockpitDialog::applyFilter);
    connect(m_personEdit, &QLineEdit::textChanged, this, &CockpitDialog::applyFilter);
    connect(m_table, &QTableView::doubleClicked, this, &CockpitDialog::acceptSelection);

    auto *filterRow = new QHBoxLayout();
    filterRow->addWidget(new QLabel(tr("Art"), this));
    filterRow->addWidget(m_kindBox);
    filterRow->addWidget(new QLabel(tr("Frist"), this));
    filterRow->addWidget(m_dueBox);
    filterRow->addWidget(m_hideDoneBox);
    filterRow->addWidget(m_mineBox);
    filterRow->addWidget(new QLabel(tr("Verantwortlich"), this));
    filterRow->addWidget(m_personEdit, 1);

    auto *openButton = new QPushButton(tr("Im Projekt öffnen"), this);
    openButton->setDefault(true);
    connect(openButton, &QPushButton::clicked, this, &CockpitDialog::acceptSelection);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Close, this);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);

    auto *bottomRow = new QHBoxLayout();
    bottomRow->addWidget(openButton);
    bottomRow->addStretch();
    bottomRow->addWidget(buttons);

    auto *layout = new QVBoxLayout(this);
    layout->addLayout(filterRow);
    layout->addWidget(m_summaryLabel);
    layout->addWidget(m_table, 1);
    layout->addLayout(bottomRow);

    CockpitService service(m_context.catalogRepository(), m_context.projectRepository(),
                           m_context.targetObjectRepository(), m_context.measureRepository());
    m_allItems = service.buildItems(m_project.id, m_context.catalogVersion());
    applyFilter();
}

void CockpitDialog::applyFilter()
{
    m_filter.kind = static_cast<CockpitKindFilter>(m_kindBox->currentData().toInt());
    m_filter.due = static_cast<CockpitDueFilter>(m_dueBox->currentData().toInt());
    m_filter.hideDone = m_hideDoneBox->isChecked();
    m_filter.mineOnly = m_mineBox->isChecked();
    m_filter.responsibleNeedle = m_personEdit->text().trimmed();
    const QList<CockpitItem> visible = CockpitService::applyFilter(m_allItems, m_filter);
    m_model->setItems(visible);
    m_summaryLabel->setText(CockpitService::formatSummary(CockpitService::summarize(visible)));
    if (m_model->rowCount() > 0)
        m_table->selectRow(0);
}

void CockpitDialog::acceptSelection()
{
    const QModelIndex index = m_table->currentIndex();
    if (!index.isValid()) {
        QMessageBox::information(this, tr("Cockpit"),
                                 tr("Bitte einen Eintrag mit Anforderung wählen."));
        return;
    }
    const CockpitItem item = m_model->itemAt(index.row());
    if (item.requirementDbId <= 0) {
        QMessageBox::information(this, tr("Cockpit"),
                                 tr("Bitte einen Eintrag mit Anforderung wählen."));
        return;
    }
    m_selected = item;
    accept();
}
