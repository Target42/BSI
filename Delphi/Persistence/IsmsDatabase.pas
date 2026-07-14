unit IsmsDatabase;

interface

uses
  System.SysUtils, FireDAC.Comp.Client, FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.Def, FireDAC.Stan.Intf, FireDAC.Stan.Async, FireDAC.DApt;

type
  TIsmsDatabase = class
  private
    FConnection: TFDConnection;
    FLastError: string;
    function TableExists(const ATable: string): Boolean;
    function TableHasColumn(const ATable, AColumn: string): Boolean;
    function InitializeSchema: Boolean;
    function MigrateSchema: Boolean;
    function EnsureIndexes: Boolean;
    function MigrateAssessmentTargetObjectColumn: Boolean;
    function MigrateAssessmentDueDateColumn: Boolean;
    function MigrateTargetObjectProtectionNeedColumn: Boolean;
  public
    constructor Create(const AFilePath: string);
    destructor Destroy; override;
    function Open: Boolean;
    procedure Close;
    function IsOpen: Boolean;
    property Connection: TFDConnection read FConnection;
    property LastError: string read FLastError;
  end;

implementation

constructor TIsmsDatabase.Create(const AFilePath: string);
begin
  inherited Create;
  FConnection := TFDConnection.Create(nil);
  FConnection.DriverName := 'SQLite';
  FConnection.Params.Values['Database'] := AFilePath;
  FConnection.Params.Values['OpenMode'] := 'CreateUTF8';
  FConnection.Params.Values['LockingMode'] := 'Normal';
end;

destructor TIsmsDatabase.Destroy;
begin
  Close;
  FConnection.Free;
  inherited;
end;

function TIsmsDatabase.Open: Boolean;
begin
  if FConnection.Connected then
    Exit(True);
  try
    FConnection.Connected := True;
    FConnection.ExecSQL('PRAGMA foreign_keys = ON');
    if not InitializeSchema then
    begin
      Close;
      Exit(False);
    end;
    if not MigrateSchema then
    begin
      Close;
      Exit(False);
    end;
    if not EnsureIndexes then
    begin
      Close;
      Exit(False);
    end;
    Result := True;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      Result := False;
    end;
  end;
end;

procedure TIsmsDatabase.Close;
begin
  if FConnection.Connected then
    FConnection.Connected := False;
end;

function TIsmsDatabase.IsOpen: Boolean;
begin
  Result := FConnection.Connected;
end;

function TIsmsDatabase.TableExists(const ATable: string): Boolean;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := 'SELECT name FROM sqlite_master WHERE type = ''table'' AND name = :t';
    Q.ParamByName('t').AsString := ATable;
    Q.Open;
    Result := not Q.IsEmpty;
  finally
    Q.Free;
  end;
end;

function TIsmsDatabase.TableHasColumn(const ATable, AColumn: string): Boolean;
var
  Q: TFDQuery;
begin
  Result := False;
  if not TableExists(ATable) then
    Exit;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := 'PRAGMA table_info(' + ATable + ')';
    Q.Open;
    while not Q.Eof do
    begin
      if SameText(Q.FieldByName('name').AsString, AColumn) then
        Exit(True);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

function TIsmsDatabase.InitializeSchema: Boolean;
const
  Statements: array[0..7] of string = (
    'CREATE TABLE IF NOT EXISTS catalog_meta (' +
      'key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS bausteine (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, standard TEXT NOT NULL, external_id TEXT NOT NULL, ' +
      'title TEXT NOT NULL, group_name TEXT, catalog_version TEXT NOT NULL, ' +
      'UNIQUE(standard, external_id, catalog_version))',
    'CREATE TABLE IF NOT EXISTS requirements (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, baustein_id INTEGER NOT NULL, standard TEXT NOT NULL, ' +
      'external_id TEXT NOT NULL, baustein_external_id TEXT NOT NULL, title TEXT NOT NULL, ' +
      'text TEXT, level TEXT NOT NULL, responsible_role TEXT, withdrawn INTEGER NOT NULL DEFAULT 0, ' +
      'FOREIGN KEY(baustein_id) REFERENCES bausteine(id) ON DELETE CASCADE, ' +
      'UNIQUE(standard, external_id, baustein_id))',
    'CREATE TABLE IF NOT EXISTS projects (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, description TEXT, ' +
      'catalog_version TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS target_objects (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, project_id INTEGER NOT NULL, parent_id INTEGER NOT NULL DEFAULT 0, ' +
      'type TEXT NOT NULL, protection_need TEXT NOT NULL DEFAULT ''Normal (Basis + Standard)'', ' +
      'name TEXT NOT NULL, description TEXT, ' +
      'FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE)',
    'CREATE TABLE IF NOT EXISTS baustein_applicability (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, project_id INTEGER NOT NULL, target_object_id INTEGER NOT NULL, ' +
      'baustein_id INTEGER NOT NULL, status TEXT NOT NULL, ' +
      'FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE, ' +
      'FOREIGN KEY(target_object_id) REFERENCES target_objects(id) ON DELETE CASCADE, ' +
      'FOREIGN KEY(baustein_id) REFERENCES bausteine(id) ON DELETE CASCADE, ' +
      'UNIQUE(project_id, target_object_id, baustein_id))',
    'CREATE TABLE IF NOT EXISTS requirement_assessments (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, project_id INTEGER NOT NULL, ' +
      'target_object_id INTEGER NOT NULL DEFAULT 0, requirement_id INTEGER NOT NULL, ' +
      'status TEXT NOT NULL, note TEXT, responsible TEXT, due_date TEXT, ' +
      'FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE, ' +
      'FOREIGN KEY(requirement_id) REFERENCES requirements(id) ON DELETE CASCADE, ' +
      'UNIQUE(project_id, target_object_id, requirement_id))',
    'CREATE TABLE IF NOT EXISTS measures (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, project_id INTEGER NOT NULL, target_object_id INTEGER NOT NULL, ' +
      'requirement_id INTEGER NOT NULL, title TEXT NOT NULL, description TEXT, responsible TEXT, ' +
      'due_date TEXT, status TEXT NOT NULL, ' +
      'FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE, ' +
      'FOREIGN KEY(target_object_id) REFERENCES target_objects(id) ON DELETE CASCADE, ' +
      'FOREIGN KEY(requirement_id) REFERENCES requirements(id) ON DELETE CASCADE)'
  );
