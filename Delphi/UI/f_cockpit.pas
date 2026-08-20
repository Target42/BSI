unit f_cockpit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Grids,
  Vcl.ExtCtrls, IsmsDomain, AppContext, CockpitService;

type
  TCockpitForm = class(TForm)
    pnlTop: TPanel;
    lblKind: TLabel;
    cboKind: TComboBox;
    lblDue: TLabel;
    cboDue: TComboBox;
    chkHideDone: TCheckBox;
    chkMine: TCheckBox;
    lblPerson: TLabel;
    edtPerson: TEdit;
    lblSummary: TLabel;
    sgItems: TStringGrid;
    pnlBottom: TPanel;
    btnOpen: TButton;
    btnClose: TButton;
    procedure FormCreate(Sender: TObject);
  private
    FContext: TAppContext;
    FProject: TProject;
    FAllItems: TArray<TCockpitItem>;
    FVisibleItems: TArray<TCockpitItem>;
    FFilter: TCockpitFilter;
    FSelected: TCockpitItem;
    FService: TCockpitService;
    procedure KindChange(Sender: TObject);
    procedure DueChange(Sender: TObject);
    procedure HideDoneClick(Sender: TObject);
    procedure MineClick(Sender: TObject);
    procedure PersonChange(Sender: TObject);
    procedure GridDblClick(Sender: TObject);
    procedure GridDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect;
      State: TGridDrawState);
    procedure GridKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure OpenClick(Sender: TObject);
    procedure CloseClick(Sender: TObject);
    procedure ApplyCurrentFilter;
    procedure FillGrid;
    function SelectedItem(out AItem: TCockpitItem): Boolean;
    function AcceptSelected: Boolean;
  public
    constructor Create(AOwner: TComponent; AContext: TAppContext;
      const AProject: TProject; const AUserName, AUserEmail: string); reintroduce;
    destructor Destroy; override;
    class function Execute(AOwner: TComponent; AContext: TAppContext;
      const AProject: TProject; const AUserName, AUserEmail: string;
      out AItem: TCockpitItem): Boolean;
  end;

implementation

{$R *.dfm}

constructor TCockpitForm.Create(AOwner: TComponent; AContext: TAppContext;
  const AProject: TProject; const AUserName, AUserEmail: string);
begin
  FContext := AContext;
  FProject := AProject;
  FFilter := DefaultCockpitFilter;
  FFilter.CurrentUserName := AUserName;
  FFilter.CurrentUserEmail := AUserEmail;
  inherited Create(AOwner);
end;

destructor TCockpitForm.Destroy;
begin
  FService.Free;
  inherited;
end;

class function TCockpitForm.Execute(AOwner: TComponent; AContext: TAppContext;
  const AProject: TProject; const AUserName, AUserEmail: string;
  out AItem: TCockpitItem): Boolean;
var
  Form: TCockpitForm;
begin
  FillChar(AItem, SizeOf(AItem), 0);
  Form := TCockpitForm.Create(AOwner, AContext, AProject, AUserName, AUserEmail);
  try
    Result := Form.ShowModal = mrOk;
    if Result then
      AItem := Form.FSelected;
  finally
    Form.Free;
  end;
end;

