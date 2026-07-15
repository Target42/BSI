unit MeasureRepository;

interface

uses
  System.SysUtils, System.Generics.Collections, FireDAC.Comp.Client, FireDAC.DApt, IsmsDomain, RepositoryBase;

type
  TMeasureRepository = class(TMeasureRepositoryBase)
  private
    FConnection: TFDConnection;
    FLastError: string;
  public
    constructor Create(AConnection: TFDConnection);
    function LoadMeasures(AProjectId, ATargetObjectId, ARequirementDbId: Integer): TArray<TMeasure>; override;
    function MeasureCounts(AProjectId, ATargetObjectId: Integer): TDictionary<Integer, Integer>; override;
    function CreateMeasure(const AMeasure: TMeasure): TMeasure; override;
    function UpdateMeasure(const AMeasure: TMeasure): TMeasureSaveResult; override;
    function DeleteMeasure(AMeasureId: Integer): Boolean; override;
    function GetLastError: string; override;
  end;

implementation

constructor TMeasureRepository.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TMeasureRepository.LoadMeasures(AProjectId, ATargetObjectId,
  ARequirementDbId: Integer): TArray<TMeasure>;
var
  Q: TFDQuery;
  List: TArray<TMeasure>;
  M: TMeasure;
  DueStr: string;
begin
  SetLength(List, 0);
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'SELECT id, title, description, responsible, due_date, status FROM measures ' +
      'WHERE project_id = :pid AND target_object_id = :tid AND requirement_id = :rid ' +
      'ORDER BY due_date IS NULL, due_date, title';
    Q.ParamByName('pid').AsInteger := AProjectId;
    Q.ParamByName('tid').AsInteger := ATargetObjectId;
    Q.ParamByName('rid').AsInteger := ARequirementDbId;
    Q.Open;
    while not Q.Eof do
    begin
      FillChar(M, SizeOf(M), 0);
      M.ProjectId := AProjectId;
      M.TargetObjectId := ATargetObjectId;
      M.RequirementDbId := ARequirementDbId;
      M.Id := Q.FieldByName('id').AsInteger;
      M.Title := Q.FieldByName('title').AsString;
      M.Description := Q.FieldByName('description').AsString;
      M.Responsible := Q.FieldByName('responsible').AsString;
      DueStr := Q.FieldByName('due_date').AsString;
      if DueStr <> '' then
        M.DueDate := IsoToDate(DueStr);
      M.Status := MeasureStatusFromString(Q.FieldByName('status').AsString);
      SetLength(List, Length(List) + 1);
      List[High(List)] := M;
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  Result := List;
end;

function TMeasureRepository.MeasureCounts(AProjectId,
  ATargetObjectId: Integer): TDictionary<Integer, Integer>;
var
  Q: TFDQuery;
begin
  Result := TDictionary<Integer, Integer>.Create;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'SELECT requirement_id, COUNT(*) AS cnt FROM measures ' +
      'WHERE project_id = :pid AND target_object_id = :tid GROUP BY requirement_id';
    Q.ParamByName('pid').AsInteger := AProjectId;
    Q.ParamByName('tid').AsInteger := ATargetObjectId;
    Q.Open;
    while not Q.Eof do
    begin
      Result.AddOrSetValue(Q.FieldByName('requirement_id').AsInteger,
        Q.FieldByName('cnt').AsInteger);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

function TMeasureRepository.CreateMeasure(const AMeasure: TMeasure): TMeasure;
var
  Q: TFDQuery;
  DueStr: string;
begin
  Result := AMeasure;
  if IsValidDate(AMeasure.DueDate) then
    DueStr := DateToIso(AMeasure.DueDate)
  else
    DueStr := '';
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'INSERT INTO measures (project_id, target_object_id, requirement_id, title, description, ' +
      'responsible, due_date, status) VALUES (:pid, :tid, :rid, :title, :desc, :resp, :due, :status)';
    Q.ParamByName('pid').AsInteger := Result.ProjectId;
    Q.ParamByName('tid').AsInteger := Result.TargetObjectId;
    Q.ParamByName('rid').AsInteger := Result.RequirementDbId;
    Q.ParamByName('title').AsString := Result.Title;
    Q.ParamByName('desc').AsString := Result.Description;
    Q.ParamByName('resp').AsString := Result.Responsible;
    if DueStr = '' then
      Q.ParamByName('due').Clear
    else
      Q.ParamByName('due').AsString := DueStr;
    Q.ParamByName('status').AsString := MeasureStatusToString(Result.Status);
    Q.ExecSQL;
    Result.Id := Integer(FConnection.ExecSQLScalar('SELECT last_insert_rowid()'));
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      FillChar(Result, SizeOf(Result), 0);
    end;
  end;
  Q.Free;
end;

function TMeasureRepository.UpdateMeasure(const AMeasure: TMeasure): TMeasureSaveResult;
var
  Q: TFDQuery;
  DueStr: string;
  Updated: TMeasure;
begin
  Result := MeasureSaveFailed;
  if IsValidDate(AMeasure.DueDate) then
    DueStr := DateToIso(AMeasure.DueDate)
  else
    DueStr := '';
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'UPDATE measures SET title = :title, description = :desc, responsible = :resp, ' +
      'due_date = :due, status = :status WHERE id = :id';
    Q.ParamByName('title').AsString := AMeasure.Title;
    Q.ParamByName('desc').AsString := AMeasure.Description;
    Q.ParamByName('resp').AsString := AMeasure.Responsible;
    if DueStr = '' then
      Q.ParamByName('due').Clear
    else
      Q.ParamByName('due').AsString := DueStr;
    Q.ParamByName('status').AsString := MeasureStatusToString(AMeasure.Status);
    Q.ParamByName('id').AsInteger := AMeasure.Id;
    Q.ExecSQL;
    Updated := AMeasure;
    Result := MeasureSaveOk(Updated);
  except
    on E: Exception do
      FLastError := E.Message;
  end;
  Q.Free;
end;

function TMeasureRepository.DeleteMeasure(AMeasureId: Integer): Boolean;
var
  Q: TFDQuery;
begin
  Result := False;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := 'DELETE FROM measures WHERE id = :id';
    Q.ParamByName('id').AsInteger := AMeasureId;
    Q.ExecSQL;
    Result := Q.RowsAffected > 0;
  except
    on E: Exception do
      FLastError := E.Message;
  end;
  Q.Free;
end;

function TMeasureRepository.GetLastError: string;
begin
  Result := FLastError;
end;

end.
