unit f_createuser;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls;

type
  TCreateUserResult = record
    Email: string;
    DisplayName: string;
    Password: string;
    IsAdmin: Boolean;
  end;

  TCreateUserForm = class(TForm)
    lblIntro: TLabel;
    lblEmail: TLabel;
    edtEmail: TEdit;
    lblDisplayName: TLabel;
    edtDisplayName: TEdit;
    lblPassword: TLabel;
    edtPassword: TEdit;
    lblConfirmPassword: TLabel;
    edtConfirmPassword: TEdit;
    chkAdmin: TCheckBox;
    btnOk: TButton;
    btnCancel: TButton;
    procedure btnOkClick(Sender: TObject);
  public
    class function Execute(AOwner: TComponent; out AResult: TCreateUserResult): Boolean;
  end;

implementation

{$R *.dfm}

class function TCreateUserForm.Execute(AOwner: TComponent; out AResult: TCreateUserResult): Boolean;
var
  F: TCreateUserForm;
begin
  FillChar(AResult, SizeOf(AResult), 0);
  F := TCreateUserForm.Create(AOwner);
  try
    Result := F.ShowModal = mrOk;
    if Result then
    begin
      AResult.Email := Trim(F.edtEmail.Text);
      AResult.DisplayName := Trim(F.edtDisplayName.Text);
      AResult.Password := F.edtPassword.Text;
      AResult.IsAdmin := F.chkAdmin.Checked;
    end;
  finally
    F.Free;
  end;
end;

procedure TCreateUserForm.btnOkClick(Sender: TObject);
begin
  if (Trim(edtEmail.Text) = '') or (Trim(edtDisplayName.Text) = '') or (edtPassword.Text = '') then
  begin
    MessageDlg('Bitte alle Felder ausfüllen.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if Length(edtPassword.Text) < 8 then
  begin
    MessageDlg('Das Passwort muss mindestens 8 Zeichen lang sein.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if edtPassword.Text <> edtConfirmPassword.Text then
  begin
    MessageDlg('Die Passwörter stimmen nicht überein.', mtWarning, [mbOK], 0);
    Exit;
  end;
  ModalResult := mrOk;
end;

end.
