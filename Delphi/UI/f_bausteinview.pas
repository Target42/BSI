unit f_bausteinview;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Grids, Vcl.ComCtrls,
  IsmsDomain, RequirementTextFormatter, SearchEditHelper;

type
  TBausteinViewForm = class(TForm)
    lblHeader: TLabel;
    edtSearch: TEdit;
    sgRequirements: TStringGrid;
    reRequirementText: TRichEdit;
    btnClose: TButton;
    procedure FormCreate(Sender: TObject);
    procedure edtSearchChange(Sender: TObject);
    procedure sgRequirementsSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
    procedure btnCloseClick(Sender: TObject);
  private
    FBaustein: TBaustein;
    FRequirements: TArray<TRequirement>;
    FVisibleRows: TArray<Integer>;
    FClearSearch: TSearchClearButton;
    procedure SetupGrid;
    procedure ApplySearch;
    procedure ShowRequirementAt(ARow: Integer);
  public
    class procedure Execute(AOwner: TComponent; const ABaustein: TBaustein;
      const ARequirements: TArray<TRequirement>; const AInitialSearch: string = '';
      AInitialRequirementId: Integer = 0);
  end;

implementation

{$R *.dfm}

class procedure TBausteinViewForm.Execute(AOwner: TComponent; const ABaustein: TBaustein;
  const ARequirements: TArray<TRequirement>; const AInitialSearch: string;
  AInitialRequirementId: Integer);
var
  Form: TBausteinViewForm;
  I, Row: Integer;
begin
  Form := TBausteinViewForm.Create(AOwner);
  try
    Form.FBaustein := ABaustein;
    Form.FRequirements := ARequirements;
    Form.Caption := ABaustein.ExternalId + ' - ' + ABaustein.Title;
    Form.lblHeader.Caption := ABaustein.ExternalId + ' ' + ABaustein.Title + sLineBreak + ABaustein.GroupName;
    Form.edtSearch.Text := AInitialSearch;
    Form.SetupGrid;
    Form.ApplySearch;
    if AInitialRequirementId > 0 then
    begin
      for I := 0 to High(Form.FVisibleRows) do
        if Form.FRequirements[Form.FVisibleRows[I]].Id = AInitialRequirementId then
        begin
          Row := I + 1;
          Form.sgRequirements.Row := Row;
          Form.ShowRequirementAt(Row);
          Break;
        end;
    end
    else if Form.sgRequirements.RowCount > 1 then
    begin
      Form.sgRequirements.Row := 1;
      Form.ShowRequirementAt(1);
    end;
    Form.ShowModal;
  finally
    Form.Free;
  end;
end;

procedure TBausteinViewForm.FormCreate(Sender: TObject);
begin
  SetupGrid;
  FClearSearch := TSearchClearButton.Create(Self, edtSearch);
  FClearSearch.OnSearchChange := edtSearchChange;
end;

procedure TBausteinViewForm.SetupGrid;
begin
  sgRequirements.FixedRows := 1;
  sgRequirements.Cells[0, 0] := 'Anforderung';
  sgRequirements.Cells[1, 0] := 'Titel';
  sgRequirements.Cells[2, 0] := 'Stufe';
  sgRequirements.Cells[3, 0] := 'Rolle';
  sgRequirements.ColWidths[0] := 100;
  sgRequirements.ColWidths[1] := 360;
  sgRequirements.ColWidths[2] := 80;
  sgRequirements.ColWidths[3] := 120;
end;

function TextContains(const AHaystack, ANeedle: string): Boolean;
begin
  Result := Pos(LowerCase(ANeedle), LowerCase(AHaystack)) > 0;
end;

procedure TBausteinViewForm.ApplySearch;
var
  Needle: string;
  I, Row: Integer;
  R: TRequirement;
  IdLabel: string;
  Visible: TArray<Integer>;
begin
  Needle := Trim(edtSearch.Text);
  SetLength(Visible, 0);
  for I := 0 to High(FRequirements) do
  begin
    R := FRequirements[I];
    if (Needle = '') or TextContains(R.ExternalId, Needle) or TextContains(R.Title, Needle) or
       TextContains(R.Text, Needle) or TextContains(R.ResponsibleRole, Needle) then
    begin
      SetLength(Visible, Length(Visible) + 1);
      Visible[High(Visible)] := I;
    end;
  end;
  FVisibleRows := Visible;

  sgRequirements.RowCount := 1;
  Row := 1;
  for I := 0 to High(FVisibleRows) do
  begin
    R := FRequirements[FVisibleRows[I]];
    sgRequirements.RowCount := Row + 1;
    IdLabel := R.ExternalId;
    if R.Withdrawn then
      IdLabel := IdLabel + ' (zurückgezogen)';
    sgRequirements.Cells[0, Row] := IdLabel;
    sgRequirements.Cells[1, Row] := R.Title;
    sgRequirements.Cells[2, Row] := RequirementLevelToString(R.Level);
    sgRequirements.Cells[3, Row] := R.ResponsibleRole;
    Inc(Row);
  end;

  if sgRequirements.RowCount > 1 then
  begin
    sgRequirements.Row := 1;
    ShowRequirementAt(1);
  end
  else
    reRequirementText.Clear;
end;

procedure TBausteinViewForm.ShowRequirementAt(ARow: Integer);
var
  Index: Integer;
begin
  if (ARow < 1) or (ARow > Length(FVisibleRows)) then
  begin
    reRequirementText.Clear;
    Exit;
  end;
  Index := FVisibleRows[ARow - 1];
  TRequirementTextFormatter.ApplyToRichEdit(reRequirementText, FRequirements[Index].Text);
end;

procedure TBausteinViewForm.edtSearchChange(Sender: TObject);
begin
  ApplySearch;
end;

procedure TBausteinViewForm.sgRequirementsSelectCell(Sender: TObject; ACol, ARow: Integer;
  var CanSelect: Boolean);
begin
  if ARow >= 1 then
    ShowRequirementAt(ARow);
  CanSelect := True;
end;

procedure TBausteinViewForm.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
