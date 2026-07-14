unit IsmsDomain;

interface

uses
  System.SysUtils, System.Generics.Collections, System.DateUtils;

type
  TStandardType = (stITGrundschutz, stISO27001);
  TAssessmentStatus = (asOpen, asPartial, asFulfilled, asNotApplicable);
  TApplicabilityStatus = (apUndefined, apRequired, apPossible, apNotApplicable);
  TProtectionNeed = (pnBasisOnly, pnNormal, pnElevated);
  TTargetObjectType = (totScope, totProcess, totApplication, totITSystem, totNetwork, totInfrastructure);
  TRequirementLevel = (rlUnknown, rlBasis, rlStandard, rlErhoeht);
  TMeasureStatus = (msOpen, msInProgress, msDone);

  TProject = record
    Id: Integer;
    Name: string;
    Description: string;
    CatalogVersion: string;
    Role: string;
    CreatedAt: TDateTime;
    UpdatedAt: TDateTime;
  end;

  TTargetObject = record
    Id: Integer;
    ProjectId: Integer;
    ParentId: Integer;
    ObjType: TTargetObjectType;
    ProtectionNeed: TProtectionNeed;
    Name: string;
    Description: string;
  end;

  TBaustein = record
    Id: Integer;
    Standard: TStandardType;
    ExternalId: string;
    Title: string;
    GroupName: string;
    CatalogVersion: string;
  end;

  TRequirement = record
    Id: Integer;
    BausteinDbId: Integer;
    Standard: TStandardType;
    ExternalId: string;
    BausteinExternalId: string;
    Title: string;
    Text: string;
    Level: TRequirementLevel;
    ResponsibleRole: string;
    Withdrawn: Boolean;
  end;

  TRequirementAssessment = record
    Id: Integer;
    ProjectId: Integer;
    TargetObjectId: Integer;
    RequirementDbId: Integer;
    Status: TAssessmentStatus;
    Note: string;
    Responsible: string;
    DueDate: TDateTime;
    MeasureCount: Integer;
    Version: Integer;
  end;

  TMeasure = record
    Id: Integer;
    ProjectId: Integer;
    TargetObjectId: Integer;
    RequirementDbId: Integer;
    Title: string;
    Description: string;
    Responsible: string;
    DueDate: TDateTime;
    Status: TMeasureStatus;
    Version: Integer;
  end;

  TBausteinApplicability = record
    ProjectId: Integer;
    TargetObjectId: Integer;
    BausteinDbId: Integer;
    Status: TApplicabilityStatus;
  end;

  TGrundschutzImportResult = record
    CatalogVersion: string;
    Bausteine: TArray<TBaustein>;
    Requirements: TArray<TRequirement>;
    ErrorMessage: string;
    Success: Boolean;
  end;

  TReportRow = record
    TargetObjectId: Integer;
    TargetObjectName: string;
    BausteinExternalId: string;
    BausteinTitle: string;
    RequirementExternalId: string;
    RequirementTitle: string;
    Level: string;
    Applicability: TApplicabilityStatus;
    Status: TAssessmentStatus;
    Responsible: string;
    DueDate: TDateTime;
    MeasureCount: Integer;
    Overdue: Boolean;
  end;

  TReportSummary = record
    TotalRequirements: Integer;
    OpenCount: Integer;
    PartialCount: Integer;
    FulfilledCount: Integer;
    NotApplicableCount: Integer;
    OverdueCount: Integer;
    MeasureCount: Integer;
  end;

  TBausteinRecommendationTier = (brtCore, brtSupplementary);

  TBausteinRecommendation = record
    BausteinDbId: Integer;
    ExternalId: string;
    Title: string;
    GroupName: string;
    Tier: TBausteinRecommendationTier;
    SuggestedStatus: TApplicabilityStatus;
    Reason: string;
  end;

  TBausteinRecommendationSelection = record
    BausteinDbId: Integer;
    Status: TApplicabilityStatus;
  end;

  TSessionSelection = record
    TargetObjectId: Integer;
    BausteinId: Integer;
    RequirementId: Integer;
  end;

  TServerUser = record
    Id: Integer;
    Email: string;
    DisplayName: string;
    IsAdmin: Boolean;
  end;

  TProjectMember = record
    UserId: Integer;
    Email: string;
    DisplayName: string;
    Role: string;
  end;

