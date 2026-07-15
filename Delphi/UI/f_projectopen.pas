unit f_projectopen;



interface



uses

  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,

  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Grids, IsmsDomain, System.DateUtils;



type

  TProjectOpenForm = class(TForm)

    lblHint: TLabel;

    lstProjects: TListBox;

    btnOk: TButton;

    btnCancel: TButton;

    procedure btnOkClick(Sender: TObject);

    procedure lstProjectsDblClick(Sender: TObject);

  private

    FProjects: TArray<TProject>;

    function SelectedProject: TProject;

    class function FormatProjectLabel(const AProject: TProject; ARemote: Boolean): string;

  public

    class function Execute(const AProjects: TArray<TProject>; out ASelected: TProject;

      ARemote: Boolean = False): Boolean;

  end;



implementation



{$R *.dfm}



class function TProjectOpenForm.FormatProjectLabel(const AProject: TProject;

  ARemote: Boolean): string;

var

  DateText: string;

begin

  Result := AProject.Name;

  if ARemote then
    Result := Format('%s  [#%d]', [Result, AProject.Id]);

  if AProject.UpdatedAt <> 0.0 then
  begin

    DateText := FormatDateTime('dd.mm.yyyy hh:nn',

      TTimeZone.Local.ToLocalTime(AProject.UpdatedAt));

    Result := Format('%s  —  zuletzt bearbeitet: %s', [AProject.Name, DateText]);

  end;

  if ARemote and (Trim(AProject.Role) <> '') then

    Result := Result + Format('  [%s]', [ProjectMemberRoleLabel(AProject.Role)]);

end;



class function TProjectOpenForm.Execute(const AProjects: TArray<TProject>;

  out ASelected: TProject; ARemote: Boolean): Boolean;

var

  F: TProjectOpenForm;

  P: TProject;

begin

  F := TProjectOpenForm.Create(Application);

  try

    F.FProjects := AProjects;

    if ARemote then

      F.lblHint.Caption := 'Verfügbare IT-Grundschutz-Projekte auf dem Server.'

    else

      F.lblHint.Caption := 'IT-Grundschutz-Projekte in der lokalen Datenbank.';

    for P in AProjects do

      F.lstProjects.Items.Add(FormatProjectLabel(P, ARemote));

    if F.lstProjects.Items.Count > 0 then

      F.lstProjects.ItemIndex := 0;

    F.btnOk.Enabled := F.lstProjects.Items.Count > 0;

    Result := F.ShowModal = mrOk;

    if Result then

      ASelected := F.SelectedProject;

  finally

    F.Free;

  end;

end;



function TProjectOpenForm.SelectedProject: TProject;

begin

  if (lstProjects.ItemIndex >= 0) and (lstProjects.ItemIndex < Length(FProjects)) then

    Result := FProjects[lstProjects.ItemIndex]

  else

    FillChar(Result, SizeOf(Result), 0);

end;



procedure TProjectOpenForm.btnOkClick(Sender: TObject);

begin

  if lstProjects.ItemIndex < 0 then

  begin

    MessageDlg('Bitte ein Projekt auswählen.', mtWarning, [mbOK], 0);

    Exit;

  end;

  ModalResult := mrOk;

end;



procedure TProjectOpenForm.lstProjectsDblClick(Sender: TObject);

begin

  btnOkClick(Sender);

end;



end.


