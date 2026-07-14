unit GrundschutzImporter;

interface

uses
  System.SysUtils, System.Classes, System.RegularExpressions, Xml.XMLIntf, Xml.XMLDoc,
  IsmsDomain;

type
  TGrundschutzImporter = class
  private
    class function ElementTitle(const ANode: IXMLNode): string;
    class function SectionTitle(const ANode: IXMLNode): string;
    class function CollectText(const ANode: IXMLNode): string;
    class function CollectParagraphs(const ANode: IXMLNode): TArray<string>;
    class function StripMarkup(const AText: string): string;
    class procedure WalkNode(const ANode: IXMLNode; const AGroupName: string;
      ACurrentBausteinIndex: Integer; ACurrentLevel: TRequirementLevel;
      var ABausteine: TArray<TBaustein>; var ARequirements: TArray<TRequirement>);
    class function TryParseBaustein(const ATitle, AGroupName: string; out ABaustein: TBaustein): Boolean;
    class function TryParseRequirement(const ATitle: string; const ABaustein: TBaustein;
      ALevel: TRequirementLevel; const ASectionNode: IXMLNode; out ARequirement: TRequirement): Boolean;
  public
    class function ImportFromFile(const AFilePath: string): TGrundschutzImportResult;
  end;

implementation

const
  BausteinTitlePattern = '^(?<id>[A-Z]{2,4}(?:\.\d+)+)\s+(?<title>.+)$';
  RequirementTitlePattern = '^(?<id>[A-Z]{2,4}(?:\.\d+)+\.A\d+)\s+(?<title>.+)$';
  LevelMarkerPattern = '\(([BSH])\)';
  RolePattern = '\[(?<role>[^\]]+)\]';

class function TGrundschutzImporter.ElementTitle(const ANode: IXMLNode): string;
var
  I: Integer;
  Child: IXMLNode;
begin
  Result := '';
  if ANode = nil then
    Exit;
  if (ANode.NodeName <> 'section') and (ANode.NodeName <> 'chapter') then
    Exit;
  for I := 0 to ANode.ChildNodes.Count - 1 do
  begin
    Child := ANode.ChildNodes[I];
    if Child.NodeName = 'title' then
      Exit(Trim(Child.Text));
  end;
end;

class function TGrundschutzImporter.SectionTitle(const ANode: IXMLNode): string;
begin
  Result := ElementTitle(ANode);
end;

class function TGrundschutzImporter.CollectText(const ANode: IXMLNode): string;
var
  I: Integer;
  Child: IXMLNode;
  Part: string;
