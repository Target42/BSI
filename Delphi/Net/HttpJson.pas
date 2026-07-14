unit HttpJson;

interface

uses
  System.SysUtils, System.JSON, System.DateUtils, IsmsDomain;

function ProjectFromJson(AObj: TJSONObject): TProject;
function TargetObjectFromJson(AObj: TJSONObject): TTargetObject;
function BausteinFromJson(AObj: TJSONObject): TBaustein;
function RequirementFromJson(AObj: TJSONObject): TRequirement;
function AssessmentFromJson(AObj: TJSONObject): TRequirementAssessment;
function MeasureFromJson(AObj: TJSONObject): TMeasure;
function ServerUserFromJson(AObj: TJSONObject): TServerUser;
function ProjectMemberFromJson(AObj: TJSONObject): TProjectMember;

implementation

function ParseDateTimeValue(AValue: TJSONValue): TDateTime;
var
  S: string;
begin
  Result := 0;
  if AValue = nil then
    Exit;
  if AValue is TJSONString then
    S := TJSONString(AValue).Value
  else
    S := AValue.Value;
  if S <> '' then
    Result := IsoToDateTime(S);
end;

function ParseDateValue(AValue: TJSONValue): TDateTime;
var
  S: string;
begin
  Result := 0;
  if AValue = nil then
    Exit;
  if AValue is TJSONString then
    S := TJSONString(AValue).Value
  else
    S := AValue.Value;
  if S <> '' then
    Result := IsoToDate(S);
end;

function ProjectFromJson(AObj: TJSONObject): TProject;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Id := AObj.GetValue<Integer>('id', 0);
  Result.Name := AObj.GetValue<string>('name', '');
  Result.Description := AObj.GetValue<string>('description', '');
  Result.CatalogVersion := AObj.GetValue<string>('catalogVersion', '');
  Result.Role := AObj.GetValue<string>('role', '');
  Result.CreatedAt := ParseDateTimeValue(AObj.GetValue('createdAt'));
  Result.UpdatedAt := ParseDateTimeValue(AObj.GetValue('updatedAt'));
end;

function TargetObjectFromJson(AObj: TJSONObject): TTargetObject;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Id := AObj.GetValue<Integer>('id', 0);
  Result.ProjectId := AObj.GetValue<Integer>('projectId', 0);
  Result.ParentId := AObj.GetValue<Integer>('parentId', 0);
  Result.ObjType := TargetObjectTypeFromString(AObj.GetValue<string>('type', ''));
  Result.ProtectionNeed := ProtectionNeedFromString(AObj.GetValue<string>('protectionNeed', ''));
  Result.Name := AObj.GetValue<string>('name', '');
  Result.Description := AObj.GetValue<string>('description', '');
end;

function BausteinFromJson(AObj: TJSONObject): TBaustein;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Id := AObj.GetValue<Integer>('id', 0);
  Result.Standard := stITGrundschutz;
  Result.ExternalId := AObj.GetValue<string>('externalId', '');
  Result.Title := AObj.GetValue<string>('title', '');
  Result.GroupName := AObj.GetValue<string>('groupName', '');
  Result.CatalogVersion := AObj.GetValue<string>('catalogVersion', '');
end;

function RequirementFromJson(AObj: TJSONObject): TRequirement;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Id := AObj.GetValue<Integer>('id', 0);
  Result.BausteinDbId := AObj.GetValue<Integer>('bausteinId', 0);
  Result.Standard := stITGrundschutz;
  Result.ExternalId := AObj.GetValue<string>('externalId', '');
  Result.BausteinExternalId := AObj.GetValue<string>('bausteinExternalId', '');
  Result.Title := AObj.GetValue<string>('title', '');
  Result.Text := AObj.GetValue<string>('text', '');
  Result.Level := RequirementLevelFromString(AObj.GetValue<string>('level', ''));
  Result.ResponsibleRole := AObj.GetValue<string>('responsibleRole', '');
  Result.Withdrawn := AObj.GetValue<Boolean>('withdrawn', False);
end;

function AssessmentFromJson(AObj: TJSONObject): TRequirementAssessment;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Id := AObj.GetValue<Integer>('id', 0);
  Result.ProjectId := AObj.GetValue<Integer>('projectId', 0);
  Result.TargetObjectId := AObj.GetValue<Integer>('targetObjectId', 0);
  Result.RequirementDbId := AObj.GetValue<Integer>('requirementId', 0);
  Result.Status := AssessmentStatusFromString(AObj.GetValue<string>('status', ''));
  Result.Note := AObj.GetValue<string>('note', '');
  Result.Responsible := AObj.GetValue<string>('responsible', '');
  Result.DueDate := ParseDateValue(AObj.GetValue('dueDate'));
  Result.Version := AObj.GetValue<Integer>('version', 0);
end;

function MeasureFromJson(AObj: TJSONObject): TMeasure;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Id := AObj.GetValue<Integer>('id', 0);
  Result.ProjectId := AObj.GetValue<Integer>('projectId', 0);
  Result.TargetObjectId := AObj.GetValue<Integer>('targetObjectId', 0);
  Result.RequirementDbId := AObj.GetValue<Integer>('requirementId', 0);
  Result.Title := AObj.GetValue<string>('title', '');
  Result.Description := AObj.GetValue<string>('description', '');
  Result.Responsible := AObj.GetValue<string>('responsible', '');
  Result.DueDate := ParseDateValue(AObj.GetValue('dueDate'));
  Result.Status := MeasureStatusFromString(AObj.GetValue<string>('status', ''));
  Result.Version := AObj.GetValue<Integer>('version', 0);
end;

function ServerUserFromJson(AObj: TJSONObject): TServerUser;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Id := AObj.GetValue<Integer>('id', 0);
  Result.Email := AObj.GetValue<string>('email', '');
  Result.DisplayName := AObj.GetValue<string>('displayName', '');
  Result.IsAdmin := AObj.GetValue<Boolean>('isAdmin', False);
end;

function ProjectMemberFromJson(AObj: TJSONObject): TProjectMember;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.UserId := AObj.GetValue<Integer>('userId', 0);
  Result.Email := AObj.GetValue<string>('email', '');
  Result.DisplayName := AObj.GetValue<string>('displayName', '');
  Result.Role := AObj.GetValue<string>('role', '');
end;

end.
