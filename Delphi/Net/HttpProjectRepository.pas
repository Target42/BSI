unit HttpProjectRepository;

interface

uses
  System.SysUtils, System.JSON, IsmsDomain, RepositoryBase, ApiClient, HttpJson;

type
  THttpProjectRepository = class(TProjectRepositoryBase)
  private
    FClient: TApiClient;
    FLastError: string;
  public
    constructor Create(AClient: TApiClient);
    function LoadProjects: TArray<TProject>; override;
    function CreateProject(const AName, ADescription, ACatalogVersion: string): TProject; override;
    function UpdateProject(const AProject: TProject): Boolean; override;
    function DeleteProject(AProjectId: Integer): Boolean; override;
    function LoadAssessment(AProjectId, ATargetObjectId, ARequirementDbId: Integer): TRequirementAssessment; override;
    function SaveAssessment(const AAssessment: TRequirementAssessment): Boolean; override;
    function GetLastError: string; override;
  end;

implementation

constructor THttpProjectRepository.Create(AClient: TApiClient);
begin
  inherited Create;
  FClient := AClient;
end;

function THttpProjectRepository.LoadProjects: TArray<TProject>;
var
  Doc: TJSONValue;
  Arr: TJSONArray;
  I: Integer;
  List: TArray<TProject>;
  Status: Integer;
begin
  SetLength(List, 0);
  Doc := FClient.Get('/api/v1/projects', Status);
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
        List[I] := ProjectFromJson(TJSONObject(Arr.Items[I]));
  finally
    Doc.Free;
  end;
  Result := List;
end;

function THttpProjectRepository.CreateProject(const AName, ADescription,
  ACatalogVersion: string): TProject;
var
  Body: TJSONObject;
  Doc: TJSONValue;
  Status: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  Body := TJSONObject.Create;
  try
    Body.AddPair('name', AName);
    Body.AddPair('description', ADescription);
    Body.AddPair('catalogVersion', ACatalogVersion);
    Doc := FClient.PostJson('/api/v1/projects', Body, Status);
    try
      if (Status <> 201) or not (Doc is TJSONObject) then
      begin
        FLastError := FClient.LastError;
        Exit;
      end;
      Result := ProjectFromJson(TJSONObject(Doc));
    finally
      Doc.Free;
    end;
  finally
    Body.Free;
  end;
end;

function THttpProjectRepository.UpdateProject(const AProject: TProject): Boolean;
var
  Body: TJSONObject;
  Doc: TJSONValue;
  Status: Integer;
begin
  Result := False;
  Body := TJSONObject.Create;
  try
    Body.AddPair('name', AProject.Name);
    Body.AddPair('description', AProject.Description);
    Doc := FClient.PatchJson(Format('/api/v1/projects/%d', [AProject.Id]), Body, Status);
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

function THttpProjectRepository.DeleteProject(AProjectId: Integer): Boolean;
var
  Status: Integer;
begin
  Result := FClient.Delete(Format('/api/v1/projects/%d', [AProjectId]), Status) and (Status = 204);
  if not Result then
    FLastError := FClient.LastError;
end;

function THttpProjectRepository.LoadAssessment(AProjectId, ATargetObjectId,
  ARequirementDbId: Integer): TRequirementAssessment;
var
  Doc: TJSONValue;
  Status: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.ProjectId := AProjectId;
  Result.TargetObjectId := ATargetObjectId;
  Result.RequirementDbId := ARequirementDbId;
  Result.Status := asOpen;
  Doc := FClient.Get(
    Format('/api/v1/projects/%d/target-objects/%d/requirements/%d/assessment',
      [AProjectId, ATargetObjectId, ARequirementDbId]), Status);
  try
    if (Status <> 200) or not (Doc is TJSONObject) then
    begin
      FLastError := FClient.LastError;
      Exit;
    end;
    Result := AssessmentFromJson(TJSONObject(Doc));
  finally
    Doc.Free;
  end;
end;

function THttpProjectRepository.SaveAssessment(const AAssessment: TRequirementAssessment): Boolean;
var
  Body: TJSONObject;
  Doc: TJSONValue;
  Status: Integer;
begin
  Result := False;
  Body := TJSONObject.Create;
  try
    Body.AddPair('status', AssessmentStatusToString(AAssessment.Status));
    Body.AddPair('note', AAssessment.Note);
    Body.AddPair('responsible', AAssessment.Responsible);
    if IsValidDate(AAssessment.DueDate) then
      Body.AddPair('dueDate', DateToIso(AAssessment.DueDate));
    Body.AddPair('version', TJSONNumber.Create(AAssessment.Version));
    Doc := FClient.PutJson(
      Format('/api/v1/projects/%d/target-objects/%d/requirements/%d/assessment',
        [AAssessment.ProjectId, AAssessment.TargetObjectId, AAssessment.RequirementDbId]),
      Body, Status);
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
      if (Status <> 200) or not (Doc is TJSONObject) then
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

function THttpProjectRepository.GetLastError: string;
begin
  if FLastError <> '' then
    Exit(FLastError);
  Result := FClient.LastError;
end;

end.
