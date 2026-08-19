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
    lblProtection: TLabel;
    cboProtection: TComboBox;
    lblDescription: TLabel;
    memDescription: TMemo;
    btnOk: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnOkClick(Sender: TObject);
  private
    FTargetObject: TTargetObject;
    FParent: TTargetObject;
    FEditMode: Boolean;
    procedure FillTypeItems(const ATypes: TArray<TTargetObjectType>;
      ASelected: TTargetObjectType);
    function SelectedObjType: TTargetObjectType;
    procedure ApplyParentContext;
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

procedure TTargetObjectForm.FormCreate(Sender: TObject);
begin
  cboProtection.Items.Clear;
  cboProtection.Items.Add(ProtectionNeedToString(pnBasisOnly));
  cboProtection.Items.Add(ProtectionNeedToString(pnNormal));
  cboProtection.Items.Add(ProtectionNeedToString(pnElevated));
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

procedure TTargetObjectForm.ApplyParentContext;
var
  Allowed: TArray<TTargetObjectType>;
begin
  if IsRootScopeTarget(FTargetObject) and FEditMode then
  begin
    lblParent.Caption := S_Wurzel;
    FillTypeItems(TArray<TTargetObjectType>.Create(totScope), totScope);
    cboType.Enabled := False;
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
    F.cboProtection.ItemIndex := Ord(ATargetObject.ProtectionNeed);
    F.memDescription.Clear;
    F.ApplyParentContext;
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
    F.cboProtection.ItemIndex := Ord(ATargetObject.ProtectionNeed);
    F.memDescription.Text := ATargetObject.Description;
    F.ApplyParentContext;
    Result := F.ShowModal = mrOk;
    if Result then
      ATargetObject := F.FTargetObject;
  finally
    F.Free;
  end;
end;

procedure TTargetObjectForm.btnOkClick(Sender: TObject);
begin
  if Trim(edtName.Text) = '' then
  begin
    MessageDlg('Bitte einen Namen eingeben.', mtWarning, [mbOK], 0);
    Exit;
  end;
  FTargetObject.Name := Trim(edtName.Text);
  FTargetObject.Description := Trim(memDescription.Text);
  FTargetObject.ObjType := SelectedObjType;
  if cboProtection.ItemIndex >= 0 then
    FTargetObject.ProtectionNeed := TProtectionNeed(cboProtection.ItemIndex);
  ModalResult := mrOk;
end;

end.
