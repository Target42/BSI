unit f_main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.Generics.Collections, System.Math, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.Menus, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Grids,
  IsmsDomain, AppContext, AppPaths, FireDAC.UI.Intf, FireDAC.VCLUI.Wait,
  FireDAC.Stan.Intf, FireDAC.Comp.UI;

type
  TMainForm = class(TForm)
    ToolBar: TToolBar;
    btnToolNewProject: TToolButton;
    btnToolOpenProject: TToolButton;
    btnToolAddTarget: TToolButton;
    btnToolImportCatalog: TToolButton;
    StatusBar: TStatusBar;
    pnlLeft: TPanel;
    grpTargets: TGroupBox;
    lblProjectProgress: TLabel;
    pbProjectProgress: TProgressBar;
    tvTargets: TTreeView;
    grpBausteine: TGroupBox;
    edtBausteinSearch: TEdit;
    chkFilterApplicable: TCheckBox;
    chkHighlightRecommendations: TCheckBox;
    tvBausteine: TTreeView;
    mnuBaustein: TPopupMenu;
    mnuTargets: TPopupMenu;
    mniTargetAdd: TMenuItem;
    mniTargetEdit: TMenuItem;
    mniTargetDelete: TMenuItem;
    mniTargetSep: TMenuItem;
    mniTargetRecommendations: TMenuItem;
    mniBausteinView: TMenuItem;
    mniBausteinSep1: TMenuItem;
    mniBausteinRequired: TMenuItem;
    mniBausteinPossible: TMenuItem;
    mniBausteinNotApplicable: TMenuItem;
    mniBausteinSep2: TMenuItem;
    mniBausteinReset: TMenuItem;
    splMain: TSplitter;
    pnlCenter: TPanel;
    grpRequirements: TGroupBox;
    lblTargetProgress: TLabel;
    pbTargetProgress: TProgressBar;
    lblBaustein: TLabel;
    cboAssignedBausteine: TComboBox;
    sgRequirements: TStringGrid;
    splCenter: TSplitter;
    pnlDetail: TPanel;
    lblRequirementText: TLabel;
    reRequirementText: TRichEdit;
    lblStatus: TLabel;
    cboAssessmentStatus: TComboBox;
    lblResponsible: TLabel;
    edtResponsible: TEdit;
    chkHasDueDate: TCheckBox;
    dtpDueDate: TDateTimePicker;
    lblAssessmentNote: TLabel;
    memAssessmentNote: TMemo;
    grpMeasures: TGroupBox;
    sgMeasures: TStringGrid;
    btnAddMeasure: TButton;
    btnEditMeasure: TButton;
    btnDeleteMeasure: TButton;
    MainMenu: TMainMenu;
    mnuFile: TMenuItem;
    mnuImportCatalog: TMenuItem;
    mnuNewProject: TMenuItem;
    mnuOpenProject: TMenuItem;
    mnuCloseProject: TMenuItem;
    mnuSepSession: TMenuItem;
    mnuRelogin: TMenuItem;
    mnuSwitchUser: TMenuItem;
    mnuSep1: TMenuItem;
    mnuExit: TMenuItem;
    mnuProject: TMenuItem;
    mnuEditProject: TMenuItem;
    mnuManageMembers: TMenuItem;
    mnuDeleteProject: TMenuItem;
    mnuSep2: TMenuItem;
    mnuAddTarget: TMenuItem;
    mnuEditTarget: TMenuItem;
    mnuDeleteTarget: TMenuItem;
    mnuSep3: TMenuItem;
    mnuApplyRecommendations: TMenuItem;
    mnuReports: TMenuItem;
    mnuSollIst: TMenuItem;
    mnuCatalog: TMenuItem;
    mnuViewBaustein: TMenuItem;
    mnuCatalogSearch: TMenuItem;
    FDGUIxWaitCursor1: TFDGUIxWaitCursor;
    procedure FormCreate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure DoImportCatalog(Sender: TObject);
    procedure DoCreateProject(Sender: TObject);
    procedure DoOpenProject(Sender: TObject);
    procedure DoCloseProject(Sender: TObject);
    procedure DoEditProject(Sender: TObject);
    procedure DoManageMembers(Sender: TObject);
    procedure DoDeleteProject(Sender: TObject);
    procedure DoAddTarget(Sender: TObject);
    procedure DoEditTarget(Sender: TObject);
    procedure DoDeleteTarget(Sender: TObject);
    procedure DoShowSollIstReport(Sender: TObject);
    procedure tvTargetsClick(Sender: TObject);
    procedure tvTargetsChange(Sender: TObject; Node: TTreeNode);
    procedure tvBausteineChange(Sender: TObject; Node: TTreeNode);
    procedure tvBausteineClick(Sender: TObject);
    procedure tvBausteineDblClick(Sender: TObject);
    procedure tvBausteineCustomDrawItem(Sender: TCustomTreeView; Node: TTreeNode; State: TCustomDrawState;
      var DefaultDraw: Boolean);
    procedure tvBausteineContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
    procedure sgRequirementsSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
    procedure sgRequirementsDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
    procedure cboAssessmentStatusChange(Sender: TObject);
    procedure edtResponsibleExit(Sender: TObject);
    procedure memAssessmentNoteExit(Sender: TObject);
    procedure memAssessmentNoteChange(Sender: TObject);
    procedure chkHasDueDateClick(Sender: TObject);
    procedure dtpDueDateChange(Sender: TObject);
    procedure edtBausteinSearchChange(Sender: TObject);
    procedure chkFilterApplicableClick(Sender: TObject);
    procedure DoAddMeasure(Sender: TObject);
    procedure DoEditMeasure(Sender: TObject);
    procedure DoDeleteMeasure(Sender: TObject);
    procedure sgMeasuresDblClick(Sender: TObject);
    procedure endProgramm(Sender: TObject);
    procedure DoViewBaustein(Sender: TObject);
    procedure DoCatalogSearch(Sender: TObject);
    procedure DoApplyRecommendations(Sender: TObject);
    procedure DoRelogin(Sender: TObject);
    procedure DoSwitchUser(Sender: TObject);
    procedure CheckRemoteSession(Sender: TObject);
    procedure tvTargetsContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
    procedure cboAssignedBausteineChange(Sender: TObject);
    procedure chkHighlightRecommendationsClick(Sender: TObject);
    procedure BausteinViewMenuClick(Sender: TObject);
    procedure ApplicabilityRequiredClick(Sender: TObject);
    procedure ApplicabilityPossibleClick(Sender: TObject);
    procedure ApplicabilityNotApplicableClick(Sender: TObject);
    procedure ApplicabilityResetClick(Sender: TObject);
  private
    FContext: TAppContext;
    FActiveProject: TProject;
    FActiveTarget: TTargetObject;
    FActiveBausteinId: Integer;
    FActiveRequirementId: Integer;
    FCatalogBausteine: TArray<TBaustein>;
    FCatalogRequirements: TArray<TRequirement>;
    FCurrentRequirements: TArray<TRequirement>;
    FCurrentMeasures: TArray<TMeasure>;
    FApplicabilityMap: TDictionary<Integer, TApplicabilityStatus>;
    FMeasureCounts: TDictionary<Integer, Integer>;
    FSummariesByTarget: TDictionary<Integer, TReportSummary>;
    FRecommendedIds: TDictionary<Integer, Byte>;
    FRecommendationTiers: TDictionary<Integer, TBausteinRecommendationTier>;
    FLastBausteinByTarget: TDictionary<Integer, Integer>;
    FLastRequirementByTarget: TDictionary<Integer, Integer>;
    FSuppressAssessmentSave: Boolean;
    FSuppressAssignedBausteinChange: Boolean;
    FCurrentAssessmentVersion: Integer;
    FSessionTimer: TTimer;
    FStatusTimer: TTimer;
    FStatusPreviousMessage: string;
    FLastConflictNotifiedRequirementId: Integer;
    FContextMenuBausteinId: Integer;
    FBlockTargetSelection: Boolean;

    procedure SetAppContext(const AContext: TAppContext);
    procedure ActivateWithContext;
    procedure InitializeUi;
    procedure UpdateProjectUi;
    procedure UpdateContextLabel;
    procedure UpdateSessionInfoLabel;
    procedure ShowTemporaryStatusMessage(const AMessage: string; ATimeoutMs: Integer = 5000);
    procedure StatusTimerElapsed(Sender: TObject);
    function CanEditActiveProject: Boolean;
    function CanDeleteActiveProject: Boolean;
    function CanManageProjectMembers: Boolean;
    procedure ReloadCatalog;
    procedure ReloadTargetObjects(APreferredTargetId: Integer = 0);
    procedure ReloadBausteinTree;
    procedure ReloadRecommendationMarkers;
    procedure ReloadApplicabilityFromServer;
    procedure PopulateAssignedBausteinBox;
    procedure ReloadProgress;
    procedure UpdateTargetProgress;
    procedure PersistSessionSelection;
    function FindBausteinById(ABausteinId: Integer): TBaustein;
    function BuildTargetTreeCaption(const Obj: TTargetObject): string;
    function TargetHasAssignedBausteine(ATargetId: Integer): Boolean;
    function FindAlternateTargetWithAssignments(const Objects: TArray<TTargetObject>;
      const ACurrent: TTargetObject): Integer;
    function FindAnyTargetWithAssignments(const Objects: TArray<TTargetObject>;
      AExcludeId: Integer): Integer;
    function FindDescendantTargetWithAssignments(const Objects: TArray<TTargetObject>;
      AParentId: Integer): Integer;
    function BuildBausteinCaption(const B: TBaustein): string;
    function MatchingBausteinIdsForSearch(const ANeedle: string): TDictionary<Integer, Byte>;
    procedure EnsureApplicableFilterFeasible;
    procedure ShowBausteinNotApplicableMessage(ABausteinDbId: Integer; AStatus: TApplicabilityStatus);
    procedure OpenBausteinView(const B: TBaustein; const AInitialSearch: string);
    procedure SelectBausteinInTree(ABausteinId: Integer);
    procedure SelectTargetInTree(ATargetId: Integer);
    procedure ApplyTargetSelection(ATargetId: Integer; AAutoSwitchIfEmpty: Boolean = False);
    procedure ApplyBausteinSelection(ABausteinId: Integer);
    procedure SelectRequirementRow(ARequirementId: Integer);
    procedure LoadRequirementsForBaustein(ABausteinDbId: Integer);
    procedure LoadRequirementDetails(ARow: Integer);
    procedure LoadMeasuresForCurrentRequirement;
    procedure ClearRequirementView;
    function SaveCurrentAssessment(ANotifyDialog: Boolean = False): Boolean;
    procedure SaveAssessmentFields;
    procedure SyncAssessmentUi(const AAssessment: TRequirementAssessment);
    procedure ApplyAssessmentConflict(const AAssessment: TRequirementAssessment;
      ARequirementDbId: Integer; AShowDialog: Boolean);
    function HasActiveProject: Boolean;
    function SelectedBausteinId: Integer;
    function IsBausteinApplicable(ABausteinDbId: Integer): Boolean;
    function IsAssessmentDueDateOverdue(const AAssessment: TRequirementAssessment): Boolean;
    procedure SetBausteinApplicability(AStatus: TApplicabilityStatus; ABausteinId: Integer = 0);
  public
    property AppContext: TAppContext read FContext write SetAppContext;
  end;