function StandardTypeToString(AValue: TStandardType): string;
function StandardTypeFromString(const AValue: string): TStandardType;
function AssessmentStatusToString(AValue: TAssessmentStatus): string;
function AssessmentStatusFromString(const AValue: string): TAssessmentStatus;
function ApplicabilityStatusToString(AValue: TApplicabilityStatus): string;
function ApplicabilityStatusFromString(const AValue: string): TApplicabilityStatus;
function ProtectionNeedToString(AValue: TProtectionNeed): string;
function ProtectionNeedFromString(const AValue: string): TProtectionNeed;
function TargetObjectTypeToString(AValue: TTargetObjectType): string;
function TargetObjectTypeFromString(const AValue: string): TTargetObjectType;
function RequirementLevelToString(AValue: TRequirementLevel): string;
function RequirementLevelFromString(const AValue: string): TRequirementLevel;
function RequirementLevelFromSectionTitle(const ATitle: string): TRequirementLevel;
function RequirementLevelFromMarker(AChar: Char): TRequirementLevel;
function MeasureStatusToString(AValue: TMeasureStatus): string;
function MeasureStatusFromString(const AValue: string): TMeasureStatus;
function RequirementLevelApplies(ALevel: TRequirementLevel; ANeed: TProtectionNeed): Boolean;
function DateToIso(const ADate: TDateTime): string;
function IsoToDate(const AValue: string): TDateTime;
function DateTimeToIso(const AValue: TDateTime): string;
function IsoToDateTime(const AValue: string): TDateTime;
function IsValidDate(const ADate: TDateTime): Boolean;
function ReportProgressPercent(const ASummary: TReportSummary): Integer;
function BausteinRecommendationTierToString(AValue: TBausteinRecommendationTier): string;

function ProjectMemberRoleLabel(const ARole: string): string;
function ProjectMemberRoleOptions: TArray<string>;

implementation

function StandardTypeToString(AValue: TStandardType): string;
begin
  case AValue of
    stITGrundschutz: Result := 'IT-Grundschutz';
    stISO27001: Result := 'ISO 27001';
  else
    Result := 'Unbekannt';
  end;
end;

function StandardTypeFromString(const AValue: string): TStandardType;
begin
  if (AValue = 'ISO 27001') or (AValue = 'ISO27001') then
    Exit(stISO27001);
  Result := stITGrundschutz;
end;

function AssessmentStatusToString(AValue: TAssessmentStatus): string;
begin
  case AValue of
    asOpen: Result := 'Offen';
    asPartial: Result := 'Teilweise';
    asFulfilled: Result := 'Erfüllt';
    asNotApplicable: Result := 'Entfällt';
  else
    Result := 'Offen';
  end;
end;

function AssessmentStatusFromString(const AValue: string): TAssessmentStatus;
var
  Normalized: string;
begin
  Normalized := Trim(AValue);
  if Normalized = 'Teilweise' then Exit(asPartial);
  if Normalized = 'Erfüllt' then Exit(asFulfilled);
  if Normalized = 'Entfällt' then Exit(asNotApplicable);
  Result := asOpen;
end;

function ApplicabilityStatusToString(AValue: TApplicabilityStatus): string;
begin
  case AValue of
    apUndefined: Result := 'Undefiniert';
    apRequired: Result := 'Benötigt';
    apPossible: Result := 'Möglicherweise';
    apNotApplicable: Result := 'Nicht relevant';
  else
    Result := 'Undefiniert';
  end;
