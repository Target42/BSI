program BSIClient;



uses

  Vcl.Forms,

  System.SysUtils,

  AppPaths in 'App\AppPaths.pas',

  AppSettings in 'App\AppSettings.pas',

  AppSession in 'App\AppSession.pas',

  AppContext in 'App\AppContext.pas',

  IsmsDomain in 'Domain\IsmsDomain.pas',

  IsmsDatabase in 'Persistence\IsmsDatabase.pas',

  RepositoryBase in 'Persistence\RepositoryBase.pas',

  CatalogRepository in 'Persistence\CatalogRepository.pas',

  ProjectRepository in 'Persistence\ProjectRepository.pas',

  TargetObjectRepository in 'Persistence\TargetObjectRepository.pas',

  MeasureRepository in 'Persistence\MeasureRepository.pas',

  ApiClient in 'Net\ApiClient.pas',

  HttpJson in 'Net\HttpJson.pas',

  HttpCatalogRepository in 'Net\HttpCatalogRepository.pas',

  HttpProjectRepository in 'Net\HttpProjectRepository.pas',

  HttpTargetObjectRepository in 'Net\HttpTargetObjectRepository.pas',

  HttpMeasureRepository in 'Net\HttpMeasureRepository.pas',

  HttpTeamService in 'Net\HttpTeamService.pas',

  GrundschutzImporter in 'Catalog\GrundschutzImporter.pas',

  RequirementTextFormatter in 'Catalog\RequirementTextFormatter.pas',

  ReportService in 'Services\ReportService.pas',

  ReportExporter in 'Services\ReportExporter.pas',

  BausteinRecommendationService in 'Services\BausteinRecommendationService.pas',

  f_login in 'UI\f_login.pas' {LoginForm},

  f_project in 'UI\f_project.pas' {ProjectForm},

  f_projectopen in 'UI\f_projectopen.pas' {ProjectOpenForm},

  f_targetobject in 'UI\f_targetobject.pas' {TargetObjectForm},

  f_measure in 'UI\f_measure.pas' {MeasureForm},

  f_report in 'UI\f_report.pas' {ReportForm},

  f_bausteinview in 'UI\f_bausteinview.pas' {BausteinViewForm},

  f_catalogsearch in 'UI\f_catalogsearch.pas' {CatalogSearchForm},

  f_bausteinrecommendation in 'UI\f_bausteinrecommendation.pas' {BausteinRecommendationForm},

  f_createuser in 'UI\f_createuser.pas' {CreateUserForm},

  f_projectmembers in 'UI\f_projectmembers.pas' {ProjectMembersForm},

  f_main in 'f_main.pas' {MainForm},

  Vcl.Controls,

  Vcl.Dialogs;



{$R *.res}



var

  Context: TAppContext;

  Login: TLoginForm;

  Settings: TAppSettings;



begin

  Application.Initialize;

  Application.MainFormOnTaskbar := True;



  Login := TLoginForm.Create(nil);

  try

    if not Login.TrySilentLogin then

      if Login.ShowModal <> mrOk then

        Exit;

    Settings := Login.Settings;

  finally

    Login.Free;

  end;



  Context := TAppContext.Create;

  try

    if Settings.UseRemote then

    begin

      if not Context.InitializeRemote(Settings) then

      begin

        MessageDlg('Verbindung zum Server fehlgeschlagen:' + sLineBreak + Context.LastError,

          mtError, [mbOK], 0);

        Exit;

      end;

    end

    else if not Context.InitializeLocal then

    begin

      MessageDlg('Datenbank konnte nicht geöffnet werden:' + sLineBreak +

        Context.LastError + sLineBreak + sLineBreak +

        'Datei: ' + DatabaseFile, mtError, [mbOK], 0);

      Exit;

    end;



    if not Context.EnsureGrundschutzCatalog(DefaultGrundschutzXml) then

      MessageDlg(Context.LastError + sLineBreak + sLineBreak +

        'Sie können den Katalog später über "Datei → IT-Grundschutz XML importieren" laden.',

        mtWarning, [mbOK], 0);



    Application.CreateForm(TMainForm, MainForm);

    MainForm.AppContext := Context;



    Application.Run;

  finally

    Context.Free;

  end;

end.

