unit HttpNotificationService;

interface

uses
  System.SysUtils, System.JSON, IsmsDomain, ApiClient, HttpJson;

type
  THttpNotificationService = class
  private
    FClient: TApiClient;
    FLastError: string;
    class function ReadErrorMessage(ADoc: TJSONValue; const AFallback: string): string; static;
  public
    constructor Create(AClient: TApiClient);
    function List: TArray<TNotification>;
    function MarkRead(ANotificationId: Integer): Boolean;
    function MarkAllRead: Boolean;
    function GetLastError: string;
    property LastError: string read GetLastError;
  end;

implementation

constructor THttpNotificationService.Create(AClient: TApiClient);
begin
  inherited Create;
  FClient := AClient;
end;

class function THttpNotificationService.ReadErrorMessage(ADoc: TJSONValue;
  const AFallback: string): string;
var
  Obj: TJSONObject;
begin
  Result := AFallback;
  if not (ADoc is TJSONObject) then
    Exit;
  Obj := TJSONObject(ADoc);
  if Obj.TryGetValue<string>('error', Result) then
    Exit;
  if Obj.TryGetValue<string>('message', Result) then
    Exit;
  Result := AFallback;
end;

function THttpNotificationService.GetLastError: string;
begin
  if FLastError <> '' then
    Exit(FLastError);
  Result := FClient.LastError;
end;

function THttpNotificationService.List: TArray<TNotification>;
var
  Doc: TJSONValue;
  Arr: TJSONArray;
  Status, I: Integer;
begin
  SetLength(Result, 0);
  FLastError := '';
  Doc := FClient.Get('/api/v1/notifications', Status);
  try
    if (Status <> 200) or not (Doc is TJSONArray) then
    begin
      FLastError := ReadErrorMessage(Doc, FClient.LastError);
      Exit;
    end;
    Arr := TJSONArray(Doc);
    SetLength(Result, Arr.Count);
    for I := 0 to Arr.Count - 1 do
      if Arr.Items[I] is TJSONObject then
        Result[I] := NotificationFromJson(TJSONObject(Arr.Items[I]));
  finally
    Doc.Free;
  end;
end;

function THttpNotificationService.MarkRead(ANotificationId: Integer): Boolean;
var
  Body, Doc: TJSONValue;
  Status: Integer;
begin
  Result := False;
  if ANotificationId <= 0 then
    Exit;
  FLastError := '';
  Body := TJSONObject.Create;
  try
    Doc := FClient.PostJson('/api/v1/notifications/' + IntToStr(ANotificationId) + '/read',
      TJSONObject(Body), Status);
  finally
    Body.Free;
  end;
  try
    Result := (Status >= 200) and (Status < 300);
    if not Result then
      FLastError := ReadErrorMessage(Doc, FClient.LastError);
  finally
    Doc.Free;
  end;
end;

function THttpNotificationService.MarkAllRead: Boolean;
var
  Body, Doc: TJSONValue;
  Status: Integer;
begin
  FLastError := '';
  Body := TJSONObject.Create;
  try
    Doc := FClient.PostJson('/api/v1/notifications/read-all', TJSONObject(Body), Status);
  finally
    Body.Free;
  end;
  try
    Result := (Status >= 200) and (Status < 300);
    if not Result then
      FLastError := ReadErrorMessage(Doc, FClient.LastError);
  finally
    Doc.Free;
  end;
end;

end.
