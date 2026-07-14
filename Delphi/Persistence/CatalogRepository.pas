unit CatalogRepository;

interface

uses
  System.SysUtils, System.Generics.Collections, FireDAC.Comp.Client, FireDAC.DApt,
  IsmsDomain, GrundschutzImporter, RepositoryBase;

type
  TCatalogRepository = class(TCatalogRepositoryBase)
  private
    FConnection: TFDConnection;
    FLastError: string;
  public
    constructor Create(AConnection: TFDConnection);
    function ReplaceGrundschutzCatalog(const AImportResult: TGrundschutzImportResult;
      const ASourceXmlPath: string = ''): Boolean; override;
    function HasGrundschutzCatalog(const ACatalogVersion: string): Boolean; override;
    function LoadBausteine(AStandard: TStandardType; const ACatalogVersion: string): TArray<TBaustein>; override;
    function LoadRequirements(ABausteinDbId: Integer): TArray<TRequirement>; override;
    function LoadAllRequirements(AStandard: TStandardType; const ACatalogVersion: string): TArray<TRequirement>; override;
    function GetLastError: string; override;
  end;

implementation

constructor TCatalogRepository.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TCatalogRepository.ReplaceGrundschutzCatalog(const AImportResult: TGrundschutzImportResult;
  const ASourceXmlPath: string): Boolean;
var
  Q: TFDQuery;
  BausteinIds: TDictionary<string, Integer>;
  B: TBaustein;
  R: TRequirement;
  BausteinId: Integer;
begin
  Result := False;
  if not AImportResult.Success then
    Exit;
  BausteinIds := TDictionary<string, Integer>.Create;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    FConnection.StartTransaction;
    try
      Q.ExecSQL('DELETE FROM requirements');
      Q.SQL.Text := 'DELETE FROM bausteine WHERE standard = :std AND catalog_version = :ver';
      Q.ParamByName('std').AsString := StandardTypeToString(stITGrundschutz);
      Q.ParamByName('ver').AsString := AImportResult.CatalogVersion;
      Q.ExecSQL;
      Q.SQL.Text :=
        'INSERT INTO bausteine (standard, external_id, title, group_name, catalog_version) ' +
        'VALUES (:std, :ext, :title, :grp, :ver)';
      for B in AImportResult.Bausteine do
      begin
        Q.ParamByName('std').AsString := StandardTypeToString(B.Standard);
        Q.ParamByName('ext').AsString := B.ExternalId;
        Q.ParamByName('title').AsString := B.Title;
        Q.ParamByName('grp').AsString := B.GroupName;
        Q.ParamByName('ver').AsString := AImportResult.CatalogVersion;
        Q.ExecSQL;
        BausteinIds.AddOrSetValue(B.ExternalId,
          Integer(FConnection.ExecSQLScalar('SELECT last_insert_rowid()')));
      end;
      Q.SQL.Text :=
        'INSERT INTO requirements (baustein_id, standard, external_id, baustein_external_id, ' +
        'title, text, level, responsible_role, withdrawn) ' +
        'VALUES (:bid, :std, :ext, :bext, :title, :txt, :lvl, :role, :wd)';
      for R in AImportResult.Requirements do
      begin
        if not BausteinIds.TryGetValue(R.BausteinExternalId, BausteinId) then
          Continue;
        Q.ParamByName('bid').AsInteger := BausteinId;
        Q.ParamByName('std').AsString := StandardTypeToString(R.Standard);
        Q.ParamByName('ext').AsString := R.ExternalId;
        Q.ParamByName('bext').AsString := R.BausteinExternalId;
        Q.ParamByName('title').AsString := R.Title;
        Q.ParamByName('txt').AsString := R.Text;
        Q.ParamByName('lvl').AsString := RequirementLevelToString(R.Level);
        Q.ParamByName('role').AsString := R.ResponsibleRole;
        Q.ParamByName('wd').AsInteger := Ord(R.Withdrawn);
        Q.ExecSQL;
      end;
      Q.SQL.Text :=
        'INSERT INTO catalog_meta (key, value) VALUES (:k, :v) ' +
        'ON CONFLICT(key) DO UPDATE SET value = excluded.value';
      Q.ParamByName('k').AsString := 'grundschutz_version';
      Q.ParamByName('v').AsString := AImportResult.CatalogVersion;
      Q.ExecSQL;
      FConnection.Commit;
      Result := True;
    except
      on E: Exception do
      begin
        FLastError := E.Message;
        FConnection.Rollback;
      end;
    end;
  finally
    Q.Free;
    BausteinIds.Free;
  end;
end;

