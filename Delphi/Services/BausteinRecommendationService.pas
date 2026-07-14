unit BausteinRecommendationService;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, IsmsDomain;

type
  TPrefixRule = record
    Prefix: string;
    Tier: TBausteinRecommendationTier;
    SuggestedStatus: TApplicabilityStatus;
    Reason: string;
  end;

  TBausteinRecommendationService = class
  public
    class function BausteinPrefix(const AExternalId: string): string;
    class function BuildRecommendations(const ABausteine: TArray<TBaustein>;
      const ATargetObject: TTargetObject): TArray<TBausteinRecommendation>;
    class function IsRecommended(const ABaustein: TBaustein;
      const ATargetObject: TTargetObject): Boolean;
    class function RecommendationHint(const ATargetObject: TTargetObject): string;
    class function RecommendationTier(const ABaustein: TBaustein;
      const ATargetObject: TTargetObject): TBausteinRecommendationTier;
  end;

implementation

uses
  System.Math;

procedure AddRule(var ARules: TArray<TPrefixRule>; const APrefix: string;
  ATier: TBausteinRecommendationTier; ASuggestedStatus: TApplicabilityStatus;
  const AReason: string);
var
  Rule: TPrefixRule;
  I: Integer;
begin
  for I := 0 to High(ARules) do
    if SameText(ARules[I].Prefix, APrefix) then
      Exit;
  Rule.Prefix := APrefix;
  Rule.Tier := ATier;
  Rule.SuggestedStatus := ASuggestedStatus;
  Rule.Reason := AReason;
  SetLength(ARules, Length(ARules) + 1);
  ARules[High(ARules)] := Rule;
end;

procedure AddCoreRules(var ARules: TArray<TPrefixRule>; const APrefixes: array of string;
  const AReason: string; ASuggestedStatus: TApplicabilityStatus = apRequired);
var
  Prefix: string;
begin
  for Prefix in APrefixes do
    AddRule(ARules, Prefix, brtCore, ASuggestedStatus, AReason);
end;

procedure AddSupplementaryRules(var ARules: TArray<TPrefixRule>;
  const APrefixes: array of string; const AReason: string;
  ASuggestedStatus: TApplicabilityStatus = apPossible);
var
  Prefix: string;
begin
  for Prefix in APrefixes do
    AddRule(ARules, Prefix, brtSupplementary, ASuggestedStatus, AReason);
end;

function RulesForTarget(const ATargetObject: TTargetObject): TArray<TPrefixRule>;
var
  Elevated: Boolean;
begin
  SetLength(Result, 0);
  Elevated := ATargetObject.ProtectionNeed = pnElevated;
  case ATargetObject.ObjType of
    totScope:
    begin
      AddCoreRules(Result, ['ISMS', 'ORP', 'CON'],
        'Organisationsweite Grundbausteine für den Informationsverbund');
      AddSupplementaryRules(Result, ['OPS'],
        'Betriebliche Querschnittsaspekte im Gesamtverbund');
      if Elevated then
        AddSupplementaryRules(Result, ['DER'],
          'Erkennung und Reaktion bei erhöhtem Schutzbedarf', apRequired);
    end;
    totProcess:
    begin
      AddCoreRules(Result, ['ORP', 'OPS'],
        'Organisation, Personal und Betrieb für Geschäftsprozesse');
      AddSupplementaryRules(Result, ['CON'],
        'Übergreifende Konfiguration und Steuerung');
      if Elevated then
        AddSupplementaryRules(Result, ['DER', 'ISMS'],
          'Zusätzliche Schutz- und Steuerungsaspekte bei erhöhtem Schutzbedarf');
    end;
    totApplication:
    begin
      AddCoreRules(Result, ['APP'],
        'Anwendungsspezifische IT-Grundschutz-Bausteine');
      AddSupplementaryRules(Result, ['OPS', 'CON'],
        'Betrieb und Konfiguration der Anwendungsumgebung');
      if Elevated then
        AddSupplementaryRules(Result, ['DER', 'SYS'],
          'System- und Reaktionsaspekte bei erhöhtem Schutzbedarf');
    end;
    totITSystem:
    begin
      AddCoreRules(Result, ['SYS', 'OPS'],
        'System- und Betriebsbausteine für IT-Systeme');
      AddSupplementaryRules(Result, ['CON', 'NET'],
        'Einbindung in Konfiguration und Netzwerk');
      AddSupplementaryRules(Result, ['IND'],
        'Industrielle oder spezialisierte Systemumgebungen');
      if Elevated then
        AddSupplementaryRules(Result, ['DER'],
          'Erkennung und Reaktion bei erhöhtem Schutzbedarf', apRequired);
    end;
    totNetwork:
    begin
      AddCoreRules(Result, ['NET'],
        'Netz- und Kommunikationsbausteine');
      AddSupplementaryRules(Result, ['INF', 'OPS', 'CON'],
        'Infrastruktur, Betrieb und Konfiguration der Verbindung');
      if Elevated then
        AddSupplementaryRules(Result, ['DER'],
          'Überwachung und Reaktion bei erhöhtem Schutzbedarf', apRequired);
    end;
    totInfrastructure:
    begin
      AddCoreRules(Result, ['INF'],
        'Infrastrukturbausteine für Räume, Gebäude und Anlagen');
      AddSupplementaryRules(Result, ['NET', 'OPS', 'IND'],
        'Anbindung, Betrieb und spezialisierte Infrastruktur');
      if Elevated then
        AddSupplementaryRules(Result, ['DER', 'CON'],
          'Zusätzliche Schutz- und Steuerungsaspekte bei erhöhtem Schutzbedarf');
    end;
  end;
end;

