unit CockpitService;

interface

uses
  System.SysUtils, System.DateUtils, System.Generics.Collections, System.Generics.Defaults,
  IsmsDomain, RepositoryBase, ReportService;

type
  TCockpitService = class
  private
    FCatalog: TCatalogRepositoryBase;
    FProject: TProjectRepositoryBase;
    FTarget: TTargetObjectRepositoryBase;
    FMeasure: TMeasureRepositoryBase;
    class function ItemDueSortKey(const AItem: TCockpitItem): TDateTime;
    class function CompareItems(const L, R: TCockpitItem): Integer;
    class function ResponsibleMatches(const AResponsible, AName, AEmail,
      ANeedle: string): Boolean;
  public
    constructor Create(ACatalog: TCatalogRepositoryBase; AProject: TProjectRepositoryBase;
      ATarget: TTargetObjectRepositoryBase; AMeasure: TMeasureRepositoryBase);
    function BuildItems(AProjectId: Integer;
      const ACatalogVersion: string): TArray<TCockpitItem>;
    class function ApplyFilter(const AItems: TArray<TCockpitItem>;
      const AFilter: TCockpitFilter): TArray<TCockpitItem>;
    class function Summarize(const AItems: TArray<TCockpitItem>): TCockpitSummary;
    class function FormatSummary(const ASummary: TCockpitSummary): string;
  end;

implementation

constructor TCockpitService.Create(ACatalog: TCatalogRepositoryBase;
  AProject: TProjectRepositoryBase; ATarget: TTargetObjectRepositoryBase;
  AMeasure: TMeasureRepositoryBase);
begin
  inherited Create;
  FCatalog := ACatalog;
  FProject := AProject;
  FTarget := ATarget;
  FMeasure := AMeasure;
end;

class function TCockpitService.ItemDueSortKey(const AItem: TCockpitItem): TDateTime;
begin
  if IsValidDate(AItem.DueDate) then
    Exit(AItem.DueDate);
  Result := EncodeDate(9999, 12, 31);
end;

class function TCockpitService.CompareItems(const L, R: TCockpitItem): Integer;
begin
  if L.Overdue <> R.Overdue then
  begin
    if L.Overdue then
      Exit(-1);
    Exit(1);
  end;
  Result := CompareDate(ItemDueSortKey(L), ItemDueSortKey(R));
  if Result <> 0 then
    Exit;
  Result := CompareText(L.TargetObjectName, R.TargetObjectName);
  if Result <> 0 then
    Exit;
  Result := CompareText(L.BausteinExternalId, R.BausteinExternalId);
  if Result <> 0 then
    Exit;
  Result := Ord(L.Kind) - Ord(R.Kind);
  if Result <> 0 then
    Exit;
  Result := CompareText(L.RequirementExternalId, R.RequirementExternalId);
  if Result <> 0 then
    Exit;
  Result := CompareText(L.Title, R.Title);
end;

class function TCockpitService.ResponsibleMatches(const AResponsible, AName, AEmail,
  ANeedle: string): Boolean;
var
  ResponsibleLower, NeedleLower: string;
begin
  ResponsibleLower := LowerCase(Trim(AResponsible));
  if ResponsibleLower = '' then
    Exit(False);
  if Trim(ANeedle) <> '' then
  begin
    NeedleLower := LowerCase(Trim(ANeedle));
    Exit(Pos(NeedleLower, ResponsibleLower) > 0);
  end;
  if (Trim(AName) <> '') and (Pos(LowerCase(Trim(AName)), ResponsibleLower) > 0) then
    Exit(True);
  if (Trim(AEmail) <> '') and (Pos(LowerCase(Trim(AEmail)), ResponsibleLower) > 0) then
    Exit(True);
  Result := False;
end;

function TCockpitService.BuildItems(AProjectId: Integer;
  const ACatalogVersion: string): TArray<TCockpitItem>;
