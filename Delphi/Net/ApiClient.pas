unit ApiClient;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.DateUtils,
  IdHTTP, IdSSLOpenSSL, IdMultipartFormData, IdGlobal, IsmsDomain, HttpJson;

type
  TReloginHandler = reference to function: Boolean;

  TApiClient = class
  private
    FHttp: TIdHTTP;
    FSsl: TIdSSLIOHandlerSocketOpenSSL;
    FBaseUrl: string;
    FAccessToken: string;
    FTokenExpiresAt: TDateTime;
    FInsecureSkipTls: Boolean;
    FReloginHandler: TReloginHandler;
    FLastError: string;
    FLastAuthFailure: Boolean;
    function DoHttpRequest(const AMethod, APath: string; const ABody: string;
      const AContentType: string; out AStatus: Integer; AAllowRelogin: Boolean): TJSONValue;
    function BuildUrl(const APath: string): string;
    class function ReadApiError(ADoc: TJSONValue; const AFallback: string): string; static;
    function IsAuthEndpoint(const APath: string): Boolean;
    procedure ConfigureHttp;
    class function StreamToUtf8Bytes(AStream: TStream): TBytes; static;
    class function ParseUtf8Json(const ABytes: TBytes): TJSONValue; static;
  public
    constructor Create(const ABaseUrl: string = '');
    destructor Destroy; override;
    procedure SetBaseUrl(const AValue: string);
    function GetBaseUrl: string;
    procedure SetAccessToken(const AValue: string);
    function GetAccessToken: string;
    procedure SetTokenExpiresAt(const AValue: TDateTime);
    function GetTokenExpiresAt: TDateTime;
    procedure SetInsecureSkipTlsVerify(AValue: Boolean);
    function GetInsecureSkipTlsVerify: Boolean;
    property ReloginHandler: TReloginHandler read FReloginHandler write FReloginHandler;
    function IsTokenExpired: Boolean;
    function ApplyFromSettings(const ABaseUrl, AAccessToken: string; ATokenExpiresAt: TDateTime): Boolean;
    function Login(const AEmail, APassword: string; out AError: string): Boolean;
    function ValidateSession(out AError: string): Boolean;
    function Get(const APath: string; out AStatus: Integer): TJSONValue;
    function PostJson(const APath: string; ABody: TJSONObject; out AStatus: Integer): TJSONValue;
    function PutJson(const APath: string; ABody: TJSONObject; out AStatus: Integer): TJSONValue;
    function PatchJson(const APath: string; ABody: TJSONObject; out AStatus: Integer): TJSONValue;
    function Delete(const APath: string; out AStatus: Integer): Boolean;
    function UploadFile(const APath, AFieldName, AFilePath: string; out AStatus: Integer): TJSONValue;
    function GetLastError: string;
    function GetLastAuthFailure: Boolean;
    property AccessToken: string read GetAccessToken write SetAccessToken;
    property TokenExpiresAt: TDateTime read GetTokenExpiresAt write SetTokenExpiresAt;
    property LastError: string read GetLastError;
    property LastAuthFailure: Boolean read GetLastAuthFailure;
  end;

implementation

const
  kExpirySkewSeconds = 60;

constructor TApiClient.Create(const ABaseUrl: string);
begin
  inherited Create;
  GIdDefaultTextEncoding := encUTF8;
  FHttp := TIdHTTP.Create(nil);
  FHttp.HandleRedirects := True;
  FHttp.ReadTimeout := 30000;
  FHttp.ConnectTimeout := 15000;
  SetBaseUrl(ABaseUrl);
end;

destructor TApiClient.Destroy;
begin
  FSsl.Free;
  FHttp.Free;
  inherited;
end;

procedure TApiClient.SetBaseUrl(const AValue: string);
var
  S: string;
begin
  S := Trim(AValue);
  while (S <> '') and (Copy(S, Length(S), 1) = '/') do
    SetLength(S, Length(S) - 1);
  FBaseUrl := S;
end;

function TApiClient.GetBaseUrl: string;
begin
  Result := FBaseUrl;
end;

procedure TApiClient.SetAccessToken(const AValue: string);
begin
  FAccessToken := AValue;
end;

function TApiClient.GetAccessToken: string;
begin
  Result := FAccessToken;
end;

procedure TApiClient.SetTokenExpiresAt(const AValue: TDateTime);
begin
  FTokenExpiresAt := AValue;
end;

