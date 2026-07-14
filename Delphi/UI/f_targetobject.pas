unit f_targetobject;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, IsmsDomain;

type
  TTargetObjectForm = class(TForm)
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
    FEditMode: Boolean;
  public
    class function ExecuteCreate(var ATargetObject: TTargetObject): Boolean;
    class function ExecuteEdit(var ATargetObject: TTargetObject): Boolean;
  end;

implementation

{$R *.dfm}

procedure TTargetObjectForm.FormCreate(Sender: TObject);
begin
  cboType.Items.Clear;
  cboType.Items.Add(TargetObjectTypeToString(totScope));
  cboType.Items.Add(TargetObjectTypeToString(totProcess));
  cboType.Items.Add(TargetObjectTypeToString(totApplication));
  cboType.Items.Add(TargetObjectTypeToString(totITSystem));
  cboType.Items.Add(TargetObjectTypeToString(totNetwork));
  cboType.Items.Add(TargetObjectTypeToString(totInfrastructure));
  cboProtection.Items.Clear;
  cboProtection.Items.Add(ProtectionNeedToString(pnBasisOnly));
  cboProtection.Items.Add(ProtectionNeedToString(pnNormal));
  cboProtection.Items.Add(ProtectionNeedToString(pnElevated));
end;

class function TTargetObjectForm.ExecuteCreate(var ATargetObject: TTargetObject): Boolean;
var
  F: TTargetObjectForm;
begin
  F := TTargetObjectForm.Create(Application);
  try
    F.FEditMode := False;
    F.Caption := 'Zielobjekt hinzufügen';
    F.FTargetObject := ATargetObject;
    F.edtName.Text := '';
    F.cboType.ItemIndex := 1;
    F.cboProtection.ItemIndex := 1;
    F.memDescription.Clear;
    Result := F.ShowModal = mrOk;
    if Result then
      ATargetObject := F.FTargetObject;
  finally
    F.Free;
  end;
end;

class function TTargetObjectForm.ExecuteEdit(var ATargetObject: TTargetObject): Boolean;
var
  F: TTargetObjectForm;
begin
  F := TTargetObjectForm.Create(Application);
  try
    F.FEditMode := True;
    F.Caption := 'Zielobjekt bearbeiten';
    F.FTargetObject := ATargetObject;
    F.edtName.Text := ATargetObject.Name;
    F.cboType.ItemIndex := Ord(ATargetObject.ObjType);
    F.cboProtection.ItemIndex := Ord(ATargetObject.ProtectionNeed);
    F.memDescription.Text := ATargetObject.Description;
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
  if cboType.ItemIndex >= 0 then
    FTargetObject.ObjType := TTargetObjectType(cboType.ItemIndex);
  if cboProtection.ItemIndex >= 0 then
    FTargetObject.ProtectionNeed := TProtectionNeed(cboProtection.ItemIndex);
  ModalResult := mrOk;
end;

end.
