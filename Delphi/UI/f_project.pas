unit f_project;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  IsmsDomain;

type
  TProjectForm = class(TForm)
    lblName: TLabel;
    edtName: TEdit;
    lblDescription: TLabel;
    memDescription: TMemo;
    rgVisibility: TRadioGroup;
    btnOk: TButton;
    btnCancel: TButton;
    procedure btnOkClick(Sender: TObject);
  private
    FProject: TProject;
    FEditMode: Boolean;
    chkWorkflow: TCheckBox;
    procedure ApplyExtraUi(AShowVisibility, AShowWorkflow: Boolean);
    function SelectedVisibility: string;
  public
    class function ExecuteCreate(var AProject: TProject;
      AShowVisibility: Boolean = False): Boolean;
    class function ExecuteEdit(var AProject: TProject;
      AShowVisibility: Boolean = False; AShowWorkflow: Boolean = False): Boolean;
  end;

implementation

{$R *.dfm}

procedure TProjectForm.ApplyExtraUi(AShowVisibility, AShowWorkflow: Boolean);
begin
  if chkWorkflow = nil then
  begin
    chkWorkflow := TCheckBox.Create(Self);
    chkWorkflow.Parent := Self;
    chkWorkflow.Left := 16;
    chkWorkflow.Width := 388;
    chkWorkflow.Height := 17;
    chkWorkflow.Caption := 'Pr'#$00FC'fkreislauf (Einreichen und Abnehmen von Bausteinen)';
    chkWorkflow.ShowHint := True;
    chkWorkflow.Hint :=
      'Wenn eingeschaltet, m'#$00FC'ssen Bausteine eingereicht und abgenommen werden. ' +
      'Ausgeschaltet bleibt der freie Bearbeitungsmodus.';
  end;
  rgVisibility.Visible := AShowVisibility;
  chkWorkflow.Visible := AShowWorkflow;
  if AShowVisibility and AShowWorkflow then
  begin
    chkWorkflow.Top := 286;
    ClientHeight := 360;
    btnOk.Top := 320;
    btnCancel.Top := 320;
  end
  else if AShowVisibility then
  begin
    ClientHeight := 330;
    btnOk.Top := 290;
    btnCancel.Top := 290;
  end
  else if AShowWorkflow then
  begin
    chkWorkflow.Top := 180;
    ClientHeight := 270;
    btnOk.Top := 230;
    btnCancel.Top := 230;
  end
  else
  begin
    ClientHeight := 240;
    btnOk.Top := 200;
    btnCancel.Top := 200;
  end;
end;

function TProjectForm.SelectedVisibility: string;
begin
  if rgVisibility.ItemIndex = 1 then
    Result := 'public'
  else
    Result := 'private';
end;

class function TProjectForm.ExecuteCreate(var AProject: TProject;
  AShowVisibility: Boolean): Boolean;
var
  F: TProjectForm;
begin
  F := TProjectForm.Create(Application);
  try
    F.FEditMode := False;
    F.Caption := 'Neues Projekt';
    F.edtName.Text := '';
    F.memDescription.Clear;
    F.rgVisibility.ItemIndex := 0;
    F.ApplyExtraUi(AShowVisibility, False);
    Result := F.ShowModal = mrOk;
    if Result then
      AProject := F.FProject;
  finally
    F.Free;
  end;
end;

class function TProjectForm.ExecuteEdit(var AProject: TProject;
  AShowVisibility, AShowWorkflow: Boolean): Boolean;
var
  F: TProjectForm;
begin
  F := TProjectForm.Create(Application);
  try
    F.FEditMode := True;
    F.Caption := 'Projekt bearbeiten';
    F.FProject := AProject;
    F.edtName.Text := AProject.Name;
    F.memDescription.Text := AProject.Description;
    if ProjectIsPublic(AProject) then
      F.rgVisibility.ItemIndex := 1
    else
      F.rgVisibility.ItemIndex := 0;
    F.ApplyExtraUi(AShowVisibility, AShowWorkflow);
    if AShowWorkflow then
      F.chkWorkflow.Checked := AProject.WorkflowEnabled;
    Result := F.ShowModal = mrOk;
    if Result then
      AProject := F.FProject;
  finally
    F.Free;
  end;
end;

procedure TProjectForm.btnOkClick(Sender: TObject);
begin
  if Trim(edtName.Text) = '' then
  begin
    MessageDlg('Bitte einen Projektnamen eingeben.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if FEditMode then
  begin
    FProject.Name := Trim(edtName.Text);
    FProject.Description := Trim(memDescription.Text);
    if rgVisibility.Visible then
      FProject.Visibility := SelectedVisibility;
    if (chkWorkflow <> nil) and chkWorkflow.Visible then
      FProject.WorkflowEnabled := chkWorkflow.Checked;
  end
  else
  begin
    FillChar(FProject, SizeOf(FProject), 0);
    FProject.Name := Trim(edtName.Text);
    FProject.Description := Trim(memDescription.Text);
    FProject.CatalogVersion := '2023';
    FProject.Visibility := SelectedVisibility;
  end;
  ModalResult := mrOk;
end;

end.