function TApiClient.GetTokenExpiresAt: TDateTime;
begin
  Result := FTokenExpiresAt;
end;

procedure TApiClient.SetInsecureSkipTlsVerify(AValue: Boolean);
begin
  FInsecureSkipTls := AValue;
  ConfigureHttp;
end;

function TApiClient.GetInsecureSkipTlsVerify: Boolean;
begin
  Result := FInsecureSkipTls;
end;

procedure TApiClient.ConfigureHttp;
begin
  if FInsecureSkipTls and SameText(Copy(FBaseUrl, 1, 8), 'https://') then
  begin
    if FSsl = nil then
    begin
      FSsl := TIdSSLIOHandlerSocketOpenSSL.Create(FHttp);
      FSsl.SSLOptions.VerifyMode := [];
      FSsl.SSLOptions.VerifyDepth := 0;
    end;
    FHttp.IOHandler := FSsl;
  end
  else
    FHttp.IOHandler := nil;
end;

function TApiClient.IsTokenExpired: Boolean;
begin
  if FAccessToken = '' then
    Exit(True);
  if FTokenExpiresAt <= 0 then
    Exit(False);
  Result := Now >= IncSecond(FTokenExpiresAt, -kExpirySkewSeconds);
end;

function TApiClient.BuildUrl(const APath: string): string;
var
  Normalized: string;
begin
  Normalized := APath;
  if (Normalized = '') or (Normalized[1] <> '/') then
    Normalized := '/' + Normalized;
  Result := FBaseUrl + Normalized;
end;

class function TApiClient.ReadApiError(ADoc: TJSONValue; const AFallback: string): string;
var
  Obj: TJSONObject;
begin
  Result := AFallback;
  if not (ADoc is TJSONObject) then
    Exit;
  Obj := TJSONObject(ADoc);
  if Obj.TryGetValue<string>('error', Result) then
  begin
    Result := RepairUtf8Mojibake(Result);
    Exit;
  end;
  if Obj.TryGetValue<string>('message', Result) then
  begin
    Result := RepairUtf8Mojibake(Result);
    Exit;
  end;
  Result := AFallback;
end;

function TApiClient.IsAuthEndpoint(const APath: string): Boolean;
begin
  Result := Copy(APath, 1, Length('/api/v1/auth/')) = '/api/v1/auth/';
end;

class function TApiClient.StreamToUtf8Bytes(AStream: TStream): TBytes;
begin
  SetLength(Result, 0);
  if (AStream = nil) or (AStream.Size = 0) then
    Exit;
  SetLength(Result, AStream.Size);
  AStream.Position := 0;
  AStream.ReadBuffer(Result[0], Length(Result));
end;

class function TApiClient.ParseUtf8Json(const ABytes: TBytes): TJSONValue;
var
  JsonText: string;
  Utf8: UTF8String;
begin
  Result := nil;
  if Length(ABytes) = 0 then
    Exit;
  // IsUTF8=True expects a UTF-8 BOM; API responses are UTF-8 without BOM.
  JsonText := TEncoding.UTF8.GetString(ABytes);
  Result := TJSONObject.ParseJSONValue(JsonText);
  if Result <> nil then
    Exit;
  SetString(Utf8, PAnsiChar(@ABytes[0]), Length(ABytes));
  Result := TJSONObject.ParseJSONValue(Utf8);
end;

function TApiClient.DoHttpRequest(const AMethod, APath: string; const ABody: string;
  const AContentType: string; out AStatus: Integer; AAllowRelogin: Boolean): TJSONValue;
var
  RequestStream, ResponseStream: TMemoryStream;
  BodyBytes, ResponseBytes: TBytes;
