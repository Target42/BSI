unit HttpTargetObjectRepository;

interface

uses
  System.SysUtils, System.JSON, System.Generics.Collections, IsmsDomain,
  RepositoryBase, ApiClient, HttpJson;

type
  THttpTargetObjectRepository = class(TTargetObjectRepositoryBase)
  private
    FClient: TApiClient;
    FLastError: string;
  public
    constructor Create(AClient: TApiClient);
    function LoadTargetObjects(AProjectId: Integer): TArray<TTargetObject>; override;
    function CreateTargetObject(const ATargetObject: TTargetObject): TTargetObject; override;
    function UpdateTargetObject(const ATargetObject: TTargetObject): Boolean; override;
    function DeleteTargetObject(ATargetObjectId: Integer): Boolean; override;
    function CreateDefaultScope(AProjectId: Integer; const AProjectName: string): TTargetObject; override;
    function LoadApplicabilityMap(AProjectId, ATargetObjectId: Integer): TDictionary<Integer, TApplicabilityStatus>; override;
    function Applicability(AProjectId, ATargetObjectId, ABausteinDbId: Integer): TApplicabilityStatus; override;
    function SaveApplicability(const AApplicability: TBausteinApplicability): Boolean; override;
    function LoadDeviation(AProjectId, ATargetObjectId, ABausteinDbId: Integer): string; override;
    function SaveDeviation(AProjectId, ATargetObjectId, ABausteinDbId: Integer;
      const ANote: string): Boolean; override;
    function LoadReviews(AProjectId, ATargetObjectId: Integer): TDictionary<Integer, TBausteinReview>; override;
    function LoadProjectReviews(AProjectId: Integer): TArray<TBausteinReview>; override;
    function ApplyReview(AProjectId, ATargetObjectId, ABausteinId: Integer;
      const AAction, ANote: string;
      const ARequirementIds: TArray<Integer>): TReviewSaveResult; override;
    function AssignReviewer(AProjectId, ATargetObjectId, ABausteinId,
      AAssignedReviewerId: Integer): TReviewSaveResult; override;
    function GetLastError: string; override;
  end;

implementation

constructor THttpTargetObjectRepository.Create(AClient: TApiClient);
begin
  inherited Create;
  FClient := AClient;
end;

function THttpTargetObjectRepository.LoadTargetObjects(AProjectId: Integer): TArray<TTargetObject>;
var
  Doc: TJSONValue;
  Arr: TJSONArray;
  I: Integer;
  List: TArray<TTargetObject>;
  Status: Integer;
begin
  SetLength(List, 0);
  Doc := FClient.Get(Format('/api/v1/projects/%d/target-objects', [AProjectId]), Status);
  try
    if (Status <> 200) or not (Doc is TJSONArray) then
    begin
      FLastError := FClient.LastError;
      Exit;
    end;
    Arr := TJSONArray(Doc);
    SetLength(List, Arr.Count);
    for I := 0 to Arr.Count - 1 do
      if Arr.Items[I] is TJSONObject then
        List[I] := TargetObjectFromJson(TJSONObject(Arr.Items[I]));
  finally
    Doc.Free;
  end;
  Result := List;
end;

function THttpTargetObjectRepository.CreateTargetObject(const ATargetObject: TTargetObject): TTargetObject;
var
  Body: TJSONObject;
  Doc: TJSONValue;
  Status: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  Body := TJSONObject.Create;
  try
    AddTargetObjectJsonFields(Body, ATargetObject);
    Doc := FClient.PostJson(Format('/api/v1/projects/%d/target-objects', [ATargetObject.ProjectId]), Body, Status);
    try
      if (Status <> 201) or not (Doc is TJSONObject) then
      begin
        if (Status = 409) and (Doc is TJSONObject) and IsModelLockedJson(TJSONObject(Doc)) then
          FLastError := ModelLockMessage
        else
          FLastError := FClient.LastError;
        Exit;
      end;
      Result := TargetObjectFromJson(TJSONObject(Doc));
    finally
      Doc.Free;
    end;
  finally
    Body.Free;
  end;
end;

function THttpTargetObjectRepository.UpdateTargetObject(const ATargetObject: TTargetObject): Boolean;
var
  Body: TJSONObject;
  Doc: TJSONValue;
  Status: Integer;
