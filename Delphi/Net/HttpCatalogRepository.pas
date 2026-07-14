unit HttpCatalogRepository;

interface

uses
  System.SysUtils, System.JSON, System.Generics.Collections, IsmsDomain, GrundschutzImporter,
  RepositoryBase, ApiClient, HttpJson;

type
  THttpCatalogRepository = class(TCatalogRepositoryBase)
  private
    FClient: TApiClient;
    FLastError: string;
  public
    constructor Create(AClient: TApiClient);
    function ReplaceGrundschutzCatalog(const AImportResult: TGrundschutzImportResult;
      const ASourceXmlPath: string = ''): Boolean; override;
    function HasGrundschutzCatalog(const ACatalogVersion: string): Boolean; override;
    function LoadBausteine(AStandard: TStandardType; const ACatalogVersion: string): TArray<TBaustein>; override;
    function LoadRequirements(ABausteinDbId: Integer): TArray<TRequirement>; override;
    function LoadAllRequirements(AStandard: TStandardType; const ACatalogVersion: string): TArray<TRequirement>; override;
    function GetLastError: string; override;
  end;

implementation

constructor THttpCatalogRepository.Create(AClient: TApiClient);
begin
  inherited Create;
  FClient := AClient;
end;

function THttpCatalogRepository.ReplaceGrundschutzCatalog(const AImportResult: TGrundschutzImportResult;
  const ASourceXmlPath: string): Boolean;
var
  Doc: TJSONValue;
  Status: Integer;
begin
  Result := False;
  if ASourceXmlPath = '' then
  begin
    FLastError := 'Kein Importpfad gesetzt.';
    Exit;
  end;
  Doc := FClient.UploadFile('/api/v1/admin/catalog/import', 'file', ASourceXmlPath, Status);
  try
    if Status <> 200 then
    begin
      FLastError := FClient.LastError;
      if (Doc is TJSONObject) and TJSONObject(Doc).TryGetValue<string>('message', FLastError) then
        ;
      Exit;
    end;
    Result := True;
  finally
    Doc.Free;
  end;
end;

function THttpCatalogRepository.HasGrundschutzCatalog(const ACatalogVersion: string): Boolean;
var
  Doc: TJSONValue;
  Arr: TJSONArray;
  I: Integer;
  Status: Integer;
begin
  Result := False;
  Doc := FClient.Get('/api/v1/catalog/versions', Status);
  try
    if (Status <> 200) or not (Doc is TJSONArray) then
    begin
      FLastError := FClient.LastError;
      Exit;
    end;
    Arr := TJSONArray(Doc);
    for I := 0 to Arr.Count - 1 do
      if Arr.Items[I].Value = ACatalogVersion then
        Exit(True);
  finally
    Doc.Free;
  end;
end;

function THttpCatalogRepository.LoadBausteine(AStandard: TStandardType;
  const ACatalogVersion: string): TArray<TBaustein>;
var
  Doc: TJSONValue;
  Arr: TJSONArray;
  I: Integer;
  List: TArray<TBaustein>;
  Status: Integer;
begin
  SetLength(List, 0);
  Doc := FClient.Get(Format('/api/v1/catalog/%s/bausteine', [ACatalogVersion]), Status);
  try
    if (Status <> 200) or not (Doc is TJSONArray) then
    begin
      FLastError := FClient.LastError;
      Exit;
    end;
    Arr := TJSONArray(Doc);
    SetLength(List, Arr.Count);
    for I := 0 to Arr.Count - 1 do
      if Arr.Items[I] is TJSONObject then
        List[I] := BausteinFromJson(TJSONObject(Arr.Items[I]));
  finally
    Doc.Free;
  end;
  Result := List;
end;

function THttpCatalogRepository.LoadRequirements(ABausteinDbId: Integer): TArray<TRequirement>;
var
  Doc: TJSONValue;
  Arr: TJSONArray;
  I: Integer;
  List: TArray<TRequirement>;
  Status: Integer;
begin
  SetLength(List, 0);
  Doc := FClient.Get(Format('/api/v1/catalog/bausteine/%d/requirements', [ABausteinDbId]), Status);
  try
    if (Status <> 200) or not (Doc is TJSONArray) then
    begin
      FLastError := FClient.LastError;
      Exit;
    end;
    Arr := TJSONArray(Doc);
    SetLength(List, Arr.Count);
    for I := 0 to Arr.Count - 1 do
      if Arr.Items[I] is TJSONObject then
        List[I] := RequirementFromJson(TJSONObject(Arr.Items[I]));
  finally
    Doc.Free;
  end;
  Result := List;
end;

function THttpCatalogRepository.LoadAllRequirements(AStandard: TStandardType;
  const ACatalogVersion: string): TArray<TRequirement>;
var
  Bausteine: TArray<TBaustein>;
  B: TBaustein;
  ReqList, AllList: TArray<TRequirement>;
  I, Offset: Integer;
begin
  SetLength(AllList, 0);
  Bausteine := LoadBausteine(AStandard, ACatalogVersion);
  for B in Bausteine do
  begin
    ReqList := LoadRequirements(B.Id);
    if Length(ReqList) = 0 then
      Continue;
    Offset := Length(AllList);
    SetLength(AllList, Offset + Length(ReqList));
    for I := 0 to High(ReqList) do
      AllList[Offset + I] := ReqList[I];
  end;
  Result := AllList;
end;

function THttpCatalogRepository.GetLastError: string;
begin
  if FLastError <> '' then
    Exit(FLastError);
  Result := FClient.LastError;
end;

end.
