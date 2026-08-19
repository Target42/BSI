unit InheritanceService;

interface

uses
  System.SysUtils, System.Generics.Collections, IsmsDomain;

type
  TInheritanceService = class
  public
    class function FindById(const AObjects: TArray<TTargetObject>; AId: Integer): TTargetObject;
    class function AncestorChain(const AObjects: TArray<TTargetObject>;
      const ATarget: TTargetObject): TArray<TTargetObject>;
    class procedure CollectInherited(
      const AObjects: TArray<TTargetObject>;
      const ATarget: TTargetObject;
      AOwnMap: TDictionary<Integer, TApplicabilityStatus>;
      AParentMaps: TObjectDictionary<Integer, TDictionary<Integer, TApplicabilityStatus>>;
      AInherited: TDictionary<Integer, TInheritedBaustein>);
  end;

implementation

class function TInheritanceService.FindById(const AObjects: TArray<TTargetObject>;
  AId: Integer): TTargetObject;
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

class function TInheritanceService.AncestorChain(const AObjects: TArray<TTargetObject>;
  const ATarget: TTargetObject): TArray<TTargetObject>;
var
  Current, Parent: TTargetObject;
  Guard: Integer;
begin
  SetLength(Result, 0);
  Current := ATarget;
  Guard := 0;
  while (Current.ParentId > 0) and (Guard < 64) do
  begin
    Inc(Guard);
    Parent := FindById(AObjects, Current.ParentId);
    if Parent.Id = 0 then
      Break;
    if not CanInheritAssessments(Parent.ObjType, Current.ObjType) then
      Break;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := Parent;
    Current := Parent;
  end;
end;

class procedure TInheritanceService.CollectInherited(
  const AObjects: TArray<TTargetObject>;
  const ATarget: TTargetObject;
  AOwnMap: TDictionary<Integer, TApplicabilityStatus>;
  AParentMaps: TObjectDictionary<Integer, TDictionary<Integer, TApplicabilityStatus>>;
  AInherited: TDictionary<Integer, TInheritedBaustein>);
var
  Ancestors: TArray<TTargetObject>;
  Parent: TTargetObject;
  Map: TDictionary<Integer, TApplicabilityStatus>;
  Pair: TPair<Integer, TApplicabilityStatus>;
  Item: TInheritedBaustein;
begin
  AInherited.Clear;
  Ancestors := AncestorChain(AObjects, ATarget);
  for Parent in Ancestors do
  begin
    if not AParentMaps.TryGetValue(Parent.Id, Map) then
      Continue;
    for Pair in Map do
    begin
      if (Pair.Value <> apRequired) and (Pair.Value <> apPossible) then
        Continue;
      if AOwnMap.ContainsKey(Pair.Key) then
        Continue;
      if AInherited.ContainsKey(Pair.Key) then
        Continue;
      Item.BausteinDbId := Pair.Key;
      Item.Status := Pair.Value;
      Item.SourceTargetId := Parent.Id;
      Item.SourceCaption := TargetObjectCaption(Parent);
      AInherited.Add(Pair.Key, Item);
    end;
  end;
end;

end.
