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
    function ReadTargetObject(Q: TFDQuery): TTargetObject;
    function LoadTargetObjectsRaw(AProjectId: Integer): TArray<TTargetObject>;
    procedure PersistInheritedProtectionNeeds(AProjectId: Integer);
    procedure BindProtectionNeedParams(Q: TFDQuery; const ATargetObject: TTargetObject);
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
    function LoadDeviation(AProjectId, ATargetObjectId, ABausteinDbId: Integer): string; override;
    function SaveDeviation(AProjectId, ATargetObjectId, ABausteinDbId: Integer;
      const ANote: string): Boolean; override;
    function GetLastError: string; override;
  end;

implementation

constructor TTargetObjectRepository.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TTargetObjectRepository.ReadTargetObject(Q: TFDQuery): TTargetObject;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Id := Q.FieldByName('id').AsInteger;
  Result.ProjectId := Q.FieldByName('project_id').AsInteger;
  Result.ParentId := Q.FieldByName('parent_id').AsInteger;
  Result.ObjType := TargetObjectTypeFromString(Q.FieldByName('type').AsString);
  Result.ProtectionNeed := ProtectionNeedFromString(Q.FieldByName('protection_need').AsString);
  Result.Confidentiality := CiaLevelFromString(Q.FieldByName('confidentiality').AsString);
  Result.Integrity := CiaLevelFromString(Q.FieldByName('integrity').AsString);
  Result.Availability := CiaLevelFromString(Q.FieldByName('availability').AsString);
  Result.InheritProtectionNeed := Q.FieldByName('inherit_protection_need').AsInteger <> 0;
  Result.ProtectionNeedNote := Q.FieldByName('protection_need_note').AsString;
  Result.Name := Q.FieldByName('name').AsString;
  Result.Description := Q.FieldByName('description').AsString;
  if (Result.Confidentiality = clNormal) and (Result.Integrity = clNormal) and
     (Result.Availability = clNormal) and (Result.ProtectionNeed = pnElevated) then
  begin
    Result.Confidentiality := clHigh;
    Result.Integrity := clHigh;
    Result.Availability := clHigh;
  end;
end;

procedure TTargetObjectRepository.BindProtectionNeedParams(Q: TFDQuery;
  const ATargetObject: TTargetObject);
begin
  Q.ParamByName('pn').AsString := ProtectionNeedToString(ATargetObject.ProtectionNeed);
  Q.ParamByName('conf').AsString := CiaLevelToString(ATargetObject.Confidentiality);
  Q.ParamByName('integ').AsString := CiaLevelToString(ATargetObject.Integrity);
  Q.ParamByName('avail').AsString := CiaLevelToString(ATargetObject.Availability);
  Q.ParamByName('inherit').AsInteger := Ord(ATargetObject.InheritProtectionNeed);
  Q.ParamByName('pnnote').AsString := ATargetObject.ProtectionNeedNote;
end;

function TTargetObjectRepository.LoadTargetObjectsRaw(AProjectId: Integer): TArray<TTargetObject>;
var
  Q: TFDQuery;
  List: TArray<TTargetObject>;
begin
  SetLength(List, 0);
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'SELECT id, project_id, parent_id, type, protection_need, confidentiality, integrity, ' +
      'availability, inherit_protection_need, protection_need_note, name, description ' +
      'FROM target_objects WHERE project_id = :pid ORDER BY parent_id, name';
    Q.ParamByName('pid').AsInteger := AProjectId;
    Q.Open;
    while not Q.Eof do
    begin
      SetLength(List, Length(List) + 1);
      List[High(List)] := ReadTargetObject(Q);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  Result := List;
end;

procedure TTargetObjectRepository.PersistInheritedProtectionNeeds(AProjectId: Integer);
var
  Objects: TArray<TTargetObject>;
  O: TTargetObject;
  Q: TFDQuery;
begin
  Objects := LoadTargetObjectsRaw(AProjectId);
  ResolveInheritedProtectionNeeds(Objects);
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'UPDATE target_objects SET confidentiality = :conf, integrity = :integ, ' +
      'availability = :avail, protection_need = :pn WHERE id = :id';
    for O in Objects do
    begin
      if not O.InheritProtectionNeed then
        Continue;
      Q.ParamByName('conf').AsString := CiaLevelToString(O.Confidentiality);
      Q.ParamByName('integ').AsString := CiaLevelToString(O.Integrity);
      Q.ParamByName('avail').AsString := CiaLevelToString(O.Availability);
      Q.ParamByName('pn').AsString := ProtectionNeedToString(O.ProtectionNeed);
      Q.ParamByName('id').AsInteger := O.Id;
      Q.ExecSQL;
    end;
  finally
    Q.Free;
  end;
