unit HttpJson;

interface

uses
  System.SysUtils, System.JSON, System.DateUtils, System.Classes, IsmsDomain;

function ProjectFromJson(AObj: TJSONObject): TProject;
function TargetObjectFromJson(AObj: TJSONObject): TTargetObject;
function BausteinFromJson(AObj: TJSONObject): TBaustein;
function RequirementFromJson(AObj: TJSONObject): TRequirement;
function AssessmentFromJson(AObj: TJSONObject): TRequirementAssessment;
function MeasureFromJson(AObj: TJSONObject): TMeasure;
function ServerUserFromJson(AObj: TJSONObject): TServerUser;
function ProjectMemberFromJson(AObj: TJSONObject): TProjectMember;
function RepairUtf8Mojibake(const S: string): string;

implementation

function RepairUtf8Mojibake(const S: string): string;
var
  I: Integer;
  Bytes: TBytes;
begin
  Result := S;
  if (S = '') or (Pos(#$00C3, S) = 0) then
    Exit;
  SetLength(Bytes, Length(S));
  for I := 1 to Length(S) do
    Bytes[I - 1] := Byte(Ord(S[I]) and $FF);
  Result := TEncoding.UTF8.GetString(Bytes);
end;

function JsonStringValue(AObj: TJSONObject; const AName: string;
  const ADefault: string = ''): string;
var
  V: TJSONValue;
begin
  Result := ADefault;
  if not AObj.TryGetValue(AName, V) or (V = nil) then
    Exit;
  if V is TJSONString then
    Result := TJSONString(V).Value
  else
    Result := V.Value;
  Result := RepairUtf8Mojibake(Result);
end;

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
  Result.Name := JsonStringValue(AObj, 'name');
  Result.Description := JsonStringValue(AObj, 'description');
  Result.CatalogVersion := JsonStringValue(AObj, 'catalogVersion');
  Result.Role := JsonStringValue(AObj, 'role');
  Result.CreatedAt := ParseDateTimeValue(AObj.GetValue('createdAt'));
  Result.UpdatedAt := ParseDateTimeValue(AObj.GetValue('updatedAt'));
end;

function TargetObjectFromJson(AObj: TJSONObject): TTargetObject;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Id := AObj.GetValue<Integer>('id', 0);
  Result.ProjectId := AObj.GetValue<Integer>('projectId', 0);
  Result.ParentId := AObj.GetValue<Integer>('parentId', 0);
  Result.ObjType := TargetObjectTypeFromString(JsonStringValue(AObj, 'type'));
  Result.ProtectionNeed := ProtectionNeedFromString(JsonStringValue(AObj, 'protectionNeed'));
  Result.Name := JsonStringValue(AObj, 'name');
  Result.Description := JsonStringValue(AObj, 'description');
end;

function BausteinFromJson(AObj: TJSONObject): TBaustein;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Id := AObj.GetValue<Integer>('id', 0);
  Result.Standard := stITGrundschutz;
  Result.ExternalId := JsonStringValue(AObj, 'externalId');
  Result.Title := JsonStringValue(AObj, 'title');
  Result.GroupName := JsonStringValue(AObj, 'groupName');
  Result.CatalogVersion := JsonStringValue(AObj, 'catalogVersion');
end;

function RequirementFromJson(AObj: TJSONObject): TRequirement;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Id := AObj.GetValue<Integer>('id', 0);
  Result.BausteinDbId := AObj.GetValue<Integer>('bausteinId', 0);
  Result.Standard := stITGrundschutz;
  Result.ExternalId := JsonStringValue(AObj, 'externalId');
  Result.BausteinExternalId := JsonStringValue(AObj, 'bausteinExternalId');
  Result.Title := JsonStringValue(AObj, 'title');
  Result.Text := JsonStringValue(AObj, 'text');
  Result.Level := RequirementLevelFromString(JsonStringValue(AObj, 'level'));
  Result.ResponsibleRole := JsonStringValue(AObj, 'responsibleRole');
  Result.Withdrawn := AObj.GetValue<Boolean>('withdrawn', False);
end;

function AssessmentFromJson(AObj: TJSONObject): TRequirementAssessment;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Id := AObj.GetValue<Integer>('id', 0);
  Result.ProjectId := AObj.GetValue<Integer>('projectId', 0);
  Result.TargetObjectId := AObj.GetValue<Integer>('targetObjectId', 0);
  Result.RequirementDbId := AObj.GetValue<Integer>('requirementId', 0);
  Result.Status := AssessmentStatusFromString(JsonStringValue(AObj, 'status'));
  Result.Note := JsonStringValue(AObj, 'note');
  Result.Responsible := JsonStringValue(AObj, 'responsible');
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
  Result.Title := JsonStringValue(AObj, 'title');
  Result.Description := JsonStringValue(AObj, 'description');
  Result.Responsible := JsonStringValue(AObj, 'responsible');
  Result.DueDate := ParseDateValue(AObj.GetValue('dueDate'));
  Result.Status := MeasureStatusFromString(JsonStringValue(AObj, 'status'));
  Result.Version := AObj.GetValue<Integer>('version', 0);
end;

function ServerUserFromJson(AObj: TJSONObject): TServerUser;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Id := AObj.GetValue<Integer>('id', 0);
  Result.Email := JsonStringValue(AObj, 'email');
  Result.DisplayName := JsonStringValue(AObj, 'displayName');
  Result.IsAdmin := AObj.GetValue<Boolean>('isAdmin', False);
end;

function ProjectMemberFromJson(AObj: TJSONObject): TProjectMember;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.UserId := AObj.GetValue<Integer>('userId', 0);
  Result.Email := JsonStringValue(AObj, 'email');
  Result.DisplayName := JsonStringValue(AObj, 'displayName');
  Result.Role := JsonStringValue(AObj, 'role');
end;

end.
