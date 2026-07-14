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
  end;

implementation

uses
  System.Classes, System.Math, System.DateUtils;

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

class function TReportExporter.ExportHtml(const AFilePath: string; const AProject: TProject;
  const ASummary: TReportSummary; const ARows: TArray<TReportRow>;
  out AErrorMessage: string): Boolean;
var
  SL: TStringList;
  Row: TReportRow;
  RowClass: string;
begin
  Result := False;
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
    SL.Add(Format('<p>Anforderungen gesamt: %d | Offen: %d | Teilweise: %d | Erfüllt: %d | ' +
      'Entfällt: %d | Überfällig: %d | Maßnahmen: %d</p>',
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
      SL.Add(Format('<td>%s – %s</td>',
        [HtmlEscape(Row.RequirementExternalId), HtmlEscape(Row.RequirementTitle)]));
      SL.Add('<td>' + HtmlEscape(Row.Level) + '</td>');
      SL.Add('<td>' + HtmlEscape(AssessmentStatusToString(Row.Status)) + '</td>');
      SL.Add('<td>' + HtmlEscape(Row.Responsible) + '</td>');
      SL.Add('<td>' + HtmlEscape(FormatReportDate(Row.DueDate)) + '</td>');
      SL.Add('<td>' + IntToStr(Row.MeasureCount) + '</td>');
      SL.Add('</tr>');
    end;
    SL.Add('</tbody></table></body></html>');
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

end.