var
  MainForm: TMainForm;

implementation

uses
  f_project, f_projectopen, f_targetobject, f_measure, f_report, ReportService,
  RequirementTextFormatter, BausteinRecommendationService, AppSession,
  f_bausteinview, f_catalogsearch, f_bausteinrecommendation, f_projectmembers;

{$R *.dfm}

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FillChar(FActiveProject, SizeOf(FActiveProject), 0);
  FillChar(FActiveTarget, SizeOf(FActiveTarget), 0);
  FActiveBausteinId := 0;
  FActiveRequirementId := 0;
  FApplicabilityMap := TDictionary<Integer, TApplicabilityStatus>.Create;
  FMeasureCounts := TDictionary<Integer, Integer>.Create;
  FSummariesByTarget := TDictionary<Integer, TReportSummary>.Create;
  FRecommendedIds := TDictionary<Integer, Byte>.Create;
  FRecommendationTiers := TDictionary<Integer, TBausteinRecommendationTier>.Create;
  FLastBausteinByTarget := TDictionary<Integer, Integer>.Create;
  FLastRequirementByTarget := TDictionary<Integer, Integer>.Create;
  FLastConflictNotifiedRequirementId := 0;
  FStatusTimer := TTimer.Create(Self);
  FStatusTimer.Enabled := False;
  FStatusTimer.Interval := 5000;
  FStatusTimer.OnTimer := StatusTimerElapsed;
  InitializeUi;
  UpdateContextLabel;
  StatusBar.Panels[2].Text := 'Lokaler Modus';
end;

procedure TMainForm.SetAppContext(const AContext: TAppContext);
begin
  FContext := AContext;
  if (FContext <> nil) and not (csDestroying in ComponentState) then
    ActivateWithContext;
end;

procedure TMainForm.ActivateWithContext;
begin
  if FContext.IsRemote then
  begin
    FContext.SetReloginHandler(
      function: Boolean
      begin
        Result := FContext.PromptRelogin;
        if Result then
          ActivateWithContext;
      end);
    if FSessionTimer = nil then
    begin
      FSessionTimer := TTimer.Create(Self);
      FSessionTimer.Interval := 60000;
      FSessionTimer.OnTimer := CheckRemoteSession;
    end;
    FSessionTimer.Enabled := True;
  end
  else if FSessionTimer <> nil then
    FSessionTimer.Enabled := False;
  UpdateSessionInfoLabel;
  ReloadCatalog;
  UpdateProjectUi;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  SaveCurrentAssessment;
  PersistSessionSelection;
  FApplicabilityMap.Free;
  FMeasureCounts.Free;
  FSummariesByTarget.Free;
  FRecommendedIds.Free;
  FRecommendationTiers.Free;
  FLastBausteinByTarget.Free;
  FLastRequirementByTarget.Free;
  CanClose := True;
end;

procedure TMainForm.InitializeUi;
begin
  pbProjectProgress.Min := 0;
  pbProjectProgress.Max := 100;
  pbTargetProgress.Min := 0;
  pbTargetProgress.Max := 100;

  sgRequirements.FixedRows := 1;
  sgRequirements.ColCount := 8;
  sgRequirements.DefaultDrawing := False;
  sgRequirements.Cells[0, 0] := 'ID';
  sgRequirements.Cells[1, 0] := 'Anforderung';
  sgRequirements.Cells[2, 0] := 'Stufe';
  sgRequirements.Cells[3, 0] := 'Rolle';
  sgRequirements.Cells[4, 0] := 'Status';
  sgRequirements.Cells[5, 0] := 'Umsetzung durch';
  sgRequirements.Cells[6, 0] := 'Frist';
  sgRequirements.Cells[7, 0] := 'Maßnahmen';
  sgRequirements.ColWidths[0] := 90;
  sgRequirements.ColWidths[1] := 240;
  sgRequirements.ColWidths[2] := 60;
  sgRequirements.ColWidths[3] := 90;
  sgRequirements.ColWidths[4] := 80;
  sgRequirements.ColWidths[5] := 120;
  sgRequirements.ColWidths[6] := 80;
  sgRequirements.ColWidths[7] := 70;

  sgMeasures.FixedRows := 1;
  sgMeasures.Cells[0, 0] := 'Titel';
  sgMeasures.Cells[1, 0] := 'Verantwortlicher';
  sgMeasures.Cells[2, 0] := 'Frist';
  sgMeasures.Cells[3, 0] := 'Status';
  sgMeasures.ColWidths[0] := 250;
  sgMeasures.ColWidths[1] := 150;
  sgMeasures.ColWidths[2] := 90;
  sgMeasures.ColWidths[3] := 100;

  cboAssessmentStatus.Items.Add(AssessmentStatusToString(asOpen));
  cboAssessmentStatus.Items.Add(AssessmentStatusToString(asPartial));
  cboAssessmentStatus.Items.Add(AssessmentStatusToString(asFulfilled));
  cboAssessmentStatus.Items.Add(AssessmentStatusToString(asNotApplicable));
end;

function TMainForm.HasActiveProject: Boolean;
begin
  Result := FActiveProject.Id > 0;
end;

function TMainForm.CanEditActiveProject: Boolean;
begin
  if not FContext.IsRemote or (FActiveProject.Id = 0) then
    Exit(True);
  Result := (FActiveProject.Role = 'owner') or (FActiveProject.Role = 'editor');
end;

function TMainForm.CanDeleteActiveProject: Boolean;
begin
  if FActiveProject.Id = 0 then
    Exit(False);
  if not FContext.IsRemote then
    Exit(True);
  Result := FActiveProject.Role = 'owner';
end;

function TMainForm.CanManageProjectMembers: Boolean;
begin
  Result := FContext.IsRemote and (FActiveProject.Id > 0) and (FActiveProject.Role = 'owner');
end;

procedure TMainForm.UpdateSessionInfoLabel;
var
  Server: string;
begin
  if not FContext.IsRemote then
    StatusBar.Panels[2].Text := 'Lokaler Modus'
  else
  begin
    Server := FContext.Settings.ServerUrl;
    if Trim(FContext.RemoteUser.Email) <> '' then
      StatusBar.Panels[2].Text := Trim(FContext.RemoteUser.Email) + ' · ' + Server
    else
      StatusBar.Panels[2].Text := 'Server: ' + Server;
  end;
end;

procedure TMainForm.UpdateContextLabel;
var
  ContextText: string;
begin
  if not HasActiveProject then
    ContextText := 'Kein Projekt geöffnet'
  else if FActiveTarget.Id = 0 then
  begin
    ContextText := Format('Projekt "%s" – bitte Zielobjekt wählen', [FActiveProject.Name]);
    if FContext.IsRemote and SameText(FActiveProject.Role, 'viewer') then
      ContextText := ContextText + ' (Nur Lesen)';
  end
  else
  begin
    ContextText := Format('Projekt "%s" – Zielobjekt: %s – %s  (%s)',
      [FActiveProject.Name,
       TargetObjectTypeToString(FActiveTarget.ObjType),
       FActiveTarget.Name,
       ProtectionNeedToString(FActiveTarget.ProtectionNeed)]);
    if FContext.IsRemote and SameText(FActiveProject.Role, 'viewer') then
      ContextText := ContextText + ' — Nur Lesen';
  end;
  StatusBar.Panels[0].Text := ContextText;
end;

procedure TMainForm.ShowTemporaryStatusMessage(const AMessage: string; ATimeoutMs: Integer);
begin
  if AMessage = '' then
    Exit;
  FStatusPreviousMessage := StatusBar.Panels[1].Text;
  StatusBar.Panels[1].Text := AMessage;
  FStatusTimer.Interval := ATimeoutMs;
  FStatusTimer.Enabled := False;
  FStatusTimer.Enabled := True;
end;

procedure TMainForm.StatusTimerElapsed(Sender: TObject);
begin
  FStatusTimer.Enabled := False;
  StatusBar.Panels[1].Text := FStatusPreviousMessage;
end;

procedure TMainForm.CheckRemoteSession(Sender: TObject);
var
  Err: string;
begin
  if not FContext.IsRemote or (FContext.ApiClient = nil) then
    Exit;
  if FContext.ApiClient.IsTokenExpired or not FContext.ApiClient.ValidateSession(Err) then
  begin
    if not FContext.PromptRelogin then
      Application.Terminate
    else
      ActivateWithContext;
  end;
end;

procedure TMainForm.DoRelogin(Sender: TObject);
begin
  if FContext.PromptRelogin then
    ActivateWithContext;
end;

procedure TMainForm.DoSwitchUser(Sender: TObject);
begin
  SaveCurrentAssessment;
  PersistSessionSelection;
  if FContext.PromptSwitchUser then
  begin
    FillChar(FActiveProject, SizeOf(FActiveProject), 0);
    FillChar(FActiveTarget, SizeOf(FActiveTarget), 0);
    FActiveBausteinId := 0;
    FActiveRequirementId := 0;
    tvTargets.Items.Clear;
    ClearRequirementView;
    ActivateWithContext;
  end;
end;

procedure TMainForm.UpdateProjectUi;
var
  HasProject: Boolean;
  CanEdit, CanDelete: Boolean;
begin
  HasProject := HasActiveProject;
  CanEdit := CanEditActiveProject;
  CanDelete := CanDeleteActiveProject;
  mnuCloseProject.Enabled := HasProject;
  mnuEditProject.Enabled := HasProject and CanEdit;
  mnuManageMembers.Enabled := CanManageProjectMembers;
  mnuDeleteProject.Enabled := HasProject and CanDelete;
  mnuAddTarget.Enabled := HasProject and CanEdit;
  mnuEditTarget.Enabled := HasProject and CanEdit and (FActiveTarget.Id > 0);
  mnuDeleteTarget.Enabled := HasProject and CanEdit and (FActiveTarget.Id > 0);
  mnuSollIst.Enabled := HasProject;
  mnuApplyRecommendations.Enabled := HasProject and CanEdit and (FActiveTarget.Id > 0);
  mnuRelogin.Enabled := FContext.IsRemote;
  mnuSwitchUser.Enabled := True;
  mnuViewBaustein.Enabled := True;
  mnuCatalogSearch.Enabled := True;
  chkHighlightRecommendations.Enabled := HasProject and (FActiveTarget.Id > 0);
  cboAssignedBausteine.Enabled := HasProject and CanEdit and (FActiveTarget.Id > 0) and
    (cboAssignedBausteine.ItemIndex >= 0) and
    (Integer(cboAssignedBausteine.Items.Objects[cboAssignedBausteine.ItemIndex]) > 0);
  btnAddMeasure.Enabled := HasProject and CanEdit and (FActiveRequirementId > 0);
  btnEditMeasure.Enabled := HasProject and (FActiveRequirementId > 0);
  btnDeleteMeasure.Enabled := HasProject and CanEdit and (FActiveRequirementId > 0);
  if CanEdit then
    btnEditMeasure.Caption := 'Bearbeiten'
  else
    btnEditMeasure.Caption := 'Anzeigen';
  btnToolNewProject.Enabled := True;
  btnToolOpenProject.Enabled := True;
  btnToolAddTarget.Enabled := HasProject and CanEdit;
  btnToolImportCatalog.Enabled := True;
  cboAssessmentStatus.Enabled := HasProject and (FActiveTarget.Id > 0) and CanEdit;
  edtResponsible.Enabled := HasProject and (FActiveTarget.Id > 0) and CanEdit;
  chkHasDueDate.Enabled := HasProject and (FActiveTarget.Id > 0) and CanEdit;
  dtpDueDate.Enabled := HasProject and (FActiveTarget.Id > 0) and CanEdit and chkHasDueDate.Checked;
  memAssessmentNote.ReadOnly := HasProject and (FActiveTarget.Id > 0) and not CanEdit;
  if HasActiveProject then
  begin
    if FContext.IsRemote then
      Caption := Format('ISMS Werkzeug – IT-Grundschutz %s – Projekt: %s (#%d, %d Anforderungen im Katalog)',
        [FContext.CatalogVersion, FActiveProject.Name, FActiveProject.Id, Length(FCatalogRequirements)])
    else
      Caption := Format('ISMS Werkzeug – IT-Grundschutz %s – Projekt: %s (%d Anforderungen im Katalog)',
        [FContext.CatalogVersion, FActiveProject.Name, Length(FCatalogRequirements)]);
  end
  else
  begin
    Caption := Format('ISMS Werkzeug – IT-Grundschutz %s (%d Anforderungen im Katalog)',
      [FContext.CatalogVersion, Length(FCatalogRequirements)]);
    lblProjectProgress.Caption := 'Kein Projekt geöffnet';
    pbProjectProgress.Visible := False;
  end;
  UpdateTargetProgress;
  UpdateContextLabel;
