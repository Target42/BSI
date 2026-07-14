unit AppContext;



interface



uses

  System.SysUtils, IsmsDomain, AppSettings, AppPaths, IsmsDatabase,

  RepositoryBase, CatalogRepository, ProjectRepository, TargetObjectRepository, MeasureRepository,

  GrundschutzImporter, ApiClient, HttpCatalogRepository, HttpProjectRepository,

  HttpTargetObjectRepository, HttpMeasureRepository, HttpTeamService;



type

  TReloginHandler = ApiClient.TReloginHandler;



  TAppContext = class

  private

    FDatabase: TIsmsDatabase;

    FApiClient: TApiClient;

    FCatalogRepo: TCatalogRepositoryBase;

    FProjectRepo: TProjectRepositoryBase;

    FTargetRepo: TTargetObjectRepositoryBase;

    FMeasureRepo: TMeasureRepositoryBase;

    FCatalogVersion: string;

    FLastError: string;

    FRemote: Boolean;

    FRemoteUser: TServerUser;

    FSettings: TAppSettings;

    procedure ResetRepositories;

    procedure RestoreSession(const ASettings: TAppSettings);

  public

    constructor Create;

    destructor Destroy; override;

    function InitializeLocal: Boolean;

    function InitializeRemote(const ASettings: TAppSettings): Boolean;

    function UpdateRemoteSession(const ASettings: TAppSettings): Boolean;

    function PromptRelogin: Boolean;

    function PromptSwitchUser: Boolean;

    procedure SetReloginHandler(AHandler: TReloginHandler);

    function EnsureGrundschutzCatalog(const AXmlPath: string): Boolean;

    function ImportCatalogFile(const AXmlPath: string): Boolean;

    function CatalogVersion: string;

    function IsRemote: Boolean;

    function LastError: string;

    function RemoteUser: TServerUser;

    function IsRemoteAdmin: Boolean;

    function Settings: TAppSettings;

    property CatalogRepository: TCatalogRepositoryBase read FCatalogRepo;

    property ProjectRepository: TProjectRepositoryBase read FProjectRepo;

    property TargetObjectRepository: TTargetObjectRepositoryBase read FTargetRepo;

    property MeasureRepository: TMeasureRepositoryBase read FMeasureRepo;

    property ApiClient: TApiClient read FApiClient;

  end;



implementation



uses
  System.JSON, System.UITypes, f_login;



constructor TAppContext.Create;

begin

  inherited Create;

  FCatalogVersion := '2023';

  FRemote := False;

end;



destructor TAppContext.Destroy;

begin

  ResetRepositories;

  inherited;

end;



procedure TAppContext.ResetRepositories;

begin

  FMeasureRepo.Free;

  FTargetRepo.Free;

  FProjectRepo.Free;

  FCatalogRepo.Free;

  FApiClient.Free;

  FDatabase.Free;

  FMeasureRepo := nil;

  FTargetRepo := nil;

  FProjectRepo := nil;

  FCatalogRepo := nil;

  FApiClient := nil;

  FDatabase := nil;

  FRemote := False;

  FillChar(FRemoteUser, SizeOf(FRemoteUser), 0);

end;



procedure TAppContext.RestoreSession(const ASettings: TAppSettings);

begin

  ResetRepositories;

  if ASettings.UseRemote and ASettings.HasStoredRemoteSession then

    InitializeRemote(ASettings)

  else

    InitializeLocal;

end;



function TAppContext.InitializeLocal: Boolean;

begin

  ResetRepositories;

  FRemote := False;

  FSettings := TAppSettings.Load;

  FSettings.UseRemote := False;

  FDatabase := TIsmsDatabase.Create(DatabaseFile);

  if not FDatabase.Open then

  begin

    FLastError := FDatabase.LastError;

    Exit(False);

  end;

  FCatalogRepo := TCatalogRepository.Create(FDatabase.Connection);

  FProjectRepo := TProjectRepository.Create(FDatabase.Connection);

  FTargetRepo := TTargetObjectRepository.Create(FDatabase.Connection);

  FMeasureRepo := TMeasureRepository.Create(FDatabase.Connection);

  Result := True;

end;



function TAppContext.InitializeRemote(const ASettings: TAppSettings): Boolean;

var

  Team: THttpTeamService;

begin

  ResetRepositories;

  FRemote := True;

  FSettings := ASettings;

  FApiClient := TApiClient.Create(ASettings.ServerUrl);

  FApiClient.SetAccessToken(ASettings.AccessToken);

  FApiClient.SetTokenExpiresAt(ASettings.TokenExpiresAt);

  FApiClient.SetInsecureSkipTlsVerify(ASettings.InsecureSkipTlsVerify);

  FCatalogRepo := THttpCatalogRepository.Create(FApiClient);

  FProjectRepo := THttpProjectRepository.Create(FApiClient);

  FTargetRepo := THttpTargetObjectRepository.Create(FApiClient);

  FMeasureRepo := THttpMeasureRepository.Create(FApiClient);

  Team := THttpTeamService.Create(FApiClient);

  try

    if not Team.FetchCurrentUser(FRemoteUser) then

    begin

      FLastError := Team.LastError;

      ResetRepositories;

      Exit(False);

    end;

  finally

    Team.Free;

  end;

  Result := True;

