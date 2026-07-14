unit f_projectmembers;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.Generics.Collections, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.Grids, Vcl.ExtCtrls, IsmsDomain, ApiClient, HttpTeamService,
  f_createuser;

type
  TProjectMembersForm = class(TForm)
    lblIntro: TLabel;
    sgMembers: TStringGrid;
    btnChangeRole: TButton;
    btnRemove: TButton;
    btnCreateUser: TButton;
    grpAdd: TGroupBox;
    lblEmail: TLabel;
    edtEmail: TEdit;
    lblUserPicker: TLabel;
    cboUserPicker: TComboBox;
    lblRole: TLabel;
    cboRole: TComboBox;
    btnAdd: TButton;
    btnClose: TButton;
    procedure FormCreate(Sender: TObject);
    procedure sgMembersSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
    procedure btnAddClick(Sender: TObject);
    procedure btnChangeRoleClick(Sender: TObject);
    procedure btnRemoveClick(Sender: TObject);
    procedure btnCreateUserClick(Sender: TObject);
    procedure cboUserPickerChange(Sender: TObject);
  private
    FClient: TApiClient;
    FProjectId: Integer;
    FProjectName: string;
    FCanManage: Boolean;
    FCanCreateUsers: Boolean;
    FMembers: TArray<TProjectMember>;
    FUsers: TArray<TServerUser>;
    FRoleValues: TArray<string>;
    procedure PopulateRoleCombo(const ASelectRole: string);
    function SelectedRoleCode: string;
    function SelectedUserId: Integer;
    procedure UpdateButtons;
    procedure ReloadMembers;
    procedure ReloadUserPicker;
    procedure ConfigureManagementUi;
  public
    class procedure Execute(AOwner: TComponent; AClient: TApiClient; AProjectId: Integer;
      const AProjectName: string; ACanManage, ACanCreateUsers: Boolean);
  end;

implementation

{$R *.dfm}

class procedure TProjectMembersForm.Execute(AOwner: TComponent; AClient: TApiClient;
  AProjectId: Integer; const AProjectName: string; ACanManage, ACanCreateUsers: Boolean);
var
  F: TProjectMembersForm;
begin
  F := TProjectMembersForm.Create(AOwner);
  try
    F.FClient := AClient;
    F.FProjectId := AProjectId;
    F.FProjectName := AProjectName;
    F.FCanManage := ACanManage;
    F.FCanCreateUsers := ACanCreateUsers;
    F.Caption := Format('Projektmitglieder – %s', [AProjectName]);
    if ACanManage then
      F.lblIntro.Caption := Format('Verwalten Sie, wer auf das Projekt "%s" zugreifen darf.',
        [AProjectName])
    else
      F.lblIntro.Caption := Format('Mitglieder des Projekts "%s" (nur Ansicht).', [AProjectName]);
    F.ConfigureManagementUi;
    F.ReloadMembers;
    if ACanManage then
      F.ReloadUserPicker;
    F.UpdateButtons;
    F.ShowModal;
  finally
    F.Free;
  end;
end;

procedure TProjectMembersForm.FormCreate(Sender: TObject);
begin
  sgMembers.FixedRows := 1;
  sgMembers.Cells[0, 0] := 'Name';
  sgMembers.Cells[1, 0] := 'E-Mail';
  sgMembers.Cells[2, 0] := 'Rolle';
end;

procedure TProjectMembersForm.ConfigureManagementUi;
begin
  grpAdd.Visible := FCanManage;
  btnChangeRole.Visible := FCanManage;
  btnRemove.Visible := FCanManage;
  btnCreateUser.Visible := FCanManage and FCanCreateUsers;
  lblUserPicker.Visible := FCanCreateUsers;
  cboUserPicker.Visible := FCanCreateUsers;
  if FCanManage then
    PopulateRoleCombo('editor');
end;

procedure TProjectMembersForm.PopulateRoleCombo(const ASelectRole: string);
var
  Roles: TArray<string>;
  Role: string;
  I, SelectIndex: Integer;
begin
  cboRole.Items.Clear;
  SetLength(FRoleValues, 0);
  Roles := ProjectMemberRoleOptions;
  SelectIndex := -1;
  for Role in Roles do
  begin
    I := cboRole.Items.Add(ProjectMemberRoleLabel(Role));
    SetLength(FRoleValues, Length(FRoleValues) + 1);
    FRoleValues[High(FRoleValues)] := Role;
    if SameText(Role, ASelectRole) then
      SelectIndex := I;
  end;
  if SelectIndex >= 0 then
    cboRole.ItemIndex := SelectIndex
  else if cboRole.Items.Count > 0 then
    cboRole.ItemIndex := 0;
end;

function TProjectMembersForm.SelectedRoleCode: string;
begin
  if (cboRole.ItemIndex < 0) or (cboRole.ItemIndex > High(FRoleValues)) then
    Exit('editor');
  Result := FRoleValues[cboRole.ItemIndex];
end;

function TProjectMembersForm.SelectedUserId: Integer;
var
  Row: Integer;