begin
  Result := '';
  if ANode = nil then
    Exit;
  if ANode.NodeType = ntText then
    Exit(Trim(ANode.Text));
  if ANode.NodeName = 'linebreak' then
    Exit(#10);
  for I := 0 to ANode.ChildNodes.Count - 1 do
  begin
    Child := ANode.ChildNodes[I];
    Part := CollectText(Child);
    if Part = '' then
      Continue;
    if (Result <> '') and (not Part.StartsWith(#10)) and (not Result.EndsWith(#10)) then
      Result := Result + ' ';
    Result := Result + Part;
  end;
  Result := Trim(Result);
end;

class function TGrundschutzImporter.CollectParagraphs(const ANode: IXMLNode): TArray<string>;
var
  I: Integer;
  Child: IXMLNode;
  Text: string;
  Parts: TArray<string>;
  SubParts: TArray<string>;
begin
  SetLength(Parts, 0);
  if ANode = nil then
    Exit(Parts);
  if ANode.NodeName = 'para' then
  begin
    Text := CollectText(ANode);
    if Text <> '' then
    begin
      SetLength(Parts, 1);
      Parts[0] := Text;
    end;
    Exit(Parts);
  end;
  for I := 0 to ANode.ChildNodes.Count - 1 do
  begin
    Child := ANode.ChildNodes[I];
    SubParts := CollectParagraphs(Child);
    Parts := Parts + SubParts;
  end;
  Result := Parts;
end;

class function TGrundschutzImporter.StripMarkup(const AText: string): string;
begin
  Result := Trim(TRegEx.Replace(AText, '<[^>]+>', '', [roMultiLine]));
end;

class function TGrundschutzImporter.TryParseBaustein(const ATitle, AGroupName: string;
  out ABaustein: TBaustein): Boolean;
var
  Match: TMatch;
begin
  Result := False;
  FillChar(ABaustein, SizeOf(ABaustein), 0);
  if TRegEx.IsMatch(ATitle, RequirementTitlePattern) then
    Exit;
  Match := TRegEx.Match(ATitle, BausteinTitlePattern);
  if not Match.Success then
    Exit;
  ABaustein.Standard := stITGrundschutz;
  ABaustein.ExternalId := Match.Groups['id'].Value;
  ABaustein.Title := Trim(Match.Groups['title'].Value);
  ABaustein.GroupName := AGroupName;
  ABaustein.CatalogVersion := '2023';
  Result := True;
end;

class function TGrundschutzImporter.TryParseRequirement(const ATitle: string;
  const ABaustein: TBaustein; ALevel: TRequirementLevel; const ASectionNode: IXMLNode;
  out ARequirement: TRequirement): Boolean;
var
  Match, LevelMatch, RoleMatch: TMatch;
  Paragraphs: TArray<string>;
  Body: string;
begin
  Result := False;
  FillChar(ARequirement, SizeOf(ARequirement), 0);
  Match := TRegEx.Match(ATitle, RequirementTitlePattern);
  if not Match.Success then
    Exit;
  ARequirement.Standard := stITGrundschutz;
  ARequirement.ExternalId := Match.Groups['id'].Value;
  ARequirement.BausteinExternalId := ABaustein.ExternalId;
  ARequirement.Title := Trim(Match.Groups['title'].Value);
  Paragraphs := CollectParagraphs(ASectionNode);
  Body := StripMarkup(string.Join(sLineBreak + sLineBreak, Paragraphs));
  ARequirement.Text := Body;
  ARequirement.Withdrawn := ARequirement.Title.ToUpper.StartsWith('ENTFALLEN');
  LevelMatch := TRegEx.Match(ATitle, LevelMarkerPattern);
  if LevelMatch.Success then
    ARequirement.Level := RequirementLevelFromMarker(LevelMatch.Groups[1].Value[1])
  else
    ARequirement.Level := ALevel;
  RoleMatch := TRegEx.Match(ATitle, RolePattern);
  if RoleMatch.Success then
    ARequirement.ResponsibleRole := Trim(RoleMatch.Groups['role'].Value);
  Result := True;
end;

class procedure TGrundschutzImporter.WalkNode(const ANode: IXMLNode; const AGroupName: string;
  ACurrentBausteinIndex: Integer; ACurrentLevel: TRequirementLevel;
  var ABausteine: TArray<TBaustein>; var ARequirements: TArray<TRequirement>);
var
  I: Integer;
  Child: IXMLNode;
  ActiveGroup: string;
  ActiveBausteinIndex: Integer;
  ActiveLevel: TRequirementLevel;
  Title: string;
  ParsedBaustein: TBaustein;
  ParsedRequirement: TRequirement;
  SectionLevel: TRequirementLevel;
begin
  if ANode = nil then
    Exit;
  ActiveGroup := AGroupName;
  ActiveBausteinIndex := ACurrentBausteinIndex;
  ActiveLevel := ACurrentLevel;
  if ANode.NodeName = 'chapter' then
  begin
    Title := ElementTitle(ANode);
    if Title <> '' then
      ActiveGroup := Title;
  end;
  if ANode.NodeName = 'section' then
  begin
    Title := SectionTitle(ANode);
    if TryParseBaustein(Title, ActiveGroup, ParsedBaustein) then
    begin
      SetLength(ABausteine, Length(ABausteine) + 1);
      ABausteine[High(ABausteine)] := ParsedBaustein;
      ActiveBausteinIndex := High(ABausteine);
      ActiveLevel := rlUnknown;
    end
    else if Title = 'Anforderungen' then
      ActiveLevel := rlUnknown
    else
    begin
      SectionLevel := RequirementLevelFromSectionTitle(Title);
      if SectionLevel <> rlUnknown then
        ActiveLevel := SectionLevel;
      if (ActiveBausteinIndex >= 0) and
         TryParseRequirement(Title, ABausteine[ActiveBausteinIndex], ActiveLevel, ANode, ParsedRequirement) then
      begin
        SetLength(ARequirements, Length(ARequirements) + 1);
        ARequirements[High(ARequirements)] := ParsedRequirement;
      end;
    end;
  end;
  for I := 0 to ANode.ChildNodes.Count - 1 do
  begin
    Child := ANode.ChildNodes[I];
    WalkNode(Child, ActiveGroup, ActiveBausteinIndex, ActiveLevel, ABausteine, ARequirements);
  end;
end;

class function TGrundschutzImporter.ImportFromFile(const AFilePath: string): TGrundschutzImportResult;
var
  Doc: IXMLDocument;
  Bausteine: TArray<TBaustein>;
  Requirements: TArray<TRequirement>;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.CatalogVersion := '2023';
  if not FileExists(AFilePath) then
  begin
    Result.ErrorMessage := 'Datei konnte nicht geöffnet werden: ' + AFilePath;
    Exit;
  end;
  Doc := TXMLDocument.Create(nil);
  try
    Doc.Active := True;
    Doc.LoadFromFile(AFilePath);
    if Doc.DocumentElement.NodeName <> 'book' then
    begin
      Result.ErrorMessage := 'Unerwartete Wurzel: ' + Doc.DocumentElement.NodeName;
      Exit;
    end;
    SetLength(Bausteine, 0);
    SetLength(Requirements, 0);
    WalkNode(Doc.DocumentElement, '', -1, rlUnknown, Bausteine, Requirements);
    Result.Bausteine := Bausteine;
    Result.Requirements := Requirements;
    Result.Success := True;
  except
    on E: Exception do
      Result.ErrorMessage := E.Message;
  end;
end;

end.
