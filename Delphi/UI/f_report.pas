unit f_report;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Grids, Vcl.ExtCtrls,
  IsmsDomain, AppContext, ReportService, ReportExporter;

type
  TReportForm = class(TForm)
    pnlTop: TPanel;
    lblScope: TLabel;
    cboScope: TComboBox;
    btnRefresh: TButton;
    lblSummary: TLabel;
    sgReport: TStringGrid;
    pnlBottom: TPanel;
    btnExportCsv: TButton;
    btnExportPdf: TButton;
    btnClose: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnRefreshClick(Sender: TObject);
    procedure cboScopeChange(Sender: TObject);
    procedure btnExportCsvClick(Sender: TObject);
    procedure btnExportPdfClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
  private
    FContext: TAppContext;
    FProject: TProject;
    FTargetObject: TTargetObject;
    FRows: TArray<TReportRow>;
    FSummary: TReportSummary;
    FReportService: TReportService;
    procedure RefreshReport;
    procedure UpdateSummary;
    procedure FillGrid;
    function SelectedTargetObjectId: Integer;
  public
    constructor Create(AOwner: TComponent; AContext: TAppContext;
      const AProject: TProject; const ATargetObject: TTargetObject); reintroduce;
    destructor Destroy; override;
  end;

implementation

{$R *.dfm}

constructor TReportForm.Create(AOwner: TComponent; AContext: TAppContext;
  const AProject: TProject; const ATargetObject: TTargetObject);
begin
  FContext := AContext;
  FProject := AProject;
  FTargetObject := ATargetObject;
  inherited Create(AOwner);
end;

destructor TReportForm.Destroy;
begin
  FReportService.Free;
  inherited;
end;

procedure TReportForm.FormCreate(Sender: TObject);
begin
  Caption := 'Soll-Ist-Bericht';
  Width := 1100;
  Height := 650;
  Position := poScreenCenter;

  FReportService := TReportService.Create(
    FContext.CatalogRepository,
    FContext.ProjectRepository,
    FContext.TargetObjectRepository,
    FContext.MeasureRepository);

  cboScope.Items.AddObject('Gesamtes Projekt', TObject(0));
  if FTargetObject.Id <> 0 then
  begin
    cboScope.Items.AddObject('Aktuelles Zielobjekt: ' + FTargetObject.Name,
      TObject(FTargetObject.Id));
    cboScope.ItemIndex := 1;
  end
  else
    cboScope.ItemIndex := 0;

  sgReport.ColCount := 9;
  sgReport.RowCount := 2;
  sgReport.FixedRows := 1;
  sgReport.Options := sgReport.Options + [goRowSelect];
  sgReport.Cells[0, 0] := 'Zielobjekt';
  sgReport.Cells[1, 0] := 'Baustein';
  sgReport.Cells[2, 0] := 'Anforderung';
  sgReport.Cells[3, 0] := 'Titel';
  sgReport.Cells[4, 0] := 'Stufe';
  sgReport.Cells[5, 0] := 'Status';
  sgReport.Cells[6, 0] := 'Verantwortlicher';
  sgReport.Cells[7, 0] := 'Frist';
  sgReport.Cells[8, 0] := 'Maßnahmen';
  sgReport.ColWidths[0] := 120;
  sgReport.ColWidths[1] := 80;
  sgReport.ColWidths[2] := 90;
  sgReport.ColWidths[3] := 220;
  sgReport.ColWidths[4] := 70;
  sgReport.ColWidths[5] := 80;
  sgReport.ColWidths[6] := 120;
  sgReport.ColWidths[7] := 80;
  sgReport.ColWidths[8] := 70;

  RefreshReport;
end;

function TReportForm.SelectedTargetObjectId: Integer;
begin
  if cboScope.ItemIndex < 0 then
    Exit(0);
  Result := Integer(cboScope.Items.Objects[cboScope.ItemIndex]);