procedure TCockpitForm.FormCreate(Sender: TObject);
begin
  Caption := 'Aufgaben-Cockpit';
  Width := 1100;
  Height := 650;

  FService := TCockpitService.Create(
    FContext.CatalogRepository,
    FContext.ProjectRepository,
    FContext.TargetObjectRepository,
    FContext.MeasureRepository);

  cboKind.Items.Add('Alle');
  cboKind.Items.Add('Bewertungen');
  cboKind.Items.Add('Ma'#$00DF'nahmen');
  cboKind.ItemIndex := 0;

  cboDue.Items.Add('Alle Fristen');
  cboDue.Items.Add(#$00DC'berf'#$00E4'llig');
  cboDue.Items.Add('Diese Woche');
  cboDue.Items.Add('Mit Frist');
  cboDue.Items.Add('Ohne Frist');
  cboDue.ItemIndex := 0;

  chkMine.Enabled := (Trim(FFilter.CurrentUserName) <> '') or
    (Trim(FFilter.CurrentUserEmail) <> '');

  sgItems.ColCount := 8;
  sgItems.RowCount := 2;
  sgItems.FixedRows := 1;
  sgItems.Cells[0, 0] := 'Art';
  sgItems.Cells[1, 0] := 'Zielobjekt';
  sgItems.Cells[2, 0] := 'Baustein';
  sgItems.Cells[3, 0] := 'Anforderung';
  sgItems.Cells[4, 0] := 'Titel';
  sgItems.Cells[5, 0] := 'Status';
  sgItems.Cells[6, 0] := 'Verantwortlich';
  sgItems.Cells[7, 0] := 'Frist';
  sgItems.ColWidths[0] := 90;
  sgItems.ColWidths[1] := 150;
  sgItems.ColWidths[2] := 80;
  sgItems.ColWidths[3] := 110;
  sgItems.ColWidths[4] := 260;
  sgItems.ColWidths[5] := 110;
  sgItems.ColWidths[6] := 140;
  sgItems.ColWidths[7] := 90;

  cboKind.OnChange := KindChange;
  cboDue.OnChange := DueChange;
  chkHideDone.OnClick := HideDoneClick;
  chkMine.OnClick := MineClick;
  edtPerson.OnChange := PersonChange;
  sgItems.OnDblClick := GridDblClick;
  sgItems.OnDrawCell := GridDrawCell;
  sgItems.OnKeyDown := GridKeyDown;
  btnOpen.OnClick := OpenClick;
  btnClose.OnClick := CloseClick;

  Screen.Cursor := crHourGlass;
  try
    FAllItems := FService.BuildItems(FProject.Id, FContext.CatalogVersion);
  finally
    Screen.Cursor := crDefault;
  end;
  ApplyCurrentFilter;
end;

procedure TCockpitForm.ApplyCurrentFilter;
begin
  case cboKind.ItemIndex of
    1: FFilter.Kind := ckfAssessments;
    2: FFilter.Kind := ckfMeasures;
  else
    FFilter.Kind := ckfAll;
  end;
  case cboDue.ItemIndex of
    1: FFilter.Due := cdfOverdue;
    2: FFilter.Due := cdfThisWeek;
    3: FFilter.Due := cdfHasDate;
    4: FFilter.Due := cdfNoDate;
  else
    FFilter.Due := cdfAll;
  end;
  FFilter.HideDone := chkHideDone.Checked;
  FFilter.MineOnly := chkMine.Checked;
  FFilter.ResponsibleNeedle := Trim(edtPerson.Text);
  FVisibleItems := TCockpitService.ApplyFilter(FAllItems, FFilter);
  FillGrid;
  lblSummary.Caption := TCockpitService.FormatSummary(
    TCockpitService.Summarize(FVisibleItems));
end;

procedure TCockpitForm.FillGrid;
var
  I, GridRow: Integer;
  Item: TCockpitItem;
begin
  sgItems.RowCount := 1;
  if Length(FVisibleItems) = 0 then
  begin
    sgItems.RowCount := 2;
    sgItems.Rows[1].Clear;
    Exit;
  end;
  sgItems.RowCount := Length(FVisibleItems) + 1;
  for I := 0 to High(FVisibleItems) do
  begin
    Item := FVisibleItems[I];
    GridRow := I + 1;
    sgItems.Cells[0, GridRow] := CockpitKindToString(Item.Kind);
    sgItems.Cells[1, GridRow] := Item.TargetObjectName;
    sgItems.Cells[2, GridRow] := Item.BausteinExternalId;
    sgItems.Cells[3, GridRow] := Item.RequirementExternalId;
    sgItems.Cells[4, GridRow] := Item.Title;
    sgItems.Cells[5, GridRow] := Item.StatusText;
    sgItems.Cells[6, GridRow] := Item.Responsible;
    if IsValidDate(Item.DueDate) then
      sgItems.Cells[7, GridRow] := FormatDateTime('dd.mm.yyyy', Item.DueDate)
    else
      sgItems.Cells[7, GridRow] := '';
    sgItems.Objects[0, GridRow] := TObject(I + 1);
  end;
end;

function TCockpitForm.SelectedItem(out AItem: TCockpitItem): Boolean;
var
  Index: Integer;
begin
  FillChar(AItem, SizeOf(AItem), 0);
  if (sgItems.Row < 1) or (Length(FVisibleItems) = 0) then
    Exit(False);
  Index := Integer(sgItems.Objects[0, sgItems.Row]) - 1;
  if (Index < 0) or (Index > High(FVisibleItems)) then
    Exit(False);
  AItem := FVisibleItems[Index];
  Result := AItem.RequirementDbId > 0;
end;

function TCockpitForm.AcceptSelected: Boolean;
begin
  Result := SelectedItem(FSelected);
  if not Result then
  begin
    MessageDlg('Bitte einen Eintrag mit Anforderung w'#$00E4'hlen.', mtInformation, [mbOK], 0);
    Exit;
  end;
  ModalResult := mrOk;
end;

procedure TCockpitForm.KindChange(Sender: TObject);
begin
  ApplyCurrentFilter;
end;

procedure TCockpitForm.DueChange(Sender: TObject);
begin
  ApplyCurrentFilter;
end;

procedure TCockpitForm.HideDoneClick(Sender: TObject);
begin
  ApplyCurrentFilter;
end;

procedure TCockpitForm.MineClick(Sender: TObject);
begin
  ApplyCurrentFilter;
end;

procedure TCockpitForm.PersonChange(Sender: TObject);
begin
  ApplyCurrentFilter;
end;

procedure TCockpitForm.GridDblClick(Sender: TObject);
begin
  AcceptSelected;
end;

procedure TCockpitForm.GridDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect;
  State: TGridDrawState);
var
  Index: Integer;
begin
  if (ARow < 1) or (Length(FVisibleItems) = 0) then
    Exit;
  Index := Integer(sgItems.Objects[0, ARow]) - 1;
  if (Index < 0) or (Index > High(FVisibleItems)) then
    Exit;
  if FVisibleItems[Index].Overdue and not (gdSelected in State) then
    sgItems.Canvas.Font.Color := clRed;
end;

procedure TCockpitForm.GridKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    Key := 0;
    AcceptSelected;
  end;
end;

procedure TCockpitForm.OpenClick(Sender: TObject);
begin
  AcceptSelected;
end;

procedure TCockpitForm.CloseClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
