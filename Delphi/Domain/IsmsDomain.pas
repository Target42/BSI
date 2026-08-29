unit IsmsDomain;

interface

uses
  System.SysUtils, System.Generics.Collections, System.DateUtils;

type
  TStandardType = (stITGrundschutz, stISO27001);
  TAssessmentStatus = (asOpen, asPartial, asFulfilled, asNotApplicable);
  TApplicabilityStatus = (apUndefined, apRequired, apPossible, apNotApplicable);
  TProtectionNeed = (pnBasisOnly, pnNormal, pnElevated);
  TCiaLevel = (clNormal, clHigh, clVeryHigh);
  TTargetObjectType = (totScope, totProcess, totApplication, totITSystem, totNetwork, totInfrastructure);
  TRequirementLevel = (rlUnknown, rlBasis, rlStandard, rlErhoeht);
  TMeasureStatus = (msOpen, msInProgress, msDone);

  TProject = record
    Id: Integer;
    Name: string;
    Description: string;
    CatalogVersion: string;
    Visibility: string;
    Role: string;
    IsMember: Boolean;
    CreatedAt: TDateTime;
    UpdatedAt: TDateTime;
  end;

  TTargetObject = record
    Id: Integer;
    ProjectId: Integer;
    ParentId: Integer;
    ObjType: TTargetObjectType;
    ProtectionNeed: TProtectionNeed;
    Confidentiality: TCiaLevel;
    Integrity: TCiaLevel;
    Availability: TCiaLevel;
    InheritProtectionNeed: Boolean;
    ProtectionNeedNote: string;
    Name: string;
    Description: string;
  end;

  TTargetMoveDestination = record
    ParentId: Integer;
    Caption: string;
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

  TInheritedBaustein = record
    BausteinDbId: Integer;
    Status: TApplicabilityStatus;
    SourceTargetId: Integer;
    SourceCaption: string;
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
    BausteinDbId: Integer;
    BausteinExternalId: string;
    BausteinTitle: string;
    RequirementDbId: Integer;
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

  TCockpitKind = (ckAssessment, ckMeasure);
  TCockpitKindFilter = (ckfAll, ckfAssessments, ckfMeasures);
  TCockpitDueFilter = (cdfAll, cdfOverdue, cdfThisWeek, cdfHasDate, cdfNoDate);

  TCockpitItem = record
    Kind: TCockpitKind;
    TargetObjectId: Integer;
    TargetObjectName: string;
    BausteinDbId: Integer;
    BausteinExternalId: string;
    RequirementDbId: Integer;
    RequirementExternalId: string;
    Title: string;
    StatusText: string;
    Responsible: string;
    DueDate: TDateTime;
    Overdue: Boolean;
    MeasureId: Integer;
    AssessmentStatus: TAssessmentStatus;
    MeasureStatus: TMeasureStatus;
  end;

  TCockpitFilter = record
    Kind: TCockpitKindFilter;
    Due: TCockpitDueFilter;
    HideDone: Boolean;
    MineOnly: Boolean;
    CurrentUserName: string;
    CurrentUserEmail: string;
    ResponsibleNeedle: string;
  end;

  TCockpitSummary = record
    TotalCount: Integer;
    AssessmentCount: Integer;
    MeasureCount: Integer;
    OverdueCount: Integer;
    DueThisWeekCount: Integer;
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

  TAssessmentSaveStatus = (assOk, assVersionConflict, assForbidden, assFailed);
  TAssessmentSaveResult = record
    Status: TAssessmentSaveStatus;
    Assessment: TRequirementAssessment;
  end;

  TMeasureSaveStatus = (mssOk, mssVersionConflict, mssForbidden, mssFailed);
  TMeasureSaveResult = record
    Status: TMeasureSaveStatus;
    Measure: TMeasure;
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
function CiaLevelToString(AValue: TCiaLevel): string;
function CiaLevelFromString(const AValue: string): TCiaLevel;
function MaxCiaLevel(ALeft, ARight: TCiaLevel): TCiaLevel;
function ProtectionNeedFromCiaLevels(AConfidentiality, AIntegrity, AAvailability: TCiaLevel): TProtectionNeed;
function ProtectionNeedSummary(const ATarget: TTargetObject): string;
procedure ApplyCiaToProtectionNeed(var ATarget: TTargetObject);
procedure CopyProtectionNeedFromParent(var AChild: TTargetObject; const AParent: TTargetObject);
procedure FinalizeTargetObjectProtectionNeed(var ATarget: TTargetObject; const AParent: TTargetObject);
procedure ResolveInheritedProtectionNeeds(var AObjects: TArray<TTargetObject>);
function TargetObjectTypeToString(AValue: TTargetObjectType): string;
function TargetObjectTypeFromString(const AValue: string): TTargetObjectType;
function TargetObjectCaption(const ATarget: TTargetObject): string;
function AllowedChildTargetTypes(AParentType: TTargetObjectType): TArray<TTargetObjectType>;
function DefaultChildTargetType(AParentType: TTargetObjectType): TTargetObjectType;
function CanHaveChildTargetObjects(AParentType: TTargetObjectType): Boolean;
function IsAllowedChildTargetType(AParentType, AChildType: TTargetObjectType): Boolean;
function IsRootScopeTarget(const ATarget: TTargetObject): Boolean;
function FindTargetObjectById(const AObjects: TArray<TTargetObject>; AId: Integer): TTargetObject;
function FindRootScopeTarget(const AObjects: TArray<TTargetObject>): TTargetObject;
function WouldCreateTargetParentCycle(const AObjects: TArray<TTargetObject>;
  AObjectId, ANewParentId: Integer): Boolean;
