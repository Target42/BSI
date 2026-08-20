unit f_targetobject;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, IsmsDomain;

type
  TTargetObjectForm = class(TForm)
    lblParent: TLabel;
    lblName: TLabel;
    edtName: TEdit;
    lblType: TLabel;
    cboType: TComboBox;
    chkInherit: TCheckBox;
    lblConfidentiality: TLabel;
    cboConfidentiality: TComboBox;
    lblIntegrity: TLabel;
    cboIntegrity: TComboBox;
    lblAvailability: TLabel;
    cboAvailability: TComboBox;
    lblOverall: TLabel;
    lblProtectionNote: TLabel;
    memProtectionNote: TMemo;
    lblDescription: TLabel;
    memDescription: TMemo;
    btnOk: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
  private
    FTargetObject: TTargetObject;
    FParent: TTargetObject;
    FEditMode: Boolean;
    procedure FillTypeItems(const ATypes: TArray<TTargetObjectType>;
      ASelected: TTargetObjectType);
    procedure FillCiaCombo(ACombo: TComboBox);
    function SelectedObjType: TTargetObjectType;
    function SelectedCiaLevel(ACombo: TComboBox): TCiaLevel;
    procedure SetCiaCombo(ACombo: TComboBox; ALevel: TCiaLevel);
    procedure ApplyParentContext;
    procedure LoadProtectionNeedToControls;
    procedure UpdateCiaEnabled;
    procedure SyncOverallLabel;
    procedure InheritClick(Sender: TObject);
    procedure CiaChange(Sender: TObject);
    procedure OkClick(Sender: TObject);
  public
    class function ExecuteCreate(var ATargetObject: TTargetObject;
      const AParent: TTargetObject): Boolean;
    class function ExecuteEdit(var ATargetObject: TTargetObject;
      const AParent: TTargetObject): Boolean;
  end;

implementation

{$R *.dfm}

const
  S_WirdAngelegtUnter = 'Wird angelegt unter: ';
  S_Uebergeordnet = #$00DC'bergeordnet: ';
  S_Wurzel = 'Wurzel des Informationsverbunds';
  S_GesamtPrefix = 'Gesamt nach Maximumprinzip: ';

procedure TTargetObjectForm.FormCreate(Sender: TObject);
begin
  FillCiaCombo(cboConfidentiality);
  FillCiaCombo(cboIntegrity);
  FillCiaCombo(cboAvailability);
  chkInherit.OnClick := InheritClick;
  cboConfidentiality.OnChange := CiaChange;
  cboIntegrity.OnChange := CiaChange;
  cboAvailability.OnChange := CiaChange;
  btnOk.OnClick := OkClick;
end;

procedure TTargetObjectForm.FillCiaCombo(ACombo: TComboBox);
var
  Level: TCiaLevel;
begin
  ACombo.Items.BeginUpdate;
  try
    ACombo.Items.Clear;
    for Level := Low(TCiaLevel) to High(TCiaLevel) do
      ACombo.Items.Add(CiaLevelToString(Level));
  finally
    ACombo.Items.EndUpdate;
  end;
  ACombo.ItemIndex := 0;
end;

procedure TTargetObjectForm.FillTypeItems(const ATypes: TArray<TTargetObjectType>;
  ASelected: TTargetObjectType);
var
  T: TTargetObjectType;
  Types: TArray<TTargetObjectType>;
  Found: Boolean;
begin
  Types := Copy(ATypes);
  Found := False;
  for T in Types do
    if T = ASelected then
    begin
      Found := True;
      Break;
    end;
  if not Found then
  begin
    SetLength(Types, Length(Types) + 1);
    Types[High(Types)] := ASelected;
  end;

  cboType.Items.BeginUpdate;
  try
    cboType.Items.Clear;
    for T in Types do
      cboType.Items.AddObject(TargetObjectTypeToString(T), TObject(NativeInt(T) + 1));
  finally
    cboType.Items.EndUpdate;
  end;
  cboType.ItemIndex := cboType.Items.IndexOfObject(TObject(NativeInt(ASelected) + 1));
  if (cboType.ItemIndex < 0) and (cboType.Items.Count > 0) then
    cboType.ItemIndex := 0;
end;

function TTargetObjectForm.SelectedObjType: TTargetObjectType;
begin
  if cboType.ItemIndex < 0 then
    Exit(FTargetObject.ObjType);
  Result := TTargetObjectType(NativeInt(cboType.Items.Objects[cboType.ItemIndex]) - 1);
end;

function TTargetObjectForm.SelectedCiaLevel(ACombo: TComboBox): TCiaLevel;
begin
  if ACombo.ItemIndex < 0 then
    Exit(clNormal);
  Result := TCiaLevel(ACombo.ItemIndex);
end;

procedure TTargetObjectForm.SetCiaCombo(ACombo: TComboBox; ALevel: TCiaLevel);
begin
  ACombo.ItemIndex := Ord(ALevel);
  if ACombo.ItemIndex < 0 then
    ACombo.ItemIndex := 0;
end;

procedure TTargetObjectForm.ApplyParentContext;
var
  Allowed: TArray<TTargetObjectType>;
  CanInherit: Boolean;