begin
  Result := False;
  Body := TJSONObject.Create;
  try
    AddTargetObjectJsonFields(Body, ATargetObject, True);
    Doc := FClient.PatchJson(Format('/api/v1/target-objects/%d', [ATargetObject.Id]), Body, Status);
    try
      if Status <> 200 then
      begin
        if (Status = 409) and (Doc is TJSONObject) and IsModelLockedJson(TJSONObject(Doc)) then
          FLastError := ModelLockMessage
        else if (Status = 409) and (Doc is TJSONObject) and IsReviewLockedJson(TJSONObject(Doc)) then
          FLastError := ReviewLockMessage
        else
          FLastError := FClient.LastError;
      end
      else
        Result := True;
    finally
      Doc.Free;
    end;
  finally
    Body.Free;
  end;
end;

function THttpTargetObjectRepository.DeleteTargetObject(ATargetObjectId: Integer): Boolean;
var
  Status: Integer;
begin
  Result := FClient.Delete(Format('/api/v1/target-objects/%d', [ATargetObjectId]), Status) and (Status = 204);
  if not Result then
  begin
    if FClient.LastError = 'model_locked' then
      FLastError := ModelLockMessage
    else
      FLastError := FClient.LastError;
  end;
end;

function THttpTargetObjectRepository.CreateDefaultScope(AProjectId: Integer;
  const AProjectName: string): TTargetObject;
var
  Objects: TArray<TTargetObject>;
  O: TTargetObject;
  Scope: TTargetObject;
begin
  FillChar(Result, SizeOf(Result), 0);
  Objects := LoadTargetObjects(AProjectId);
  for O in Objects do
    if O.ObjType = totScope then
      Exit(O);
  FillChar(Scope, SizeOf(Scope), 0);
  Scope.ProjectId := AProjectId;
  Scope.ObjType := totScope;
  Scope.Name := AProjectName;
  Result := CreateTargetObject(Scope);
end;

function JsonStatusText(AValue: TJSONValue): string;
begin
  Result := '';
  if AValue = nil then
    Exit;
  if AValue is TJSONString then
    Exit(TJSONString(AValue).Value);
  Result := AValue.Value;
end;

function THttpTargetObjectRepository.LoadApplicabilityMap(AProjectId,
  ATargetObjectId: Integer): TDictionary<Integer, TApplicabilityStatus>;
var
  Doc: TJSONValue;
  Obj: TJSONObject;
  Pair: TJSONPair;
  Status: Integer;
  BausteinId: Integer;
  StatusText: string;
  ParsedStatus: TApplicabilityStatus;
  I: Integer;
begin
  Result := TDictionary<Integer, TApplicabilityStatus>.Create;
  Doc := FClient.Get(
    Format('/api/v1/projects/%d/target-objects/%d/applicability', [AProjectId, ATargetObjectId]),
    Status);
  try
    if Status <> 200 then
    begin
      FLastError := FClient.LastError;
      Exit;
    end;
    if (Doc = nil) or (Doc is TJSONNull) then
      Exit;
    if not (Doc is TJSONObject) then
    begin
      FLastError := 'Ungültige Applicability-Antwort vom Server.';
      Exit;
    end;
    Obj := TJSONObject(Doc);
    for I := 0 to Obj.Count - 1 do
    begin
      Pair := Obj.Pairs[I];
      BausteinId := StrToIntDef(Pair.JsonString.Value, 0);
      if BausteinId <= 0 then
        Continue;
      StatusText := JsonStatusText(Pair.JsonValue);
      ParsedStatus := ApplicabilityStatusFromString(StatusText);
      Result.AddOrSetValue(BausteinId, ParsedStatus);
    end;
  finally
    Doc.Free;
  end;
end;

function THttpTargetObjectRepository.Applicability(AProjectId, ATargetObjectId,
  ABausteinDbId: Integer): TApplicabilityStatus;
var
  Map: TDictionary<Integer, TApplicabilityStatus>;
begin
  Result := apUndefined;
  Map := LoadApplicabilityMap(AProjectId, ATargetObjectId);
  try
    if not Map.TryGetValue(ABausteinDbId, Result) then
      Result := apUndefined;
  finally
    Map.Free;
  end;
end;

function THttpTargetObjectRepository.SaveApplicability(const AApplicability: TBausteinApplicability): Boolean;
var
  Body: TJSONObject;
  Doc: TJSONValue;
  Status: Integer;
  Path: string;