begin
  Result := 0;
  Row := sgMembers.Row;
  if Row < sgMembers.FixedRows then
    Exit;
  Result := Integer(sgMembers.Objects[0, Row]);
end;

procedure TProjectMembersForm.UpdateButtons;
var
  HasSelection: Boolean;
begin
  HasSelection := SelectedUserId > 0;
  btnChangeRole.Enabled := FCanManage and HasSelection;
  btnRemove.Enabled := FCanManage and HasSelection;
end;

procedure TProjectMembersForm.ReloadMembers;
var
  Service: THttpTeamService;
  Row: Integer;
  Member: TProjectMember;
begin
  Service := THttpTeamService.Create(FClient);
  try
    FMembers := Service.ListMembers(FProjectId);
    if (Length(FMembers) = 0) and (Service.LastError <> '') then
    begin
      MessageDlg(Service.LastError, mtError, [mbOK], 0);
      Exit;
    end;
  finally
    Service.Free;
  end;

  sgMembers.RowCount := sgMembers.FixedRows;
  Row := sgMembers.FixedRows;
  for Member in FMembers do
  begin
    sgMembers.RowCount := Row + 1;
    sgMembers.Cells[0, Row] := Member.DisplayName;
    sgMembers.Cells[1, Row] := Member.Email;
    sgMembers.Cells[2, Row] := ProjectMemberRoleLabel(Member.Role);
    sgMembers.Objects[0, Row] := TObject(Member.UserId);
    Inc(Row);
  end;
  if sgMembers.RowCount = sgMembers.FixedRows then
  begin
    sgMembers.RowCount := sgMembers.FixedRows + 1;
    sgMembers.Rows[sgMembers.FixedRows].Clear;
  end;
  UpdateButtons;
end;

procedure TProjectMembersForm.ReloadUserPicker;
var
  Service: THttpTeamService;
  MemberIds: TDictionary<Integer, Byte>;
  Member: TProjectMember;
  User: TServerUser;
  I: Integer;
begin
  cboUserPicker.Items.Clear;
  cboUserPicker.Items.AddObject('(Manuell per E-Mail)', TObject(0));
  if not FCanCreateUsers then
    Exit;

  Service := THttpTeamService.Create(FClient);
  MemberIds := TDictionary<Integer, Byte>.Create;
  try
    FUsers := Service.ListUsers;
    for Member in FMembers do
      MemberIds.AddOrSetValue(Member.UserId, 1);
    for User in FUsers do
    begin
      if MemberIds.ContainsKey(User.Id) then
        Continue;
      I := cboUserPicker.Items.Add(Format('%s <%s>', [User.DisplayName, User.Email]));
      cboUserPicker.Items.Objects[I] := TObject(User.Id);
    end;
    cboUserPicker.ItemIndex := 0;
  finally
    MemberIds.Free;
    Service.Free;
  end;
end;

procedure TProjectMembersForm.cboUserPickerChange(Sender: TObject);
var
  UserId, I: Integer;
begin
  if cboUserPicker.ItemIndex < 0 then
    Exit;
  UserId := Integer(cboUserPicker.Items.Objects[cboUserPicker.ItemIndex]);
  if UserId <= 0 then
    Exit;
  for I := 0 to High(FUsers) do
    if FUsers[I].Id = UserId then
    begin
      edtEmail.Text := FUsers[I].Email;
      Break;
    end;
end;

procedure TProjectMembersForm.sgMembersSelectCell(Sender: TObject; ACol, ARow: Integer;
  var CanSelect: Boolean);
begin
  UpdateButtons;
end;

procedure TProjectMembersForm.btnAddClick(Sender: TObject);
var
  Service: THttpTeamService;
  Member: TProjectMember;
  Email: string;
begin
  Email := Trim(edtEmail.Text);
  if Email = '' then
  begin
    MessageDlg('Bitte eine E-Mail-Adresse angeben.', mtWarning, [mbOK], 0);
    Exit;
  end;
  Service := THttpTeamService.Create(FClient);
  try
    Member := Service.AddMember(FProjectId, Email, SelectedRoleCode);
    if Member.UserId = 0 then
    begin
      MessageDlg(Service.LastError, mtError, [mbOK], 0);
      Exit;
    end;
  finally
    Service.Free;
  end;
  edtEmail.Clear;
  ReloadMembers;
  ReloadUserPicker;
end;

procedure TProjectMembersForm.btnChangeRoleClick(Sender: TObject);
var
  UserId, I, MemberIndex: Integer;
  RoleDlg: TForm;
  lblUser, lblRole: TLabel;
  cboNewRole: TComboBox;
  btnOk, btnCancel: TButton;
  RoleValues: TArray<string>;
  Roles: TArray<string>;
  Role: string;
  Service: THttpTeamService;
  Updated: TProjectMember;
  CurrentRole: string;
  CurrentName: string;
