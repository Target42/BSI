unit ReportExporter;

interface

uses
  System.SysUtils, IsmsDomain;

type
  TReportExporter = class
  public
    class function ExportCsv(const AFilePath: string; const ARows: TArray<TReportRow>;
      out AErrorMessage: string): Boolean;
    class function ExportHtml(const AFilePath: string; const AProject: TProject;
      const ASummary: TReportSummary; const ARows: TArray<TReportRow>;
      out AErrorMessage: string): Boolean;
    class function ExportPdf(const AFilePath: string; const AProject: TProject;
      const ASummary: TReportSummary; const ARows: TArray<TReportRow>;
      out AErrorMessage: string): Boolean;
  end;

implementation

uses
  System.Classes, System.Math, System.DateUtils, System.IOUtils, Winapi.Windows, Winapi.WebView2,
  Vcl.Forms, Vcl.Edge;

function EscapeCsvField(const AValue: string): string;
begin
  Result := AValue;
  Result := StringReplace(Result, '"', '""', [rfReplaceAll]);
  if (Pos('"', Result) > 0) or (Pos(';', Result) > 0) or (Pos(#10, Result) > 0) then
    Result := '"' + Result + '"';
end;

function FormatReportDate(const ADate: TDateTime): string;
begin
  // Prüfen, ob das Datum "Null" bzw. nicht gesetzt ist
  if ADate <= 0 then
    Result := ''
  else
    Result := FormatDateTime('dd.mm.yyyy', ADate);
end;
function HtmlEscape(const AValue: string): string;
begin
  Result := AValue;
  Result := StringReplace(Result, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

class function TReportExporter.ExportCsv(const AFilePath: string; const ARows: TArray<TReportRow>;
  out AErrorMessage: string): Boolean;
var
  SL: TStringList;
  Row: TReportRow;
  OverdueText : string;
begin
  Result := False;
  SL := TStringList.Create;
  try
    SL.Add(#$EF#$BB#$BF + 'Zielobjekt;Baustein;Baustein-Titel;Anforderung;Titel;Stufe;' +
      'Anwendbarkeit;Status;Verantwortlich;Frist;Maßnahmen;Überfällig');
    for Row in ARows do
    begin
      if Row.Overdue then
        OverdueText := 'Ja'
      else
        OverdueText := 'Nein';
      SL.Add(
        EscapeCsvField(Row.TargetObjectName) + ';' +
        EscapeCsvField(Row.BausteinExternalId) + ';' +
        EscapeCsvField(Row.BausteinTitle) + ';' +
        EscapeCsvField(Row.RequirementExternalId) + ';' +
        EscapeCsvField(Row.RequirementTitle) + ';' +
        EscapeCsvField(Row.Level) + ';' +
        EscapeCsvField(ApplicabilityStatusToString(Row.Applicability)) + ';' +
        EscapeCsvField(AssessmentStatusToString(Row.Status)) + ';' +
        EscapeCsvField(Row.Responsible) + ';' +
        EscapeCsvField(FormatReportDate(Row.DueDate)) + ';' +
        IntToStr(Row.MeasureCount) + ';' +
        OverdueText)
    end;
    try
      SL.SaveToFile(AFilePath, TEncoding.UTF8);
      Result := True;
    except
      on E: Exception do
        AErrorMessage := E.Message;
    end;
  finally
    SL.Free;
  end;
end;

function BuildReportHtml(const AProject: TProject; const ASummary: TReportSummary;
  const ARows: TArray<TReportRow>): string;
var
  SL: TStringList;
  Row: TReportRow;
  RowClass: string;
begin
  SL := TStringList.Create;
  try
    SL.Add('<html><head><meta charset="utf-8"><style>');
    SL.Add('body{font-family:Arial,sans-serif;font-size:10pt;}');
    SL.Add('h1{font-size:16pt;} table{border-collapse:collapse;width:100%;}');
    SL.Add('th,td{border:1px solid #888;padding:4px;text-align:left;}');
    SL.Add('th{background:#eee;} .overdue{color:red;}');
    SL.Add('</style></head><body>');
    SL.Add('<h1>Soll-Ist-Bericht</h1>');
    SL.Add(Format('<p><b>Projekt:</b> %s<br><b>Erstellt:</b> %s</p>',
      [HtmlEscape(AProject.Name), HtmlEscape(FormatDateTime('dd.mm.yyyy hh:nn', Now))]));
    SL.Add(Format('<p>Anforderungen gesamt: %d &nbsp;|&nbsp; Offen: %d &nbsp;|&nbsp; ' +
      'Teilweise: %d &nbsp;|&nbsp; Erfüllt: %d &nbsp;|&nbsp; Entfällt: %d &nbsp;|&nbsp; ' +
      'Überfällig: %d &nbsp;|&nbsp; Maßnahmen: %d</p>',
      [ASummary.TotalRequirements, ASummary.OpenCount, ASummary.PartialCount,
       ASummary.FulfilledCount, ASummary.NotApplicableCount, ASummary.OverdueCount,
       ASummary.MeasureCount]));
    SL.Add('<table><thead><tr>');
    SL.Add('<th>Zielobjekt</th><th>Baustein</th><th>Anforderung</th>');
    SL.Add('<th>Stufe</th><th>Status</th><th>Verantwortlich</th>');
    SL.Add('<th>Frist</th><th>Maßn.</th></tr></thead><tbody>');
    for Row in ARows do
    begin
      if Row.Overdue then
        RowClass := ' class="overdue"'
      else
        RowClass := '';
      SL.Add('<tr' + RowClass + '>');
      SL.Add('<td>' + HtmlEscape(Row.TargetObjectName) + '</td>');
      SL.Add('<td>' + HtmlEscape(Row.BausteinExternalId) + '</td>');
      SL.Add(Format('<td>%s - %s</td>',
        [HtmlEscape(Row.RequirementExternalId), HtmlEscape(Row.RequirementTitle)]));
      SL.Add('<td>' + HtmlEscape(Row.Level) + '</td>');
      SL.Add('<td>' + HtmlEscape(AssessmentStatusToString(Row.Status)) + '</td>');
      SL.Add('<td>' + HtmlEscape(Row.Responsible) + '</td>');
      SL.Add('<td>' + HtmlEscape(FormatReportDate(Row.DueDate)) + '</td>');
      SL.Add('<td>' + IntToStr(Row.MeasureCount) + '</td>');
      SL.Add('</tr>');
    end;
    SL.Add('</tbody></table></body></html>');
    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

type
  THtmlToPdfExporter = class
  private
    FForm: TForm;
    FBrowser: TEdgeBrowser;
    FHtmlContent: string;
    FPdfPath: string;
    FErrorMessage: string;
    FCompleted: Boolean;
    FSuccess: Boolean;
    procedure OnCreateWebViewCompleted(Sender: TCustomEdgeBrowser; AResult: HResult);
    procedure OnNavigationCompleted(Sender: TCustomEdgeBrowser; IsSuccess: Boolean;
      WebErrorStatus: COREWEBVIEW2_WEB_ERROR_STATUS);
    procedure OnPrintToPDFCompleted(Sender: TCustomEdgeBrowser; ErrorCode: HResult;
      IsSuccessful: Boolean);
    procedure Fail(const AMessage: string);
  public
    function Export(const AHtmlContent, APdfPath: string; out AErrorMessage: string): Boolean;
  end;

procedure THtmlToPdfExporter.Fail(const AMessage: string);
begin
  FErrorMessage := AMessage;
  FSuccess := False;
  FCompleted := True;
end;

procedure THtmlToPdfExporter.OnCreateWebViewCompleted(Sender: TCustomEdgeBrowser;
  AResult: HResult);
begin
  if not Succeeded(AResult) then
  begin
    Fail('WebView2 konnte nicht initialisiert werden.');
    Exit;
  end;
  if not FBrowser.NavigateToString(FHtmlContent) then
    Fail('HTML konnte nicht geladen werden.');
end;

procedure THtmlToPdfExporter.OnNavigationCompleted(Sender: TCustomEdgeBrowser;
  IsSuccess: Boolean; WebErrorStatus: COREWEBVIEW2_WEB_ERROR_STATUS);
var
  PrintSettings: ICoreWebView2PrintSettings;
begin
  if not IsSuccess then
  begin
    Fail('HTML konnte nicht geladen werden.');
    Exit;
  end;

  PrintSettings := FBrowser.CreatePrintSettings;
  if PrintSettings = nil then
  begin
    Fail('Druckeinstellungen konnten nicht erstellt werden.');
    Exit;
  end;

  PrintSettings.Set_Orientation(COREWEBVIEW2_PRINT_ORIENTATION_LANDSCAPE);
  PrintSettings.Set_ShouldPrintHeaderAndFooter(0);

  if not FBrowser.PrintToPDF(FPdfPath, PrintSettings) then
    Fail('PDF-Druck konnte nicht gestartet werden.');
end;

procedure THtmlToPdfExporter.OnPrintToPDFCompleted(Sender: TCustomEdgeBrowser;
  ErrorCode: HResult; IsSuccessful: Boolean);
begin
  if IsSuccessful then
    FSuccess := True
  else
    FErrorMessage := Format('PDF-Export fehlgeschlagen (0x%.8x).', [ErrorCode]);
  FCompleted := True;
end;

function THtmlToPdfExporter.Export(const AHtmlContent, APdfPath: string;
  out AErrorMessage: string): Boolean;
const
  TimeoutMs = 60000;
var
  Deadline: Cardinal;
begin
  Result := False;
  AErrorMessage := '';
  FHtmlContent := AHtmlContent;
  FPdfPath := APdfPath;
  FErrorMessage := '';
  FCompleted := False;
  FSuccess := False;

  FForm := TForm.Create(nil);
  try
    FForm.Visible := False;
    FBrowser := TEdgeBrowser.Create(FForm);
    FBrowser.Parent := FForm;
    FBrowser.Width := 1024;
    FBrowser.Height := 768;
    FBrowser.OnCreateWebViewCompleted := OnCreateWebViewCompleted;
    FBrowser.OnNavigationCompleted := OnNavigationCompleted;
    FBrowser.OnPrintToPDFCompleted := OnPrintToPDFCompleted;
    FBrowser.CreateWebView;

    Deadline := GetTickCount + TimeoutMs;
    while not FCompleted do
    begin
      Application.ProcessMessages;
      if GetTickCount > Deadline then
      begin
        AErrorMessage := 'PDF-Export: Zeitüberschreitung.';
        Exit;
      end;
    end;

    Result := FSuccess;
    if not Result then
      AErrorMessage := FErrorMessage;
  finally
    FBrowser.Free;
    FForm.Free;
  end;
end;

class function TReportExporter.ExportHtml(const AFilePath: string; const AProject: TProject;
  const ASummary: TReportSummary; const ARows: TArray<TReportRow>;
  out AErrorMessage: string): Boolean;
var
  HtmlContent: string;
begin
  Result := False;
  HtmlContent := BuildReportHtml(AProject, ASummary, ARows);
  try
    TFile.WriteAllText(AFilePath, HtmlContent, TEncoding.UTF8);
    Result := True;
  except
    on E: Exception do
      AErrorMessage := E.Message;
  end;
end;

class function TReportExporter.ExportPdf(const AFilePath: string; const AProject: TProject;
  const ASummary: TReportSummary; const ARows: TArray<TReportRow>;
  out AErrorMessage: string): Boolean;
var
  Exporter: THtmlToPdfExporter;
  HtmlContent: string;
begin
  HtmlContent := BuildReportHtml(AProject, ASummary, ARows);
  Exporter := THtmlToPdfExporter.Create;
  try
    Result := Exporter.Export(HtmlContent, AFilePath, AErrorMessage);
  finally
    Exporter.Free;
  end;
end;

end.
