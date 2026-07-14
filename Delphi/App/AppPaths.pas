unit AppPaths;

interface

function DataDirectory: string;
function DatabaseFile: string;
function DefaultGrundschutzXml: string;

implementation

uses
  System.IOUtils, Winapi.Windows, Winapi.SHFolder, System.SysUtils;

function GetKnownFolderPath(CSIDL: Integer): string;
var
  Path: array[0..MAX_PATH] of Char;
begin
  if SHGetFolderPath(0, CSIDL, 0, SHGFP_TYPE_CURRENT, Path) = S_OK then
    Result := IncludeTrailingPathDelimiter(string(Path))
  else
    Result := '';
end;

function DataDirectory: string;
var
  Base: string;
begin
  Base := GetKnownFolderPath(CSIDL_APPDATA);
  if Base = '' then
    Exit('');
  Result := TPath.Combine(Base, 'BSI-Tools\ISMS');
  if not TDirectory.Exists(Result) then
    TDirectory.CreateDirectory(Result);
end;

function DatabaseFile: string;
begin
  Result := TPath.Combine(DataDirectory, 'isms.db');
end;

function DefaultGrundschutzXml: string;
var
  Docs: string;
begin
  Docs := TPath.GetDocumentsPath;
  Result := TPath.Combine(Docs, 'XML_Kompendium_2023.xml');
end;

end.