begin
  Result := nil;
  AStatus := 0;

  if AAllowRelogin and not IsAuthEndpoint(APath) and (FAccessToken <> '') and IsTokenExpired then
  begin
    FLastAuthFailure := True;
    FLastError := 'token_expired';
    if Assigned(FReloginHandler) and FReloginHandler then
      Exit(DoHttpRequest(AMethod, APath, ABody, AContentType, AStatus, False));
    AStatus := 401;
    Exit;
  end;

  ConfigureHttp;
  FHttp.Request.Accept := 'application/json';
  FHttp.Request.AcceptCharSet := 'utf-8';
  FHttp.Request.CustomHeaders.Clear;
  if FAccessToken <> '' then
    FHttp.Request.CustomHeaders.AddValue('Authorization', 'Bearer ' + FAccessToken);
  if AContentType <> '' then
  begin
    if SameText(AContentType, 'application/json') then
      FHttp.Request.ContentType := 'application/json; charset=utf-8'
    else
      FHttp.Request.ContentType := AContentType;
  end;

  RequestStream := TMemoryStream.Create;
  ResponseStream := TMemoryStream.Create;
  try
    if ABody <> '' then
    begin
      BodyBytes := TEncoding.UTF8.GetBytes(ABody);
      if Length(BodyBytes) > 0 then
        RequestStream.WriteBuffer(BodyBytes[0], Length(BodyBytes));
      RequestStream.Position := 0;
      FHttp.Request.ContentLength := Length(BodyBytes);
    end
    else
      FHttp.Request.ContentLength := 0;
    try
      if SameText(AMethod, 'GET') then
        FHttp.Get(BuildUrl(APath), ResponseStream)
      else if SameText(AMethod, 'POST') then
        FHttp.Post(BuildUrl(APath), RequestStream, ResponseStream)
      else if SameText(AMethod, 'PUT') then
        FHttp.Put(BuildUrl(APath), RequestStream, ResponseStream)
      else if SameText(AMethod, 'PATCH') then
        FHttp.Patch(BuildUrl(APath), RequestStream, ResponseStream)
      else if SameText(AMethod, 'DELETE') then
        FHttp.Delete(BuildUrl(APath), ResponseStream);
      AStatus := FHttp.ResponseCode;
      ResponseBytes := StreamToUtf8Bytes(ResponseStream);
      if Length(ResponseBytes) > 0 then
      begin
        Result := ParseUtf8Json(ResponseBytes);
        if Result = nil then
          FLastError := 'Ungültige JSON-Antwort vom Server.'
        else if AStatus >= 400 then
        begin
          FLastError := ReadApiError(Result, Format('HTTP %d', [AStatus]));
          FLastAuthFailure := AStatus = 401;
        end
        else
          FLastAuthFailure := False;
      end
      else if AStatus >= 400 then
      begin
        FLastError := Format('HTTP %d', [AStatus]);
        FLastAuthFailure := AStatus = 401;
      end
      else
        FLastAuthFailure := False;
    except
      on E: Exception do
      begin
        FLastError := E.Message;
        FLastAuthFailure := False;
        AStatus := FHttp.ResponseCode;
      end;
    end;
  finally
    ResponseStream.Free;
    RequestStream.Free;
  end;

  if AAllowRelogin and (AStatus = 401) and not IsAuthEndpoint(APath) and Assigned(FReloginHandler) then
  begin
    if FReloginHandler then
    begin
      if Result <> nil then
        Result.Free;
      Result := DoHttpRequest(AMethod, APath, ABody, AContentType, AStatus, False);
    end;
  end;
end;

function TApiClient.ApplyFromSettings(const ABaseUrl, AAccessToken: string;
  ATokenExpiresAt: TDateTime): Boolean;
begin
  SetBaseUrl(ABaseUrl);
  SetAccessToken(AAccessToken);
  SetTokenExpiresAt(ATokenExpiresAt);
  Result := not IsTokenExpired and ValidateSession(FLastError);
end;

function TApiClient.Login(const AEmail, APassword: string; out AError: string): Boolean;
var
  Body: TJSONObject;
  Doc: TJSONValue;
  Status: Integer;
  ExpiresStr: string;
begin
  Result := False;
  AError := '';
  Body := TJSONObject.Create;
  try
    Body.AddPair('email', AEmail);
    Body.AddPair('password', APassword);
    Doc := PostJson('/api/v1/auth/login', Body, Status);
    try
      if (Status <> 200) or not (Doc is TJSONObject) then
      begin
        AError := ReadApiError(Doc, 'Login fehlgeschlagen.');
        FLastError := AError;
        Exit;
      end;
      if not TJSONObject(Doc).TryGetValue<string>('accessToken', FAccessToken) or (FAccessToken = '') then
      begin
        AError := 'Server lieferte kein Token.';
        FLastError := AError;
        Exit;
      end;
      FTokenExpiresAt := 0;
      if TJSONObject(Doc).TryGetValue<string>('expiresAt', ExpiresStr) and (ExpiresStr <> '') then
        FTokenExpiresAt := IsoToDateTime(ExpiresStr);
      FLastAuthFailure := False;
      Result := True;
    finally
      Doc.Free;
    end;
  finally
    Body.Free;
  end;
end;