end;

procedure TMainForm.ReloadProgress;
var
  Service: TReportService;
  Rows: TArray<TReportRow>;
  ProjectSummary: TReportSummary;
  NewSummaries: TDictionary<Integer, TReportSummary>;
begin
  if not HasActiveProject then
  begin
    pbProjectProgress.Visible := False;
    lblProjectProgress.Caption := 'Kein Projekt geöffnet';
    FSummariesByTarget.Clear;
    UpdateTargetProgress;
    Exit;
  end;
  Service := TReportService.Create(
    FContext.CatalogRepository,
    FContext.ProjectRepository,
    FContext.TargetObjectRepository,
    FContext.MeasureRepository);
  try
    Rows := Service.BuildSollIstReport(FActiveProject.Id, 0, FContext.CatalogVersion);
    ProjectSummary := Service.Summarize(Rows);
    NewSummaries := Service.SummarizeByTargetObject(Rows);
    FSummariesByTarget.Free;
    FSummariesByTarget := NewSummaries;
    lblProjectProgress.Caption := 'Projekt: ' + TReportService.FormatSummaryText(ProjectSummary);
    pbProjectProgress.Position := TReportService.ProgressPercent(ProjectSummary);
    pbProjectProgress.Visible := ProjectSummary.TotalRequirements > 0;
    UpdateTargetProgress;
  finally
    Service.Free;
  end;
end;

procedure TMainForm.UpdateTargetProgress;
var
  Summary: TReportSummary;
begin
  if not HasActiveProject then
  begin
    lblTargetProgress.Caption := '';
    pbTargetProgress.Visible := False;
    Exit;
  end;
  if FActiveTarget.Id = 0 then
  begin
    lblTargetProgress.Caption := 'Bitte Zielobjekt wählen';
    pbTargetProgress.Position := 0;
    pbTargetProgress.Visible := False;
    Exit;
  end;
  if FSummariesByTarget.TryGetValue(FActiveTarget.Id, Summary) then
  begin
    lblTargetProgress.Caption := Format('Zielobjekt "%s – %s": %s',
      [TargetObjectTypeToString(FActiveTarget.ObjType),
       FActiveTarget.Name,
       TReportService.FormatSummaryText(Summary)]);
    pbTargetProgress.Position := TReportService.ProgressPercent(Summary);
    pbTargetProgress.Visible := Summary.TotalRequirements > 0;
  end
  else
  begin
    lblTargetProgress.Caption := Format('Zielobjekt "%s – %s": Keine anwendbaren Anforderungen',
      [TargetObjectTypeToString(FActiveTarget.ObjType), FActiveTarget.Name]);
    pbTargetProgress.Position := 0;
    pbTargetProgress.Visible := False;
  end;
end;

function TMainForm.IsAssessmentDueDateOverdue(const AAssessment: TRequirementAssessment): Boolean;
begin
  Result := IsValidDate(AAssessment.DueDate) and
    (Trunc(AAssessment.DueDate) < Trunc(Date)) and
    (AAssessment.Status <> asFulfilled) and
    (AAssessment.Status <> asNotApplicable);
end;

procedure TMainForm.sgRequirementsDrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var
  Text: string;
  DrawRect: TRect;
begin
  Text := sgRequirements.Cells[ACol, ARow];
  if ARow = 0 then
  begin
    sgRequirements.Canvas.Brush.Color := clBtnFace;
    sgRequirements.Canvas.FillRect(Rect);
    sgRequirements.Canvas.Font.Color := clWindowText;
    sgRequirements.Canvas.Font.Style := [fsBold];
  end
  else
  begin
    sgRequirements.Canvas.Brush.Color := clWindow;
    if gdSelected in State then
    begin
      sgRequirements.Canvas.Brush.Color := clHighlight;
      sgRequirements.Canvas.Font.Color := clHighlightText;
    end
    else if (ACol = 6) and (sgRequirements.Objects[2, ARow] <> nil) then
      sgRequirements.Canvas.Font.Color := clRed
    else
      sgRequirements.Canvas.Font.Color := clWindowText;
    sgRequirements.Canvas.FillRect(Rect);
  end;
  DrawRect := Rect;
  Inc(DrawRect.Left, 2);
  sgRequirements.Canvas.TextRect(DrawRect, DrawRect.Left, DrawRect.Top + 2, Text);
  if ARow = 0 then
    sgRequirements.Canvas.Font.Style := [];
end;

procedure TMainForm.ReloadCatalog;
begin
  FCatalogBausteine := FContext.CatalogRepository.LoadBausteine(stITGrundschutz, FContext.CatalogVersion);
  FCatalogRequirements := FContext.CatalogRepository.LoadAllRequirements(stITGrundschutz, FContext.CatalogVersion);
  ReloadRecommendationMarkers;
  ReloadBausteinTree;
  UpdateProjectUi;
end;

procedure TMainForm.ReloadRecommendationMarkers;
var
  Recs: TArray<TBausteinRecommendation>;
  Rec: TBausteinRecommendation;
begin
  FRecommendedIds.Clear;
  FRecommendationTiers.Clear;
  if not HasActiveProject or (FActiveTarget.Id = 0) then
    Exit;
  Recs := TBausteinRecommendationService.BuildRecommendations(FCatalogBausteine, FActiveTarget);
  for Rec in Recs do
  begin
    FRecommendedIds.AddOrSetValue(Rec.BausteinDbId, 1);
    FRecommendationTiers.AddOrSetValue(Rec.BausteinDbId, Rec.Tier);
  end;
end;

function TMainForm.FindBausteinById(ABausteinId: Integer): TBaustein;
var
  B: TBaustein;
begin
  FillChar(Result, SizeOf(Result), 0);
  for B in FCatalogBausteine do
    if B.Id = ABausteinId then
      Exit(B);
end;

function TMainForm.BuildTargetTreeCaption(const Obj: TTargetObject): string;
var
  Summary: TReportSummary;
begin
  Result := Format('%s – %s [%s]',
    [TargetObjectTypeToString(Obj.ObjType), Obj.Name, ProtectionNeedToString(Obj.ProtectionNeed)]);
  if FSummariesByTarget.TryGetValue(Obj.Id, Summary) then
    Result := Result + TReportService.FormatTreeProgressSuffix(Summary);
end;

function TMainForm.TargetHasAssignedBausteine(ATargetId: Integer): Boolean;
var
  Map: TDictionary<Integer, TApplicabilityStatus>;
  Pair: TPair<Integer, TApplicabilityStatus>;
begin
  Result := False;
  if not HasActiveProject or (ATargetId <= 0) then
    Exit;
  Map := FContext.TargetObjectRepository.LoadApplicabilityMap(FActiveProject.Id, ATargetId);
  try
    for Pair in Map do
      if (Pair.Value = apRequired) or (Pair.Value = apPossible) then
        Exit(True);
  finally
    Map.Free;
  end;
end;

function TMainForm.FindAnyTargetWithAssignments(const Objects: TArray<TTargetObject>;
  AExcludeId: Integer): Integer;
var
  O: TTargetObject;
  Fallback: Integer;
begin
  Fallback := 0;
  for O in Objects do
  begin
    if (AExcludeId > 0) and (O.Id = AExcludeId) then
      Continue;
    if not TargetHasAssignedBausteine(O.Id) then
      Continue;
    if O.ObjType = totProcess then
      Exit(O.Id);
    if Fallback = 0 then
      Fallback := O.Id;
  end;
  Exit(Fallback);
end;

function TMainForm.FindDescendantTargetWithAssignments(const Objects: TArray<TTargetObject>;
  AParentId: Integer): Integer;
var
  O: TTargetObject;
begin
  Result := 0;
  for O in Objects do
  begin
    if O.ParentId <> AParentId then
      Continue;
    if TargetHasAssignedBausteine(O.Id) then
      Exit(O.Id);
    Result := FindDescendantTargetWithAssignments(Objects, O.Id);
    if Result > 0 then
      Exit;
  end;
end;

function TMainForm.FindAlternateTargetWithAssignments(const Objects: TArray<TTargetObject>;
  const ACurrent: TTargetObject): Integer;
var
  O: TTargetObject;
begin
  Result := 0;
  if ACurrent.Id <= 0 then
    Exit;
  for O in Objects do
  begin
    if (O.Id = ACurrent.Id) or not SameText(O.Name, ACurrent.Name) then
      Continue;
    if TargetHasAssignedBausteine(O.Id) then
      Exit(O.Id);
  end;
  Result := FindDescendantTargetWithAssignments(Objects, ACurrent.Id);
  if Result = 0 then
    Result := FindAnyTargetWithAssignments(Objects, ACurrent.Id);
end;

function TMainForm.BuildBausteinCaption(const B: TBaustein): string;
var
  Status: TApplicabilityStatus;
  Tier: TBausteinRecommendationTier;
begin
  Result := B.ExternalId + ' ' + B.Title;
  if HasActiveProject and (FActiveTarget.Id > 0) then
  begin
    if not FApplicabilityMap.TryGetValue(B.Id, Status) then
      Status := apUndefined;
    if Status = apRequired then
      Result := '✓ ' + Result
    else if Status = apPossible then
      Result := '◐ ' + Result;
  end;
  if chkHighlightRecommendations.Checked and HasActiveProject and (FActiveTarget.Id > 0) then
  begin
    if not FApplicabilityMap.TryGetValue(B.Id, Status) then
      Status := apUndefined;
    if FRecommendedIds.ContainsKey(B.Id) and (Status = apUndefined) then
    begin
      if FRecommendationTiers.TryGetValue(B.Id, Tier) and (Tier = brtCore) then
        Result := '★ ' + Result
      else
        Result := '○ ' + Result;
    end;
  end;
