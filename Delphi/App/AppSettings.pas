unit AppSettings;

interface

uses
  System.SysUtils, System.IniFiles, System.DateUtils, System.IOUtils, IsmsDomain, AppPaths;

type
  TAppSettings = record
    UseRemote: Boolean;
    ServerUrl: string;
    AccessToken: string;
    TokenExpiresAt: TDateTime;
    UserEmail: string;
    InsecureSkipTlsVerify: Boolean;
    class function Load: TAppSettings; static;
    procedure Save;
    function IsTokenExpired: Boolean;
    function HasStoredRemoteSession: Boolean;
  end;

implementation

const
  SETTINGS_FILE = 'settings.ini';

function SettingsFilePath: string;
begin
  Result := TPath.Combine(DataDirectory, SETTINGS_FILE);
end;

class function TAppSettings.Load: TAppSettings;
var
  Ini: TIniFile;
  Path: string;
begin
  Result.UseRemote := False;
  Result.ServerUrl := 'http://localhost:8080';
  Result.AccessToken := '';
  Result.TokenExpiresAt := 0;
  Result.UserEmail := '';
  Result.InsecureSkipTlsVerify := False;

  Path := SettingsFilePath;
  if not FileExists(Path) then
    Exit;

  Ini := TIniFile.Create(Path);
  try
    Result.UseRemote := Ini.ReadBool('Session', 'UseRemote', False);
    Result.ServerUrl := Ini.ReadString('Session', 'ServerUrl', Result.ServerUrl);
    Result.AccessToken := Ini.ReadString('Session', 'AccessToken', '');
    Result.TokenExpiresAt := IsoToDateTime(Ini.ReadString('Session', 'TokenExpiresAt', ''));
    Result.UserEmail := Ini.ReadString('Session', 'UserEmail', '');
    Result.InsecureSkipTlsVerify := Ini.ReadBool('Session', 'InsecureSkipTlsVerify', False);
  finally
    Ini.Free;
  end;
end;

procedure TAppSettings.Save;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(SettingsFilePath);
  try
    Ini.WriteBool('Session', 'UseRemote', UseRemote);
    Ini.WriteString('Session', 'ServerUrl', ServerUrl);
    Ini.WriteString('Session', 'AccessToken', AccessToken);
    Ini.WriteString('Session', 'TokenExpiresAt', DateTimeToIso(TokenExpiresAt));
    Ini.WriteString('Session', 'UserEmail', UserEmail);
    Ini.WriteBool('Session', 'InsecureSkipTlsVerify', InsecureSkipTlsVerify);
  finally
    Ini.Free;
  end;
end;

function TAppSettings.IsTokenExpired: Boolean;
begin
  if AccessToken = '' then
    Exit(True);
  if TokenExpiresAt <= 0 then
    Exit(True);
  Result := Now >= IncSecond(TokenExpiresAt, -60);
end;

function TAppSettings.HasStoredRemoteSession: Boolean;
begin
  Result := UseRemote and (AccessToken <> '') and not IsTokenExpired;
end;

end.