function TCatalogRepository.HasGrundschutzCatalog(const ACatalogVersion: string): Boolean;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := 'SELECT COUNT(*) FROM bausteine WHERE standard = :std AND catalog_version = :ver';
    Q.ParamByName('std').AsString := StandardTypeToString(stITGrundschutz);
    Q.ParamByName('ver').AsString := ACatalogVersion;
    Q.Open;
    Result := Q.Fields[0].AsInteger > 0;
  finally
    Q.Free;
  end;
end;

function TCatalogRepository.LoadBausteine(AStandard: TStandardType;
  const ACatalogVersion: string): TArray<TBaustein>;
var
  Q: TFDQuery;
  List: TArray<TBaustein>;
  B: TBaustein;
begin
  SetLength(List, 0);
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'SELECT id, external_id, title, group_name FROM bausteine ' +
      'WHERE standard = :std AND catalog_version = :ver ORDER BY group_name, external_id';
    Q.ParamByName('std').AsString := StandardTypeToString(AStandard);
    Q.ParamByName('ver').AsString := ACatalogVersion;
    Q.Open;
    while not Q.Eof do
    begin
      FillChar(B, SizeOf(B), 0);
      B.Id := Q.FieldByName('id').AsInteger;
      B.Standard := AStandard;
      B.ExternalId := Q.FieldByName('external_id').AsString;
      B.Title := Q.FieldByName('title').AsString;
      B.GroupName := Q.FieldByName('group_name').AsString;
      B.CatalogVersion := ACatalogVersion;
      SetLength(List, Length(List) + 1);
      List[High(List)] := B;
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  Result := List;
end;

function TCatalogRepository.LoadRequirements(ABausteinDbId: Integer): TArray<TRequirement>;
var
  Q: TFDQuery;
  List: TArray<TRequirement>;
  R: TRequirement;
begin
  SetLength(List, 0);
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'SELECT id, baustein_id, standard, external_id, baustein_external_id, title, text, ' +
      'level, responsible_role, withdrawn FROM requirements WHERE baustein_id = :bid ORDER BY external_id';
    Q.ParamByName('bid').AsInteger := ABausteinDbId;
    Q.Open;
    while not Q.Eof do
    begin
      FillChar(R, SizeOf(R), 0);
      R.Id := Q.FieldByName('id').AsInteger;
      R.BausteinDbId := Q.FieldByName('baustein_id').AsInteger;
      R.Standard := StandardTypeFromString(Q.FieldByName('standard').AsString);
      R.ExternalId := Q.FieldByName('external_id').AsString;
      R.BausteinExternalId := Q.FieldByName('baustein_external_id').AsString;
      R.Title := Q.FieldByName('title').AsString;
      R.Text := Q.FieldByName('text').AsString;
      R.Level := RequirementLevelFromString(Q.FieldByName('level').AsString);
      R.ResponsibleRole := Q.FieldByName('responsible_role').AsString;
      R.Withdrawn := Q.FieldByName('withdrawn').AsInteger <> 0;
      SetLength(List, Length(List) + 1);
      List[High(List)] := R;
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  Result := List;
end;

function TCatalogRepository.LoadAllRequirements(AStandard: TStandardType;
  const ACatalogVersion: string): TArray<TRequirement>;
var
  Q: TFDQuery;
  List: TArray<TRequirement>;
  R: TRequirement;
begin
  SetLength(List, 0);
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'SELECT r.id, r.baustein_id, r.standard, r.external_id, r.baustein_external_id, ' +
      'r.title, r.text, r.level, r.responsible_role, r.withdrawn ' +
      'FROM requirements r JOIN bausteine b ON r.baustein_id = b.id ' +
      'WHERE r.standard = :std AND b.catalog_version = :ver ORDER BY r.external_id';
    Q.ParamByName('std').AsString := StandardTypeToString(AStandard);
    Q.ParamByName('ver').AsString := ACatalogVersion;
    Q.Open;
    while not Q.Eof do
    begin
      FillChar(R, SizeOf(R), 0);
      R.Id := Q.FieldByName('id').AsInteger;
      R.BausteinDbId := Q.FieldByName('baustein_id').AsInteger;
      R.Standard := StandardTypeFromString(Q.FieldByName('standard').AsString);
      R.ExternalId := Q.FieldByName('external_id').AsString;
      R.BausteinExternalId := Q.FieldByName('baustein_external_id').AsString;
      R.Title := Q.FieldByName('title').AsString;
      R.Text := Q.FieldByName('text').AsString;
      R.Level := RequirementLevelFromString(Q.FieldByName('level').AsString);
      R.ResponsibleRole := Q.FieldByName('responsible_role').AsString;
      R.Withdrawn := Q.FieldByName('withdrawn').AsInteger <> 0;
      SetLength(List, Length(List) + 1);
      List[High(List)] := R;
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  Result := List;
end;

function TCatalogRepository.GetLastError: string;
begin
  Result := FLastError;
end;

end.