function TApiClient.ValidateSession(out AError: string): Boolean;
var
  Doc: TJSONValue;
  Status: Integer;
begin
  Result := False;
  AError := '';
  if FAccessToken = '' then
  begin
    AError := 'Kein Zugriffstoken.';
    FLastError := AError;
    Exit;
  end;
  if IsTokenExpired then
  begin
    AError := 'token_expired';
    FLastError := AError;
    FLastAuthFailure := True;
    Exit;
  end;
  Doc := Get('/api/v1/auth/me', Status);
  try
    if Status <> 200 then
    begin
      AError := ReadApiError(Doc, 'Sitzung ungültig.');
      FLastError := AError;
      FLastAuthFailure := Status = 401;
      Exit;
    end;
    FLastAuthFailure := False;
    Result := True;
  finally
    Doc.Free;
  end;
end;

function TApiClient.Get(const APath: string; out AStatus: Integer): TJSONValue;
begin
  Result := DoHttpRequest('GET', APath, '', '', AStatus, True);
end;

function TApiClient.PostJson(const APath: string; ABody: TJSONObject; out AStatus: Integer): TJSONValue;
begin
  Result := DoHttpRequest('POST', APath, ABody.ToJSON, 'application/json', AStatus, True);
end;

function TApiClient.PutJson(const APath: string; ABody: TJSONObject; out AStatus: Integer): TJSONValue;
begin
  Result := DoHttpRequest('PUT', APath, ABody.ToJSON, 'application/json', AStatus, True);
end;

function TApiClient.PatchJson(const APath: string; ABody: TJSONObject; out AStatus: Integer): TJSONValue;
begin
  Result := DoHttpRequest('PATCH', APath, ABody.ToJSON, 'application/json', AStatus, True);
end;

function TApiClient.Delete(const APath: string; out AStatus: Integer): Boolean;
var
  Doc: TJSONValue;
begin
  Doc := DoHttpRequest('DELETE', APath, '', '', AStatus, True);
  try
    Result := (AStatus >= 200) and (AStatus < 300);
  finally
    Doc.Free;
  end;
end;

function TApiClient.UploadFile(const APath, AFieldName, AFilePath: string;
  out AStatus: Integer): TJSONValue;
var
  Form: TIdMultipartFormDataStream;
  Doc: TJSONValue;
  ResponseBytes: TBytes;
  ResponseStream: TMemoryStream;
begin
  Result := nil;
  AStatus := 0;
  if not FileExists(AFilePath) then
  begin
    FLastError := 'Datei konnte nicht geöffnet werden: ' + AFilePath;
    Exit;
  end;

  ConfigureHttp;
  FHttp.Request.CustomHeaders.Clear;
  if FAccessToken <> '' then
    FHttp.Request.CustomHeaders.AddValue('Authorization', 'Bearer ' + FAccessToken);

  Form := TIdMultipartFormDataStream.Create;
  ResponseStream := TMemoryStream.Create;
  try
    Form.AddFile(AFieldName, AFilePath, 'application/xml');
    try
      FHttp.Post(BuildUrl(APath), Form, ResponseStream);
      AStatus := FHttp.ResponseCode;
      ResponseBytes := StreamToUtf8Bytes(ResponseStream);
      if Length(ResponseBytes) > 0 then
      begin
        Doc := ParseUtf8Json(ResponseBytes);
        if AStatus >= 400 then
        begin
          FLastError := ReadApiError(Doc, Format('HTTP %d', [AStatus]));
          FLastAuthFailure := AStatus = 401;
        end
        else
          FLastAuthFailure := False;
        Result := Doc;
      end
      else if AStatus >= 400 then
      begin
        FLastError := Format('HTTP %d', [AStatus]);
        FLastAuthFailure := AStatus = 401;
      end;
    except
      on E: Exception do
      begin
        FLastError := E.Message;
        AStatus := FHttp.ResponseCode;
      end;
    end;
  finally
    ResponseStream.Free;
    Form.Free;
  end;

  if (AStatus = 401) and not IsAuthEndpoint(APath) and Assigned(FReloginHandler) and FReloginHandler then
  begin
    if Result <> nil then
      Result.Free;
    Result := UploadFile(APath, AFieldName, AFilePath, AStatus);
  end;
end;

function TApiClient.GetLastError: string;
begin
  Result := FLastError;
end;

function TApiClient.GetLastAuthFailure: Boolean;
begin
  Result := FLastAuthFailure;
end;

end.
