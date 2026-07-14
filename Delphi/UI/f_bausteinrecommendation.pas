unit f_bausteinrecommendation;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.Generics.Collections, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.Grids, IsmsDomain, BausteinRecommendationService;

type
  TBausteinRecommendationForm = class(TForm)
    lblHint: TLabel;
    sgRecommendations: TStringGrid;
    lblStatus: TLabel;
    cboStatus: TComboBox;
    btnOk: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure sgRecommendationsDblClick(Sender: TObject);
    procedure btnOkClick(Sender: TObject);
  private
    FSelections: TArray<TBausteinRecommendationSelection>;
    procedure SetupGrid;
    procedure Populate(const ARecommendations: TArray<TBausteinRecommendation>;
      const ACurrentApplicability: TDictionary<Integer, TApplicabilityStatus>;
      const ATargetObject: TTargetObject);
    procedure CollectSelections;
    function ToggleSelected(ARow: Integer): Boolean;
  public
    class function Execute(const ARecommendations: TArray<TBausteinRecommendation>;
      const ACurrentApplicability: TDictionary<Integer, TApplicabilityStatus>;
      const ATargetObject: TTargetObject;
      out ASelections: TArray<TBausteinRecommendationSelection>): Boolean;
  end;

implementation

{$R *.dfm}

class function TBausteinRecommendationForm.Execute(
  const ARecommendations: TArray<TBausteinRecommendation>;
  const ACurrentApplicability: TDictionary<Integer, TApplicabilityStatus>;
  const ATargetObject: TTargetObject;
  out ASelections: TArray<TBausteinRecommendationSelection>): Boolean;
var
  Form: TBausteinRecommendationForm;
begin
  Form := TBausteinRecommendationForm.Create(nil);
  try
    Form.Populate(ARecommendations, ACurrentApplicability, ATargetObject);
    Result := Form.ShowModal = mrOk;
    if Result then
      ASelections := Form.FSelections;
  finally
    Form.Free;
  end;
end;

procedure TBausteinRecommendationForm.FormCreate(Sender: TObject);
begin
  SetupGrid;
  cboStatus.Items.Add(ApplicabilityStatusToString(apPossible));
  cboStatus.Items.Add(ApplicabilityStatusToString(apRequired));
  cboStatus.ItemIndex := 1;
end;

procedure TBausteinRecommendationForm.SetupGrid;
begin
  sgRecommendations.FixedRows := 1;
  sgRecommendations.Cells[0, 0] := 'Übernehmen';
  sgRecommendations.Cells[1, 0] := 'Baustein';
  sgRecommendations.Cells[2, 0] := 'Empfehlung';
  sgRecommendations.Cells[3, 0] := 'Begründung';
  sgRecommendations.Cells[4, 0] := 'Aktuell';
  sgRecommendations.ColWidths[0] := 80;
  sgRecommendations.ColWidths[1] := 220;
  sgRecommendations.ColWidths[2] := 90;
  sgRecommendations.ColWidths[3] := 320;
  sgRecommendations.ColWidths[4] := 100;
end;

procedure TBausteinRecommendationForm.Populate(
  const ARecommendations: TArray<TBausteinRecommendation>;
  const ACurrentApplicability: TDictionary<Integer, TApplicabilityStatus>;
  const ATargetObject: TTargetObject);
var
  Rec: TBausteinRecommendation;
  CurrentStatus: TApplicabilityStatus;
  Row: Integer;
  Checked: Boolean;
  Enabled: Boolean;
begin
  lblHint.Caption :=
    Format('Zielobjekt "%s" (%s, %s)' + sLineBreak + sLineBreak + '%s',
      [ATargetObject.Name,
       TargetObjectTypeToString(ATargetObject.ObjType),
       ProtectionNeedToString(ATargetObject.ProtectionNeed),
       TBausteinRecommendationService.RecommendationHint(ATargetObject)]);

  sgRecommendations.RowCount := 1;
  Row := 1;
  for Rec in ARecommendations do
  begin
    if not ACurrentApplicability.TryGetValue(Rec.BausteinDbId, CurrentStatus) then
      CurrentStatus := apUndefined;

    if CurrentStatus = apUndefined then
    begin
      Checked := Rec.Tier = brtCore;
      Enabled := True;
    end
    else
    begin
      Checked := False;
      Enabled := False;
    end;

    Inc(Row);
    sgRecommendations.RowCount := Row + 1;
    if Checked then
      sgRecommendations.Cells[0, Row] := '[X]'
    else
      sgRecommendations.Cells[0, Row] := '[ ]';
    sgRecommendations.Cells[1, Row] := Rec.ExternalId + ' ' + Rec.Title;
    sgRecommendations.Cells[2, Row] := BausteinRecommendationTierToString(Rec.Tier);
    sgRecommendations.Cells[3, Row] := Rec.Reason;
    sgRecommendations.Cells[4, Row] := ApplicabilityStatusToString(CurrentStatus);
    sgRecommendations.Objects[0, Row] := TObject(Rec.BausteinDbId);
    if Enabled then
      sgRecommendations.Objects[1, Row] := TObject(1)
    else
      sgRecommendations.Objects[1, Row] := nil;
  end;
end;

function TBausteinRecommendationForm.ToggleSelected(ARow: Integer): Boolean;
begin
  Result := False;
  if (ARow < 1) or (sgRecommendations.Objects[1, ARow] = nil) then
    Exit;
  if sgRecommendations.Cells[0, ARow] = '[X]' then
    sgRecommendations.Cells[0, ARow] := '[ ]'
  else
    sgRecommendations.Cells[0, ARow] := '[X]';
  Result := True;
end;

procedure TBausteinRecommendationForm.sgRecommendationsDblClick(Sender: TObject);
begin
  ToggleSelected(sgRecommendations.Row);
end;

function SelectedStatusFromCombo(AIndex: Integer): TApplicabilityStatus;
begin
  if AIndex = 0 then
    Exit(apPossible);
  Result := apRequired;
end;

procedure TBausteinRecommendationForm.CollectSelections;
var
  Row: Integer;
  Selection: TBausteinRecommendationSelection;
  List: TList<TBausteinRecommendationSelection>;
  DefaultStatus: TApplicabilityStatus;
begin
  List := TList<TBausteinRecommendationSelection>.Create;
  try
    DefaultStatus := SelectedStatusFromCombo(cboStatus.ItemIndex);
    for Row := 1 to sgRecommendations.RowCount - 1 do
    begin
      if (sgRecommendations.Objects[1, Row] <> nil) and (sgRecommendations.Cells[0, Row] = '[X]') then
      begin
        Selection.BausteinDbId := Integer(sgRecommendations.Objects[0, Row]);
        Selection.Status := DefaultStatus;
        List.Add(Selection);
      end;
    end;
    FSelections := List.ToArray;
  finally
    List.Free;
  end;
end;

procedure TBausteinRecommendationForm.btnOkClick(Sender: TObject);
begin
  CollectSelections;
  ModalResult := mrOk;
end;

end.