var
  Report: TReportService;
  Rows: TArray<TReportRow>;
  Row: TReportRow;
  Measures: TArray<TMeasure>;
  Measure: TMeasure;
  Requirements: TArray<TRequirement>;
  Requirement: TRequirement;
  Targets: TArray<TTargetObject>;
  Target: TTargetObject;
  ReqById: TDictionary<Integer, TRequirement>;
  TargetNameById: TDictionary<Integer, string>;
  AssessmentByKey: TDictionary<string, TReportRow>;
  Item: TCockpitItem;
  List: TList<TCockpitItem>;
  Key: string;
  Linked: TReportRow;
begin
  List := TList<TCockpitItem>.Create;
  ReqById := TDictionary<Integer, TRequirement>.Create;
  TargetNameById := TDictionary<Integer, string>.Create;
  AssessmentByKey := TDictionary<string, TReportRow>.Create;
  Report := TReportService.Create(FCatalog, FProject, FTarget, FMeasure);
  try
    Rows := Report.BuildSollIstReport(AProjectId, 0, ACatalogVersion);
    for Row in Rows do
    begin
      FillChar(Item, SizeOf(Item), 0);
      Item.Kind := ckAssessment;
      Item.TargetObjectId := Row.TargetObjectId;
      Item.TargetObjectName := Row.TargetObjectName;
      Item.BausteinDbId := Row.BausteinDbId;
      Item.BausteinExternalId := Row.BausteinExternalId;
      Item.RequirementDbId := Row.RequirementDbId;
      Item.RequirementExternalId := Row.RequirementExternalId;
      Item.Title := Row.RequirementTitle;
      Item.StatusText := AssessmentStatusToString(Row.Status);
      Item.Responsible := Row.Responsible;
      Item.DueDate := Row.DueDate;
      Item.Overdue := Row.Overdue;
      Item.AssessmentStatus := Row.Status;
      List.Add(Item);
      AssessmentByKey.AddOrSetValue(Format('%d:%d', [Row.TargetObjectId, Row.RequirementDbId]), Row);
    end;

    Requirements := FCatalog.LoadAllRequirements(stITGrundschutz, ACatalogVersion);
    for Requirement in Requirements do
      ReqById.AddOrSetValue(Requirement.Id, Requirement);

    Targets := FTarget.LoadTargetObjects(AProjectId);
    for Target in Targets do
      TargetNameById.AddOrSetValue(Target.Id, Target.Name);

    Measures := FMeasure.LoadProjectMeasures(AProjectId);
    for Measure in Measures do
    begin
      FillChar(Item, SizeOf(Item), 0);
      Item.Kind := ckMeasure;
      Item.MeasureId := Measure.Id;
      Item.TargetObjectId := Measure.TargetObjectId;
      if not TargetNameById.TryGetValue(Measure.TargetObjectId, Item.TargetObjectName) then
        Item.TargetObjectName := IntToStr(Measure.TargetObjectId);
      Item.RequirementDbId := Measure.RequirementDbId;
      if ReqById.TryGetValue(Measure.RequirementDbId, Requirement) then
      begin
        Item.BausteinDbId := Requirement.BausteinDbId;
        Item.BausteinExternalId := Requirement.BausteinExternalId;
        Item.RequirementExternalId := Requirement.ExternalId;
      end;
      Key := Format('%d:%d', [Measure.TargetObjectId, Measure.RequirementDbId]);
      if AssessmentByKey.TryGetValue(Key, Linked) then
      begin
        Item.AssessmentStatus := Linked.Status;
        if Item.BausteinDbId = 0 then
        begin
          Item.BausteinDbId := Linked.BausteinDbId;
          Item.BausteinExternalId := Linked.BausteinExternalId;
          Item.RequirementExternalId := Linked.RequirementExternalId;
        end;
      end;
      Item.Title := Measure.Title;
      Item.StatusText := MeasureStatusToString(Measure.Status);
      Item.Responsible := Measure.Responsible;
      Item.DueDate := Measure.DueDate;
      Item.MeasureStatus := Measure.Status;
      Item.Overdue := IsValidDate(Measure.DueDate) and (Measure.DueDate < Date) and
        (Measure.Status <> msDone);
      List.Add(Item);
    end;

    List.Sort(TComparer<TCockpitItem>.Construct(
      function(const L, R: TCockpitItem): Integer
      begin
        Result := CompareItems(L, R);
      end));
    Result := List.ToArray;
  finally
    Report.Free;
    AssessmentByKey.Free;
    TargetNameById.Free;
    ReqById.Free;
    List.Free;
  end;