begin
  UserId := SelectedUserId;
  if UserId <= 0 then
    Exit;

  CurrentRole := '';
  CurrentName := '';
  MemberIndex := -1;
  for I := 0 to High(FMembers) do
    if FMembers[I].UserId = UserId then
    begin
      CurrentRole := FMembers[I].Role;
      CurrentName := FMembers[I].DisplayName;
      MemberIndex := I;
      Break;
    end;
  if MemberIndex < 0 then
    Exit;

  RoleDlg := TForm.Create(Self);
  try
    RoleDlg.BorderStyle := bsDialog;
    RoleDlg.Caption := 'Rolle ändern';
    RoleDlg.ClientWidth := 360;
    RoleDlg.ClientHeight := 170;
    RoleDlg.Position := poOwnerFormCenter;

    lblUser := TLabel.Create(RoleDlg);
    lblUser.Parent := RoleDlg;
    lblUser.Left := 16;
    lblUser.Top := 16;
    lblUser.Caption := Format('Benutzer: %s', [CurrentName]);

    lblRole := TLabel.Create(RoleDlg);
    lblRole.Parent := RoleDlg;
    lblRole.Left := 16;
    lblRole.Top := 48;
    lblRole.Caption := 'Neue Rolle';

    cboNewRole := TComboBox.Create(RoleDlg);
    cboNewRole.Parent := RoleDlg;
    cboNewRole.Left := 16;
    cboNewRole.Top := 66;
    cboNewRole.Width := 328;
    cboNewRole.Style := csDropDownList;
    Roles := ProjectMemberRoleOptions;
    SetLength(RoleValues, 0);
    for Role in Roles do
    begin
      I := cboNewRole.Items.Add(ProjectMemberRoleLabel(Role));
      SetLength(RoleValues, Length(RoleValues) + 1);
      RoleValues[High(RoleValues)] := Role;
      if SameText(Role, CurrentRole) then
        cboNewRole.ItemIndex := I;
    end;
    if cboNewRole.ItemIndex < 0 then
      cboNewRole.ItemIndex := 0;

    btnOk := TButton.Create(RoleDlg);
    btnOk.Parent := RoleDlg;
    btnOk.Left := 168;
    btnOk.Top := 120;
    btnOk.Width := 85;
    btnOk.Caption := 'OK';
    btnOk.ModalResult := mrOk;
    btnOk.Default := True;

    btnCancel := TButton.Create(RoleDlg);
    btnCancel.Parent := RoleDlg;
    btnCancel.Left := 259;
    btnCancel.Top := 120;
    btnCancel.Width := 85;
    btnCancel.Caption := 'Abbrechen';
    btnCancel.ModalResult := mrCancel;
    btnCancel.Cancel := True;

    if RoleDlg.ShowModal <> mrOk then
      Exit;

    if (cboNewRole.ItemIndex < 0) or (cboNewRole.ItemIndex > High(RoleValues)) then
      Exit;

    Service := THttpTeamService.Create(FClient);
    try
      Updated := Service.UpdateMemberRole(FProjectId, UserId, RoleValues[cboNewRole.ItemIndex]);
      if Updated.UserId = 0 then
      begin
        MessageDlg(Service.LastError, mtError, [mbOK], 0);
        Exit;
      end;
    finally
      Service.Free;
    end;
    ReloadMembers;
  finally
    RoleDlg.Free;
  end;
end;

procedure TProjectMembersForm.btnRemoveClick(Sender: TObject);
var
  UserId, I: Integer;
  Member: TProjectMember;
  Found: Boolean;
  Service: THttpTeamService;
begin
  UserId := SelectedUserId;
  if UserId <= 0 then
    Exit;

  Found := False;
  FillChar(Member, SizeOf(Member), 0);
  for I := 0 to High(FMembers) do
    if FMembers[I].UserId = UserId then
    begin
      Member := FMembers[I];
      Found := True;
      Break;
    end;
  if not Found then
    Exit;

  if MessageDlg(Format('Soll "%s" (%s) wirklich aus dem Projekt entfernt werden?',
    [Member.DisplayName, Member.Email]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  Service := THttpTeamService.Create(FClient);
  try
    if not Service.RemoveMember(FProjectId, UserId) then
    begin
      MessageDlg(Service.LastError, mtError, [mbOK], 0);
      Exit;
    end;
  finally
    Service.Free;
  end;
  ReloadMembers;
  ReloadUserPicker;
end;

procedure TProjectMembersForm.btnCreateUserClick(Sender: TObject);
var
  Input: TCreateUserResult;
  Service: THttpTeamService;
  User: TServerUser;
begin
  if not TCreateUserForm.Execute(Self, Input) then
    Exit;
  Service := THttpTeamService.Create(FClient);
  try
    User := Service.CreateUser(Input.Email, Input.DisplayName, Input.Password, Input.IsAdmin);
    if User.Id = 0 then
    begin
      MessageDlg(Service.LastError, mtError, [mbOK], 0);
      Exit;
    end;
  finally
    Service.Free;
  end;
  MessageDlg(Format('Der Benutzer "%s" wurde angelegt. Sie können ihn jetzt dem Projekt hinzufügen.',
    [User.DisplayName]), mtInformation, [mbOK], 0);
  ReloadUserPicker;
end;

end.