end;

procedure TReportForm.RefreshReport;
begin
  FRows := FReportService.BuildSollIstReport(
    FProject.Id, SelectedTargetObjectId, FContext.CatalogVersion);
  FSummary := FReportService.Summarize(FRows);
  FillGrid;
  UpdateSummary;
end;

procedure TReportForm.UpdateSummary;
begin
  lblSummary.Caption := TReportService.FormatSummaryText(FSummary);
end;

procedure TReportForm.FillGrid;
var
  Row: TReportRow;
  GridRow: Integer;
begin
  sgReport.RowCount := 1;
  GridRow := 1;
  for Row in FRows do
  begin
    Inc(GridRow);
    sgReport.RowCount := GridRow + 1;
    sgReport.Cells[0, GridRow] := Row.TargetObjectName;
    sgReport.Cells[1, GridRow] := Row.BausteinExternalId;
    sgReport.Cells[2, GridRow] := Row.RequirementExternalId;
    sgReport.Cells[3, GridRow] := Row.RequirementTitle;
    sgReport.Cells[4, GridRow] := Row.Level;
    sgReport.Cells[5, GridRow] := AssessmentStatusToString(Row.Status);
    sgReport.Cells[6, GridRow] := Row.Responsible;
    if IsValidDate(Row.DueDate) then
      sgReport.Cells[7, GridRow] := FormatDateTime('dd.mm.yyyy', Row.DueDate)
    else
      sgReport.Cells[7, GridRow] := '';
    sgReport.Cells[8, GridRow] := IntToStr(Row.MeasureCount);
  end;
end;

procedure TReportForm.btnRefreshClick(Sender: TObject);
begin
  RefreshReport;
end;

procedure TReportForm.cboScopeChange(Sender: TObject);
begin
  RefreshReport;
end;

procedure TReportForm.btnExportCsvClick(Sender: TObject);
var
  Dlg: TSaveDialog;
  ErrorMsg: string;
begin
  if Length(FRows) = 0 then
  begin
    MessageDlg('Keine Daten für den Export vorhanden.', mtInformation, [mbOK], 0);
    Exit;
  end;
  Dlg := TSaveDialog.Create(Self);
  try
    Dlg.Filter := 'CSV-Dateien (*.csv)|*.csv';
    Dlg.FileName := 'soll-ist-' + FProject.Name + '.csv';
    if not Dlg.Execute then
      Exit;
    if TReportExporter.ExportCsv(Dlg.FileName, FRows, ErrorMsg) then
      MessageDlg('CSV wurde gespeichert:' + sLineBreak + Dlg.FileName, mtInformation, [mbOK], 0)
    else
      MessageDlg('Export fehlgeschlagen: ' + ErrorMsg, mtError, [mbOK], 0);
  finally
    Dlg.Free;
  end;
end;

procedure TReportForm.btnExportPdfClick(Sender: TObject);
var
  Dlg: TSaveDialog;
  ErrorMsg: string;
begin
  if Length(FRows) = 0 then
  begin
    MessageDlg('Keine Daten für den Export vorhanden.', mtInformation, [mbOK], 0);
    Exit;
  end;
  Dlg := TSaveDialog.Create(Self);
  try
    Dlg.Filter := 'PDF-Dateien (*.pdf)|*.pdf';
    Dlg.FileName := 'soll-ist-' + FProject.Name + '.pdf';
    if not Dlg.Execute then
      Exit;
    if TReportExporter.ExportPdf(Dlg.FileName, FProject, FSummary, FRows, ErrorMsg) then
      MessageDlg('PDF wurde gespeichert:' + sLineBreak + Dlg.FileName, mtInformation, [mbOK], 0)
    else
      MessageDlg('Export fehlgeschlagen: ' + ErrorMsg, mtError, [mbOK], 0);
  finally
    Dlg.Free;
  end;
end;

procedure TReportForm.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
