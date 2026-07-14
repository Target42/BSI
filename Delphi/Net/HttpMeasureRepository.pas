unit HttpMeasureRepository;

interface

uses
  System.SysUtils, System.JSON, System.Generics.Collections, IsmsDomain,
  RepositoryBase, ApiClient, HttpJson;

type
  THttpMeasureRepository = class(TMeasureRepositoryBase)
  private
    FClient: TApiClient;
    FLastError: string;
  public
    constructor Create(AClient: TApiClient);
    function LoadMeasures(AProjectId, ATargetObjectId, ARequirementDbId: Integer): TArray<TMeasure>; override;
    function MeasureCounts(AProjectId, ATargetObjectId: Integer): TDictionary<Integer, Integer>; override;
    function CreateMeasure(const AMeasure: TMeasure): TMeasure; override;
    function UpdateMeasure(const AMeasure: TMeasure): Boolean; override;
    function DeleteMeasure(AMeasureId: Integer): Boolean; override;
    function GetLastError: string; override;
  end;

implementation

constructor THttpMeasureRepository.Create(AClient: TApiClient);
begin
  inherited Create;
  FClient := AClient;
end;

function THttpMeasureRepository.LoadMeasures(AProjectId, ATargetObjectId,
  ARequirementDbId: Integer): TArray<TMeasure>;
var
  Doc: TJSONValue;
  Arr: TJSONArray;
  I: Integer;
  List: TArray<TMeasure>;
  Status: Integer;
begin
  SetLength(List, 0);
  Doc := FClient.Get(
    Format('/api/v1/projects/%d/target-objects/%d/requirements/%d/measures',
      [AProjectId, ATargetObjectId, ARequirementDbId]), Status);
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
        List[I] := MeasureFromJson(TJSONObject(Arr.Items[I]));
  finally
    Doc.Free;
  end;
  Result := List;
end;

function THttpMeasureRepository.MeasureCounts(AProjectId,
  ATargetObjectId: Integer): TDictionary<Integer, Integer>;
var
  Doc: TJSONValue;
  Obj: TJSONObject;
  Pair: TJSONPair;
  Status: Integer;
begin
  Result := TDictionary<Integer, Integer>.Create;
  Doc := FClient.Get(
    Format('/api/v1/projects/%d/target-objects/%d/measure-counts', [AProjectId, ATargetObjectId]),
    Status);
  try
    if (Status <> 200) or not (Doc is TJSONObject) then
    begin
      FLastError := FClient.LastError;
      Exit;
    end;
    Obj := TJSONObject(Doc);
    for Pair in Obj do
      Result.AddOrSetValue(StrToIntDef(Pair.JsonString.Value, 0), StrToIntDef(Pair.JsonValue.Value, 0));
  finally
    Doc.Free;
  end;
end;

function THttpMeasureRepository.CreateMeasure(const AMeasure: TMeasure): TMeasure;
var
  Body: TJSONObject;
  Doc: TJSONValue;
  Status: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  Body := TJSONObject.Create;
  try
    Body.AddPair('title', AMeasure.Title);
    Body.AddPair('description', AMeasure.Description);
    Body.AddPair('responsible', AMeasure.Responsible);
    if IsValidDate(AMeasure.DueDate) then
      Body.AddPair('dueDate', DateToIso(AMeasure.DueDate));
    Body.AddPair('status', MeasureStatusToString(AMeasure.Status));
    Doc := FClient.PostJson(
      Format('/api/v1/projects/%d/target-objects/%d/requirements/%d/measures',
        [AMeasure.ProjectId, AMeasure.TargetObjectId, AMeasure.RequirementDbId]),
      Body, Status);
    try
      if (Status <> 201) or not (Doc is TJSONObject) then
      begin
        FLastError := FClient.LastError;
        Exit;
      end;
      Result := MeasureFromJson(TJSONObject(Doc));
    finally
      Doc.Free;
    end;
  finally
    Body.Free;
  end;
end;

function THttpMeasureRepository.UpdateMeasure(const AMeasure: TMeasure): Boolean;
var
  Body: TJSONObject;
  Doc: TJSONValue;
  Status: Integer;
begin
  Result := False;
  Body := TJSONObject.Create;
  try
    Body.AddPair('title', AMeasure.Title);
    Body.AddPair('description', AMeasure.Description);
    Body.AddPair('responsible', AMeasure.Responsible);
    if IsValidDate(AMeasure.DueDate) then
      Body.AddPair('dueDate', DateToIso(AMeasure.DueDate));
    Body.AddPair('status', MeasureStatusToString(AMeasure.Status));
    Body.AddPair('version', TJSONNumber.Create(AMeasure.Version));
    Doc := FClient.PatchJson(Format('/api/v1/measures/%d', [AMeasure.Id]), Body, Status);
    try
      if Status = 403 then
      begin
        FLastError := 'Keine Berechtigung zum Speichern.';
        Exit;
      end;
      if Status = 409 then
      begin
        FLastError := 'Datensatz wurde zwischenzeitlich geändert. Bitte neu laden.';
        Exit;
      end;
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

function THttpMeasureRepository.DeleteMeasure(AMeasureId: Integer): Boolean;
var
  Status: Integer;
begin
  Result := FClient.Delete(Format('/api/v1/measures/%d', [AMeasureId]), Status) and (Status = 204);
  if not Result then
    FLastError := FClient.LastError;
end;

function THttpMeasureRepository.GetLastError: string;
begin
  if FLastError <> '' then
    Exit(FLastError);
  Result := FClient.LastError;
end;

end.
