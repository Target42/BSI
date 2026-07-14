unit HttpTargetObjectRepository;

interface

uses
  System.SysUtils, System.JSON, System.Generics.Collections, IsmsDomain,
  RepositoryBase, ApiClient, HttpJson;

type
  THttpTargetObjectRepository = class(TTargetObjectRepositoryBase)
  private
    FClient: TApiClient;
    FLastError: string;
  public
    constructor Create(AClient: TApiClient);
    function LoadTargetObjects(AProjectId: Integer): TArray<TTargetObject>; override;
    function CreateTargetObject(const ATargetObject: TTargetObject): TTargetObject; override;
    function UpdateTargetObject(const ATargetObject: TTargetObject): Boolean; override;
    function DeleteTargetObject(ATargetObjectId: Integer): Boolean; override;
    function CreateDefaultScope(AProjectId: Integer; const AProjectName: string): TTargetObject; override;
    function LoadApplicabilityMap(AProjectId, ATargetObjectId: Integer): TDictionary<Integer, TApplicabilityStatus>; override;
    function Applicability(AProjectId, ATargetObjectId, ABausteinDbId: Integer): TApplicabilityStatus; override;
    function SaveApplicability(const AApplicability: TBausteinApplicability): Boolean; override;
    function GetLastError: string; override;
  end;

implementation

constructor THttpTargetObjectRepository.Create(AClient: TApiClient);
begin
  inherited Create;
  FClient := AClient;
end;

function THttpTargetObjectRepository.LoadTargetObjects(AProjectId: Integer): TArray<TTargetObject>;
var
  Doc: TJSONValue;
  Arr: TJSONArray;
  I: Integer;
  List: TArray<TTargetObject>;
  Status: Integer;
begin
  SetLength(List, 0);
  Doc := FClient.Get(Format('/api/v1/projects/%d/target-objects', [AProjectId]), Status);
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
        List[I] := TargetObjectFromJson(TJSONObject(Arr.Items[I]));
  finally
    Doc.Free;
  end;
  Result := List;
end;

function THttpTargetObjectRepository.CreateTargetObject(const ATargetObject: TTargetObject): TTargetObject;
var
  Body: TJSONObject;
  Doc: TJSONValue;
  Status: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  Body := TJSONObject.Create;
  try
    Body.AddPair('parentId', TJSONNumber.Create(ATargetObject.ParentId));
    Body.AddPair('type', TargetObjectTypeToString(ATargetObject.ObjType));
    Body.AddPair('protectionNeed', ProtectionNeedToString(ATargetObject.ProtectionNeed));
    Body.AddPair('name', ATargetObject.Name);
    Body.AddPair('description', ATargetObject.Description);
    Doc := FClient.PostJson(Format('/api/v1/projects/%d/target-objects', [ATargetObject.ProjectId]), Body, Status);
    try
      if (Status <> 201) or not (Doc is TJSONObject) then
      begin
        FLastError := FClient.LastError;
        Exit;
      end;
      Result := TargetObjectFromJson(TJSONObject(Doc));
    finally
      Doc.Free;
    end;
  finally
    Body.Free;
  end;
end;

function THttpTargetObjectRepository.UpdateTargetObject(const ATargetObject: TTargetObject): Boolean;
var
  Body: TJSONObject;
  Doc: TJSONValue;
  Status: Integer;
begin
  Result := False;
  Body := TJSONObject.Create;
  try
    Body.AddPair('parentId', TJSONNumber.Create(ATargetObject.ParentId));
    Body.AddPair('type', TargetObjectTypeToString(ATargetObject.ObjType));
    Body.AddPair('protectionNeed', ProtectionNeedToString(ATargetObject.ProtectionNeed));
    Body.AddPair('name', ATargetObject.Name);
    Body.AddPair('description', ATargetObject.Description);
    Doc := FClient.PatchJson(Format('/api/v1/target-objects/%d', [ATargetObject.Id]), Body, Status);
    try
      if Status <> 200 then
        FLastError := FClient.LastError
      else
        Result := True;
    finally
      Doc.Free;
    end;
  finally
    Body.Free;
  end;
end;

function THttpTargetObjectRepository.DeleteTargetObject(ATargetObjectId: Integer): Boolean;
var
  Status: Integer;