begin
  CanInherit := FParent.Id > 0;
  chkInherit.Visible := CanInherit;
  if IsRootScopeTarget(FTargetObject) and FEditMode then
  begin
    lblParent.Caption := S_Wurzel;
    FillTypeItems(TArray<TTargetObjectType>.Create(totScope), totScope);
    cboType.Enabled := False;
    chkInherit.Visible := False;
    chkInherit.Checked := False;
    UpdateCiaEnabled;
    Exit;
  end;

  cboType.Enabled := True;
  if FParent.Id > 0 then
  begin
    if FEditMode then
      lblParent.Caption := S_Uebergeordnet + TargetObjectCaption(FParent)
    else
      lblParent.Caption := S_WirdAngelegtUnter + TargetObjectCaption(FParent);
    Allowed := AllowedChildTargetTypes(FParent.ObjType);
  end
  else
  begin
    lblParent.Caption := '';
    Allowed := ScopeLayerTypes;
  end;
  FillTypeItems(Allowed, FTargetObject.ObjType);
  UpdateCiaEnabled;
end;

procedure TTargetObjectForm.LoadProtectionNeedToControls;
begin
  chkInherit.Checked := FTargetObject.InheritProtectionNeed and (FParent.Id > 0);
  SetCiaCombo(cboConfidentiality, FTargetObject.Confidentiality);
  SetCiaCombo(cboIntegrity, FTargetObject.Integrity);
  SetCiaCombo(cboAvailability, FTargetObject.Availability);
  memProtectionNote.Text := FTargetObject.ProtectionNeedNote;
  UpdateCiaEnabled;
  SyncOverallLabel;
end;

procedure TTargetObjectForm.UpdateCiaEnabled;
var
  Inherit: Boolean;
begin
  Inherit := chkInherit.Visible and chkInherit.Checked;
  cboConfidentiality.Enabled := not Inherit;
  cboIntegrity.Enabled := not Inherit;
  cboAvailability.Enabled := not Inherit;
  if Inherit and (FParent.Id > 0) then
  begin
    SetCiaCombo(cboConfidentiality, FParent.Confidentiality);
    SetCiaCombo(cboIntegrity, FParent.Integrity);
    SetCiaCombo(cboAvailability, FParent.Availability);
  end;
  SyncOverallLabel;
end;

procedure TTargetObjectForm.SyncOverallLabel;
var
  Need: TProtectionNeed;
begin
  Need := ProtectionNeedFromCiaLevels(
    SelectedCiaLevel(cboConfidentiality),
    SelectedCiaLevel(cboIntegrity),
    SelectedCiaLevel(cboAvailability));
  lblOverall.Caption := S_GesamtPrefix + ProtectionNeedToString(Need);
end;

procedure TTargetObjectForm.InheritClick(Sender: TObject);
begin
  UpdateCiaEnabled;
end;

procedure TTargetObjectForm.CiaChange(Sender: TObject);
begin
  SyncOverallLabel;
end;

class function TTargetObjectForm.ExecuteCreate(var ATargetObject: TTargetObject;
  const AParent: TTargetObject): Boolean;
var
  F: TTargetObjectForm;
begin
  F := TTargetObjectForm.Create(Application);
  try
    F.FEditMode := False;
    F.Caption := 'Zielobjekt hinzuf'#$00FC'gen';
    F.FTargetObject := ATargetObject;
    F.FParent := AParent;
    F.edtName.Text := '';
    F.memDescription.Clear;
    F.ApplyParentContext;
    F.LoadProtectionNeedToControls;
    Result := F.ShowModal = mrOk;
    if Result then
      ATargetObject := F.FTargetObject;
  finally
    F.Free;
  end;
end;

class function TTargetObjectForm.ExecuteEdit(var ATargetObject: TTargetObject;
  const AParent: TTargetObject): Boolean;
var
  F: TTargetObjectForm;
begin
  F := TTargetObjectForm.Create(Application);
  try
    F.FEditMode := True;
    F.Caption := 'Zielobjekt bearbeiten';
    F.FTargetObject := ATargetObject;
    F.FParent := AParent;
    F.edtName.Text := ATargetObject.Name;
    F.memDescription.Text := ATargetObject.Description;
    F.ApplyParentContext;
    F.LoadProtectionNeedToControls;
    Result := F.ShowModal = mrOk;
    if Result then
      ATargetObject := F.FTargetObject;
  finally
    F.Free;
  end;
end;

procedure TTargetObjectForm.OkClick(Sender: TObject);
begin
  if Trim(edtName.Text) = '' then
  begin
    MessageDlg('Bitte einen Namen eingeben.', mtWarning, [mbOK], 0);
    Exit;
  end;
  FTargetObject.Name := Trim(edtName.Text);
  FTargetObject.Description := Trim(memDescription.Text);
  FTargetObject.ObjType := SelectedObjType;
  FTargetObject.InheritProtectionNeed := chkInherit.Visible and chkInherit.Checked;
  FTargetObject.Confidentiality := SelectedCiaLevel(cboConfidentiality);
  FTargetObject.Integrity := SelectedCiaLevel(cboIntegrity);
  FTargetObject.Availability := SelectedCiaLevel(cboAvailability);
  FTargetObject.ProtectionNeedNote := Trim(memProtectionNote.Text);
  FTargetObject.ProtectionNeed := ProtectionNeedFromCiaLevels(
    FTargetObject.Confidentiality, FTargetObject.Integrity, FTargetObject.Availability);
  FinalizeTargetObjectProtectionNeed(FTargetObject, FParent);
  ModalResult := mrOk;
end;

end.