end;

procedure TMainForm.ReloadTargetObjects(APreferredTargetId: Integer);
var
  Objects: TArray<TTargetObject>;
  O: TTargetObject;
  NodeMap: TDictionary<Integer, TTreeNode>;
  Changed: Boolean;
  Pass: Integer;
  TargetId: Integer;
  Found: Boolean;
  AlternateId: Integer;

  function AddOrphanObject(const Obj: TTargetObject): TTreeNode;
  var
    RootNode: TTreeNode;
    Caption: string;
  begin
    Caption := BuildTargetTreeCaption(Obj);
    RootNode := tvTargets.Items.GetFirstNode;
    if RootNode <> nil then
      Result := tvTargets.Items.AddChild(RootNode, Caption)
    else
      Result := tvTargets.Items.AddChild(nil, Caption);
    Result.Data := Pointer(Obj.Id);
    NodeMap.Add(Obj.Id, Result);
  end;

  function AddObject(const Obj: TTargetObject): TTreeNode;
  var
    ParentNode: TTreeNode;
    Caption: string;
  begin
    Caption := BuildTargetTreeCaption(Obj);
    if Obj.ParentId > 0 then
    begin
      if not NodeMap.TryGetValue(Obj.ParentId, ParentNode) then
        ParentNode := nil;
      Result := tvTargets.Items.AddChild(ParentNode, Caption);
    end
    else
      Result := tvTargets.Items.AddChild(nil, Caption);
    Result.Data := Pointer(Obj.Id);
    NodeMap.Add(Obj.Id, Result);
  end;

begin
  tvTargets.Items.BeginUpdate;
  try
    tvTargets.Items.Clear;
    if not HasActiveProject then
      Exit;
    ReloadProgress;
    NodeMap := TDictionary<Integer, TTreeNode>.Create;
    try
      Objects := FContext.TargetObjectRepository.LoadTargetObjects(FActiveProject.Id);
      Changed := True;
      Pass := 0;
      while Changed and (Pass < Length(Objects) + 1) do
      begin
        Changed := False;
        Inc(Pass);
        for O in Objects do
        begin
          if NodeMap.ContainsKey(O.Id) then
            Continue;
          if (O.ParentId = 0) or NodeMap.ContainsKey(O.ParentId) then
          begin
            AddObject(O);
            Changed := True;
          end;
        end;
      end;
      for O in Objects do
        if not NodeMap.ContainsKey(O.Id) then
          AddOrphanObject(O);
      if tvTargets.Items.Count > 0 then
      begin
        TargetId := APreferredTargetId;
        if TargetId > 0 then
        begin
          Found := False;
          for O in Objects do
            if O.Id = TargetId then
            begin
              Found := True;
              Break;
            end;
          if not Found then
            TargetId := 0;
        end;
        if (TargetId <= 0) or not TargetHasAssignedBausteine(TargetId) then
        begin
          AlternateId := FindAnyTargetWithAssignments(Objects, 0);
          if AlternateId > 0 then
            TargetId := AlternateId;
        end;
        if TargetId <= 0 then
          for O in Objects do
            if O.ParentId = 0 then
            begin
              TargetId := O.Id;
              Break;
            end;
        if TargetId <= 0 then
          TargetId := Integer(tvTargets.Items[0].Data);
        tvTargets.FullExpand;
        ApplyTargetSelection(TargetId, True);
      end;
    finally
      NodeMap.Free;
    end;
  finally
    tvTargets.Items.EndUpdate;
  end;
end;

function TMainForm.IsBausteinApplicable(ABausteinDbId: Integer): Boolean;
var
  Status: TApplicabilityStatus;
begin
  if not FApplicabilityMap.TryGetValue(ABausteinDbId, Status) then
    Exit(False);
  Result := (Status = apRequired) or (Status = apPossible);
end;

procedure TMainForm.ReloadBausteinTree;
var
  B: TBaustein;
  GroupNode, BausteinNode: TTreeNode;
  GroupMap: TDictionary<string, TTreeNode>;
  SearchText: string;
  Caption: string;
  MatchingIds: TDictionary<Integer, Byte>;
  HasSearch: Boolean;
begin
  tvBausteine.Items.BeginUpdate;
  try
    tvBausteine.Items.Clear;
    GroupMap := TDictionary<string, TTreeNode>.Create;
    try
      SearchText := Trim(edtBausteinSearch.Text);
      HasSearch := SearchText <> '';
      if HasSearch then
        MatchingIds := MatchingBausteinIdsForSearch(SearchText)
      else
        MatchingIds := nil;
      try
        for B in FCatalogBausteine do
        begin
          if chkFilterApplicable.Checked and HasActiveProject and (FActiveTarget.Id > 0) then
            if not IsBausteinApplicable(B.Id) then
              Continue;
          if HasSearch then
          begin
            if (MatchingIds = nil) or not MatchingIds.ContainsKey(B.Id) then
              Continue;
          end;
          if not GroupMap.TryGetValue(B.GroupName, GroupNode) then
          begin
            GroupNode := tvBausteine.Items.AddChild(nil, B.GroupName);
            GroupNode.Data := nil;
            GroupMap.Add(B.GroupName, GroupNode);
          end;
          Caption := BuildBausteinCaption(B);
          BausteinNode := tvBausteine.Items.AddChild(GroupNode, Caption);
          BausteinNode.Data := Pointer(B.Id);
        end;
        tvBausteine.FullExpand;
        if FActiveBausteinId > 0 then
          SelectBausteinInTree(FActiveBausteinId);
      finally
        MatchingIds.Free;
      end;
    finally
      GroupMap.Free;
    end;
  finally
    tvBausteine.Items.EndUpdate;
  end;
end;

function TMainForm.MatchingBausteinIdsForSearch(const ANeedle: string): TDictionary<Integer, Byte>;
var
  NeedleLower: string;
  B: TBaustein;
  R: TRequirement;
begin
  Result := TDictionary<Integer, Byte>.Create;
  NeedleLower := LowerCase(Trim(ANeedle));
  if NeedleLower = '' then
    Exit;
  for B in FCatalogBausteine do
  begin
    if (Pos(NeedleLower, LowerCase(B.ExternalId)) > 0) or
       (Pos(NeedleLower, LowerCase(B.Title)) > 0) or
       (Pos(NeedleLower, LowerCase(B.GroupName)) > 0) then
      Result.AddOrSetValue(B.Id, 1);
  end;
  for R in FCatalogRequirements do
  begin
    if (Pos(NeedleLower, LowerCase(R.ExternalId)) > 0) or
       (Pos(NeedleLower, LowerCase(R.Title)) > 0) or
       (Pos(NeedleLower, LowerCase(R.Text)) > 0) or
       (Pos(NeedleLower, LowerCase(R.ResponsibleRole)) > 0) then
      Result.AddOrSetValue(R.BausteinDbId, 1);
  end;
end;

procedure TMainForm.EnsureApplicableFilterFeasible;
begin
  if not chkFilterApplicable.Checked or not HasActiveProject or (FActiveTarget.Id = 0) then
    Exit;
  if TargetHasAssignedBausteine(FActiveTarget.Id) then
    Exit;
  chkFilterApplicable.Checked := False;
  ReloadBausteinTree;
  ShowTemporaryStatusMessage(
    Format('Filter deaktiviert: Für "%s – %s" sind noch keine Bausteine markiert. ' +
      'Baustein wählen → Rechtsklick → "Benötigt" oder "Möglicherweise".',
      [TargetObjectTypeToString(FActiveTarget.ObjType), FActiveTarget.Name]), 8000);
end;

procedure TMainForm.ShowBausteinNotApplicableMessage(ABausteinDbId: Integer;
  AStatus: TApplicabilityStatus);
begin
  ClearRequirementView;
  if AStatus = apNotApplicable then
    reRequirementText.Text :=
      Format('Dieser Baustein ist für das Zielobjekt "%s – %s" als "Nicht relevant" markiert.',
        [TargetObjectTypeToString(FActiveTarget.ObjType), FActiveTarget.Name])
  else
    reRequirementText.Text :=
      Format('Der Baustein ist für "%s – %s" noch nicht als anwendbar markiert.' + sLineBreak +
        sLineBreak +
        'Bitte zuerst per Rechtsklick auf den Baustein "Benötigt" oder "Möglicherweise" wählen. ' +
        'Erst dann können Anforderungen und Maßnahmen für dieses Zielobjekt bearbeitet werden.',
        [TargetObjectTypeToString(FActiveTarget.ObjType), FActiveTarget.Name]);
end;

procedure TMainForm.tvBausteineCustomDrawItem(Sender: TCustomTreeView; Node: TTreeNode;
  State: TCustomDrawState; var DefaultDraw: Boolean);
var
  BausteinId: Integer;
  Status: TApplicabilityStatus;
  Tier: TBausteinRecommendationTier;
begin
  DefaultDraw := True;
  if Node.Data = nil then
    Exit;
  BausteinId := Integer(Node.Data);
  if not FApplicabilityMap.TryGetValue(BausteinId, Status) then
    Status := apUndefined;
  if chkHighlightRecommendations.Checked and HasActiveProject and (FActiveTarget.Id > 0) and
     FRecommendedIds.ContainsKey(BausteinId) and (Status = apUndefined) then
  begin
    if FRecommendationTiers.TryGetValue(BausteinId, Tier) and (Tier = brtCore) then
      tvBausteine.Canvas.Font.Color := RGB(0, 102, 153)
    else
      tvBausteine.Canvas.Font.Color := RGB(0, 128, 96);
  end
  else
    case Status of
      apRequired: tvBausteine.Canvas.Font.Color := clMaroon;
      apPossible: tvBausteine.Canvas.Font.Color := RGB(0, 128, 0);
      apNotApplicable: tvBausteine.Canvas.Font.Color := clGrayText;
    else
      tvBausteine.Canvas.Font.Color := clWindowText;
    end;
end;

procedure TMainForm.tvBausteineDblClick(Sender: TObject);
begin
  DoViewBaustein(Sender);
end;

procedure TMainForm.sgMeasuresDblClick(Sender: TObject);
begin
  DoEditMeasure(Sender);
end;

function TMainForm.SelectedBausteinId: Integer;
begin
  Result := 0;
  if (tvBausteine.Selected <> nil) and (tvBausteine.Selected.Data <> nil) then
    Result := Integer(tvBausteine.Selected.Data);
end;

procedure TMainForm.ClearRequirementView;
begin
  FActiveRequirementId := 0;
  SetLength(FCurrentRequirements, 0);
  sgRequirements.RowCount := 2;
  sgRequirements.Rows[1].Clear;
  reRequirementText.Clear;
  FSuppressAssessmentSave := True;
  cboAssessmentStatus.ItemIndex := 0;
  edtResponsible.Text := '';
  chkHasDueDate.Checked := False;
  dtpDueDate.Enabled := False;
  memAssessmentNote.Clear;
  FSuppressAssessmentSave := False;
  sgMeasures.RowCount := 2;
  sgMeasures.Rows[1].Clear;
end;

procedure TMainForm.LoadRequirementsForBaustein(ABausteinDbId: Integer);
var
  R: TRequirement;
  Assessment: TRequirementAssessment;
  Row: Integer;
  MeasureCnt: Integer;