end;

function TTargetObjectRepository.LoadTargetObjects(AProjectId: Integer): TArray<TTargetObject>;
begin
  Result := LoadTargetObjectsRaw(AProjectId);
  ResolveInheritedProtectionNeeds(Result);
end;

function TTargetObjectRepository.CreateTargetObject(const ATargetObject: TTargetObject): TTargetObject;
var
  Q: TFDQuery;
begin
  Result := ATargetObject;
  ApplyCiaToProtectionNeed(Result);
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'INSERT INTO target_objects (project_id, parent_id, type, protection_need, ' +
      'confidentiality, integrity, availability, inherit_protection_need, protection_need_note, ' +
      'name, description) VALUES (:pid, :parent, :typ, :pn, :conf, :integ, :avail, :inherit, :pnnote, :name, :desc)';
    Q.ParamByName('pid').AsInteger := Result.ProjectId;
    Q.ParamByName('parent').AsInteger := Result.ParentId;
    Q.ParamByName('typ').AsString := TargetObjectTypeToString(Result.ObjType);
    BindProtectionNeedParams(Q, Result);
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
  Target: TTargetObject;
begin
  Result := False;
  Target := ATargetObject;
  ApplyCiaToProtectionNeed(Target);
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'UPDATE target_objects SET parent_id = :parent, type = :typ, protection_need = :pn, ' +
      'confidentiality = :conf, integrity = :integ, availability = :avail, ' +
      'inherit_protection_need = :inherit, protection_need_note = :pnnote, ' +
      'name = :name, description = :desc WHERE id = :id';
    Q.ParamByName('parent').AsInteger := Target.ParentId;
    Q.ParamByName('typ').AsString := TargetObjectTypeToString(Target.ObjType);
    BindProtectionNeedParams(Q, Target);
    Q.ParamByName('name').AsString := Target.Name;
    Q.ParamByName('desc').AsString := Target.Description;
    Q.ParamByName('id').AsInteger := Target.Id;
    Q.ExecSQL;
    PersistInheritedProtectionNeeds(Target.ProjectId);
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
    Q.SQL.Text := 'DELETE FROM baustein_deviations WHERE target_object_id = :id';
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
  Scope.Confidentiality := clNormal;
  Scope.Integrity := clNormal;
  Scope.Availability := clNormal;
  Scope.InheritProtectionNeed := False;
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

function TTargetObjectRepository.LoadDeviation(AProjectId, ATargetObjectId,
  ABausteinDbId: Integer): string;
var
  Q: TFDQuery;
begin
  Result := '';
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'SELECT note FROM baustein_deviations ' +
      'WHERE project_id = :pid AND target_object_id = :tid AND baustein_id = :bid';
    Q.ParamByName('pid').AsInteger := AProjectId;
    Q.ParamByName('tid').AsInteger := ATargetObjectId;
    Q.ParamByName('bid').AsInteger := ABausteinDbId;
    Q.Open;
    if not Q.IsEmpty then
      Result := Q.FieldByName('note').AsString;
  finally
    Q.Free;
  end;
end;

function TTargetObjectRepository.SaveDeviation(AProjectId, ATargetObjectId,
  ABausteinDbId: Integer; const ANote: string): Boolean;
var
  Q: TFDQuery;
begin
  Result := False;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    if Trim(ANote) = '' then
    begin
      Q.SQL.Text :=
        'DELETE FROM baustein_deviations ' +
        'WHERE project_id = :pid AND target_object_id = :tid AND baustein_id = :bid';
      Q.ParamByName('pid').AsInteger := AProjectId;
      Q.ParamByName('tid').AsInteger := ATargetObjectId;
      Q.ParamByName('bid').AsInteger := ABausteinDbId;
      Q.ExecSQL;
      Exit(True);
    end;
    Q.SQL.Text :=
      'INSERT INTO baustein_deviations (project_id, target_object_id, baustein_id, note) ' +
      'VALUES (:pid, :tid, :bid, :note) ' +
      'ON CONFLICT(project_id, target_object_id, baustein_id) DO UPDATE SET note = excluded.note';
    Q.ParamByName('pid').AsInteger := AProjectId;
    Q.ParamByName('tid').AsInteger := ATargetObjectId;
    Q.ParamByName('bid').AsInteger := ABausteinDbId;
    Q.ParamByName('note').AsString := ANote;
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
