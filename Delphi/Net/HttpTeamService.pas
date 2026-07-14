unit HttpTeamService;

interface

uses
  System.SysUtils, System.JSON, IsmsDomain, ApiClient, HttpJson;

type
  THttpTeamService = class
  private
    FClient: TApiClient;
    FLastError: string;
    class function ReadErrorMessage(ADoc: TJSONValue; const AFallback: string): string; static;
  public
    constructor Create(AClient: TApiClient);
    function FetchCurrentUser(out AUser: TServerUser): Boolean;
    function ListUsers: TArray<TServerUser>;
    function ListMembers(AProjectId: Integer): TArray<TProjectMember>;
    function AddMember(AProjectId: Integer; const AEmail, ARole: string): TProjectMember;
    function UpdateMemberRole(AProjectId, AUserId: Integer; const ARole: string): TProjectMember;
    function RemoveMember(AProjectId, AUserId: Integer): Boolean;
    function CreateUser(const AEmail, ADisplayName, APassword: string; AIsAdmin: Boolean): TServerUser;
    function GetLastError: string;
    property LastError: string read GetLastError;
  end;

implementation

constructor THttpTeamService.Create(AClient: TApiClient);
begin
  inherited Create;
  FClient := AClient;
end;

class function THttpTeamService.ReadErrorMessage(ADoc: TJSONValue; const AFallback: string): string;
var
  Obj: TJSONObject;
begin
  Result := AFallback;
  if not (ADoc is TJSONObject) then
    Exit;
  Obj := TJSONObject(ADoc);
  if Obj.TryGetValue<string>('error', Result) then
    Exit;
  if Obj.TryGetValue<string>('message', Result) then
    Exit;
  Result := AFallback;
end;

function THttpTeamService.FetchCurrentUser(out AUser: TServerUser): Boolean;
var
  Doc: TJSONValue;
  Status: Integer;
begin
  FillChar(AUser, SizeOf(AUser), 0);
  Doc := FClient.Get('/api/v1/auth/me', Status);
  try
    if (Status <> 200) or not (Doc is TJSONObject) then
    begin
      FLastError := ReadErrorMessage(Doc, FClient.LastError);
      Exit(False);
    end;
    AUser := ServerUserFromJson(TJSONObject(Doc));
    Result := True;
  finally
    Doc.Free;
  end;
end;

function THttpTeamService.GetLastError: string;
begin
  if FLastError <> '' then
    Exit(FLastError);
  Result := FClient.LastError;
end;

function THttpTeamService.ListUsers: TArray<TServerUser>;
var
  Doc: TJSONValue;
  Arr: TJSONArray;
  I: Integer;
  List: TArray<TServerUser>;
  Status: Integer;
begin
  SetLength(List, 0);
  Doc := FClient.Get('/api/v1/admin/users', Status);
  try
    if (Status <> 200) or not (Doc is TJSONArray) then
    begin
      FLastError := ReadErrorMessage(Doc, FClient.LastError);
      Exit;
    end;
    Arr := TJSONArray(Doc);
    SetLength(List, Arr.Count);
    for I := 0 to Arr.Count - 1 do
      if Arr.Items[I] is TJSONObject then
        List[I] := ServerUserFromJson(TJSONObject(Arr.Items[I]));
  finally
    Doc.Free;
  end;
  Result := List;
end;

function THttpTeamService.ListMembers(AProjectId: Integer): TArray<TProjectMember>;
var
  Doc: TJSONValue;
  Arr: TJSONArray;
  I: Integer;
  List: TArray<TProjectMember>;
  Status: Integer;
begin
  SetLength(List, 0);
  Doc := FClient.Get(Format('/api/v1/projects/%d/members', [AProjectId]), Status);
  try
    if (Status <> 200) or not (Doc is TJSONArray) then
    begin
      FLastError := ReadErrorMessage(Doc, FClient.LastError);
      Exit;
    end;
    Arr := TJSONArray(Doc);
    SetLength(List, Arr.Count);
    for I := 0 to Arr.Count - 1 do
      if Arr.Items[I] is TJSONObject then
        List[I] := ProjectMemberFromJson(TJSONObject(Arr.Items[I]));
  finally
    Doc.Free;
  end;
  Result := List;
end;

function THttpTeamService.AddMember(AProjectId: Integer; const AEmail, ARole: string): TProjectMember;
var
  Body: TJSONObject;
  Doc: TJSONValue;
  Status: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  Body := TJSONObject.Create;
  try
    Body.AddPair('email', Trim(AEmail));
    Body.AddPair('role', ARole);
    Doc := FClient.PostJson(Format('/api/v1/projects/%d/members', [AProjectId]), Body, Status);
    try
      if (Status <> 201) or not (Doc is TJSONObject) then
      begin
        FLastError := ReadErrorMessage(Doc, FClient.LastError);
        Exit;
      end;
      Result := ProjectMemberFromJson(TJSONObject(Doc));
    finally
      Doc.Free;
    end;
  finally
    Body.Free;
  end;
end;

function THttpTeamService.UpdateMemberRole(AProjectId, AUserId: Integer;
  const ARole: string): TProjectMember;
var
  Body: TJSONObject;
  Doc: TJSONValue;
  Status: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  Body := TJSONObject.Create;
  try
    Body.AddPair('role', ARole);
    Doc := FClient.PatchJson(Format('/api/v1/projects/%d/members/%d', [AProjectId, AUserId]), Body, Status);
    try
      if (Status <> 200) or not (Doc is TJSONObject) then
      begin
        FLastError := ReadErrorMessage(Doc, FClient.LastError);
        Exit;
      end;
      Result := ProjectMemberFromJson(TJSONObject(Doc));
    finally
      Doc.Free;
    end;
  finally
    Body.Free;
  end;
end;

function THttpTeamService.RemoveMember(AProjectId, AUserId: Integer): Boolean;
var
  Status: Integer;
begin
  Result := FClient.Delete(Format('/api/v1/projects/%d/members/%d', [AProjectId, AUserId]), Status)
    and (Status = 204);
  if not Result then
    FLastError := FClient.LastError;
end;

function THttpTeamService.CreateUser(const AEmail, ADisplayName, APassword: string;
  AIsAdmin: Boolean): TServerUser;
var
  Body: TJSONObject;
  Doc: TJSONValue;
  Status: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  Body := TJSONObject.Create;
  try
    Body.AddPair('email', Trim(AEmail));
    Body.AddPair('displayName', Trim(ADisplayName));
    Body.AddPair('password', APassword);
    Body.AddPair('isAdmin', TJSONBool.Create(AIsAdmin));
    Doc := FClient.PostJson('/api/v1/admin/users', Body, Status);
    try
      if (Status <> 201) or not (Doc is TJSONObject) then
      begin
        FLastError := ReadErrorMessage(Doc, FClient.LastError);
        Exit;
      end;
      Result := ServerUserFromJson(TJSONObject(Doc));
    finally
      Doc.Free;
    end;
  finally
    Body.Free;
  end;
end;

end.