begin
  if not HasActiveProject or (FActiveTarget.Id = 0) or (ABausteinDbId = 0) then
  begin
    ClearRequirementView;
    Exit;
  end;
  FCurrentRequirements := FContext.CatalogRepository.LoadRequirements(ABausteinDbId);
  sgRequirements.RowCount := 1;
  Row := 1;
  for R in FCurrentRequirements do
  begin
    if R.Withdrawn then
      Continue;
    if not RequirementLevelApplies(R.Level, FActiveTarget.ProtectionNeed) then
      Continue;
    Inc(Row);
    sgRequirements.RowCount := Row + 1;
    Assessment := FContext.ProjectRepository.LoadAssessment(
      FActiveProject.Id, FActiveTarget.Id, R.Id);
    if FMeasureCounts.TryGetValue(R.Id, MeasureCnt) then
    else
      MeasureCnt := 0;
    sgRequirements.Cells[0, Row] := R.ExternalId;
    sgRequirements.Cells[1, Row] := R.Title;
    sgRequirements.Cells[2, Row] := RequirementLevelToString(R.Level);
    sgRequirements.Cells[3, Row] := R.ResponsibleRole;
    sgRequirements.Cells[4, Row] := AssessmentStatusToString(Assessment.Status);
    sgRequirements.Cells[5, Row] := Assessment.Responsible;
    if IsValidDate(Assessment.DueDate) then
      sgRequirements.Cells[6, Row] := FormatDateTime('dd.mm.yyyy', Assessment.DueDate)
    else
      sgRequirements.Cells[6, Row] := '';
    if MeasureCnt > 0 then
      sgRequirements.Cells[7, Row] := IntToStr(MeasureCnt)
    else
      sgRequirements.Cells[7, Row] := '';
    sgRequirements.Objects[0, Row] := TObject(R.Id);
    if IsAssessmentDueDateOverdue(Assessment) then
      sgRequirements.Objects[2, Row] := TObject(1)
    else
      sgRequirements.Objects[2, Row] := nil;
  end;
  if sgRequirements.RowCount > 1 then
  begin
    sgRequirements.Row := 1;
    LoadRequirementDetails(1);
  end
  else
    ClearRequirementView;
end;

procedure TMainForm.LoadRequirementDetails(ARow: Integer);
var
  ReqId: Integer;
  R: TRequirement;
  Assessment: TRequirementAssessment;
  I: Integer;
begin
  if ARow < 1 then
    Exit;
  ReqId := Integer(sgRequirements.Objects[0, ARow]);
  if ReqId = 0 then
    Exit;
  FActiveRequirementId := ReqId;
  if HasActiveProject and (FActiveTarget.Id > 0) then
    FLastRequirementByTarget.AddOrSetValue(FActiveTarget.Id, ReqId);
  FillChar(R, SizeOf(R), 0);
  for I := 0 to High(FCurrentRequirements) do
    if FCurrentRequirements[I].Id = ReqId then
    begin
      R := FCurrentRequirements[I];
      Break;
    end;
  if R.Id = 0 then
    Exit;
  TRequirementTextFormatter.ApplyToRichEdit(reRequirementText, R.Text);
  Assessment := FContext.ProjectRepository.LoadAssessment(
    FActiveProject.Id, FActiveTarget.Id, ReqId);
  SyncAssessmentUi(Assessment);
  LoadMeasuresForCurrentRequirement;
end;

procedure TMainForm.LoadMeasuresForCurrentRequirement;
var
  M: TMeasure;
  Row: Integer;
begin
  sgMeasures.RowCount := 1;
  if not HasActiveProject or (FActiveTarget.Id = 0) or (FActiveRequirementId = 0) then
    Exit;
  FCurrentMeasures := FContext.MeasureRepository.LoadMeasures(
    FActiveProject.Id, FActiveTarget.Id, FActiveRequirementId);
  Row := 1;
  for M in FCurrentMeasures do
  begin
    Inc(Row);
    sgMeasures.RowCount := Row + 1;
    sgMeasures.Cells[0, Row] := M.Title;
    sgMeasures.Cells[1, Row] := M.Responsible;
    if IsValidDate(M.DueDate) then
      sgMeasures.Cells[2, Row] := DateToIso(M.DueDate)
    else
      sgMeasures.Cells[2, Row] := '';
    sgMeasures.Cells[3, Row] := MeasureStatusToString(M.Status);
    sgMeasures.Objects[0, Row] := TObject(M.Id);
  end;
end;

procedure TMainForm.SyncAssessmentUi(const AAssessment: TRequirementAssessment);
begin
  FSuppressAssessmentSave := True;
  cboAssessmentStatus.ItemIndex := Ord(AAssessment.Status);
  edtResponsible.Text := AAssessment.Responsible;
  chkHasDueDate.Checked := IsValidDate(AAssessment.DueDate);
  dtpDueDate.Enabled := chkHasDueDate.Checked and CanEditActiveProject;
  if chkHasDueDate.Checked then
    dtpDueDate.Date := AAssessment.DueDate;
  memAssessmentNote.Text := AAssessment.Note;
  FCurrentAssessmentVersion := AAssessment.Version;
  FSuppressAssessmentSave := False;
end;

procedure TMainForm.ApplyAssessmentConflict(const AAssessment: TRequirementAssessment;
  ARequirementDbId: Integer; AShowDialog: Boolean);
var
  Refreshed: TRequirementAssessment;
begin
  Refreshed := AAssessment;
  if FMeasureCounts.TryGetValue(ARequirementDbId, Refreshed.MeasureCount) then
  else
    Refreshed.MeasureCount := 0;
  FSuppressAssessmentSave := True;
  if (FActiveTarget.Id = Refreshed.TargetObjectId) and
     (FActiveRequirementId = ARequirementDbId) then
    SyncAssessmentUi(Refreshed);
  FSuppressAssessmentSave := False;
  if FActiveBausteinId > 0 then
    LoadRequirementsForBaustein(FActiveBausteinId);
  if AShowDialog then
  begin
    MessageDlg('Ein anderer Benutzer hat diese Bewertung zwischenzeitlich geändert. ' +
      'Die aktuelle Server-Version wurde geladen.', mtWarning, [mbOK], 0);
    FLastConflictNotifiedRequirementId := 0;
  end
  else if FLastConflictNotifiedRequirementId <> ARequirementDbId then
  begin
    ShowTemporaryStatusMessage(
      'Konflikt: Bewertung wurde von einem anderen Benutzer geändert und neu geladen.', 10000);
    FLastConflictNotifiedRequirementId := ARequirementDbId;
  end;
end;

function TMainForm.SaveCurrentAssessment(ANotifyDialog: Boolean): Boolean;
var
  Assessment: TRequirementAssessment;
  SaveResult: TAssessmentSaveResult;
begin
  if FSuppressAssessmentSave or not HasActiveProject or
     (FActiveTarget.Id = 0) or (FActiveRequirementId = 0) or not CanEditActiveProject then
    Exit(True);
  FillChar(Assessment, SizeOf(Assessment), 0);
  Assessment.ProjectId := FActiveProject.Id;
  Assessment.TargetObjectId := FActiveTarget.Id;
  Assessment.RequirementDbId := FActiveRequirementId;
  Assessment.Version := FCurrentAssessmentVersion;
  if cboAssessmentStatus.ItemIndex >= 0 then
    Assessment.Status := TAssessmentStatus(cboAssessmentStatus.ItemIndex);
  Assessment.Responsible := edtResponsible.Text;
  if chkHasDueDate.Checked then
    Assessment.DueDate := dtpDueDate.Date;
  Assessment.Note := memAssessmentNote.Text;
  SaveResult := FContext.ProjectRepository.SaveAssessment(Assessment);
  if SaveResult.Status = assOk then
  begin
    FCurrentAssessmentVersion := SaveResult.Assessment.Version;
    if FLastConflictNotifiedRequirementId = FActiveRequirementId then
      FLastConflictNotifiedRequirementId := 0;
    ReloadProgress;
    if FActiveBausteinId > 0 then
      LoadRequirementsForBaustein(FActiveBausteinId);
    Exit(True);
  end;
  if SaveResult.Status = assVersionConflict then
  begin
    ApplyAssessmentConflict(SaveResult.Assessment, FActiveRequirementId, ANotifyDialog);
    Exit(False);
  end;
  if ANotifyDialog then
    MessageDlg('Speichern fehlgeschlagen: ' + FContext.ProjectRepository.LastError,
      mtError, [mbOK], 0);
  Result := False;
end;

procedure TMainForm.SaveAssessmentFields;
begin
  if FSuppressAssessmentSave or not CanEditActiveProject then
    Exit;
  if not SaveCurrentAssessment(False) then
    ShowTemporaryStatusMessage('Speichern fehlgeschlagen: ' +
      FContext.ProjectRepository.LastError, 5000);
end;

procedure TMainForm.memAssessmentNoteChange(Sender: TObject);
begin
  SaveAssessmentFields;
end;

procedure TMainForm.DoShowSollIstReport(Sender: TObject);
var
  Report: TReportForm;
begin
  if not HasActiveProject then
    Exit;
  Report := TReportForm.Create(Self, FContext, FActiveProject, FActiveTarget);
  try
    Report.ShowModal;
  finally
    Report.Free;
  end;
end;

procedure TMainForm.DoImportCatalog(Sender: TObject);
var
  Dlg: TOpenDialog;
begin
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.Filter := 'XML-Dateien (*.xml)|*.xml|Alle Dateien (*.*)|*.*';
    Dlg.FileName := DefaultGrundschutzXml;
    if not Dlg.Execute then
      Exit;
    if FContext.ImportCatalogFile(Dlg.FileName) then
    begin
      ReloadCatalog;
      MessageDlg('Katalog erfolgreich importiert.', mtInformation, [mbOK], 0);
    end
    else
      MessageDlg('Import fehlgeschlagen: ' + FContext.LastError, mtError, [mbOK], 0);
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.DoCreateProject(Sender: TObject);
var
  P: TProject;
  Scope: TTargetObject;
begin
  if not TProjectForm.ExecuteCreate(P) then
    Exit;
  P := FContext.ProjectRepository.CreateProject(P.Name, P.Description, FContext.CatalogVersion);
  if P.Id = 0 then
  begin
    MessageDlg('Projekt konnte nicht erstellt werden: ' + FContext.ProjectRepository.LastError,
      mtError, [mbOK], 0);
    Exit;
  end;
  Scope := FContext.TargetObjectRepository.CreateDefaultScope(P.Id, P.Name);
  if Scope.Id = 0 then
  begin
    MessageDlg('Standard-Zielobjekt konnte nicht erstellt werden.',
      mtError, [mbOK], 0);
    Exit;
  end;
  FActiveProject := P;
  FillChar(FActiveTarget, SizeOf(FActiveTarget), 0);
  FActiveBausteinId := 0;
  FLastBausteinByTarget.Clear;
  FLastRequirementByTarget.Clear;
  ReloadTargetObjects;
  ApplyTargetSelection(Scope.Id);
  UpdateProjectUi;
end;

procedure TMainForm.DoOpenProject(Sender: TObject);
var
  Projects: TArray<TProject>;
  Selected: TProject;
  Session: TSessionSelection;