end;



function TAppContext.UpdateRemoteSession(const ASettings: TAppSettings): Boolean;

var

  Team: THttpTeamService;

begin

  Result := False;

  if not FRemote or (FApiClient = nil) then

    Exit;

  FApiClient.SetBaseUrl(ASettings.ServerUrl);

  FApiClient.SetAccessToken(ASettings.AccessToken);

  FApiClient.SetTokenExpiresAt(ASettings.TokenExpiresAt);

  FApiClient.SetInsecureSkipTlsVerify(ASettings.InsecureSkipTlsVerify);

  FSettings := ASettings;

  FSettings.Save;

  Team := THttpTeamService.Create(FApiClient);

  try

    if not Team.FetchCurrentUser(FRemoteUser) then

    begin

      FLastError := Team.LastError;

      Exit;

    end;

    Result := True;

  finally

    Team.Free;

  end;

end;



procedure TAppContext.SetReloginHandler(AHandler: TReloginHandler);

begin

  if FApiClient <> nil then

    FApiClient.ReloginHandler := AHandler;

end;



function TAppContext.PromptRelogin: Boolean;

var

  Login: TLoginForm;

begin

  Result := False;

  if not FRemote then

    Exit;

  Login := TLoginForm.Create(nil);

  try

    Login.SetReloginMode;

    if Login.ShowModal <> mrOk then

      Exit;

    Result := UpdateRemoteSession(Login.Settings);

  finally

    Login.Free;

  end;

end;



function TAppContext.PromptSwitchUser: Boolean;

var

  Login: TLoginForm;

  NewSettings: TAppSettings;

begin

  Result := False;

  NewSettings := TAppSettings.Load;

  NewSettings.AccessToken := '';

  NewSettings.TokenExpiresAt := 0;

  Login := TLoginForm.Create(nil);

  try

    Login.InitializeSettings(NewSettings);

    Login.SetSwitchUserMode;

    if Login.ShowModal <> mrOk then

      Exit;

    NewSettings := Login.Settings;

    NewSettings.Save;

    if NewSettings.UseRemote then

      Result := InitializeRemote(NewSettings)

    else

      Result := InitializeLocal;

    if not Result then

      RestoreSession(TAppSettings.Load);

  finally

    Login.Free;

  end;

end;



function TAppContext.ImportCatalogFile(const AXmlPath: string): Boolean;

var

  ImportResult: TGrundschutzImportResult;

  Doc: TJSONValue;

  Status: Integer;

begin

  if FRemote then

  begin

    if not FileExists(AXmlPath) then

    begin

      FLastError := 'Datei nicht gefunden: ' + AXmlPath;

      Exit(False);

    end;

    Doc := FApiClient.UploadFile('/api/v1/admin/catalog/import', 'file', AXmlPath, Status);

    try

      if Status <> 200 then

      begin

        FLastError := FApiClient.LastError;

        Exit(False);

      end;

      Result := True;

    finally

      Doc.Free;

    end;

    Exit;

  end;



  ImportResult := TGrundschutzImporter.ImportFromFile(AXmlPath);

  if not ImportResult.Success then

  begin

    FLastError := ImportResult.ErrorMessage;

    Exit(False);

  end;

  if not FCatalogRepo.ReplaceGrundschutzCatalog(ImportResult) then

  begin

    FLastError := FCatalogRepo.LastError;

    Exit(False);

  end;

  FCatalogVersion := ImportResult.CatalogVersion;

  Result := True;

end;



function TAppContext.EnsureGrundschutzCatalog(const AXmlPath: string): Boolean;

begin

  if FCatalogRepo.HasGrundschutzCatalog(FCatalogVersion) then

    Exit(True);

  if FRemote then

    Exit(ImportCatalogFile(AXmlPath));

  if not FileExists(AXmlPath) then

  begin

    FLastError := 'IT-Grundschutz-Katalog nicht gefunden.';

    Exit(False);

  end;

  Result := ImportCatalogFile(AXmlPath);

end;



function TAppContext.CatalogVersion: string;

begin

  Result := FCatalogVersion;

end;



function TAppContext.IsRemote: Boolean;

begin

  Result := FRemote;

end;



function TAppContext.LastError: string;

begin

  Result := FLastError;

end;



function TAppContext.RemoteUser: TServerUser;

begin

  Result := FRemoteUser;

end;



function TAppContext.IsRemoteAdmin: Boolean;

begin

  Result := FRemote and FRemoteUser.IsAdmin;

end;



function TAppContext.Settings: TAppSettings;

begin

  Result := FSettings;

end;



end.

