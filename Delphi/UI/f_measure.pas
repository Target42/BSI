unit f_measure;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls,
  IsmsDomain;

type
  TMeasureForm = class(TForm)
    lblTitle: TLabel;
    edtTitle: TEdit;
    lblDescription: TLabel;
    memDescription: TMemo;
    lblResponsible: TLabel;
    edtResponsible: TEdit;
    lblDueDate: TLabel;
    dtpDueDate: TDateTimePicker;
    chkHasDueDate: TCheckBox;
    lblStatus: TLabel;
    cboStatus: TComboBox;
    btnOk: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure chkHasDueDateClick(Sender: TObject);
    procedure btnOkClick(Sender: TObject);
  private
    FMeasure: TMeasure;
    FEditMode: Boolean;
    FReadOnly: Boolean;
    procedure ApplyReadOnlyState;
  public
    class function ExecuteCreate(var AMeasure: TMeasure): Boolean;
    class function ExecuteEdit(var AMeasure: TMeasure): Boolean;
    class function ExecuteView(const AMeasure: TMeasure): Boolean;
  end;

implementation

{$R *.dfm}

procedure TMeasureForm.FormCreate(Sender: TObject);
begin
  cboStatus.Items.Clear;
  cboStatus.Items.Add(MeasureStatusToString(msOpen));
  cboStatus.Items.Add(MeasureStatusToString(msInProgress));
  cboStatus.Items.Add(MeasureStatusToString(msDone));
  dtpDueDate.Date := Date;
end;

procedure TMeasureForm.chkHasDueDateClick(Sender: TObject);
begin
  dtpDueDate.Enabled := chkHasDueDate.Checked;
end;

procedure TMeasureForm.ApplyReadOnlyState;
begin
  edtTitle.ReadOnly := FReadOnly;
  memDescription.ReadOnly := FReadOnly;
  edtResponsible.ReadOnly := FReadOnly;
  chkHasDueDate.Enabled := not FReadOnly;
  dtpDueDate.Enabled := not FReadOnly and chkHasDueDate.Checked;
  cboStatus.Enabled := not FReadOnly;
  if FReadOnly then
  begin
    btnOk.Caption := 'Schließen';
    btnCancel.Visible := False;
  end;
end;

class function TMeasureForm.ExecuteView(const AMeasure: TMeasure): Boolean;
var
  F: TMeasureForm;
begin
  F := TMeasureForm.Create(Application);
  try
    F.FEditMode := False;
    F.FReadOnly := True;
    F.Caption := 'Maßnahme anzeigen';
    F.FMeasure := AMeasure;
    F.edtTitle.Text := AMeasure.Title;
    F.memDescription.Text := AMeasure.Description;
    F.edtResponsible.Text := AMeasure.Responsible;
    F.chkHasDueDate.Checked := IsValidDate(AMeasure.DueDate);
    F.dtpDueDate.Enabled := F.chkHasDueDate.Checked;
    if F.chkHasDueDate.Checked then
      F.dtpDueDate.Date := AMeasure.DueDate;
    F.cboStatus.ItemIndex := Ord(AMeasure.Status);
    F.ApplyReadOnlyState;
    Result := F.ShowModal = mrOk;
  finally
    F.Free;
  end;
end;

class function TMeasureForm.ExecuteCreate(var AMeasure: TMeasure): Boolean;
var
  F: TMeasureForm;
begin
  F := TMeasureForm.Create(Application);
  try
    F.FEditMode := False;
    F.FReadOnly := False;
    F.Caption := 'Maßnahme hinzufügen';
    F.FMeasure := AMeasure;
    F.edtTitle.Text := '';
    F.memDescription.Clear;
    F.edtResponsible.Text := '';
    F.chkHasDueDate.Checked := False;
    F.dtpDueDate.Enabled := False;
    F.cboStatus.ItemIndex := 0;
    Result := F.ShowModal = mrOk;
    if Result then
      AMeasure := F.FMeasure;
  finally
    F.Free;
  end;
end;

class function TMeasureForm.ExecuteEdit(var AMeasure: TMeasure): Boolean;
var
  F: TMeasureForm;
begin
  F := TMeasureForm.Create(Application);
  try
    F.FEditMode := True;
    F.FReadOnly := False;
    F.Caption := 'Maßnahme bearbeiten';
    F.FMeasure := AMeasure;
    F.edtTitle.Text := AMeasure.Title;
    F.memDescription.Text := AMeasure.Description;
    F.edtResponsible.Text := AMeasure.Responsible;
    F.chkHasDueDate.Checked := IsValidDate(AMeasure.DueDate);
    F.dtpDueDate.Enabled := F.chkHasDueDate.Checked;
    if F.chkHasDueDate.Checked then
      F.dtpDueDate.Date := AMeasure.DueDate;
    F.cboStatus.ItemIndex := Ord(AMeasure.Status);
    Result := F.ShowModal = mrOk;
    if Result then
      AMeasure := F.FMeasure;
  finally
    F.Free;
  end;
end;

procedure TMeasureForm.btnOkClick(Sender: TObject);
begin
  if FReadOnly then
  begin
    ModalResult := mrOk;
    Exit;
  end;
  if Trim(edtTitle.Text) = '' then
  begin
    MessageDlg('Bitte einen Titel eingeben.', mtWarning, [mbOK], 0);
    Exit;
  end;
  FMeasure.Title := Trim(edtTitle.Text);
  FMeasure.Description := Trim(memDescription.Text);
  FMeasure.Responsible := Trim(edtResponsible.Text);
  if chkHasDueDate.Checked then
    FMeasure.DueDate := dtpDueDate.Date
  else
    FMeasure.DueDate := 0;
  if cboStatus.ItemIndex >= 0 then
    FMeasure.Status := TMeasureStatus(cboStatus.ItemIndex);
  ModalResult := mrOk;
end;

end.
