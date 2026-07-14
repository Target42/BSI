unit f_catalogsearch;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.Generics.Collections, System.Math, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.Grids, Vcl.ComCtrls, Vcl.ExtCtrls, IsmsDomain, AppContext,
  RequirementTextFormatter, f_bausteinview;

type
  TSearchHit = record
    BausteinDbId: Integer;
    RequirementId: Integer;
    GroupName: string;
    BausteinLabel: string;
    RequirementLabel: string;
    MatchField: string;
    Snippet: string;
    PreviewText: string;
  end;

  TCatalogSearchForm = class(TForm)
    lblHint: TLabel;
    edtSearch: TEdit;
    sgResults: TStringGrid;
    rePreview: TRichEdit;
    btnOpenBaustein: TButton;
    btnClose: TButton;
    procedure FormCreate(Sender: TObject);
    procedure edtSearchChange(Sender: TObject);
    procedure sgResultsSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
    procedure sgResultsDblClick(Sender: TObject);
    procedure btnOpenBausteinClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
  private
    FContext: TAppContext;
    FBausteine: TArray<TBaustein>;
    FRequirements: TArray<TRequirement>;
    FBausteinById: TDictionary<Integer, TBaustein>;
    FHits: TArray<TSearchHit>;
    procedure SetupGrid;
    procedure RunSearch;
    procedure ShowHitAt(ARow: Integer);
    procedure OpenSelectedHit;
  public
    destructor Destroy; override;
    class procedure Execute(AOwner: TComponent; AContext: TAppContext;
      const ABausteine: TArray<TBaustein>; const ARequirements: TArray<TRequirement>;
      const AInitialQuery: string = '');
  end;

implementation

{$R *.dfm}

class procedure TCatalogSearchForm.Execute(AOwner: TComponent; AContext: TAppContext;
  const ABausteine: TArray<TBaustein>; const ARequirements: TArray<TRequirement>;
  const AInitialQuery: string);
var
  Form: TCatalogSearchForm;
begin
  Form := TCatalogSearchForm.Create(AOwner);
  try
    Form.FContext := AContext;
    Form.FBausteine := ABausteine;
    Form.FRequirements := ARequirements;
    Form.edtSearch.Text := AInitialQuery;
    Form.RunSearch;
    Form.ShowModal;
  finally
    Form.Free;
  end;
end;

procedure TCatalogSearchForm.FormCreate(Sender: TObject);
begin
  FBausteinById := TDictionary<Integer, TBaustein>.Create;
  SetupGrid;
end;

destructor TCatalogSearchForm.Destroy;
begin
  FBausteinById.Free;
  inherited;
end;

procedure TCatalogSearchForm.SetupGrid;
begin
  sgResults.FixedRows := 1;
  sgResults.Cells[0, 0] := 'Kapitel';
  sgResults.Cells[1, 0] := 'Baustein';
  sgResults.Cells[2, 0] := 'Anforderung';
  sgResults.Cells[3, 0] := 'Fundstelle';
  sgResults.Cells[4, 0] := 'Auszug';
  sgResults.ColWidths[0] := 140;
  sgResults.ColWidths[1] := 220;
  sgResults.ColWidths[2] := 220;
  sgResults.ColWidths[3] := 120;
  sgResults.ColWidths[4] := 360;
end;

function ContainsNeedle(const AHaystack, ANeedle: string): Boolean;
begin
  Result := Pos(LowerCase(ANeedle), LowerCase(AHaystack)) > 0;
end;

function MatchSnippet(const AText, ANeedle: string): string;
var
  MatchIndex, StartPos, EndPos: Integer;
begin
  if AText = '' then
    Exit('');
  MatchIndex := Pos(LowerCase(ANeedle), LowerCase(AText));
  if MatchIndex <= 0 then
  begin
    Result := Copy(AText, 1, 90);
    if Length(AText) > 90 then
      Result := Result + '…';
    Exit;
  end;
  StartPos := Max(1, MatchIndex - 45);
  EndPos := Min(Length(AText), MatchIndex + Length(ANeedle) + 45);
  Result := StringReplace(Copy(AText, StartPos, EndPos - StartPos + 1), sLineBreak, ' ', [rfReplaceAll]);
  Result := Trim(Result);
  if StartPos > 1 then
    Result := '…' + Result;
  if EndPos < Length(AText) then
    Result := Result + '…';
end;

procedure TCatalogSearchForm.RunSearch;
var
  Needle: string;
  R: TRequirement;
  B: TBaustein;
  Hit: TSearchHit;
  BausteineWithRequirementHits: TDictionary<Integer, Byte>;
  Row: Integer;
