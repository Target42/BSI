unit ProjectRepository;

interface

uses
  System.SysUtils, System.DateUtils, FireDAC.Comp.Client, FireDAC.DApt, IsmsDomain, RepositoryBase;

type
  TProjectRepository = class(TProjectRepositoryBase)
  private
    FConnection: TFDConnection;
    FLastError: string;
  public
    constructor Create(AConnection: TFDConnection);
    function LoadProjects: TArray<TProject>; override;
    function CreateProject(const AName, ADescription, ACatalogVersion: string): TProject; override;
    function UpdateProject(const AProject: TProject): Boolean; override;
    function DeleteProject(AProjectId: Integer): Boolean; override;
    function LoadAssessment(AProjectId, ATargetObjectId, ARequirementDbId: Integer): TRequirementAssessment; override;
    function SaveAssessment(const AAssessment: TRequirementAssessment): Boolean; override;
    function GetLastError: string; override;
  end;

implementation

constructor TProjectRepository.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TProjectRepository.LoadProjects: TArray<TProject>;
var
  Q: TFDQuery;
  List: TArray<TProject>;
  P: TProject;
begin
  SetLength(List, 0);
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'SELECT id, name, description, catalog_version, created_at, updated_at ' +
      'FROM projects ORDER BY updated_at DESC';
    Q.Open;
    while not Q.Eof do
    begin
      FillChar(P, SizeOf(P), 0);
      P.Id := Q.FieldByName('id').AsInteger;
      P.Name := Q.FieldByName('name').AsString;
      P.Description := Q.FieldByName('description').AsString;
      P.CatalogVersion := Q.FieldByName('catalog_version').AsString;
      P.CreatedAt := IsoToDateTime(Q.FieldByName('created_at').AsString);
      P.UpdatedAt := IsoToDateTime(Q.FieldByName('updated_at').AsString);
      SetLength(List, Length(List) + 1);
      List[High(List)] := P;
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  Result := List;
end;

function TProjectRepository.CreateProject(const AName, ADescription, ACatalogVersion: string): TProject;
var
  Q: TFDQuery;
  NowUtc: TDateTime;
begin
  FillChar(Result, SizeOf(Result), 0);
  NowUtc := TTimeZone.Local.ToUniversalTime(Now);
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'INSERT INTO projects (name, description, catalog_version, created_at, updated_at) ' +
      'VALUES (:name, :desc, :ver, :created, :updated)';
    Q.ParamByName('name').AsString := AName;
    Q.ParamByName('desc').AsString := ADescription;
    Q.ParamByName('ver').AsString := ACatalogVersion;
    Q.ParamByName('created').AsString := DateTimeToIso(NowUtc);
    Q.ParamByName('updated').AsString := DateTimeToIso(NowUtc);
    Q.ExecSQL;
    Result.Id := Integer(FConnection.ExecSQLScalar('SELECT last_insert_rowid()'));
    Result.Name := AName;
    Result.Description := ADescription;
    Result.CatalogVersion := ACatalogVersion;
    Result.CreatedAt := NowUtc;
    Result.UpdatedAt := NowUtc;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      FillChar(Result, SizeOf(Result), 0);
    end;
  end;
  Q.Free;
end;

function TProjectRepository.UpdateProject(const AProject: TProject): Boolean;
var
  Q: TFDQuery;
begin
  Result := False;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := 'UPDATE projects SET name = :name, description = :desc, updated_at = :upd WHERE id = :id';
    Q.ParamByName('name').AsString := AProject.Name;
    Q.ParamByName('desc').AsString := AProject.Description;
    Q.ParamByName('upd').AsString := DateTimeToIso(TTimeZone.Local.ToUniversalTime(Now));
    Q.ParamByName('id').AsInteger := AProject.Id;
    Q.ExecSQL;
    Result := True;
  except
    on E: Exception do
      FLastError := E.Message;
  end;
  Q.Free;
end;

function TProjectRepository.DeleteProject(AProjectId: Integer): Boolean;
var
  Q: TFDQuery;
begin
  Result := False;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := 'DELETE FROM projects WHERE id = :id';
    Q.ParamByName('id').AsInteger := AProjectId;
    Q.ExecSQL;
    Result := Q.RowsAffected > 0;
  except
    on E: Exception do
      FLastError := E.Message;
  end;
  Q.Free;
end;

function TProjectRepository.LoadAssessment(AProjectId, ATargetObjectId,
  ARequirementDbId: Integer): TRequirementAssessment;
var
  Q: TFDQuery;
  DueStr: string;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.ProjectId := AProjectId;
  Result.TargetObjectId := ATargetObjectId;
  Result.RequirementDbId := ARequirementDbId;
  Result.Status := asOpen;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'SELECT id, status, note, responsible, due_date FROM requirement_assessments ' +
      'WHERE project_id = :pid AND target_object_id = :tid AND requirement_id = :rid';
    Q.ParamByName('pid').AsInteger := AProjectId;
    Q.ParamByName('tid').AsInteger := ATargetObjectId;
    Q.ParamByName('rid').AsInteger := ARequirementDbId;
    Q.Open;
    if Q.IsEmpty then
      Exit;
    Result.Id := Q.FieldByName('id').AsInteger;
    Result.Status := AssessmentStatusFromString(Q.FieldByName('status').AsString);
    Result.Note := Q.FieldByName('note').AsString;
    Result.Responsible := Q.FieldByName('responsible').AsString;
    DueStr := Q.FieldByName('due_date').AsString;
    if DueStr <> '' then
      Result.DueDate := IsoToDate(DueStr);
  finally
    Q.Free;
  end;
end;

function TProjectRepository.SaveAssessment(const AAssessment: TRequirementAssessment): Boolean;
var
  Q: TFDQuery;
  DueStr: string;
begin
  Result := False;
  if IsValidDate(AAssessment.DueDate) then
    DueStr := DateToIso(AAssessment.DueDate)
  else
    DueStr := '';
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'INSERT INTO requirement_assessments ' +
      '(project_id, target_object_id, requirement_id, status, note, responsible, due_date) ' +
      'VALUES (:pid, :tid, :rid, :status, :note, :resp, :due) ' +
      'ON CONFLICT(project_id, target_object_id, requirement_id) DO UPDATE SET ' +
      'status = excluded.status, note = excluded.note, responsible = excluded.responsible, ' +
      'due_date = excluded.due_date';
    Q.ParamByName('pid').AsInteger := AAssessment.ProjectId;
    Q.ParamByName('tid').AsInteger := AAssessment.TargetObjectId;
    Q.ParamByName('rid').AsInteger := AAssessment.RequirementDbId;
    Q.ParamByName('status').AsString := AssessmentStatusToString(AAssessment.Status);
    Q.ParamByName('note').AsString := AAssessment.Note;
    Q.ParamByName('resp').AsString := AAssessment.Responsible;
    if DueStr = '' then
      Q.ParamByName('due').Clear
    else
      Q.ParamByName('due').AsString := DueStr;
    Q.ExecSQL;
    Q.SQL.Text := 'UPDATE projects SET updated_at = :upd WHERE id = :id';
    Q.ParamByName('upd').AsString := DateTimeToIso(TTimeZone.Local.ToUniversalTime(Now));
    Q.ParamByName('id').AsInteger := AAssessment.ProjectId;
    Q.ExecSQL;
    Result := True;
  except
    on E: Exception do
      FLastError := E.Message;
  end;
  Q.Free;
end;

function TProjectRepository.GetLastError: string;
begin
  Result := FLastError;
end;

end.