begin
  Result := False;
  Path := Format('/api/v1/projects/%d/target-objects/%d/bausteine/%d/applicability',
    [AApplicability.ProjectId, AApplicability.TargetObjectId, AApplicability.BausteinDbId]);

  if AApplicability.Status = apUndefined then
  begin
    Result := FClient.Delete(Path, Status) and (Status = 204);
    if not Result then
    begin
      if FClient.LastError = 'model_locked' then
        FLastError := ModelLockMessage
      else if FClient.LastError = 'review_locked' then
        FLastError := ReviewLockMessage
      else
        FLastError := FClient.LastError;
    end;
    Exit;
  end;

  Body := TJSONObject.Create;
  try
    Body.AddPair('status', ApplicabilityStatusToString(AApplicability.Status));
    Doc := FClient.PutJson(Path, Body, Status);
    try
      if Status <> 200 then
      begin
        if (Status = 409) and (Doc is TJSONObject) and IsModelLockedJson(TJSONObject(Doc)) then
          FLastError := ModelLockMessage
        else if (Status = 409) and (Doc is TJSONObject) and IsReviewLockedJson(TJSONObject(Doc)) then
          FLastError := ReviewLockMessage
        else
          FLastError := FClient.LastError;
      end
      else
        Result := True;
    finally
      Doc.Free;
    end;
  finally
    Body.Free;
  end;
end;

function THttpTargetObjectRepository.LoadDeviation(AProjectId, ATargetObjectId,
  ABausteinDbId: Integer): string;
var
  Doc: TJSONValue;
  Status: Integer;
begin
  Result := '';
  Doc := FClient.Get(Format('/api/v1/projects/%d/target-objects/%d/bausteine/%d/deviation',
    [AProjectId, ATargetObjectId, ABausteinDbId]), Status);
  try
    if (Status <> 200) or not (Doc is TJSONObject) then
    begin
      FLastError := FClient.LastError;
      Exit;
    end;
    Result := JsonStringValue(TJSONObject(Doc), 'note');
  finally
    Doc.Free;
  end;
end;

function THttpTargetObjectRepository.SaveDeviation(AProjectId, ATargetObjectId,
  ABausteinDbId: Integer; const ANote: string): Boolean;
var
  Body: TJSONObject;
  Doc: TJSONValue;
  Status: Integer;
begin
  Result := False;
  Body := TJSONObject.Create;
  try
    Body.AddPair('note', ANote);
    Doc := FClient.PutJson(Format('/api/v1/projects/%d/target-objects/%d/bausteine/%d/deviation',
      [AProjectId, ATargetObjectId, ABausteinDbId]), Body, Status);
    try
      if Status <> 200 then
      begin
        if (Status = 409) and (Doc is TJSONObject) and IsModelLockedJson(TJSONObject(Doc)) then
          FLastError := ModelLockMessage
        else if (Status = 409) and (Doc is TJSONObject) and IsReviewLockedJson(TJSONObject(Doc)) then
          FLastError := ReviewLockMessage
        else
          FLastError := FClient.LastError;
      end
      else
        Result := True;
    finally
      Doc.Free;
    end;
  finally
    Body.Free;
  end;
end;

function THttpTargetObjectRepository.LoadReviews(AProjectId, ATargetObjectId: Integer): TDictionary<Integer, TBausteinReview>;
var
  Doc: TJSONValue;
  Arr: TJSONArray;
  I: Integer;
  Status: Integer;
  Review: TBausteinReview;
begin
  Result := TDictionary<Integer, TBausteinReview>.Create;
  Doc := FClient.Get(Format('/api/v1/projects/%d/target-objects/%d/reviews',
    [AProjectId, ATargetObjectId]), Status);
  try
    if (Status <> 200) or not (Doc is TJSONArray) then
    begin
      FLastError := FClient.LastError;
      Exit;
    end;
    Arr := TJSONArray(Doc);
    for I := 0 to Arr.Count - 1 do
      if Arr.Items[I] is TJSONObject then
      begin
        Review := BausteinReviewFromJson(TJSONObject(Arr.Items[I]));
        if Review.BausteinId > 0 then
          Result.AddOrSetValue(Review.BausteinId, Review);
      end;
  finally
    Doc.Free;
  end;
end;

function THttpTargetObjectRepository.LoadProjectReviews(AProjectId: Integer): TArray<TBausteinReview>;
var
  Doc: TJSONValue;
  Arr: TJSONArray;
  I: Integer;
  Status: Integer;
  List: TList<TBausteinReview>;
  Review: TBausteinReview;