end;

class function TCockpitService.ApplyFilter(const AItems: TArray<TCockpitItem>;
  const AFilter: TCockpitFilter): TArray<TCockpitItem>;
var
  Item: TCockpitItem;
  List: TList<TCockpitItem>;
begin
  List := TList<TCockpitItem>.Create;
  try
    for Item in AItems do
    begin
      case AFilter.Kind of
        ckfAssessments:
          if Item.Kind <> ckAssessment then
            Continue;
        ckfMeasures:
          if Item.Kind <> ckMeasure then
            Continue;
      end;
      if AFilter.HideDone and CockpitItemIsDone(Item) then
        Continue;
      case AFilter.Due of
        cdfOverdue:
          if not Item.Overdue then
            Continue;
        cdfThisWeek:
          if not IsDueThisWeek(Item.DueDate) then
            Continue;
        cdfHasDate:
          if not IsValidDate(Item.DueDate) then
            Continue;
        cdfNoDate:
          if IsValidDate(Item.DueDate) then
            Continue;
      end;
      if AFilter.MineOnly then
      begin
        if not ResponsibleMatches(Item.Responsible, AFilter.CurrentUserName,
          AFilter.CurrentUserEmail, '') then
          Continue;
      end
      else if Trim(AFilter.ResponsibleNeedle) <> '' then
      begin
        if not ResponsibleMatches(Item.Responsible, '', '', AFilter.ResponsibleNeedle) then
          Continue;
      end;
      List.Add(Item);
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

class function TCockpitService.Summarize(const AItems: TArray<TCockpitItem>): TCockpitSummary;
var
  Item: TCockpitItem;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.TotalCount := Length(AItems);
  for Item in AItems do
  begin
    case Item.Kind of
      ckAssessment: Inc(Result.AssessmentCount);
      ckMeasure: Inc(Result.MeasureCount);
    end;
    if Item.Overdue then
      Inc(Result.OverdueCount);
    if IsDueThisWeek(Item.DueDate) then
      Inc(Result.DueThisWeekCount);
  end;
end;

class function TCockpitService.FormatSummary(const ASummary: TCockpitSummary): string;
var
  Parts: TArray<string>;
begin
  if ASummary.TotalCount = 0 then
    Exit('Keine offenen Aufgaben');
  Result := Format('%d Eintr'#$00E4'ge', [ASummary.TotalCount]);
  SetLength(Parts, 0);
  if ASummary.AssessmentCount > 0 then
  begin
    SetLength(Parts, Length(Parts) + 1);
    Parts[High(Parts)] := Format('%d Bewertungen', [ASummary.AssessmentCount]);
  end;
  if ASummary.MeasureCount > 0 then
  begin
    SetLength(Parts, Length(Parts) + 1);
    Parts[High(Parts)] := Format('%d Ma'#$00DF'nahmen', [ASummary.MeasureCount]);
  end;
  if ASummary.OverdueCount > 0 then
  begin
    SetLength(Parts, Length(Parts) + 1);
    Parts[High(Parts)] := Format('%d '#252'berf'#$00E4'llig', [ASummary.OverdueCount]);
  end;
  if ASummary.DueThisWeekCount > 0 then
  begin
    SetLength(Parts, Length(Parts) + 1);
    Parts[High(Parts)] := Format('%d diese Woche', [ASummary.DueThisWeekCount]);
  end;
  if Length(Parts) > 0 then
    Result := Result + ' ' + #$2013 + ' ' + string.Join(', ', Parts);
end;

end.
