unit f_project;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, IsmsDomain;

type
  TProjectForm = class(TForm)
    lblName: TLabel;
    edtName: TEdit;
    lblDescription: TLabel;
    memDescription: TMemo;
    btnOk: TButton;
    btnCancel: TButton;
    procedure btnOkClick(Sender: TObject);
  private
    FProject: TProject;
    FEditMode: Boolean;
  public
    class function ExecuteCreate(var AProject: TProject): Boolean;
    class function ExecuteEdit(var AProject: TProject): Boolean;
  end;

implementation

{$R *.dfm}

class function TProjectForm.ExecuteCreate(var AProject: TProject): Boolean;
var
  F: TProjectForm;
begin
  F := TProjectForm.Create(Application);
  try
    F.FEditMode := False;
    F.Caption := 'Neues Projekt';
    F.edtName.Text := '';
    F.memDescription.Clear;
    Result := F.ShowModal = mrOk;
    if Result then
      AProject := F.FProject;
  finally
    F.Free;
  end;
end;

class function TProjectForm.ExecuteEdit(var AProject: TProject): Boolean;
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
  end
  else
  begin
    FillChar(FProject, SizeOf(FProject), 0);
    FProject.Name := Trim(edtName.Text);
    FProject.Description := Trim(memDescription.Text);
    FProject.CatalogVersion := '2023';
  end;
  ModalResult := mrOk;
end;

end.
