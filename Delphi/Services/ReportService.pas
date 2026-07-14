unit ReportService;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Math, IsmsDomain,
  RepositoryBase;

type
  TReportService = class
  private
    FCatalog: TCatalogRepositoryBase;
    FProject: TProjectRepositoryBase;
    FTarget: TTargetObjectRepositoryBase;
    FMeasure: TMeasureRepositoryBase;
    class procedure SortRows(var ARows: TArray<TReportRow>);
  public
    constructor Create(ACatalog: TCatalogRepositoryBase; AProject: TProjectRepositoryBase;
      ATarget: TTargetObjectRepositoryBase; AMeasure: TMeasureRepositoryBase);
    function BuildSollIstReport(AProjectId, ATargetObjectId: Integer;
      const ACatalogVersion: string): TArray<TReportRow>;
    function Summarize(const ARows: TArray<TReportRow>): TReportSummary;
    function SummarizeByTargetObject(const ARows: TArray<TReportRow>): TDictionary<Integer, TReportSummary>;
    function SummarizeByTargetObjectForProject(AProjectId: Integer;
      const ACatalogVersion: string): TDictionary<Integer, TReportSummary>;
    class function ProgressPercent(const ASummary: TReportSummary): Integer;
    class function FormatSummaryText(const ASummary: TReportSummary): string;
    class function FormatTreeProgressSuffix(const ASummary: TReportSummary): string;
  end;

implementation

constructor TReportService.Create(ACatalog: TCatalogRepositoryBase; AProject: TProjectRepositoryBase;
  ATarget: TTargetObjectRepositoryBase; AMeasure: TMeasureRepositoryBase);
begin
  inherited Create;
  FCatalog := ACatalog;
  FProject := AProject;
  FTarget := ATarget;
  FMeasure := AMeasure;
end;

class procedure TReportService.SortRows(var ARows: TArray<TReportRow>);
var
  I, J: Integer;
  Temp: TReportRow;
begin
  for I := 0 to High(ARows) - 1 do
    for J := I + 1 to High(ARows) do
    begin
      if (ARows[J].TargetObjectName < ARows[I].TargetObjectName) or
         ((ARows[J].TargetObjectName = ARows[I].TargetObjectName) and
          (ARows[J].BausteinExternalId < ARows[I].BausteinExternalId)) or
         ((ARows[J].TargetObjectName = ARows[I].TargetObjectName) and
          (ARows[J].BausteinExternalId = ARows[I].BausteinExternalId) and
          (ARows[J].RequirementExternalId < ARows[I].RequirementExternalId)) then
      begin
        Temp := ARows[I];
        ARows[I] := ARows[J];
        ARows[J] := Temp;
      end;
    end;
end;

function TReportService.BuildSollIstReport(AProjectId, ATargetObjectId: Integer;
  const ACatalogVersion: string): TArray<TReportRow>;
var
  Rows: TArray<TReportRow>;
  AllBausteine: TArray<TBaustein>;
  BausteinById: TDictionary<Integer, TBaustein>;
  TargetObjects: TArray<TTargetObject>;
  TargetObject: TTargetObject;
  ApplicabilityMap: TDictionary<Integer, TApplicabilityStatus>;
  MeasureCounts: TDictionary<Integer, Integer>;
  Baustein: TBaustein;
  Pair: TPair<Integer, TApplicabilityStatus>;
  Requirements: TArray<TRequirement>;
  Requirement: TRequirement;
  Assessment: TRequirementAssessment;
  Row: TReportRow;
  MeasureCnt: Integer;
begin
  SetLength(Rows, 0);
  AllBausteine := FCatalog.LoadBausteine(stITGrundschutz, ACatalogVersion);
  BausteinById := TDictionary<Integer, TBaustein>.Create;
  try
    for Baustein in AllBausteine do
      BausteinById.Add(Baustein.Id, Baustein);

    TargetObjects := FTarget.LoadTargetObjects(AProjectId);
    for TargetObject in TargetObjects do
    begin
      if (ATargetObjectId <> 0) and (TargetObject.Id <> ATargetObjectId) then
        Continue;

      ApplicabilityMap := FTarget.LoadApplicabilityMap(AProjectId, TargetObject.Id);
      try
        if ApplicabilityMap.Count = 0 then
          Continue;

        MeasureCounts := FMeasure.MeasureCounts(AProjectId, TargetObject.Id);
        try
          for Pair in ApplicabilityMap do
          begin
            if (Pair.Value <> apRequired) and (Pair.Value <> apPossible) then
              Continue;
            if not BausteinById.ContainsKey(Pair.Key) then
              Continue;

            Requirements := FCatalog.LoadRequirements(Pair.Key);
            for Requirement in Requirements do
            begin
              if Requirement.Withdrawn then
                Continue;
              if not RequirementLevelApplies(Requirement.Level, TargetObject.ProtectionNeed) then
                Continue;

              FillChar(Row, SizeOf(Row), 0);
              Row.TargetObjectId := TargetObject.Id;
              Row.TargetObjectName := TargetObject.Name;
              Row.BausteinExternalId := Requirement.BausteinExternalId;
              Row.BausteinTitle := BausteinById[Pair.Key].Title;
              Row.RequirementExternalId := Requirement.ExternalId;
              Row.RequirementTitle := Requirement.Title;
              Row.Level := RequirementLevelToString(Requirement.Level);
              Row.Applicability := Pair.Value;

              Assessment := FProject.LoadAssessment(AProjectId, TargetObject.Id, Requirement.Id);
              Row.Status := Assessment.Status;
              Row.Responsible := Assessment.Responsible;
              Row.DueDate := Assessment.DueDate;
              if MeasureCounts.TryGetValue(Requirement.Id, MeasureCnt) then
                Row.MeasureCount := MeasureCnt;
              Row.Overdue := IsValidDate(Assessment.DueDate) and
                (Assessment.DueDate < Date) and
                (Assessment.Status <> asFulfilled) and
                (Assessment.Status <> asNotApplicable);

              SetLength(Rows, Length(Rows) + 1);
              Rows[High(Rows)] := Row;
            end;
          end;
        finally
          MeasureCounts.Free;
        end;
      finally
        ApplicabilityMap.Free;
      end;
    end;
  finally
    BausteinById.Free;
  end;
  SortRows(Rows);
  Result := Rows;