end;

function ApplicabilityStatusFromString(const AValue: string): TApplicabilityStatus;
var
  Normalized, Lower: string;
begin
  Normalized := Trim(AValue);
  if SameText(Normalized, 'Benötigt') or SameText(Normalized, 'Benoetigt') then
    Exit(apRequired);
  if SameText(Normalized, 'Möglicherweise') or SameText(Normalized, 'Moeglicherweise') then
    Exit(apPossible);
  if SameText(Normalized, 'Nicht relevant') then
    Exit(apNotApplicable);
  Lower := LowerCase(Normalized);
  if (Pos('ben', Lower) > 0) and (Pos('tigt', Lower) > 0) then
    Exit(apRequired);
  if (Pos('mog', Lower) > 0) or (Pos('mög', Lower) > 0) then
    if Pos('lich', Lower) > 0 then
      Exit(apPossible);
  Result := apUndefined;
end;

function ProtectionNeedToString(AValue: TProtectionNeed): string;
begin
  case AValue of
    pnBasisOnly: Result := 'Basis-Anforderungen';
    pnNormal: Result := 'Normal (Basis + Standard)';
    pnElevated: Result := 'Erhöht (Basis + Standard + Erhöht)';
  else
    Result := 'Normal (Basis + Standard)';
  end;
end;

function ProtectionNeedFromString(const AValue: string): TProtectionNeed;
var
  Normalized: string;
begin
  Normalized := Trim(AValue);
  if Normalized = 'Basis-Anforderungen' then Exit(pnBasisOnly);
  if Normalized.StartsWith('Erhöht') then Exit(pnElevated);
  Result := pnNormal;
end;

function TargetObjectTypeToString(AValue: TTargetObjectType): string;
begin
  case AValue of
    totScope: Result := 'Informationsverbund';
    totProcess: Result := 'Geschäftsprozess';
    totApplication: Result := 'Anwendung';
    totITSystem: Result := 'IT-System';
    totNetwork: Result := 'Kommunikationsverbindung';
    totInfrastructure: Result := 'Infrastruktur';
  else
    Result := 'Unbekannt';
  end;
end;

function TargetObjectTypeFromString(const AValue: string): TTargetObjectType;
var
  Normalized: string;
begin
  Normalized := Trim(AValue);
  if SameText(Normalized, 'Informationsverbund') then Exit(totScope);
  if SameText(Normalized, 'Geschäftsprozess') then Exit(totProcess);
  if SameText(Normalized, 'Anwendung') then Exit(totApplication);
  if SameText(Normalized, 'IT-System') then Exit(totITSystem);
  if SameText(Normalized, 'Kommunikationsverbindung') then Exit(totNetwork);
  if SameText(Normalized, 'Infrastruktur') then Exit(totInfrastructure);
  Result := totScope;
end;

function RequirementLevelToString(AValue: TRequirementLevel): string;
begin
  case AValue of
    rlBasis: Result := 'Basis';
    rlStandard: Result := 'Standard';
    rlErhoeht: Result := 'Erhöht';
  else
    Result := 'Unbekannt';
  end;
end;

function RequirementLevelFromString(const AValue: string): TRequirementLevel;
var
  Normalized: string;
begin
  Normalized := Trim(AValue);
  if Normalized = 'Basis' then Exit(rlBasis);
  if Normalized = 'Standard' then Exit(rlStandard);
  if Normalized = 'Erhöht' then Exit(rlErhoeht);
  Result := rlUnknown;
end;

function RequirementLevelFromSectionTitle(const ATitle: string): TRequirementLevel;
begin
  if ATitle = 'Basis-Anforderungen' then Exit(rlBasis);
  if ATitle = 'Standard-Anforderungen' then Exit(rlStandard);
  if ATitle = 'Anforderungen bei erhöhtem Schutzbedarf' then Exit(rlErhoeht);
  Result := rlUnknown;