begin
  Projects := FContext.ProjectRepository.LoadProjects;
  if Length(Projects) = 0 then
  begin
    MessageDlg('Keine Projekte vorhanden.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if not TProjectOpenForm.Execute(Projects, Selected, FContext.IsRemote) then
    Exit;
  FActiveProject := Selected;
  FillChar(FActiveTarget, SizeOf(FActiveTarget), 0);
  FLastBausteinByTarget.Clear;
  FLastRequirementByTarget.Clear;
  TAppSessionStore.LoadTargetSelections(FActiveProject.Id, FLastBausteinByTarget,
    FLastRequirementByTarget);
  Session := TAppSessionStore.LoadSession(FActiveProject.Id);
  if (FLastBausteinByTarget.Count = 0) and (Session.TargetObjectId > 0) then
  begin
    if Session.BausteinId > 0 then
      FLastBausteinByTarget.AddOrSetValue(Session.TargetObjectId, Session.BausteinId);
    if Session.RequirementId > 0 then
      FLastRequirementByTarget.AddOrSetValue(Session.TargetObjectId, Session.RequirementId);
  end;
  ReloadTargetObjects(Session.TargetObjectId);
  UpdateProjectUi;
end;

procedure TMainForm.DoCloseProject(Sender: TObject);
begin
  PersistSessionSelection;
  SaveCurrentAssessment;
  FillChar(FActiveProject, SizeOf(FActiveProject), 0);
  FillChar(FActiveTarget, SizeOf(FActiveTarget), 0);
  FActiveBausteinId := 0;
  tvTargets.Items.Clear;
  ClearRequirementView;
  ReloadBausteinTree;
  ReloadProgress;
  UpdateProjectUi;
end;

procedure TMainForm.DoEditProject(Sender: TObject);
var
  P: TProject;
begin
  if not HasActiveProject then
    Exit;
  P := FActiveProject;
  if not TProjectForm.ExecuteEdit(P) then
    Exit;
  if not FContext.ProjectRepository.UpdateProject(P) then
  begin
    MessageDlg('Speichern fehlgeschlagen: ' + FContext.ProjectRepository.LastError,
      mtError, [mbOK], 0);
    Exit;
  end;
  FActiveProject := P;
  UpdateProjectUi;
end;

procedure TMainForm.DoManageMembers(Sender: TObject);
begin
  if not FContext.IsRemote or (FActiveProject.Id = 0) then
    Exit;
  TProjectMembersForm.Execute(Self, FContext.ApiClient, FActiveProject.Id, FActiveProject.Name,
    FActiveProject.Role = 'owner', FContext.IsRemoteAdmin);
end;

procedure TMainForm.DoDeleteProject(Sender: TObject);
begin
  if not HasActiveProject then
    Exit;
  if MessageDlg('Projekt "' + FActiveProject.Name + '" wirklich löschen?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  if not FContext.ProjectRepository.DeleteProject(FActiveProject.Id) then
  begin
    MessageDlg('Löschen fehlgeschlagen: ' + FContext.ProjectRepository.LastError,
      mtError, [mbOK], 0);
    Exit;
  end;
  DoCloseProject(Sender);
end;

procedure TMainForm.DoAddTarget(Sender: TObject);
var
  O: TTargetObject;
  ParentId: Integer;
begin
  if not HasActiveProject then
  begin
    MessageDlg('Bitte zuerst ein Projekt öffnen.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if not CanEditActiveProject then
  begin
    MessageDlg('Keine Berechtigung zum Bearbeiten dieses Projekts.', mtWarning, [mbOK], 0);
    Exit;
  end;
  FillChar(O, SizeOf(O), 0);
  O.ProjectId := FActiveProject.Id;
  if FActiveTarget.Id > 0 then
    ParentId := FActiveTarget.Id
  else
    ParentId := 0;
  O.ParentId := ParentId;
  O.ObjType := totProcess;
  O.ProtectionNeed := pnNormal;
  O.Name := 'Neues Zielobjekt';
  if not TTargetObjectForm.ExecuteCreate(O) then
    Exit;
  O := FContext.TargetObjectRepository.CreateTargetObject(O);
  if O.Id = 0 then
  begin
    MessageDlg('Zielobjekt konnte nicht erstellt werden: ' +
      FContext.TargetObjectRepository.LastError, mtError, [mbOK], 0);
    Exit;
  end;
  ReloadTargetObjects(O.Id);
end;

procedure TMainForm.DoEditTarget(Sender: TObject);
var
  O: TTargetObject;
begin
  if not HasActiveProject then
    Exit;
  if not CanEditActiveProject then
  begin
    MessageDlg('Keine Berechtigung zum Bearbeiten dieses Projekts.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if FActiveTarget.Id = 0 then
  begin
    MessageDlg('Bitte zuerst ein Zielobjekt auswählen.', mtInformation, [mbOK], 0);
    Exit;
  end;
  O := FActiveTarget;
  if not TTargetObjectForm.ExecuteEdit(O) then
    Exit;
  if not FContext.TargetObjectRepository.UpdateTargetObject(O) then
  begin
    MessageDlg('Speichern fehlgeschlagen: ' + FContext.TargetObjectRepository.LastError,
      mtError, [mbOK], 0);
    Exit;
  end;
  ReloadTargetObjects(O.Id);
end;

procedure TMainForm.DoDeleteTarget(Sender: TObject);
begin
  if not HasActiveProject then
    Exit;
  if not CanEditActiveProject then
  begin
    MessageDlg('Keine Berechtigung zum Bearbeiten dieses Projekts.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if FActiveTarget.Id = 0 then
  begin
    MessageDlg('Bitte zuerst ein Zielobjekt auswählen.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if MessageDlg(Format('Das Zielobjekt "%s" und alle untergeordneten Objekte wirklich löschen?',
    [FActiveTarget.Name]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  if not FContext.TargetObjectRepository.DeleteTargetObject(FActiveTarget.Id) then
  begin
    MessageDlg('Löschen fehlgeschlagen: ' + FContext.TargetObjectRepository.LastError,
      mtError, [mbOK], 0);
    Exit;
  end;
  FillChar(FActiveTarget, SizeOf(FActiveTarget), 0);
  ReloadTargetObjects;
  ClearRequirementView;
  UpdateProjectUi;
end;

procedure TMainForm.SelectTargetInTree(ATargetId: Integer);
var
  Node: TTreeNode;
begin
  Node := tvTargets.Items.GetFirstNode;
  while Node <> nil do
  begin
    if (Node.Data <> nil) and (Integer(Node.Data) = ATargetId) then
    begin
      FBlockTargetSelection := True;
      try
        Node.Selected := True;
        tvTargets.SetFocus;
      finally
        FBlockTargetSelection := False;
      end;
      Exit;
    end;
    Node := Node.GetNext;
  end;
end;

procedure TMainForm.ApplyTargetSelection(ATargetId: Integer; AAutoSwitchIfEmpty: Boolean);
var
  Objects: TArray<TTargetObject>;
  O: TTargetObject;
  BausteinId, RequirementId, AssignedCount, AlternateId: Integer;
  Pair: TPair<Integer, TApplicabilityStatus>;
  ErrMsg: string;
begin
  if not HasActiveProject or (ATargetId <= 0) then
  begin
    FillChar(FActiveTarget, SizeOf(FActiveTarget), 0);
    FActiveBausteinId := 0;
    ReloadBausteinTree;
    ClearRequirementView;
    UpdateProjectUi;
    Exit;
  end;

  FillChar(FActiveTarget, SizeOf(FActiveTarget), 0);
  Objects := FContext.TargetObjectRepository.LoadTargetObjects(FActiveProject.Id);
  for O in Objects do
    if O.Id = ATargetId then
    begin
      FActiveTarget := O;
      Break;
    end;
  if FActiveTarget.Id = 0 then
    Exit;

  SelectTargetInTree(ATargetId);

  ReloadApplicabilityFromServer;
  FMeasureCounts.Free;
  FMeasureCounts := FContext.MeasureRepository.MeasureCounts(
    FActiveProject.Id, FActiveTarget.Id);
  ReloadRecommendationMarkers;

  AssignedCount := 0;
  for Pair in FApplicabilityMap do
    if (Pair.Value = apRequired) or (Pair.Value = apPossible) then
      Inc(AssignedCount);

  if AAutoSwitchIfEmpty and (AssignedCount = 0) then
  begin
    AlternateId := FindAlternateTargetWithAssignments(Objects, FActiveTarget);
    if AlternateId > 0 then
    begin
      for O in Objects do
        if O.Id = AlternateId then
        begin
          StatusBar.Panels[1].Text := Format(
            'Wechsle zu „%s – %s [%s]" (dort liegen die Zuweisungen).',
            [TargetObjectTypeToString(O.ObjType), O.Name, ProtectionNeedToString(O.ProtectionNeed)]);
          Break;
        end;
      ApplyTargetSelection(AlternateId, False);
      Exit;
    end;
  end;

  FActiveBausteinId := 0;
  FActiveRequirementId := 0;
  if FLastBausteinByTarget.TryGetValue(FActiveTarget.Id, BausteinId) and
     IsBausteinApplicable(BausteinId) then
    FActiveBausteinId := BausteinId;

  ReloadBausteinTree;
  PopulateAssignedBausteinBox;
  EnsureApplicableFilterFeasible;
  if FActiveBausteinId > 0 then
  begin
    LoadRequirementsForBaustein(FActiveBausteinId);
    if FLastRequirementByTarget.TryGetValue(FActiveTarget.Id, RequirementId) then
      SelectRequirementRow(RequirementId);
  end
  else
    ClearRequirementView;
  UpdateProjectUi;
  PersistSessionSelection;

  if AssignedCount = 0 then
  begin
    ErrMsg := Trim(FContext.TargetObjectRepository.LastError);
    if ErrMsg <> '' then
      StatusBar.Panels[1].Text := Format('%s – %s: Zuweisungen nicht geladen – %s',
        [TargetObjectTypeToString(FActiveTarget.ObjType), FActiveTarget.Name, ErrMsg])
    else
      StatusBar.Panels[1].Text := Format('Projekt #%d – %s – %s: keine Bausteine zugewiesen',
        [FActiveProject.Id, TargetObjectTypeToString(FActiveTarget.ObjType), FActiveTarget.Name]);
  end
  else
    StatusBar.Panels[1].Text := Format('%s – %s: %d Baustein(e) zugewiesen',
      [TargetObjectTypeToString(FActiveTarget.ObjType), FActiveTarget.Name, AssignedCount]);
end;

procedure TMainForm.ApplyBausteinSelection(ABausteinId: Integer);
var
  ApplicabilityStatus: TApplicabilityStatus;
begin
  if ABausteinId <= 0 then
  begin
    if FActiveBausteinId <> 0 then
    begin
      FActiveBausteinId := 0;
      ClearRequirementView;
      PopulateAssignedBausteinBox;
      UpdateProjectUi;
    end;
    Exit;
  end;

  if not HasActiveProject or (FActiveTarget.Id = 0) then
    Exit;

  if not IsBausteinApplicable(ABausteinId) then
  begin
    if not FApplicabilityMap.TryGetValue(ABausteinId, ApplicabilityStatus) then
      ApplicabilityStatus := apUndefined;
    ShowBausteinNotApplicableMessage(ABausteinId, ApplicabilityStatus);
    if FActiveBausteinId > 0 then
      SelectBausteinInTree(FActiveBausteinId);
    Exit;
  end;

  if ABausteinId = FActiveBausteinId then
  begin
    LoadRequirementsForBaustein(ABausteinId);
    PopulateAssignedBausteinBox;
    Exit;
  end;

  SaveCurrentAssessment;
  FActiveBausteinId := ABausteinId;
  FActiveRequirementId := 0;
  if FActiveTarget.Id > 0 then
    FLastBausteinByTarget.AddOrSetValue(FActiveTarget.Id, ABausteinId);
  LoadRequirementsForBaustein(ABausteinId);
  PopulateAssignedBausteinBox;
  UpdateProjectUi;
end;

procedure TMainForm.SelectRequirementRow(ARequirementId: Integer);
var
  Row: Integer;
begin
  if ARequirementId <= 0 then
    Exit;
  for Row := sgRequirements.FixedRows to sgRequirements.RowCount - 1 do
    if Integer(sgRequirements.Objects[0, Row]) = ARequirementId then
    begin
      sgRequirements.Row := Row;
      LoadRequirementDetails(Row);
      Exit;
    end;
end;

procedure TMainForm.tvTargetsClick(Sender: TObject);
var
  Node: TTreeNode;
  P: TPoint;
  TargetId: Integer;
begin
  P := tvTargets.ScreenToClient(Mouse.CursorPos);
  Node := tvTargets.GetNodeAt(P.X, P.Y);
  if (Node = nil) or (Node.Data = nil) then
    Exit;
  TargetId := Integer(Node.Data);
  if Node <> tvTargets.Selected then
    Node.Selected := True
  else
  begin
    if FActiveTarget.Id > 0 then
    begin
      FLastBausteinByTarget.AddOrSetValue(FActiveTarget.Id, FActiveBausteinId);
      FLastRequirementByTarget.AddOrSetValue(FActiveTarget.Id, FActiveRequirementId);
    end;
    SaveCurrentAssessment;
    ApplyTargetSelection(TargetId);
  end;
end;

procedure TMainForm.tvTargetsChange(Sender: TObject; Node: TTreeNode);
var
  TargetId: Integer;
begin
  if FBlockTargetSelection then
    Exit;
  if (Node = nil) or (Node.Data = nil) then
    Exit;
  if FActiveTarget.Id > 0 then
  begin
    FLastBausteinByTarget.AddOrSetValue(FActiveTarget.Id, FActiveBausteinId);
    FLastRequirementByTarget.AddOrSetValue(FActiveTarget.Id, FActiveRequirementId);
  end;
  SaveCurrentAssessment;
  TargetId := Integer(Node.Data);
  ApplyTargetSelection(TargetId);
end;

procedure TMainForm.tvBausteineChange(Sender: TObject; Node: TTreeNode);
begin
  if Node = nil then
    Exit;
  if Node.Data = nil then
  begin
    ApplyBausteinSelection(0);
    Exit;
  end;
  ApplyBausteinSelection(Integer(Node.Data));
end;

procedure TMainForm.tvBausteineClick(Sender: TObject);
var
  Node: TTreeNode;
begin
  Node := tvBausteine.Selected;
  if (Node <> nil) and (Node.Data <> nil) then
    ApplyBausteinSelection(Integer(Node.Data));
end;

procedure TMainForm.SetBausteinApplicability(AStatus: TApplicabilityStatus; ABausteinId: Integer);
var
  App: TBausteinApplicability;
  BausteinId: Integer;
  B: TBaustein;
begin
  if ABausteinId > 0 then
    BausteinId := ABausteinId
  else
    BausteinId := SelectedBausteinId;

  if not HasActiveProject then
  begin
    MessageDlg('Bitte zuerst ein Projekt öffnen.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if FActiveTarget.Id = 0 then
  begin
    MessageDlg('Bitte zuerst ein Zielobjekt wählen.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if BausteinId = 0 then
  begin
    MessageDlg('Bitte zuerst einen Baustein wählen.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if not CanEditActiveProject then
  begin
    MessageDlg('Keine Berechtigung zum Bearbeiten dieses Projekts.', mtWarning, [mbOK], 0);
    Exit;
  end;

  if AStatus = apUndefined then
  begin
    B := FindBausteinById(BausteinId);
    if MessageDlg(Format('Die Zuweisung von "%s %s" zum Zielobjekt "%s – %s" wirklich entfernen?',
      [B.ExternalId, B.Title, TargetObjectTypeToString(FActiveTarget.ObjType), FActiveTarget.Name]),
      mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
      Exit;
  end;
  FillChar(App, SizeOf(App), 0);
  App.ProjectId := FActiveProject.Id;
  App.TargetObjectId := FActiveTarget.Id;
  App.BausteinDbId := BausteinId;
  App.Status := AStatus;
  if not FContext.TargetObjectRepository.SaveApplicability(App) then
  begin
    MessageDlg('Speichern fehlgeschlagen: ' + FContext.TargetObjectRepository.LastError,
      mtError, [mbOK], 0);
    StatusBar.Panels[1].Text := FContext.TargetObjectRepository.LastError;
    Exit;
  end;
  B := FindBausteinById(BausteinId);
  if FContext.IsRemote then
    StatusBar.Panels[1].Text := Format('%s %s als %s für %s gespeichert (Server)',
      [B.ExternalId, B.Title, ApplicabilityStatusToString(AStatus), FActiveTarget.Name])
  else
    StatusBar.Panels[1].Text := Format('%s %s als %s für %s gespeichert (lokal)',
      [B.ExternalId, B.Title, ApplicabilityStatusToString(AStatus), FActiveTarget.Name]);
  if AStatus = apUndefined then
    FApplicabilityMap.Remove(BausteinId)
  else
    FApplicabilityMap.AddOrSetValue(BausteinId, AStatus);
  if (AStatus = apRequired) or (AStatus = apPossible) then
  begin
    FActiveBausteinId := BausteinId;
    if FActiveTarget.Id > 0 then
      FLastBausteinByTarget.AddOrSetValue(FActiveTarget.Id, BausteinId);
  end;
  ReloadRecommendationMarkers;
  ReloadBausteinTree;
  PopulateAssignedBausteinBox;
  if BausteinId = FActiveBausteinId then
    LoadRequirementsForBaustein(FActiveBausteinId);
end;

procedure TMainForm.tvBausteineContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
var
  Node: TTreeNode;
begin
  FContextMenuBausteinId := 0;
  if not HasActiveProject or (FActiveTarget.Id = 0) then
  begin
    Handled := True;
    Exit;
  end;

  Node := tvBausteine.GetNodeAt(MousePos.X, MousePos.Y);
  if (Node = nil) or (Node.Data = nil) then
  begin
    Handled := True;
    Exit;
  end;

  Node.Selected := True;
  tvBausteine.SetFocus;
  FContextMenuBausteinId := NativeInt(Node.Data);

  mniBausteinRequired.Visible := CanEditActiveProject;
  mniBausteinPossible.Visible := CanEditActiveProject;
  mniBausteinNotApplicable.Visible := CanEditActiveProject;
  mniBausteinReset.Visible := CanEditActiveProject;
  mniBausteinSep1.Visible := CanEditActiveProject;
  mniBausteinSep2.Visible := CanEditActiveProject;
end;

procedure TMainForm.sgRequirementsSelectCell(Sender: TObject; ACol, ARow: Integer;
  var CanSelect: Boolean);
begin
  if ARow >= 1 then
    LoadRequirementDetails(ARow);
  CanSelect := True;
end;

procedure TMainForm.cboAssessmentStatusChange(Sender: TObject);
begin
  if not SaveCurrentAssessment(True) then
    ShowTemporaryStatusMessage('Speichern fehlgeschlagen: ' +
      FContext.ProjectRepository.LastError, 5000);
end;

procedure TMainForm.edtResponsibleExit(Sender: TObject);
begin
  SaveCurrentAssessment(False);
end;

procedure TMainForm.endProgramm(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.ApplicabilityRequiredClick(Sender: TObject);
begin
  SetBausteinApplicability(apRequired, FContextMenuBausteinId);
end;

procedure TMainForm.ApplicabilityPossibleClick(Sender: TObject);
begin
  SetBausteinApplicability(apPossible, FContextMenuBausteinId);
end;

procedure TMainForm.ApplicabilityNotApplicableClick(Sender: TObject);
begin
  SetBausteinApplicability(apNotApplicable, FContextMenuBausteinId);
end;

procedure TMainForm.memAssessmentNoteExit(Sender: TObject);
begin
  SaveCurrentAssessment(False);
end;

procedure TMainForm.chkHasDueDateClick(Sender: TObject);
begin
  dtpDueDate.Enabled := chkHasDueDate.Checked and CanEditActiveProject;
  SaveCurrentAssessment(True);
end;

procedure TMainForm.dtpDueDateChange(Sender: TObject);
begin
  SaveCurrentAssessment(False);
end;

procedure TMainForm.edtBausteinSearchChange(Sender: TObject);
begin
  ReloadBausteinTree;
end;

procedure TMainForm.chkFilterApplicableClick(Sender: TObject);
begin
  ReloadBausteinTree;
end;

procedure TMainForm.chkHighlightRecommendationsClick(Sender: TObject);
begin
  ReloadBausteinTree;
end;

procedure TMainForm.ReloadApplicabilityFromServer;
var
  Map: TDictionary<Integer, TApplicabilityStatus>;
begin
  if not HasActiveProject or (FActiveTarget.Id = 0) then
    Exit;
  Map := FContext.TargetObjectRepository.LoadApplicabilityMap(
    FActiveProject.Id, FActiveTarget.Id);
  FApplicabilityMap.Free;
  FApplicabilityMap := Map;
end;

procedure TMainForm.PopulateAssignedBausteinBox;
var
  Pair: TPair<Integer, TApplicabilityStatus>;
  AssignedIds: TList<Integer>;
  BausteinId: Integer;
  B: TBaustein;
  LabelText: string;
  I: Integer;
  ErrMsg: string;
begin
  FSuppressAssignedBausteinChange := True;
  try
    cboAssignedBausteine.Items.Clear;
    if not HasActiveProject or (FActiveTarget.Id = 0) then
    begin
      cboAssignedBausteine.Items.AddObject('— Kein Zielobjekt gewählt —', TObject(0));
      cboAssignedBausteine.ItemIndex := 0;
      Exit;
    end;

    AssignedIds := TList<Integer>.Create;
    try
      for Pair in FApplicabilityMap do
        if (Pair.Value = apRequired) or (Pair.Value = apPossible) then
          AssignedIds.Add(Pair.Key);
      AssignedIds.Sort;

      if AssignedIds.Count = 0 then
      begin
        ErrMsg := Trim(FContext.TargetObjectRepository.LastError);
        if ErrMsg <> '' then
        begin
          cboAssignedBausteine.Items.AddObject('— Zuweisungen nicht geladen —', TObject(0));
          cboAssignedBausteine.ItemIndex := 0;
          Exit;
        end;
        cboAssignedBausteine.Items.AddObject('— Keine Bausteine zugewiesen —', TObject(0));
        cboAssignedBausteine.ItemIndex := 0;
        Exit;
      end;

      for BausteinId in AssignedIds do
      begin
        B := FindBausteinById(BausteinId);
        LabelText := Format('%s %s (%s)', [B.ExternalId, B.Title,
          ApplicabilityStatusToString(FApplicabilityMap[BausteinId])]);
        cboAssignedBausteine.Items.AddObject(LabelText, TObject(BausteinId));
      end;

      if FActiveBausteinId > 0 then
      begin
        for I := 0 to cboAssignedBausteine.Items.Count - 1 do
          if Integer(cboAssignedBausteine.Items.Objects[I]) = FActiveBausteinId then
          begin
            cboAssignedBausteine.ItemIndex := I;
            Break;
          end;
      end
      else
        cboAssignedBausteine.ItemIndex := 0;
    finally
      AssignedIds.Free;
    end;
  finally
    FSuppressAssignedBausteinChange := False;
  end;
end;

procedure TMainForm.cboAssignedBausteineChange(Sender: TObject);
var
  BausteinId: Integer;
begin
  if FSuppressAssignedBausteinChange or (cboAssignedBausteine.ItemIndex < 0) then
    Exit;
  BausteinId := Integer(cboAssignedBausteine.Items.Objects[cboAssignedBausteine.ItemIndex]);
  if BausteinId <= 0 then
    Exit;
  SaveCurrentAssessment;
  FActiveBausteinId := BausteinId;
  SelectBausteinInTree(BausteinId);
  LoadRequirementsForBaustein(BausteinId);
end;

procedure TMainForm.SelectBausteinInTree(ABausteinId: Integer);
var
  Node: TTreeNode;
begin
  Node := tvBausteine.Items.GetFirstNode;
  while Node <> nil do
  begin
    if (Node.Data <> nil) and (Integer(Node.Data) = ABausteinId) then
    begin
      Node.Selected := True;
      Exit;
    end;
    Node := Node.GetNext;
  end;
end;

procedure TMainForm.PersistSessionSelection;
var
  Session: TSessionSelection;
begin
  if not HasActiveProject then
    Exit;
  if FActiveTarget.Id > 0 then
  begin
    FLastBausteinByTarget.AddOrSetValue(FActiveTarget.Id, FActiveBausteinId);
    FLastRequirementByTarget.AddOrSetValue(FActiveTarget.Id, FActiveRequirementId);
    TAppSessionStore.SaveTargetSelection(FActiveProject.Id, FActiveTarget.Id,
      FActiveBausteinId, FActiveRequirementId);
  end;
  Session.TargetObjectId := FActiveTarget.Id;
  Session.BausteinId := FActiveBausteinId;
  Session.RequirementId := FActiveRequirementId;
  TAppSessionStore.SaveSession(FActiveProject.Id, Session);
end;

procedure TMainForm.OpenBausteinView(const B: TBaustein; const AInitialSearch: string);
var
  Requirements: TArray<TRequirement>;
begin
  if B.Id = 0 then
    Exit;
  Requirements := FContext.CatalogRepository.LoadRequirements(B.Id);
  TBausteinViewForm.Execute(Self, B, Requirements, AInitialSearch);
end;

procedure TMainForm.DoViewBaustein(Sender: TObject);
var
  B: TBaustein;
begin
  B := FindBausteinById(SelectedBausteinId);
  if B.Id = 0 then
  begin
    MessageDlg('Bitte zuerst einen Baustein in der Bausteinliste auswählen.',
      mtInformation, [mbOK], 0);
    Exit;
  end;
  OpenBausteinView(B, Trim(edtBausteinSearch.Text));
end;

procedure TMainForm.DoCatalogSearch(Sender: TObject);
begin
  TCatalogSearchForm.Execute(Self, FContext, FCatalogBausteine, FCatalogRequirements,
    Trim(edtBausteinSearch.Text));
end;

procedure TMainForm.DoApplyRecommendations(Sender: TObject);
var
  Recs: TArray<TBausteinRecommendation>;
  Selections: TArray<TBausteinRecommendationSelection>;
  Sel: TBausteinRecommendationSelection;
  App: TBausteinApplicability;
  AppliedCount: Integer;
begin
  if not HasActiveProject then
  begin
    MessageDlg('Bitte zuerst ein Projekt öffnen.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if not CanEditActiveProject then
  begin
    MessageDlg('Keine Berechtigung zum Bearbeiten dieses Projekts.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if FActiveTarget.Id = 0 then
  begin
    MessageDlg('Bitte zuerst ein Zielobjekt wählen.', mtInformation, [mbOK], 0);
    Exit;
  end;

  Recs := TBausteinRecommendationService.BuildRecommendations(FCatalogBausteine, FActiveTarget);
  if Length(Recs) = 0 then
  begin
    MessageDlg(Format('Für Zielobjekt "%s" (%s, %s) sind keine Baustein-Empfehlungen hinterlegt.',
      [FActiveTarget.Name, TargetObjectTypeToString(FActiveTarget.ObjType),
       ProtectionNeedToString(FActiveTarget.ProtectionNeed)]), mtInformation, [mbOK], 0);
    Exit;
  end;

  if not TBausteinRecommendationForm.Execute(Recs, FApplicabilityMap, FActiveTarget, Selections) then
    Exit;
  if Length(Selections) = 0 then
  begin
    ShowTemporaryStatusMessage('Keine Baustein-Empfehlungen übernommen', 5000);
    Exit;
  end;

  AppliedCount := 0;
  for Sel in Selections do
  begin
    FillChar(App, SizeOf(App), 0);
    App.ProjectId := FActiveProject.Id;
    App.TargetObjectId := FActiveTarget.Id;
    App.BausteinDbId := Sel.BausteinDbId;
    App.Status := Sel.Status;
    if FContext.TargetObjectRepository.SaveApplicability(App) then
    begin
      FApplicabilityMap.AddOrSetValue(Sel.BausteinDbId, Sel.Status);
      Inc(AppliedCount);
    end;
  end;

  ReloadRecommendationMarkers;
  ReloadBausteinTree;
  PopulateAssignedBausteinBox;
  ReloadProgress;
  if FActiveBausteinId > 0 then
    LoadRequirementsForBaustein(FActiveBausteinId);
  StatusBar.Panels[1].Text := Format('%d Baustein-Empfehlungen übernommen', [AppliedCount]);
end;

procedure TMainForm.tvTargetsContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
var
  Node: TTreeNode;
  HasTarget: Boolean;
begin
  if not HasActiveProject or not CanEditActiveProject then
  begin
    Handled := True;
    Exit;
  end;

  Node := tvTargets.GetNodeAt(MousePos.X, MousePos.Y);
  if Node <> nil then
  begin
    Node.Selected := True;
    tvTargets.SetFocus;
  end;

  HasTarget := FActiveTarget.Id > 0;
  mniTargetAdd.Visible := True;
  mniTargetAdd.Enabled := True;
  mniTargetEdit.Visible := HasTarget;
  mniTargetEdit.Enabled := HasTarget;
  mniTargetDelete.Visible := HasTarget;
  mniTargetDelete.Enabled := HasTarget;
  mniTargetSep.Visible := HasTarget;
  mniTargetRecommendations.Visible := HasTarget;
  mniTargetRecommendations.Enabled := HasTarget;
end;

procedure TMainForm.BausteinViewMenuClick(Sender: TObject);
begin
  DoViewBaustein(Sender);
end;

procedure TMainForm.ApplicabilityResetClick(Sender: TObject);
begin
  SetBausteinApplicability(apUndefined, FContextMenuBausteinId);
end;

procedure TMainForm.DoAddMeasure(Sender: TObject);
var
  M: TMeasure;
begin
  if FActiveRequirementId = 0 then
    Exit;
  FillChar(M, SizeOf(M), 0);
  M.ProjectId := FActiveProject.Id;
  M.TargetObjectId := FActiveTarget.Id;
  M.RequirementDbId := FActiveRequirementId;
  M.Status := msOpen;
  if not TMeasureForm.ExecuteCreate(M) then
    Exit;
  M := FContext.MeasureRepository.CreateMeasure(M);
  if M.Id = 0 then
  begin
    MessageDlg('Maßnahme konnte nicht erstellt werden: ' + FContext.MeasureRepository.LastError,
      mtError, [mbOK], 0);
    Exit;
  end;
  if FMeasureCounts.ContainsKey(FActiveRequirementId) then
    FMeasureCounts[FActiveRequirementId] := FMeasureCounts[FActiveRequirementId] + 1
  else
    FMeasureCounts.Add(FActiveRequirementId, 1);
  LoadMeasuresForCurrentRequirement;
  LoadRequirementsForBaustein(FActiveBausteinId);
  ReloadProgress;
end;

procedure TMainForm.DoEditMeasure(Sender: TObject);
var
  Row, I: Integer;
  MeasureId: Integer;
  M: TMeasure;
  SaveResult: TMeasureSaveResult;
begin
  Row := sgMeasures.Row;
  if Row < 1 then
    Exit;
  MeasureId := Integer(sgMeasures.Objects[0, Row]);
  FillChar(M, SizeOf(M), 0);
  for I := 0 to High(FCurrentMeasures) do
    if FCurrentMeasures[I].Id = MeasureId then
    begin
      M := FCurrentMeasures[I];
      Break;
    end;
  if M.Id = 0 then
    Exit;
  if CanEditActiveProject then
  begin
    if not TMeasureForm.ExecuteEdit(M) then
      Exit;
    SaveResult := FContext.MeasureRepository.UpdateMeasure(M);
    if SaveResult.Status = mssOk then
    begin
      LoadMeasuresForCurrentRequirement;
      ReloadProgress;
      Exit;
    end;
    if SaveResult.Status = mssVersionConflict then
    begin
      MessageDlg('Ein anderer Benutzer hat diese Maßnahme zwischenzeitlich geändert. ' +
        'Die Liste wurde neu geladen.', mtWarning, [mbOK], 0);
      LoadMeasuresForCurrentRequirement;
      ReloadProgress;
      Exit;
    end;
    MessageDlg('Speichern fehlgeschlagen: ' + FContext.MeasureRepository.LastError,
      mtError, [mbOK], 0);
  end
  else
    TMeasureForm.ExecuteView(M);
end;

procedure TMainForm.DoDeleteMeasure(Sender: TObject);
var
  Row: Integer;
  MeasureId: Integer;
begin
  Row := sgMeasures.Row;
  if Row < 1 then
    Exit;
  MeasureId := Integer(sgMeasures.Objects[0, Row]);
  if MessageDlg('Maßnahme wirklich löschen?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  if not FContext.MeasureRepository.DeleteMeasure(MeasureId) then
  begin
    MessageDlg('Löschen fehlgeschlagen: ' + FContext.MeasureRepository.LastError,
      mtError, [mbOK], 0);
    Exit;
  end;
  if FMeasureCounts.ContainsKey(FActiveRequirementId) then
    FMeasureCounts[FActiveRequirementId] := Max(0, FMeasureCounts[FActiveRequirementId] - 1);
  LoadMeasuresForCurrentRequirement;
  LoadRequirementsForBaustein(FActiveBausteinId);
  ReloadProgress;
end;

end.