var
  I: Integer;
begin
  try
    for I := Low(Statements) to High(Statements) do
      FConnection.ExecSQL(Statements[I]);
    Result := True;
  except
    on E: Exception do
    begin
      FLastError := 'Schema: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TIsmsDatabase.MigrateAssessmentTargetObjectColumn: Boolean;
begin
  if TableHasColumn('requirement_assessments', 'target_object_id') then
    Exit(True);
  if not TableExists('requirement_assessments') then
    Exit(True);
  try
    if TableExists('requirement_assessments_new') then
      FConnection.ExecSQL('DROP TABLE requirement_assessments_new');
    FConnection.ExecSQL(
      'CREATE TABLE requirement_assessments_new (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, project_id INTEGER NOT NULL, ' +
      'target_object_id INTEGER NOT NULL DEFAULT 0, requirement_id INTEGER NOT NULL, ' +
      'status TEXT NOT NULL, note TEXT, responsible TEXT, ' +
      'FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE, ' +
      'FOREIGN KEY(requirement_id) REFERENCES requirements(id) ON DELETE CASCADE, ' +
      'UNIQUE(project_id, target_object_id, requirement_id))');
    FConnection.ExecSQL(
      'INSERT INTO requirement_assessments_new ' +
      '(id, project_id, target_object_id, requirement_id, status, note, responsible) ' +
      'SELECT id, project_id, 0, requirement_id, status, note, responsible ' +
      'FROM requirement_assessments');
    FConnection.ExecSQL('DROP TABLE requirement_assessments');
    FConnection.ExecSQL('ALTER TABLE requirement_assessments_new RENAME TO requirement_assessments');
    Result := True;
  except
    on E: Exception do
    begin
      FLastError := 'Migration: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TIsmsDatabase.MigrateAssessmentDueDateColumn: Boolean;
begin
  if not TableExists('requirement_assessments') then
    Exit(True);
  if TableHasColumn('requirement_assessments', 'due_date') then
    Exit(True);
  try
    FConnection.ExecSQL('ALTER TABLE requirement_assessments ADD COLUMN due_date TEXT');
    Result := True;
  except
    on E: Exception do
    begin
      FLastError := 'Migration (Frist): ' + E.Message;
      Result := False;
    end;
  end;
end;

function TIsmsDatabase.MigrateTargetObjectProtectionNeedColumn: Boolean;
begin
  if not TableExists('target_objects') then
    Exit(True);
  if TableHasColumn('target_objects', 'protection_need') then
    Exit(True);
  try
    FConnection.ExecSQL(
      'ALTER TABLE target_objects ADD COLUMN protection_need TEXT NOT NULL ' +
      'DEFAULT ''Normal (Basis + Standard)''');
    Result := True;
  except
    on E: Exception do
    begin
      FLastError := 'Migration (Schutzbedarf): ' + E.Message;
      Result := False;
    end;
  end;
end;

function TIsmsDatabase.MigrateSchema: Boolean;
begin
  Result := MigrateAssessmentTargetObjectColumn and
            MigrateAssessmentDueDateColumn and
            MigrateTargetObjectProtectionNeedColumn;
end;

function TIsmsDatabase.EnsureIndexes: Boolean;
const
  Statements: array[0..5] of string = (
    'CREATE INDEX IF NOT EXISTS idx_requirements_baustein ON requirements(baustein_id)',
    'CREATE INDEX IF NOT EXISTS idx_assessments_project ON requirement_assessments(project_id)',
    'CREATE INDEX IF NOT EXISTS idx_assessments_target ON requirement_assessments(project_id, target_object_id)',
    'CREATE INDEX IF NOT EXISTS idx_target_objects_project ON target_objects(project_id)',
    'CREATE INDEX IF NOT EXISTS idx_applicability_target ON baustein_applicability(project_id, target_object_id)',
    'CREATE INDEX IF NOT EXISTS idx_measures_requirement ON measures(project_id, target_object_id, requirement_id)'
  );
var
  I: Integer;
begin
  try
    for I := Low(Statements) to High(Statements) do
      FConnection.ExecSQL(Statements[I]);
    Result := True;
  except
    on E: Exception do
    begin
      FLastError := 'Index: ' + E.Message;
      Result := False;
    end;
  end;
end;

end.