end;

function RequirementLevelFromMarker(AChar: Char): TRequirementLevel;
begin
  case UpCase(AChar) of
    'B': Exit(rlBasis);
    'S': Exit(rlStandard);
    'H': Exit(rlErhoeht);
  end;
  Result := rlUnknown;
end;

function MeasureStatusToString(AValue: TMeasureStatus): string;
begin
  case AValue of
    msOpen: Result := 'Offen';
    msInProgress: Result := 'In Bearbeitung';
    msDone: Result := 'Erledigt';
  else
    Result := 'Offen';
  end;
end;

function MeasureStatusFromString(const AValue: string): TMeasureStatus;
var
  Normalized: string;
begin
  Normalized := Trim(AValue);
  if Normalized = 'In Bearbeitung' then Exit(msInProgress);
  if Normalized = 'Erledigt' then Exit(msDone);
  Result := msOpen;
end;

function RequirementLevelApplies(ALevel: TRequirementLevel; ANeed: TProtectionNeed): Boolean;
begin
  if ALevel = rlUnknown then
    Exit(True);
  case ANeed of
    pnBasisOnly:
      Result := ALevel = rlBasis;
    pnNormal:
      Result := (ALevel = rlBasis) or (ALevel = rlStandard);
    pnElevated:
      Result := (ALevel = rlBasis) or (ALevel = rlStandard) or (ALevel = rlErhoeht);
  else
    Result := True;
  end;
end;

function DateToIso(const ADate: TDateTime): string;
begin
  if not IsValidDate(ADate) then
    Exit('');
  Result := FormatDateTime('yyyy-mm-dd', ADate);
end;

function IsoToDate(const AValue: string): TDateTime;
begin
  if Trim(AValue) = '' then
    Exit(0);
  Result := ISO8601ToDate(AValue, False);
end;

function DateTimeToIso(const AValue: TDateTime): string;
begin
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', TTimeZone.Local.ToUniversalTime(AValue));
end;

function IsoToDateTime(const AValue: string): TDateTime;
var
  S: string;
  DotPos, ZonePos: Integer;
begin
  S := Trim(AValue);
  if S = '' then
    Exit(0);
  DotPos := Pos('.', S);
  if DotPos > 0 then
  begin
    ZonePos := Pos('Z', S);
    if ZonePos = 0 then
      ZonePos := Pos('+', S);
    if ZonePos = 0 then
      ZonePos := Length(S) + 1;
    if ZonePos > DotPos then
      Delete(S, DotPos, ZonePos - DotPos);
  end;
  Result := ISO8601ToDate(S, False);
end;

function IsValidDate(const ADate: TDateTime): Boolean;
begin
  Result := (ADate > 0) and (ADate < EncodeDate(9999, 12, 31));
end;

function ReportProgressPercent(const ASummary: TReportSummary): Integer;
var
  Completed: Integer;
begin
  if ASummary.TotalRequirements <= 0 then
    Exit(0);
  Completed := ASummary.FulfilledCount + ASummary.NotApplicableCount;
  Result := Round(Completed * 100.0 / ASummary.TotalRequirements);
end;

function BausteinRecommendationTierToString(AValue: TBausteinRecommendationTier): string;
begin
  case AValue of
    brtCore: Result := 'Kern';
    brtSupplementary: Result := 'Ergänzend';
  else
    Result := 'Kern';
  end;
end;

function ProjectMemberRoleLabel(const ARole: string): string;
begin
  if ARole = 'owner' then
    Exit('Besitzer');
  if ARole = 'editor' then
    Exit('Bearbeiter');
  if ARole = 'viewer' then
    Exit('Leser');
  Result := ARole;
end;

function ProjectMemberRoleOptions: TArray<string>;
begin
  Result := TArray<string>.Create('owner', 'editor', 'viewer');
end;

end.
