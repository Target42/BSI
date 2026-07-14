unit TargetObjectRepository;

interface

uses
  System.SysUtils, System.Generics.Collections, FireDAC.Comp.Client, FireDAC.DApt, IsmsDomain, RepositoryBase;

type
  TTargetObjectRepository = class(TTargetObjectRepositoryBase)
  private
    FConnection: TFDConnection;
    FLastError: string;
    procedure DeleteTargetObjectSubtree(ATargetObjectId: Integer);
  public
    constructor Create(AConnection: TFDConnection);
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

constructor TTargetObjectRepository.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TTargetObjectRepository.LoadTargetObjects(AProjectId: Integer): TArray<TTargetObject>;
var
  Q: TFDQuery;
  List: TArray<TTargetObject>;
  O: TTargetObject;
begin
  SetLength(List, 0);
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'SELECT id, project_id, parent_id, type, protection_need, name, description ' +
      'FROM target_objects WHERE project_id = :pid ORDER BY parent_id, name';
    Q.ParamByName('pid').AsInteger := AProjectId;
    Q.Open;
    while not Q.Eof do
    begin
      FillChar(O, SizeOf(O), 0);
      O.Id := Q.FieldByName('id').AsInteger;
      O.ProjectId := Q.FieldByName('project_id').AsInteger;
      O.ParentId := Q.FieldByName('parent_id').AsInteger;
      O.ObjType := TargetObjectTypeFromString(Q.FieldByName('type').AsString);
      O.ProtectionNeed := ProtectionNeedFromString(Q.FieldByName('protection_need').AsString);
      O.Name := Q.FieldByName('name').AsString;
      O.Description := Q.FieldByName('description').AsString;
      SetLength(List, Length(List) + 1);
      List[High(List)] := O;
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  Result := List;
end;

function TTargetObjectRepository.CreateTargetObject(const ATargetObject: TTargetObject): TTargetObject;
var
  Q: TFDQuery;
begin
  Result := ATargetObject;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'INSERT INTO target_objects (project_id, parent_id, type, protection_need, name, description) ' +
      'VALUES (:pid, :parent, :typ, :pn, :name, :desc)';
    Q.ParamByName('pid').AsInteger := Result.ProjectId;
    Q.ParamByName('parent').AsInteger := Result.ParentId;
    Q.ParamByName('typ').AsString := TargetObjectTypeToString(Result.ObjType);
    Q.ParamByName('pn').AsString := ProtectionNeedToString(Result.ProtectionNeed);
    Q.ParamByName('name').AsString := Result.Name;
    Q.ParamByName('desc').AsString := Result.Description;
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

function TTargetObjectRepository.UpdateTargetObject(const ATargetObject: TTargetObject): Boolean;
var
  Q: TFDQuery;
begin
  Result := False;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'UPDATE target_objects SET parent_id = :parent, type = :typ, protection_need = :pn, ' +
      'name = :name, description = :desc WHERE id = :id';
    Q.ParamByName('parent').AsInteger := ATargetObject.ParentId;
    Q.ParamByName('typ').AsString := TargetObjectTypeToString(ATargetObject.ObjType);
    Q.ParamByName('pn').AsString := ProtectionNeedToString(ATargetObject.ProtectionNeed);
    Q.ParamByName('name').AsString := ATargetObject.Name;
    Q.ParamByName('desc').AsString := ATargetObject.Description;
    Q.ParamByName('id').AsInteger := ATargetObject.Id;
    Q.ExecSQL;
    Result := True;
  except
    on E: Exception do
      FLastError := E.Message;
  end;
  Q.Free;
end;

procedure TTargetObjectRepository.DeleteTargetObjectSubtree(ATargetObjectId: Integer);
var
  Q, ChildQ: TFDQuery;
begin
  ChildQ := TFDQuery.Create(nil);
  try
    ChildQ.Connection := FConnection;
    ChildQ.SQL.Text := 'SELECT id FROM target_objects WHERE parent_id = :id';
    ChildQ.ParamByName('id').AsInteger := ATargetObjectId;
    ChildQ.Open;
    while not ChildQ.Eof do
    begin
      DeleteTargetObjectSubtree(ChildQ.FieldByName('id').AsInteger);
      ChildQ.Next;
    end;
  finally
    ChildQ.Free;
  end;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := 'DELETE FROM baustein_applicability WHERE target_object_id = :id';
    Q.ParamByName('id').AsInteger := ATargetObjectId;
    Q.ExecSQL;
    Q.SQL.Text := 'DELETE FROM requirement_assessments WHERE target_object_id = :id';
    Q.ParamByName('id').AsInteger := ATargetObjectId;
    Q.ExecSQL;
    Q.SQL.Text := 'DELETE FROM measures WHERE target_object_id = :id';
    Q.ParamByName('id').AsInteger := ATargetObjectId;
    Q.ExecSQL;
    Q.SQL.Text := 'DELETE FROM target_objects WHERE id = :id';
    Q.ParamByName('id').AsInteger := ATargetObjectId;
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