end;

function TReportService.Summarize(const ARows: TArray<TReportRow>): TReportSummary;
var
  Row: TReportRow;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.TotalRequirements := Length(ARows);
  for Row in ARows do
  begin
    case Row.Status of
      asOpen: Inc(Result.OpenCount);
      asPartial: Inc(Result.PartialCount);
      asFulfilled: Inc(Result.FulfilledCount);
      asNotApplicable: Inc(Result.NotApplicableCount);
    end;
    if Row.Overdue then
      Inc(Result.OverdueCount);
    Inc(Result.MeasureCount, Row.MeasureCount);
  end;
end;

function TReportService.SummarizeByTargetObject(const ARows: TArray<TReportRow>): TDictionary<Integer, TReportSummary>;
var
  Grouped: TDictionary<Integer, TList<TReportRow>>;
  Row: TReportRow;
  List: TList<TReportRow>;
  Pair: TPair<Integer, TList<TReportRow>>;
  RowArray: TArray<TReportRow>;
begin
  Result := TDictionary<Integer, TReportSummary>.Create;
  Grouped := TDictionary<Integer, TList<TReportRow>>.Create;
  try
    for Row in ARows do
    begin
      if not Grouped.TryGetValue(Row.TargetObjectId, List) then
      begin
        List := TList<TReportRow>.Create;
        Grouped.Add(Row.TargetObjectId, List);
      end;
      List.Add(Row);
    end;
    for Pair in Grouped do
    begin
      RowArray := Pair.Value.ToArray;
      Result.Add(Pair.Key, Summarize(RowArray));
    end;
  finally
    for Pair in Grouped do
      Pair.Value.Free;
    Grouped.Free;
  end;
end;

function TReportService.SummarizeByTargetObjectForProject(AProjectId: Integer;
  const ACatalogVersion: string): TDictionary<Integer, TReportSummary>;
begin
  Result := SummarizeByTargetObject(BuildSollIstReport(AProjectId, 0, ACatalogVersion));
end;

class function TReportService.ProgressPercent(const ASummary: TReportSummary): Integer;
begin
  Result := ReportProgressPercent(ASummary);
end;

class function TReportService.FormatSummaryText(const ASummary: TReportSummary): string;
var
  Details: TArray<string>;
  DetailCount: Integer;

  procedure AddDetail(const AText: string);
  begin
    SetLength(Details, DetailCount + 1);
    Details[DetailCount] := AText;
    Inc(DetailCount);
  end;

begin
  if ASummary.TotalRequirements = 0 then
    Exit('Keine anwendbaren Anforderungen');

  Result := Format('%d%% abgeschlossen (%d/%d Anforderungen)',
    [ProgressPercent(ASummary),
     ASummary.FulfilledCount + ASummary.NotApplicableCount,
     ASummary.TotalRequirements]);

  DetailCount := 0;
  if ASummary.OpenCount > 0 then
    AddDetail(Format('%d offen', [ASummary.OpenCount]));
  if ASummary.PartialCount > 0 then
    AddDetail(Format('%d teilweise', [ASummary.PartialCount]));
  if ASummary.OverdueCount > 0 then
    AddDetail(Format('%d überfällig', [ASummary.OverdueCount]));
  if ASummary.MeasureCount > 0 then
    AddDetail(Format('%d Maßnahmen', [ASummary.MeasureCount]));

  if DetailCount > 0 then
    Result := Result + ' — ' + string.Join(', ', Details);
end;

class function TReportService.FormatTreeProgressSuffix(const ASummary: TReportSummary): string;
begin
  Result := '';
  if ASummary.TotalRequirements = 0 then
    Exit;
  Result := Format(' · %d%%', [ProgressPercent(ASummary)]);
  if ASummary.OverdueCount > 0 then
    Result := Result + Format(', %d überfällig', [ASummary.OverdueCount]);
end;

end.