begin
  Result := FClient.Delete(Format('/api/v1/target-objects/%d', [ATargetObjectId]), Status) and (Status = 204);
  if not Result then
    FLastError := FClient.LastError;
end;

function THttpTargetObjectRepository.CreateDefaultScope(AProjectId: Integer;
  const AProjectName: string): TTargetObject;
var
  Objects: TArray<TTargetObject>;
  O: TTargetObject;
  Scope: TTargetObject;
begin
  FillChar(Result, SizeOf(Result), 0);
  Objects := LoadTargetObjects(AProjectId);
  for O in Objects do
    if O.ObjType = totScope then
      Exit(O);
  FillChar(Scope, SizeOf(Scope), 0);
  Scope.ProjectId := AProjectId;
  Scope.ObjType := totScope;
  Scope.Name := AProjectName;
  Result := CreateTargetObject(Scope);
end;

function JsonStatusText(AValue: TJSONValue): string;
begin
  Result := '';
  if AValue = nil then
    Exit;
  if AValue is TJSONString then
    Exit(TJSONString(AValue).Value);
  Result := AValue.Value;
end;

function THttpTargetObjectRepository.LoadApplicabilityMap(AProjectId,
  ATargetObjectId: Integer): TDictionary<Integer, TApplicabilityStatus>;
var
  Doc: TJSONValue;
  Obj: TJSONObject;
  Pair: TJSONPair;
  Status: Integer;
  BausteinId: Integer;
  StatusText: string;
  ParsedStatus: TApplicabilityStatus;
  I: Integer;
begin
  Result := TDictionary<Integer, TApplicabilityStatus>.Create;
  Doc := FClient.Get(
    Format('/api/v1/projects/%d/target-objects/%d/applicability', [AProjectId, ATargetObjectId]),
    Status);
  try
    if Status <> 200 then
    begin
      FLastError := FClient.LastError;
      Exit;
    end;
    if (Doc = nil) or (Doc is TJSONNull) then
      Exit;
    if not (Doc is TJSONObject) then
    begin
      FLastError := 'Ungültige Applicability-Antwort vom Server.';
      Exit;
    end;
    Obj := TJSONObject(Doc);
    for I := 0 to Obj.Count - 1 do
    begin
      Pair := Obj.Pairs[I];
      BausteinId := StrToIntDef(Pair.JsonString.Value, 0);
      if BausteinId <= 0 then
        Continue;
      StatusText := JsonStatusText(Pair.JsonValue);
      ParsedStatus := ApplicabilityStatusFromString(StatusText);
      Result.AddOrSetValue(BausteinId, ParsedStatus);
    end;
  finally
    Doc.Free;
  end;
end;

function THttpTargetObjectRepository.Applicability(AProjectId, ATargetObjectId,
  ABausteinDbId: Integer): TApplicabilityStatus;
var
  Map: TDictionary<Integer, TApplicabilityStatus>;
begin
  Result := apUndefined;
  Map := LoadApplicabilityMap(AProjectId, ATargetObjectId);
  try
    if not Map.TryGetValue(ABausteinDbId, Result) then
      Result := apUndefined;
  finally
    Map.Free;
  end;
end;

function THttpTargetObjectRepository.SaveApplicability(const AApplicability: TBausteinApplicability): Boolean;
var
  Body: TJSONObject;
  Doc: TJSONValue;
  Status: Integer;
  Path: string;
begin
  Result := False;
  Path := Format('/api/v1/projects/%d/target-objects/%d/bausteine/%d/applicability',
    [AApplicability.ProjectId, AApplicability.TargetObjectId, AApplicability.BausteinDbId]);

  if AApplicability.Status = apUndefined then
  begin
    Result := FClient.Delete(Path, Status) and (Status = 204);
    if not Result then
      FLastError := FClient.LastError;
    Exit;
  end;

  Body := TJSONObject.Create;
  try
    Body.AddPair('status', ApplicabilityStatusToString(AApplicability.Status));
    Doc := FClient.PutJson(Path, Body, Status);
    try
      if Status <> 200 then
        FLastError := FClient.LastError
      else
        Result := True;
    finally
      Doc.Free;
    end;
  finally
    Body.Free;
  end;
end;

function THttpTargetObjectRepository.GetLastError: string;
begin
  if FLastError <> '' then
    Exit(FLastError);
  Result := FClient.LastError;
end;

end.