function TTargetObjectRepository.DeleteTargetObject(ATargetObjectId: Integer): Boolean;
begin
  Result := False;
  try
    FConnection.StartTransaction;
    DeleteTargetObjectSubtree(ATargetObjectId);
    FConnection.Commit;
    Result := True;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      FConnection.Rollback;
    end;
  end;
end;

function TTargetObjectRepository.CreateDefaultScope(AProjectId: Integer;
  const AProjectName: string): TTargetObject;
var
  Scope: TTargetObject;
begin
  FillChar(Scope, SizeOf(Scope), 0);
  Scope.ProjectId := AProjectId;
  Scope.ParentId := 0;
  Scope.ObjType := totScope;
  Scope.ProtectionNeed := pnNormal;
  Scope.Name := AProjectName;
  Scope.Description := 'Informationsverbund';
  Result := CreateTargetObject(Scope);
end;

function TTargetObjectRepository.LoadApplicabilityMap(AProjectId,
  ATargetObjectId: Integer): TDictionary<Integer, TApplicabilityStatus>;
var
  Q: TFDQuery;
begin
  Result := TDictionary<Integer, TApplicabilityStatus>.Create;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'SELECT baustein_id, status FROM baustein_applicability ' +
      'WHERE project_id = :pid AND target_object_id = :tid';
    Q.ParamByName('pid').AsInteger := AProjectId;
    Q.ParamByName('tid').AsInteger := ATargetObjectId;
    Q.Open;
    while not Q.Eof do
    begin
      Result.AddOrSetValue(Q.FieldByName('baustein_id').AsInteger,
        ApplicabilityStatusFromString(Q.FieldByName('status').AsString));
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

function TTargetObjectRepository.Applicability(AProjectId, ATargetObjectId,
  ABausteinDbId: Integer): TApplicabilityStatus;
var
  Q: TFDQuery;
begin
  Result := apUndefined;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'SELECT status FROM baustein_applicability ' +
      'WHERE project_id = :pid AND target_object_id = :tid AND baustein_id = :bid';
    Q.ParamByName('pid').AsInteger := AProjectId;
    Q.ParamByName('tid').AsInteger := ATargetObjectId;
    Q.ParamByName('bid').AsInteger := ABausteinDbId;
    Q.Open;
    if not Q.IsEmpty then
      Result := ApplicabilityStatusFromString(Q.FieldByName('status').AsString);
  finally
    Q.Free;
  end;
end;

function TTargetObjectRepository.SaveApplicability(const AApplicability: TBausteinApplicability): Boolean;
var
  Q: TFDQuery;
begin
  Result := False;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    if AApplicability.Status = apUndefined then
    begin
      Q.SQL.Text :=
        'DELETE FROM baustein_applicability ' +
        'WHERE project_id = :pid AND target_object_id = :tid AND baustein_id = :bid';
      Q.ParamByName('pid').AsInteger := AApplicability.ProjectId;
      Q.ParamByName('tid').AsInteger := AApplicability.TargetObjectId;
      Q.ParamByName('bid').AsInteger := AApplicability.BausteinDbId;
      Q.ExecSQL;
      Exit(True);
    end;
    Q.SQL.Text :=
      'INSERT INTO baustein_applicability (project_id, target_object_id, baustein_id, status) ' +
      'VALUES (:pid, :tid, :bid, :status) ' +
      'ON CONFLICT(project_id, target_object_id, baustein_id) DO UPDATE SET status = excluded.status';
    Q.ParamByName('pid').AsInteger := AApplicability.ProjectId;
    Q.ParamByName('tid').AsInteger := AApplicability.TargetObjectId;
    Q.ParamByName('bid').AsInteger := AApplicability.BausteinDbId;
    Q.ParamByName('status').AsString := ApplicabilityStatusToString(AApplicability.Status);
    Q.ExecSQL;
    Result := True;
  except
    on E: Exception do
      FLastError := E.Message;
  end;
  Q.Free;
end;

function TTargetObjectRepository.GetLastError: string;
begin
  Result := FLastError;
end;

end.