class function TBausteinRecommendationService.BausteinPrefix(const AExternalId: string): string;
var
  DotIndex: Integer;
begin
  DotIndex := Pos('.', AExternalId);
  if DotIndex <= 1 then
    Exit(UpperCase(Trim(AExternalId)));
  Result := UpperCase(Copy(AExternalId, 1, DotIndex - 1));
end;

class function TBausteinRecommendationService.BuildRecommendations(
  const ABausteine: TArray<TBaustein>; const ATargetObject: TTargetObject): TArray<TBausteinRecommendation>;
var
  Rules: TArray<TPrefixRule>;
  BestRuleByPrefix: TDictionary<string, TPrefixRule>;
  Recommendations: TDictionary<Integer, TBausteinRecommendation>;
  B: TBaustein;
  Rule: TPrefixRule;
  Rec, Existing: TBausteinRecommendation;
  Items: TArray<TBausteinRecommendation>;
  I, J: Integer;
begin
  SetLength(Result, 0);
  Rules := RulesForTarget(ATargetObject);
  BestRuleByPrefix := TDictionary<string, TPrefixRule>.Create;
  Recommendations := TDictionary<Integer, TBausteinRecommendation>.Create;
  try
    for Rule in Rules do
      BestRuleByPrefix.AddOrSetValue(Rule.Prefix, Rule);

    for B in ABausteine do
    begin
      if not BestRuleByPrefix.TryGetValue(BausteinPrefix(B.ExternalId), Rule) then
        Continue;
      Rec.BausteinDbId := B.Id;
      Rec.ExternalId := B.ExternalId;
      Rec.Title := B.Title;
      Rec.GroupName := B.GroupName;
      Rec.Tier := Rule.Tier;
      Rec.SuggestedStatus := Rule.SuggestedStatus;
      Rec.Reason := Rule.Reason;
      if B.GroupName <> '' then
        Rec.Reason := Rule.Reason + ' (' + B.GroupName + ')';

      if Recommendations.TryGetValue(B.Id, Existing) then
      begin
        if (Existing.Tier = brtSupplementary) and (Rec.Tier = brtCore) then
          Recommendations.AddOrSetValue(B.Id, Rec);
      end
      else
        Recommendations.Add(B.Id, Rec);
    end;

    Items := Recommendations.Values.ToArray;
    SetLength(Result, Length(Items));
    for I := 0 to High(Items) do
      Result[I] := Items[I];

    for I := 0 to High(Result) - 1 do
      for J := I + 1 to High(Result) do
      begin
        if (Integer(Result[I].Tier) > Integer(Result[J].Tier)) or
           ((Result[I].Tier = Result[J].Tier) and (Result[I].ExternalId > Result[J].ExternalId)) then
        begin
          Rec := Result[I];
          Result[I] := Result[J];
          Result[J] := Rec;
        end;
      end;
  finally
    BestRuleByPrefix.Free;
    Recommendations.Free;
  end;
end;

class function TBausteinRecommendationService.IsRecommended(const ABaustein: TBaustein;
  const ATargetObject: TTargetObject): Boolean;
var
  Rules: TArray<TPrefixRule>;
  Prefix: string;
  Rule: TPrefixRule;
begin
  Rules := RulesForTarget(ATargetObject);
  Prefix := BausteinPrefix(ABaustein.ExternalId);
  for Rule in Rules do
    if SameText(Rule.Prefix, Prefix) then
      Exit(True);
  Result := False;
end;

class function TBausteinRecommendationService.RecommendationTier(const ABaustein: TBaustein;
  const ATargetObject: TTargetObject): TBausteinRecommendationTier;
var
  Rules: TArray<TPrefixRule>;
  Prefix: string;
  Rule: TPrefixRule;
begin
  Result := brtCore;
  Rules := RulesForTarget(ATargetObject);
  Prefix := BausteinPrefix(ABaustein.ExternalId);
  for Rule in Rules do
    if SameText(Rule.Prefix, Prefix) then
      Exit(Rule.Tier);
end;

class function TBausteinRecommendationService.RecommendationHint(
  const ATargetObject: TTargetObject): string;
var
  Rules: TArray<TPrefixRule>;
  Rule: TPrefixRule;
  CorePrefixes, SupplementaryPrefixes: TStringList;
begin
  Rules := RulesForTarget(ATargetObject);
  if Length(Rules) = 0 then
    Exit('');

  CorePrefixes := TStringList.Create;
  SupplementaryPrefixes := TStringList.Create;
  try
    CorePrefixes.Sorted := True;
    CorePrefixes.Duplicates := dupIgnore;
    SupplementaryPrefixes.Sorted := True;
    SupplementaryPrefixes.Duplicates := dupIgnore;
    for Rule in Rules do
    begin
      if Rule.Tier = brtCore then
        CorePrefixes.Add(Rule.Prefix)
      else
        SupplementaryPrefixes.Add(Rule.Prefix);
    end;

    Result := 'Kern-Bausteine: ' + StringReplace(Trim(CorePrefixes.CommaText), '"', '', [rfReplaceAll]);
    if SupplementaryPrefixes.Count > 0 then
      Result := Result + sLineBreak + 'Ergänzende Bausteine: ' +
        StringReplace(Trim(SupplementaryPrefixes.CommaText), '"', '', [rfReplaceAll]);
    Result := Result + sLineBreak + 'Schutzbedarf: ' +
      ProtectionNeedToString(ATargetObject.ProtectionNeed);
    if ATargetObject.ProtectionNeed = pnElevated then
      Result := Result + sLineBreak +
        'Bei erhöhtem Schutzbedarf werden zusätzliche Bausteine (z. B. DER) empfohlen.';
  finally
    CorePrefixes.Free;
    SupplementaryPrefixes.Free;
  end;
end;

end.