begin
  SetLength(Result, 0);
  Doc := FClient.Get(Format('/api/v1/projects/%d/reviews', [AProjectId]), Status);
  try
    if (Status <> 200) or not (Doc is TJSONArray) then
    begin
      FLastError := FClient.LastError;
      Exit;
    end;
    Arr := TJSONArray(Doc);
    List := TList<TBausteinReview>.Create;
    try
      for I := 0 to Arr.Count - 1 do
        if Arr.Items[I] is TJSONObject then
        begin
          Review := BausteinReviewFromJson(TJSONObject(Arr.Items[I]));
          if Review.BausteinId > 0 then
            List.Add(Review);
        end;
      Result := List.ToArray;
    finally
      List.Free;
    end;
  finally
    Doc.Free;
  end;
end;

function THttpTargetObjectRepository.ApplyReview(AProjectId, ATargetObjectId, ABausteinId: Integer;
  const AAction, ANote: string; const ARequirementIds: TArray<Integer>): TReviewSaveResult;
var
  Body: TJSONObject;
  Ids: TJSONArray;
  Doc: TJSONValue;
  Status: Integer;
  Code: string;
  Id: Integer;
begin
  Result := ReviewSaveFailed;
  Body := TJSONObject.Create;
  try
    Body.AddPair('action', AAction);
    Body.AddPair('note', ANote);
    if Length(ARequirementIds) > 0 then
    begin
      Ids := TJSONArray.Create;
      for Id in ARequirementIds do
        Ids.Add(Id);
      Body.AddPair('requirementIds', Ids);
    end;
    Doc := FClient.PostJson(Format('/api/v1/projects/%d/target-objects/%d/bausteine/%d/review',
      [AProjectId, ATargetObjectId, ABausteinId]), Body, Status);
    try
      if (Status = 200) and (Doc is TJSONObject) then
        Exit(ReviewSaveOk(BausteinReviewFromJson(TJSONObject(Doc))));
      if Doc is TJSONObject then
        Code := JsonErrorCode(TJSONObject(Doc))
      else
        Code := '';
      if Code <> '' then
        FLastError := ReviewClientErrorMessage(Code)
      else
        FLastError := FClient.LastError;
      if Status = 403 then
        Exit(ReviewSaveFailed(rssForbidden));
      if Code = 'review_note_required' then
        Exit(ReviewSaveFailed(rssNoteRequired));
      if (Code = 'invalid_review_transition') or (Code = 'baustein_not_applicable') or
         (Code = 'workflow_disabled') or (Code = 'invalid_returned_requirements') then
        Exit(ReviewSaveFailed(rssInvalid));
    finally
      Doc.Free;
    end;
  finally
    Body.Free;
  end;
end;

function THttpTargetObjectRepository.AssignReviewer(AProjectId, ATargetObjectId, ABausteinId,
  AAssignedReviewerId: Integer): TReviewSaveResult;
var
  Body: TJSONObject;
  Doc: TJSONValue;
  Status: Integer;
  Code: string;
begin
  Result := ReviewSaveFailed;
  Body := TJSONObject.Create;
  try
    Body.AddPair('assignedReviewerId', TJSONNumber.Create(AAssignedReviewerId));
    Doc := FClient.PutJson(Format('/api/v1/projects/%d/target-objects/%d/bausteine/%d/reviewer',
      [AProjectId, ATargetObjectId, ABausteinId]), Body, Status);
    try
      if (Status = 200) and (Doc is TJSONObject) then
        Exit(ReviewSaveOk(BausteinReviewFromJson(TJSONObject(Doc))));
      if Doc is TJSONObject then
        Code := JsonErrorCode(TJSONObject(Doc))
      else
        Code := '';
      if Code <> '' then
        FLastError := ReviewClientErrorMessage(Code)
      else
        FLastError := FClient.LastError;
      if Status = 403 then
        Exit(ReviewSaveFailed(rssForbidden));
      if (Code = 'invalid_reviewer') or (Code = 'baustein_not_applicable') then
        Exit(ReviewSaveFailed(rssInvalid));
    finally
      Doc.Free;
    end;
  finally
    Body.Free;
  end;
end;

function THttpTargetObjectRepository.GetLastError: string;
begin
  if FLastError <> '' then
    Exit(FLastError);
  Result := FClient.LastError;
end;

end.