function TargetMoveRejectedReason(const AObjects: TArray<TTargetObject>;
  const AMoving: TTargetObject; ANewParentId: Integer): string;
function CanMoveTargetObject(const AObjects: TArray<TTargetObject>;
  const AMoving: TTargetObject; ANewParentId: Integer): Boolean;
function PossibleTargetMoveDestinations(const AObjects: TArray<TTargetObject>;
  const AMoving: TTargetObject): TArray<TTargetMoveDestination>;
function ScopeLayerTypes: TArray<TTargetObjectType>;
function TargetObjectLayerGroupTitle(AType: TTargetObjectType): string;
function CanInheritAssessments(AParentType, AChildType: TTargetObjectType): Boolean;
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
function CockpitKindToString(AKind: TCockpitKind): string;
function CockpitItemIsDone(const AItem: TCockpitItem): Boolean;
function IsDueThisWeek(const ADate: TDateTime): Boolean;
function DefaultCockpitFilter: TCockpitFilter;

function ProjectMemberRoleLabel(const ARole: string): string;
function ProjectMemberRoleOptions: TArray<string>;
function NormalizeProjectVisibility(const AValue: string): string;
function ProjectIsPublic(const AProject: TProject): Boolean;
function ProjectVisibilityLabel(const AValue: string): string;

function AssessmentSaveOk(const AAssessment: TRequirementAssessment): TAssessmentSaveResult;
function AssessmentSaveConflict(const AAssessment: TRequirementAssessment): TAssessmentSaveResult;
function AssessmentSaveForbidden: TAssessmentSaveResult;
function AssessmentSaveFailed: TAssessmentSaveResult;
function MeasureSaveOk(const AMeasure: TMeasure): TMeasureSaveResult;
function MeasureSaveConflict(const AMeasure: TMeasure): TMeasureSaveResult;
function MeasureSaveForbidden: TMeasureSaveResult;
function MeasureSaveFailed: TMeasureSaveResult;

implementation

const
  S_Erfuellt = 'Erf'#$00FC'llt';
  S_Entfaellt = 'Entf'#$00E4'llt';
  S_Benoetigt = 'Ben'#$00F6'tigt';
  S_Moeglicherweise = 'M'#$00F6'glicherweise';
  S_Erhoeht = 'Erh'#$00F6'ht';
  S_ErhoehtFull = 'Erh'#$00F6'ht (Basis + Standard + Erh'#$00F6'ht)';
  S_Geschaefstsprozess = 'Gesch'#$00E4'ftsprozess';
  S_Geltungsbereich = 'Geltungsbereich';
  EnDash = #$2013;
  S_Ergaenzend = 'Erg'#$00E4'nzend';
  S_ErhoehtemSchutzbedarf = 'Anforderungen bei erh'#$00F6'htem Schutzbedarf';

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
    asFulfilled: Result := S_Erfuellt;
    asNotApplicable: Result := S_Entfaellt;
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
  if SameText(Normalized, S_Erfuellt) then Exit(asFulfilled);
  if SameText(Normalized, S_Entfaellt) then Exit(asNotApplicable);
  Result := asOpen;
end;

