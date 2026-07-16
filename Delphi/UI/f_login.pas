unit f_login;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  AppSettings, ApiClient;

type
  TLoginForm = class(TForm)
    pnlMain: TPanel;
    lblIntro: TLabel;
    chkRemote: TCheckBox;
    lblServer: TLabel;
    edtServer: TEdit;
    lblEmail: TLabel;
    edtEmail: TEdit;
    lblPassword: TLabel;
    edtPassword: TEdit;
    chkInsecureTls: TCheckBox;
    btnOk: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure chkRemoteClick(Sender: TObject);
    procedure edtServerChange(Sender: TObject);
    procedure btnOkClick(Sender: TObject);
  private
    FSettings: TAppSettings;
    FReloginMode: Boolean;
    FSwitchUserMode: Boolean;
    procedure UpdateRemoteFields;
    procedure UpdateTlsOptionVisibility;
    procedure FocusInitialControl;
  public
    property Settings: TAppSettings read FSettings;
    procedure InitializeSettings(const ASettings: TAppSettings);
    procedure SetReloginMode;
    procedure SetSwitchUserMode;
    function TrySilentLogin: Boolean;
  end;

implementation

{$R *.dfm}

procedure TLoginForm.InitializeSettings(const ASettings: TAppSettings);
begin
  FSettings := ASettings;
  chkRemote.Checked := FSettings.UseRemote;
  edtServer.Text := FSettings.ServerUrl;
  edtEmail.Text := FSettings.UserEmail;
  chkInsecureTls.Checked := FSettings.InsecureSkipTlsVerify;
  UpdateRemoteFields;
end;

procedure TLoginForm.FormCreate(Sender: TObject);
begin
  FReloginMode := False;
  FSwitchUserMode := False;
  InitializeSettings(TAppSettings.Load);
end;

procedure TLoginForm.FocusInitialControl;
begin
  if FReloginMode then
  begin
    if edtPassword.CanFocus then
      ActiveControl := edtPassword;
    Exit;
  end;
  if FSwitchUserMode then
  begin
    if chkRemote.Checked then
    begin
      if edtPassword.CanFocus then
        ActiveControl := edtPassword
      else if edtEmail.CanFocus then
        ActiveControl := edtEmail;
    end
    else if chkRemote.CanFocus then
      ActiveControl := chkRemote;
  end;
end;

procedure TLoginForm.FormShow(Sender: TObject);
begin
  FocusInitialControl;
end;

procedure TLoginForm.SetReloginMode;
begin
  FReloginMode := True;
  Caption := 'ISMS – Erneut anmelden';
  lblIntro.Caption := 'Ihre Sitzung ist abgelaufen. Bitte melden Sie sich erneut an.';
  chkRemote.Checked := True;
  chkRemote.Enabled := False;
  edtServer.Enabled := False;
  edtEmail.Enabled := True;
  UpdateRemoteFields;
end;

procedure TLoginForm.SetSwitchUserMode;
begin
  FSwitchUserMode := True;
  Caption := 'ISMS – Abmelden / Benutzer wechseln';
  lblIntro.Caption :=
    'Melden Sie sich erneut an, wechseln Sie den Benutzer oder arbeiten Sie lokal ohne Server.';
  edtPassword.Clear;
end;

procedure TLoginForm.UpdateRemoteFields;
var
  Remote: Boolean;
begin
  Remote := FReloginMode or chkRemote.Checked;
  lblServer.Visible := Remote;
  edtServer.Visible := Remote;
  lblEmail.Visible := Remote;
  edtEmail.Visible := Remote;
  lblPassword.Visible := Remote;
  edtPassword.Visible := Remote;
  UpdateTlsOptionVisibility;
  if Remote then
    lblIntro.Caption := 'Melden Sie sich am ISMS-Server an.'
  else if not FReloginMode and not FSwitchUserMode then
    lblIntro.Caption := 'Lokaler Modus: Daten werden in SQLite gespeichert.';
end;

procedure TLoginForm.UpdateTlsOptionVisibility;
var
  Https: Boolean;
begin
  Https := SameText(Copy(Trim(edtServer.Text), 1, 8), 'https://');
  chkInsecureTls.Visible := Https and (FReloginMode or chkRemote.Checked);
end;

procedure TLoginForm.chkRemoteClick(Sender: TObject);
begin
  UpdateRemoteFields;
end;

procedure TLoginForm.edtServerChange(Sender: TObject);
begin
  UpdateTlsOptionVisibility;
end;

function TLoginForm.TrySilentLogin: Boolean;
var
  Client: TApiClient;
  Err: string;
begin
  Result := False;
  try
    FSettings := TAppSettings.Load;
    if not FSettings.HasStoredRemoteSession then
      Exit;
    if FSettings.IsTokenExpired then
      Exit;
    Client := TApiClient.Create(FSettings.ServerUrl);
    try
      Client.SetAccessToken(FSettings.AccessToken);
      Client.SetTokenExpiresAt(FSettings.TokenExpiresAt);
      Client.SetInsecureSkipTlsVerify(FSettings.InsecureSkipTlsVerify);
      if not Client.ValidateSession(Err) then
        Exit;
      FSettings.UseRemote := True;
      Result := True;
    finally
      Client.Free;
    end;
  except
    Result := False;
  end;
end;

procedure TLoginForm.btnOkClick(Sender: TObject);
var
  Client: TApiClient;
  Err: string;
begin
  FSettings.UseRemote := FReloginMode or chkRemote.Checked;
  FSettings.ServerUrl := Trim(edtServer.Text);
  FSettings.UserEmail := Trim(edtEmail.Text);
  FSettings.InsecureSkipTlsVerify := chkInsecureTls.Checked;

  if not FSettings.UseRemote then
  begin
    FSettings.AccessToken := '';
    FSettings.TokenExpiresAt := 0;
    FSettings.Save;
    ModalResult := mrOk;
    Exit;
  end;

  if Trim(edtServer.Text) = '' then
  begin
    MessageDlg('Bitte Server-URL eingeben.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if Trim(edtEmail.Text) = '' then
  begin
    MessageDlg('Bitte E-Mail eingeben.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if Trim(edtPassword.Text) = '' then
  begin
    MessageDlg('Bitte Passwort eingeben.', mtWarning, [mbOK], 0);
    Exit;
  end;

  Client := TApiClient.Create(FSettings.ServerUrl);
  try
    Client.SetInsecureSkipTlsVerify(FSettings.InsecureSkipTlsVerify);
    if not Client.Login(FSettings.UserEmail, edtPassword.Text, Err) then
    begin
      MessageDlg(Err, mtError, [mbOK], 0);
      Exit;
    end;
    FSettings.AccessToken := Client.AccessToken;
    FSettings.TokenExpiresAt := Client.TokenExpiresAt;
    FSettings.Save;
    ModalResult := mrOk;
  finally
    Client.Free;
  end;
end;

end.