begin
  FBausteinById.Clear;
  for B in FBausteine do
    FBausteinById.AddOrSetValue(B.Id, B);

  Needle := Trim(edtSearch.Text);
  SetLength(FHits, 0);
  if Needle = '' then
  begin
    sgResults.RowCount := 1;
    rePreview.Clear;
    Exit;
  end;

  BausteineWithRequirementHits := TDictionary<Integer, Byte>.Create;
  try
    for R in FRequirements do
    begin
      FillChar(Hit, SizeOf(Hit), 0);
      if ContainsNeedle(R.Text, Needle) then
      begin
        Hit.MatchField := 'Anforderungstext';
        Hit.PreviewText := R.Text;
      end
      else if ContainsNeedle(R.Title, Needle) then
      begin
        Hit.MatchField := 'Anforderungstitel';
        Hit.PreviewText := R.Title;
      end
      else if ContainsNeedle(R.ExternalId, Needle) then
      begin
        Hit.MatchField := 'Anforderungs-ID';
        Hit.PreviewText := R.ExternalId;
      end
      else if ContainsNeedle(R.ResponsibleRole, Needle) then
      begin
        Hit.MatchField := 'Rolle';
        Hit.PreviewText := R.ResponsibleRole;
      end
      else
        Continue;

      BausteineWithRequirementHits.AddOrSetValue(R.BausteinDbId, 1);
      if not FBausteinById.TryGetValue(R.BausteinDbId, B) then
        Continue;
      Hit.BausteinDbId := R.BausteinDbId;
      Hit.RequirementId := R.Id;
      Hit.GroupName := B.GroupName;
      Hit.BausteinLabel := B.ExternalId + ' ' + B.Title;
      Hit.RequirementLabel := R.ExternalId + ' ' + R.Title;
      Hit.Snippet := MatchSnippet(Hit.PreviewText, Needle);
      SetLength(FHits, Length(FHits) + 1);
      FHits[High(FHits)] := Hit;
    end;

    for B in FBausteine do
    begin
      if BausteineWithRequirementHits.ContainsKey(B.Id) then
        Continue;
      FillChar(Hit, SizeOf(Hit), 0);
      if ContainsNeedle(B.ExternalId, Needle) then
      begin
        Hit.MatchField := 'Baustein-ID';
        Hit.PreviewText := B.ExternalId;
      end
      else if ContainsNeedle(B.Title, Needle) then
      begin
        Hit.MatchField := 'Baustein-Titel';
        Hit.PreviewText := B.Title;
      end
      else if ContainsNeedle(B.GroupName, Needle) then
      begin
        Hit.MatchField := 'Kapitel';
        Hit.PreviewText := B.GroupName;
      end
      else
        Continue;

      Hit.BausteinDbId := B.Id;
      Hit.GroupName := B.GroupName;
      Hit.BausteinLabel := B.ExternalId + ' ' + B.Title;
      Hit.RequirementLabel := '—';
      Hit.Snippet := MatchSnippet(Hit.PreviewText, Needle);
      SetLength(FHits, Length(FHits) + 1);
      FHits[High(FHits)] := Hit;
    end;
  finally
    BausteineWithRequirementHits.Free;
  end;

  sgResults.RowCount := 1;
  Row := 1;
  for Hit in FHits do
  begin
    Inc(Row);
    sgResults.RowCount := Row + 1;
    sgResults.Cells[0, Row] := Hit.GroupName;
    sgResults.Cells[1, Row] := Hit.BausteinLabel;
    sgResults.Cells[2, Row] := Hit.RequirementLabel;
    sgResults.Cells[3, Row] := Hit.MatchField;
    sgResults.Cells[4, Row] := Hit.Snippet;
  end;

  if sgResults.RowCount > 1 then
  begin
    sgResults.Row := 1;
    ShowHitAt(1);
  end
  else
  begin
    rePreview.Text := 'Keine Treffer für "' + Needle + '".';
  end;
end;

procedure TCatalogSearchForm.ShowHitAt(ARow: Integer);
var
  Hit: TSearchHit;
  Header: string;
begin
  if (ARow < 1) or (ARow > Length(FHits)) then
  begin
    rePreview.Clear;
    Exit;
  end;
  Hit := FHits[ARow - 1];
  Header := 'Baustein: ' + Hit.BausteinLabel + sLineBreak +
    'Kapitel: ' + Hit.GroupName + sLineBreak +
    'Fundstelle: ' + Hit.MatchField + sLineBreak + sLineBreak;
  if Hit.RequirementId > 0 then
  begin
    Header := Header + 'Anforderung: ' + Hit.RequirementLabel + sLineBreak + sLineBreak;
    rePreview.Text := Header + Hit.PreviewText;
    TRequirementTextFormatter.ApplyToRichEdit(rePreview, rePreview.Text);
    rePreview.SelStart := 0;
    rePreview.SelLength := Length(Header);
    rePreview.SelAttributes.Style := [fsBold];
  end
  else
  begin
    rePreview.Text := Header +
      'Treffer im Baustein selbst. „Baustein öffnen…“ zeigt alle Anforderungen.';
  end;
end;

procedure TCatalogSearchForm.edtSearchChange(Sender: TObject);
begin
  RunSearch;
end;

procedure TCatalogSearchForm.sgResultsSelectCell(Sender: TObject; ACol, ARow: Integer;
  var CanSelect: Boolean);
begin
  if ARow >= 1 then
    ShowHitAt(ARow);
  CanSelect := True;
end;

procedure TCatalogSearchForm.OpenSelectedHit;
var
  Row: Integer;
  Hit: TSearchHit;
  B: TBaustein;
  Requirements: TArray<TRequirement>;
  R: TRequirement;
  List: TList<TRequirement>;
begin
  Row := sgResults.Row;
  if (Row < 1) or (Row > Length(FHits)) then
    Exit;
  Hit := FHits[Row - 1];
  if not FBausteinById.TryGetValue(Hit.BausteinDbId, B) then
    Exit;

  List := TList<TRequirement>.Create;
  try
    for R in FRequirements do
      if R.BausteinDbId = B.Id then
        List.Add(R);
    Requirements := List.ToArray;
  finally
    List.Free;
  end;
  TBausteinViewForm.Execute(Self, B, Requirements, Trim(edtSearch.Text), Hit.RequirementId);
end;

procedure TCatalogSearchForm.sgResultsDblClick(Sender: TObject);
begin
  OpenSelectedHit;
end;

procedure TCatalogSearchForm.btnOpenBausteinClick(Sender: TObject);
begin
  OpenSelectedHit;
end;

procedure TCatalogSearchForm.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