function ApplicabilityStatusToString(AValue: TApplicabilityStatus): string;
begin
  case AValue of
    apUndefined: Result := 'Undefiniert';
    apRequired: Result := S_Benoetigt;
    apPossible: Result := S_Moeglicherweise;
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
  if SameText(Normalized, S_Benoetigt) or SameText(Normalized, 'Benoetigt') then
    Exit(apRequired);
  if SameText(Normalized, S_Moeglicherweise) or SameText(Normalized, 'Moeglicherweise') then
    Exit(apPossible);
  if SameText(Normalized, 'Nicht relevant') then
    Exit(apNotApplicable);
  Lower := LowerCase(Normalized);
  if (Pos('ben', Lower) > 0) and (Pos('tigt', Lower) > 0) then
    Exit(apRequired);
  if (Pos('mog', Lower) > 0) or (Pos('m'#$00F6'g', Lower) > 0) then
    if Pos('lich', Lower) > 0 then
      Exit(apPossible);
  Result := apUndefined;
end;

function ProtectionNeedToString(AValue: TProtectionNeed): string;
begin
  case AValue of
    pnBasisOnly: Result := 'Basis-Anforderungen';
    pnNormal: Result := 'Normal (Basis + Standard)';
    pnElevated: Result := S_ErhoehtFull;
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
  if Normalized.StartsWith(S_Erhoeht) then Exit(pnElevated);
  Result := pnNormal;
end;

function CiaLevelToString(AValue: TCiaLevel): string;
begin
  case AValue of
    clHigh: Result := 'hoch';
    clVeryHigh: Result := 'sehr hoch';
  else
    Result := 'normal';
  end;
end;

function CiaLevelFromString(const AValue: string): TCiaLevel;
var
  Normalized: string;
begin
  Normalized := LowerCase(Trim(AValue));
  if (Normalized = 'hoch') or (Normalized = 'high') then
    Exit(clHigh);
  if (Normalized = 'sehr hoch') or (Normalized = 'sehrhoch') or
     (Normalized = 'very high') then
    Exit(clVeryHigh);
  Result := clNormal;
end;

function MaxCiaLevel(ALeft, ARight: TCiaLevel): TCiaLevel;
begin
  if ALeft >= ARight then
    Result := ALeft
  else
    Result := ARight;
end;

function ProtectionNeedFromCiaLevels(AConfidentiality, AIntegrity,
  AAvailability: TCiaLevel): TProtectionNeed;
begin
  if MaxCiaLevel(MaxCiaLevel(AConfidentiality, AIntegrity), AAvailability) > clNormal then
    Result := pnElevated
  else
    Result := pnNormal;
end;

procedure ApplyCiaToProtectionNeed(var ATarget: TTargetObject);
var
  Derived: TProtectionNeed;
  KeepBasis: Boolean;
begin
  KeepBasis := (ATarget.ProtectionNeed = pnBasisOnly) and not ATarget.InheritProtectionNeed;
  Derived := ProtectionNeedFromCiaLevels(
    ATarget.Confidentiality, ATarget.Integrity, ATarget.Availability);
  if KeepBasis and (Derived = pnNormal) then
    ATarget.ProtectionNeed := pnBasisOnly
  else
    ATarget.ProtectionNeed := Derived;
end;

procedure CopyProtectionNeedFromParent(var AChild: TTargetObject; const AParent: TTargetObject);
begin
  AChild.Confidentiality := AParent.Confidentiality;
  AChild.Integrity := AParent.Integrity;
  AChild.Availability := AParent.Availability;
  ApplyCiaToProtectionNeed(AChild);
end;

procedure FinalizeTargetObjectProtectionNeed(var ATarget: TTargetObject;
  const AParent: TTargetObject);
begin
  if ATarget.ParentId <= 0 then
    ATarget.InheritProtectionNeed := False
  else if ATarget.InheritProtectionNeed and (AParent.Id > 0) then
    CopyProtectionNeedFromParent(ATarget, AParent);
  ApplyCiaToProtectionNeed(ATarget);
end;

function ProtectionNeedSummary(const ATarget: TTargetObject): string;
begin
  Result := Format('V %s, I %s, A %s',
    [CiaLevelToString(ATarget.Confidentiality),
     CiaLevelToString(ATarget.Integrity),
     CiaLevelToString(ATarget.Availability)]);
  if ATarget.InheritProtectionNeed then
    Result := Result + ' ' + EnDash + ' geerbt';
end;

procedure ResolveInheritedProtectionNeeds(var AObjects: TArray<TTargetObject>);
var
  ById: TDictionary<Integer, Integer>;
  I, Guard, ParentIndex: Integer;
  Parent: TTargetObject;
begin
  ById := TDictionary<Integer, Integer>.Create;
  try
    for I := 0 to High(AObjects) do
      if AObjects[I].Id > 0 then
        ById.AddOrSetValue(AObjects[I].Id, I);
    for I := 0 to High(AObjects) do
    begin
      if not AObjects[I].InheritProtectionNeed or (AObjects[I].ParentId <= 0) then
      begin
        ApplyCiaToProtectionNeed(AObjects[I]);
        Continue;
      end;
      Parent := AObjects[I];
      Guard := 0;
      while Parent.InheritProtectionNeed and (Parent.ParentId > 0) and (Guard < 64) do
      begin
        Inc(Guard);
        if not ById.TryGetValue(Parent.ParentId, ParentIndex) then
          Break;
        Parent := AObjects[ParentIndex];
      end;
      CopyProtectionNeedFromParent(AObjects[I], Parent);
    end;
  finally
    ById.Free;
  end;
end;

function TargetObjectTypeToString(AValue: TTargetObjectType): string;
begin
  case AValue of
    totScope: Result := 'Informationsverbund';
    totProcess: Result := S_Geschaefstsprozess;
    totApplication: Result := 'Anwendung';
    totITSystem: Result := 'IT-System';
    totNetwork: Result := 'Netz';
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
  if SameText(Normalized, 'Informationsverbund') or SameText(Normalized, S_Geltungsbereich) then
    Exit(totScope);
  if SameText(Normalized, S_Geschaefstsprozess) then Exit(totProcess);
  if SameText(Normalized, 'Anwendung') then Exit(totApplication);
  if SameText(Normalized, 'IT-System') then Exit(totITSystem);
  if SameText(Normalized, 'Kommunikationsverbindung') or SameText(Normalized, 'Netz')
    or SameText(Normalized, 'Netze') then
    Exit(totNetwork);
  if SameText(Normalized, 'Infrastruktur') then Exit(totInfrastructure);
  Result := totScope;
end;

function TargetObjectCaption(const ATarget: TTargetObject): string;
begin
  Result := Format('%s ' + EnDash + ' %s [%s]',
    [TargetObjectTypeToString(ATarget.ObjType), ATarget.Name,
     ProtectionNeedSummary(ATarget)]);
end;

function AllowedChildTargetTypes(AParentType: TTargetObjectType): TArray<TTargetObjectType>;
begin
  case AParentType of
    totScope:
      Result := TArray<TTargetObjectType>.Create(
        totProcess, totApplication, totITSystem, totNetwork, totInfrastructure);
    totProcess:
      Result := TArray<TTargetObjectType>.Create(totProcess, totApplication);
    totITSystem:
      Result := TArray<TTargetObjectType>.Create(totApplication, totITSystem, totNetwork);
    totInfrastructure:
      Result := TArray<TTargetObjectType>.Create(totITSystem, totInfrastructure, totNetwork);
  else
    SetLength(Result, 0);
  end;
end;

function DefaultChildTargetType(AParentType: TTargetObjectType): TTargetObjectType;
begin
  case AParentType of
    totScope: Result := totProcess;
    totProcess: Result := totApplication;
    totITSystem: Result := totApplication;
    totInfrastructure: Result := totITSystem;
  else
    Result := totProcess;
  end;
end;

function CanHaveChildTargetObjects(AParentType: TTargetObjectType): Boolean;
begin
  Result := Length(AllowedChildTargetTypes(AParentType)) > 0;
end;

function IsAllowedChildTargetType(AParentType, AChildType: TTargetObjectType): Boolean;
var
  Allowed: TArray<TTargetObjectType>;
  T: TTargetObjectType;
begin
  Allowed := AllowedChildTargetTypes(AParentType);
  for T in Allowed do
    if T = AChildType then
      Exit(True);
  Result := False;
end;

function IsRootScopeTarget(const ATarget: TTargetObject): Boolean;
begin
  Result := (ATarget.ParentId = 0) and (ATarget.ObjType = totScope);
end;

function FindTargetObjectById(const AObjects: TArray<TTargetObject>; AId: Integer): TTargetObject;
var
  O: TTargetObject;
begin
  FillChar(Result, SizeOf(Result), 0);
  if AId <= 0 then
    Exit;
  for O in AObjects do
    if O.Id = AId then
      Exit(O);
end;

function FindRootScopeTarget(const AObjects: TArray<TTargetObject>): TTargetObject;
var
  O: TTargetObject;
begin
  FillChar(Result, SizeOf(Result), 0);
  for O in AObjects do
    if IsRootScopeTarget(O) then
      Exit(O);
  for O in AObjects do
    if O.ParentId = 0 then
      Exit(O);
end;

function WouldCreateTargetParentCycle(const AObjects: TArray<TTargetObject>;
  AObjectId, ANewParentId: Integer): Boolean;
var
  CurrentId: Integer;
  Current: TTargetObject;
  Guard: Integer;
begin
  Result := False;
  if (AObjectId <= 0) or (ANewParentId <= 0) then
    Exit;
  CurrentId := ANewParentId;
  Guard := 0;
  while (CurrentId > 0) and (Guard < 64) do
  begin
    if CurrentId = AObjectId then
      Exit(True);
    Current := FindTargetObjectById(AObjects, CurrentId);
    if Current.Id = 0 then
      Exit(False);
    CurrentId := Current.ParentId;
    Inc(Guard);
  end;
end;

function TargetMoveRejectedReason(const AObjects: TArray<TTargetObject>;
  const AMoving: TTargetObject; ANewParentId: Integer): string;
var
  Parent: TTargetObject;
begin
  if AMoving.Id <= 0 then
    Exit('Kein Zielobjekt ausgew'#$00E4'hlt.');
  if IsRootScopeTarget(AMoving) then
    Exit('Der Informationsverbund kann nicht verschoben werden.');
  if ANewParentId <= 0 then
    Exit('Bitte ein '#$00FC'bergeordnetes Zielobjekt w'#$00E4'hlen.');
  if WouldCreateTargetParentCycle(AObjects, AMoving.Id, ANewParentId) then
    Exit('Ein Zielobjekt kann nicht unter ein eigenes Unterobjekt verschoben werden.');
  Parent := FindTargetObjectById(AObjects, ANewParentId);
  if Parent.Id = 0 then
    Exit(#$00DC'bergeordnetes Zielobjekt wurde nicht gefunden.');
  if not IsAllowedChildTargetType(Parent.ObjType, AMoving.ObjType) then
    Exit(Format('Dieser Zielobjekt-Typ ist unter %s nicht zul'#$00E4'ssig.',
      [TargetObjectTypeToString(Parent.ObjType)]));
  Result := '';
end;

function CanMoveTargetObject(const AObjects: TArray<TTargetObject>;
  const AMoving: TTargetObject; ANewParentId: Integer): Boolean;
begin
  Result := TargetMoveRejectedReason(AObjects, AMoving, ANewParentId) = '';
end;

function PossibleTargetMoveDestinations(const AObjects: TArray<TTargetObject>;
  const AMoving: TTargetObject): TArray<TTargetMoveDestination>;
var
  Scope: TTargetObject;
  Candidate: TTargetObject;
  Dest: TTargetMoveDestination;
begin
  SetLength(Result, 0);
  if (AMoving.Id <= 0) or IsRootScopeTarget(AMoving) then
    Exit;
  Scope := FindRootScopeTarget(AObjects);
  if (Scope.Id > 0) and (Scope.Id <> AMoving.ParentId) and
    CanMoveTargetObject(AObjects, AMoving, Scope.Id) then
  begin
    Dest.ParentId := Scope.Id;
    Dest.Caption := 'Schicht: ' + TargetObjectLayerGroupTitle(AMoving.ObjType);
    Result := Result + [Dest];
  end;
  for Candidate in AObjects do
  begin
    if (Candidate.Id = AMoving.Id) or (Candidate.Id = AMoving.ParentId) then
      Continue;
    if Candidate.Id = Scope.Id then
      Continue;
    if not CanMoveTargetObject(AObjects, AMoving, Candidate.Id) then
      Continue;
    Dest.ParentId := Candidate.Id;
    Dest.Caption := TargetObjectCaption(Candidate);
    Result := Result + [Dest];
  end;
end;

function ScopeLayerTypes: TArray<TTargetObjectType>;
begin
  Result := TArray<TTargetObjectType>.Create(
    totProcess, totApplication, totITSystem, totNetwork, totInfrastructure);
end;

function TargetObjectLayerGroupTitle(AType: TTargetObjectType): string;
begin
  case AType of
    totProcess: Result := 'Gesch'#$00E4'ftsprozesse';
    totApplication: Result := 'Anwendungen';
    totITSystem: Result := 'IT-Systeme';
    totNetwork: Result := 'Netze';
    totInfrastructure: Result := 'Infrastruktur';
  else
    Result := TargetObjectTypeToString(AType);
  end;
end;

function CanInheritAssessments(AParentType, AChildType: TTargetObjectType): Boolean;
begin
  case AParentType of
    totITSystem:
      Result := AChildType in [totITSystem, totApplication, totNetwork];
    totProcess:
      Result := AChildType in [totProcess, totApplication];
    totInfrastructure:
      Result := AChildType in [totInfrastructure, totITSystem, totNetwork];
  else
    Result := False;
  end;
end;

function RequirementLevelToString(AValue: TRequirementLevel): string;
begin
  case AValue of
    rlBasis: Result := 'Basis';
    rlStandard: Result := 'Standard';
    rlErhoeht: Result := S_Erhoeht;
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
  if SameText(Normalized, S_Erhoeht) then Exit(rlErhoeht);
  Result := rlUnknown;
end;

function RequirementLevelFromSectionTitle(const ATitle: string): TRequirementLevel;
begin
  if ATitle = 'Basis-Anforderungen' then Exit(rlBasis);
  if ATitle = 'Standard-Anforderungen' then Exit(rlStandard);
  if ATitle = S_ErhoehtemSchutzbedarf then Exit(rlErhoeht);
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
    brtSupplementary: Result := S_Ergaenzend;
  else
    Result := 'Kern';
  end;
end;

function CockpitKindToString(AKind: TCockpitKind): string;
begin
  case AKind of
    ckMeasure: Result := 'Ma'#$00DF'nahme';
  else
    Result := 'Bewertung';
  end;
end;

function CockpitItemIsDone(const AItem: TCockpitItem): Boolean;
begin
  case AItem.Kind of
    ckMeasure:
      Result := AItem.MeasureStatus = msDone;
  else
    Result := (AItem.AssessmentStatus = asFulfilled) or
      (AItem.AssessmentStatus = asNotApplicable);
  end;
end;

function IsDueThisWeek(const ADate: TDateTime): Boolean;
var
  Today: TDateTime;
begin
  if not IsValidDate(ADate) then
    Exit(False);
  Today := Date;
  Result := (Trunc(ADate) >= Trunc(Today)) and (Trunc(ADate) < Trunc(Today) + 7);
end;

function DefaultCockpitFilter: TCockpitFilter;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := ckfAll;
  Result.Due := cdfAll;
  Result.HideDone := True;
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

function NormalizeProjectVisibility(const AValue: string): string;
begin
  if SameText(Trim(AValue), 'public') then
    Exit('public');
  Result := 'private';
end;

function ProjectIsPublic(const AProject: TProject): Boolean;
begin
  Result := NormalizeProjectVisibility(AProject.Visibility) = 'public';
end;

function ProjectVisibilityLabel(const AValue: string): string;
begin
  if NormalizeProjectVisibility(AValue) = 'public' then
    Exit(#$00D6'ffentlich');
  Result := 'Privat';
end;

function AssessmentSaveOk(const AAssessment: TRequirementAssessment): TAssessmentSaveResult;
begin
  Result.Status := assOk;
  Result.Assessment := AAssessment;
end;

function AssessmentSaveConflict(const AAssessment: TRequirementAssessment): TAssessmentSaveResult;
begin
  Result.Status := assVersionConflict;
  Result.Assessment := AAssessment;
end;

function AssessmentSaveForbidden: TAssessmentSaveResult;
begin
  Result.Status := assForbidden;
  FillChar(Result.Assessment, SizeOf(Result.Assessment), 0);
end;

function AssessmentSaveFailed: TAssessmentSaveResult;
begin
  Result.Status := assFailed;
  FillChar(Result.Assessment, SizeOf(Result.Assessment), 0);
end;

function MeasureSaveOk(const AMeasure: TMeasure): TMeasureSaveResult;
begin
  Result.Status := mssOk;
  Result.Measure := AMeasure;
end;

function MeasureSaveConflict(const AMeasure: TMeasure): TMeasureSaveResult;
begin
  Result.Status := mssVersionConflict;
  Result.Measure := AMeasure;
end;

function MeasureSaveForbidden: TMeasureSaveResult;
begin
  Result.Status := mssForbidden;
  FillChar(Result.Measure, SizeOf(Result.Measure), 0);
end;

function MeasureSaveFailed: TMeasureSaveResult;
begin
  Result.Status := mssFailed;
  FillChar(Result.Measure, SizeOf(Result.Measure), 0);
end;

end.
