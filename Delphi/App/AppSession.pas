unit AppSession;

interface

uses
  System.SysUtils, System.Classes, System.IniFiles, System.IOUtils, System.Generics.Collections,
  IsmsDomain, AppPaths, AppSettings;

type
  TAppSessionStore = class
  public
    class function SessionSection(AProjectId: Integer): string;
    class procedure SaveSession(AProjectId: Integer; const ASelection: TSessionSelection);
    class function LoadSession(AProjectId: Integer): TSessionSelection;
    class procedure SaveTargetSelection(AProjectId, ATargetObjectId, ABausteinId,
      ARequirementId: Integer);
    class procedure LoadTargetSelections(AProjectId: Integer;
      out ABausteineByTarget, ARequirementsByTarget: TDictionary<Integer, Integer>);
  end;

implementation

class function TAppSessionStore.SessionSection(AProjectId: Integer): string;
var
  Settings: TAppSettings;
  UserKey: string;
begin
  Settings := TAppSettings.Load;
  if Settings.UseRemote and (Trim(Settings.UserEmail) <> '') then
    UserKey := LowerCase(Trim(Settings.UserEmail)) + '_'
  else
    UserKey := '';
  Result := 'ProjectSession_' + UserKey + IntToStr(AProjectId);
end;

class procedure TAppSessionStore.SaveSession(AProjectId: Integer;
  const ASelection: TSessionSelection);
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(TPath.Combine(DataDirectory, 'settings.ini'));
  try
    Ini.WriteInteger(SessionSection(AProjectId), 'targetObjectId', ASelection.TargetObjectId);
    Ini.WriteInteger(SessionSection(AProjectId), 'bausteinId', ASelection.BausteinId);
    Ini.WriteInteger(SessionSection(AProjectId), 'requirementId', ASelection.RequirementId);
  finally
    Ini.Free;
  end;
end;

class function TAppSessionStore.LoadSession(AProjectId: Integer): TSessionSelection;
var
  Ini: TIniFile;
begin
  FillChar(Result, SizeOf(Result), 0);
  Ini := TIniFile.Create(TPath.Combine(DataDirectory, 'settings.ini'));
  try
    Result.TargetObjectId := Ini.ReadInteger(SessionSection(AProjectId), 'targetObjectId', 0);
    Result.BausteinId := Ini.ReadInteger(SessionSection(AProjectId), 'bausteinId', 0);
    Result.RequirementId := Ini.ReadInteger(SessionSection(AProjectId), 'requirementId', 0);
  finally
    Ini.Free;
  end;
end;

class procedure TAppSessionStore.SaveTargetSelection(AProjectId, ATargetObjectId,
  ABausteinId, ARequirementId: Integer);
var
  Ini: TIniFile;
  Section: string;
begin
  if ATargetObjectId <= 0 then
    Exit;
  Ini := TIniFile.Create(TPath.Combine(DataDirectory, 'settings.ini'));
  try
    Section := SessionSection(AProjectId);
    if ABausteinId > 0 then
      Ini.WriteInteger(Section, 'target_' + IntToStr(ATargetObjectId) + '_baustein', ABausteinId);
    if ARequirementId > 0 then
      Ini.WriteInteger(Section, 'target_' + IntToStr(ATargetObjectId) + '_requirement', ARequirementId);
  finally
    Ini.Free;
  end;
end;

class procedure TAppSessionStore.LoadTargetSelections(AProjectId: Integer;
  out ABausteineByTarget, ARequirementsByTarget: TDictionary<Integer, Integer>);
var
  Ini: TIniFile;
  Keys: TStringList;
  I, TargetId, BausteinId, RequirementId: Integer;
  Key, Section, Suffix: string;
begin
  ABausteineByTarget := TDictionary<Integer, Integer>.Create;
  ARequirementsByTarget := TDictionary<Integer, Integer>.Create;
  Ini := TIniFile.Create(TPath.Combine(DataDirectory, 'settings.ini'));
  Keys := TStringList.Create;
  try
    Section := SessionSection(AProjectId);
    Ini.ReadSection(Section, Keys);
    for I := 0 to Keys.Count - 1 do
    begin
      Key := Keys[I];
      if Key.StartsWith('target_') and Key.EndsWith('_baustein') then
      begin
        Suffix := Copy(Key, Length('target_'), MaxInt);
        Delete(Suffix, Pos('_baustein', Suffix), Length('_baustein'));
        TargetId := StrToIntDef(Suffix, 0);
        BausteinId := Ini.ReadInteger(Section, Key, 0);
        if (TargetId > 0) and (BausteinId > 0) then
          ABausteineByTarget.AddOrSetValue(TargetId, BausteinId);
      end
      else if Key.StartsWith('target_') and Key.EndsWith('_requirement') then
      begin
        Suffix := Copy(Key, Length('target_'), MaxInt);
        Delete(Suffix, Pos('_requirement', Suffix), Length('_requirement'));
        TargetId := StrToIntDef(Suffix, 0);
        RequirementId := Ini.ReadInteger(Section, Key, 0);
        if (TargetId > 0) and (RequirementId > 0) then
          ARequirementsByTarget.AddOrSetValue(TargetId, RequirementId);
      end;
    end;
  finally
    Keys.Free;
    Ini.Free;
  end;
end;

end.
