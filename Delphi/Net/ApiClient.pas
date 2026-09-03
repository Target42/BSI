unit ApiClient;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.DateUtils,
  IdHTTP, IdSSLOpenSSL, IdIOHandlerStack, IdMultipartFormData, IdGlobal,
  IsmsDomain, HttpJson;

type
  TReloginHandler = reference to function: Boolean;

  TApiClient = class
  private
    FHttp: TIdHTTP;
    FStack: TIdIOHandlerStack;
    FSsl: TIdSSLIOHandlerSocketOpenSSL;
    FBaseUrl: string;
    FAccessToken: string;
    FTokenExpiresAt: TDateTime;
    FInsecureSkipTls: Boolean;
    FReloginHandler: TReloginHandler;
    FLastError: string;
    FLastAuthFailure: Boolean;
    FBaseUrlResolved: Boolean;
    function DoHttpRequest(const AMethod, APath: string; const ABody: string;
      const AContentType: string; out AStatus: Integer; AAllowRelogin: Boolean): TJSONValue;
    function BuildUrl(const APath: string): string;
    class function ReadApiError(ADoc: TJSONValue; const AFallback: string): string; static;
    function IsAuthEndpoint(const APath: string): Boolean;
    procedure ConfigureHttp;
    class function StreamToUtf8Bytes(AStream: TStream): TBytes; static;
    class function ParseUtf8Json(const ABytes: TBytes): TJSONValue; static;
    class function NormalizeBaseUrl(const AValue: string): string; static;
    class function EndsWithPath(const AUrl, APath: string): Boolean; static;
    class function BaseUrlFromHealthUrl(const AUrl: string): string; static;
    class function UrlHost(const AUrl: string): string; static;
    class function IsLoopbackHost(const AHost: string): Boolean; static;
    class function UrlHostIsIPv6(const AUrl: string): Boolean; static;
    class function ReplaceUrlHost(const AUrl, ANewHost: string): string; static;
    class function LoopbackAlternatives(const ABase: string): TArray<string>; static;
    procedure DisconnectHttp;
    procedure ApplyIpVersionForUrl(const AUrl: string);
    procedure ResolvePublicBaseUrlIfNeeded;
    function TryResolveBase(const ABase: string; out AResolved: string): Boolean;
    function IsmsReachableAt(const ABase: string; out AResolvedBase: string;
      out AUnreachable: Boolean): Boolean;
    function RawGet(const AUrl: string; out AStatus: Integer; out ABytes: TBytes): Boolean;
    function ProbeHealth(const ABase: string; out AResolvedBase: string;
      out AUnreachable: Boolean): Boolean;
    function ProbeApiRoot(const ABase: string; out AUnreachable: Boolean): Boolean;
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

uses
  IdURI, IdStack;

type
  TIdHTTPAccess = class(TIdHTTP);

const
  kExpirySkewSeconds = 60;
  kDefaultReadTimeoutMs = 30000;
  kUploadReadTimeoutMs = 15 * 60 * 1000;
  kProxyPrefixes: array[0..0] of string = ('/isms');

constructor TApiClient.Create(const ABaseUrl: string);
begin
  inherited Create;
  GIdDefaultTextEncoding := encUTF8;
  FHttp := TIdHTTP.Create(nil);
  FHttp.HandleRedirects := True;
  FHttp.ReadTimeout := kDefaultReadTimeoutMs;
  FHttp.ConnectTimeout := 15000;
  FHttp.HTTPOptions := [hoForceEncodeParams, hoNoProtocolErrorException, hoWantProtocolErrorContent];
  FStack := TIdIOHandlerStack.Create(FHttp);
  FHttp.IOHandler := FStack;
  SetBaseUrl(ABaseUrl);
end;

destructor TApiClient.Destroy;
begin
  FSsl.Free;
  FHttp.Free;
  inherited;
end;

class function TApiClient.NormalizeBaseUrl(const AValue: string): string;
var
  ApiPos: Integer;
begin
  Result := Trim(AValue);
  while (Result <> '') and (Copy(Result, Length(Result), 1) = '/') do
    SetLength(Result, Length(Result) - 1);
  ApiPos := Pos('/api/v1', LowerCase(Result));
  if ApiPos > 0 then
    Result := Copy(Result, 1, ApiPos - 1);
  while (Result <> '') and (Copy(Result, Length(Result), 1) = '/') do
    SetLength(Result, Length(Result) - 1);
end;

class function TApiClient.EndsWithPath(const AUrl, APath: string): Boolean;
begin
  Result := (APath <> '') and (Length(AUrl) >= Length(APath)) and
    SameText(Copy(AUrl, Length(AUrl) - Length(APath) + 1, Length(APath)), APath);
end;

class function TApiClient.BaseUrlFromHealthUrl(const AUrl: string): string;
begin
  Result := NormalizeBaseUrl(AUrl);
  if EndsWithPath(Result, '/health') then
    SetLength(Result, Length(Result) - Length('/health'));
  Result := NormalizeBaseUrl(Result);
end;

procedure TApiClient.SetBaseUrl(const AValue: string);
begin
  FBaseUrl := NormalizeBaseUrl(AValue);
  FBaseUrlResolved := False;
end;

class function TApiClient.UrlHost(const AUrl: string): string;
var
  URI: TIdURI;
begin
  URI := TIdURI.Create(AUrl);
  try
    Result := URI.Host;
  finally
    URI.Free;
  end;
end;

class function TApiClient.IsLoopbackHost(const AHost: string): Boolean;
var
  Host: string;
begin
  Host := Trim(AHost);
  if (Host <> '') and (Host[1] = '[') and (Host[Length(Host)] = ']') then
    Host := Copy(Host, 2, Length(Host) - 2);
  Result := SameText(Host, 'localhost') or SameText(Host, '127.0.0.1') or SameText(Host, '::1');
end;

class function TApiClient.UrlHostIsIPv6(const AUrl: string): Boolean;
var
  Host: string;
begin
  Host := UrlHost(AUrl);
  if (Host <> '') and (Host[1] = '[') and (Host[Length(Host)] = ']') then
    Host := Copy(Host, 2, Length(Host) - 2);
  Result := Pos(':', Host) > 0;
end;

class function TApiClient.ReplaceUrlHost(const AUrl, ANewHost: string): string;
var
  URI: TIdURI;
  Host, Port, Path: string;
begin
  URI := TIdURI.Create(AUrl);
  try
    if Pos(':', ANewHost) > 0 then
      Host := '[' + ANewHost + ']'
    else
      Host := ANewHost;
    if URI.Port <> '' then
      Port := ':' + URI.Port
    else
      Port := '';
    Path := URI.Path + URI.Params;
    if (Path = '/') or (Path = '') then
      Path := '';
    Result := NormalizeBaseUrl(URI.Protocol + '://' + Host + Port + Path);
  finally
    URI.Free;
  end;
end;

class function TApiClient.LoopbackAlternatives(const ABase: string): TArray<string>;
var
  Current, Candidate: string;
  Hosts: array[0..1] of string;
  I: Integer;
begin
  SetLength(Result, 0);
  if not IsLoopbackHost(UrlHost(ABase)) then
    Exit;
  Current := NormalizeBaseUrl(ABase);
  // Indy defaults to IPv4. On Windows another listener (often Apache) can own
  // 127.0.0.1:8080 while ISMS is only reachable on [::1].
  Hosts[0] := '::1';
  Hosts[1] := '127.0.0.1';
  for I := Low(Hosts) to High(Hosts) do
  begin
    Candidate := ReplaceUrlHost(ABase, Hosts[I]);
    if (Candidate <> '') and not SameText(Candidate, Current) then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Candidate;
    end;
  end;
end;

procedure TApiClient.DisconnectHttp;
begin
  try
    if FHttp.Connected then
      FHttp.Disconnect;
  except
  end;
end;

procedure TApiClient.ApplyIpVersionForUrl(const AUrl: string);
var
  Version: TIdIPVersion;
  UseSsl: Boolean;
begin
  if UrlHostIsIPv6(AUrl) then
    Version := Id_IPv6
  else
    Version := Id_IPv4;
  DisconnectHttp;
  TIdHTTPAccess(FHttp).IPVersion := Version;
  UseSsl := FInsecureSkipTls and SameText(Copy(AUrl, 1, 8), 'https://');
  if UseSsl then
  begin
    if FSsl = nil then
    begin
      FSsl := TIdSSLIOHandlerSocketOpenSSL.Create(FHttp);
      FSsl.SSLOptions.VerifyMode := [];
      FSsl.SSLOptions.VerifyDepth := 0;
    end;
    FSsl.IPVersion := Version;
    FHttp.IOHandler := FSsl;
  end
  else
  begin
    FStack.IPVersion := Version;
    FHttp.IOHandler := FStack;
  end;
end;

function TApiClient.RawGet(const AUrl: string; out AStatus: Integer; out ABytes: TBytes): Boolean;
var
  ResponseStream: TMemoryStream;
begin
  Result := False;
  AStatus := 0;
  SetLength(ABytes, 0);
  ApplyIpVersionForUrl(AUrl);
  FHttp.Request.CustomHeaders.Clear;
  FHttp.Request.Accept := 'application/json';
  FHttp.Request.ContentType := '';
  FHttp.Request.ContentLength := 0;
  ResponseStream := TMemoryStream.Create;
  try
    try
      FHttp.Get(AUrl, ResponseStream);
      AStatus := FHttp.ResponseCode;
      ABytes := StreamToUtf8Bytes(ResponseStream);
      Result := True;
    except
      on E: EIdSocketError do
      begin
        FLastError := E.Message;
        DisconnectHttp;
      end;
      on E: Exception do
      begin
        FLastError := E.Message;
        AStatus := FHttp.ResponseCode;
        DisconnectHttp;
      end;
    end;
  finally
    ResponseStream.Free;
  end;
end;

function TApiClient.ProbeHealth(const ABase: string; out AResolvedBase: string;
  out AUnreachable: Boolean): Boolean;
var
  Status: Integer;
  Bytes: TBytes;
  Doc: TJSONValue;
  StatusValue: string;
  FinalUrl: string;
begin
  Result := False;
  AUnreachable := False;
  AResolvedBase := ABase;
  if not RawGet(ABase + '/health', Status, Bytes) then
  begin
    AUnreachable := True;
    Exit;
  end;
  if Status <> 200 then
    Exit;
  Doc := ParseUtf8Json(Bytes);
  try
    if not (Doc is TJSONObject) then
      Exit;
    if not TJSONObject(Doc).TryGetValue<string>('status', StatusValue) then
      Exit;
    if not SameText(StatusValue, 'ok') then
      Exit;
  finally
    Doc.Free;
  end;
  try
    FinalUrl := FHttp.URL.GetFullURI([]);
  except
    FinalUrl := ABase + '/health';
  end;
  AResolvedBase := BaseUrlFromHealthUrl(FinalUrl);
  if AResolvedBase = '' then
    AResolvedBase := ABase;
  Result := True;
end;

function TApiClient.ProbeApiRoot(const ABase: string; out AUnreachable: Boolean): Boolean;
var
  Status: Integer;
  Bytes: TBytes;
begin
  Result := False;
  AUnreachable := False;
  if not RawGet(ABase + '/api/v1/auth/login', Status, Bytes) then
  begin
    AUnreachable := True;
    Exit;
  end;
  // POST-only login: Chi answers GET with 405. nginx without the location yields 404.
  Result := (Status = 400) or (Status = 401) or (Status = 405) or (Status = 415) or
    (Status = 422);
end;

function TApiClient.IsmsReachableAt(const ABase: string; out AResolvedBase: string;
  out AUnreachable: Boolean): Boolean;
begin
  AResolvedBase := ABase;
  if ProbeHealth(ABase, AResolvedBase, AUnreachable) then
    Exit(True);
  if AUnreachable then
    Exit(False);
  Result := ProbeApiRoot(ABase, AUnreachable);
  if Result then
    AResolvedBase := ABase;
end;

function TApiClient.TryResolveBase(const ABase: string; out AResolved: string): Boolean;
var
  Unreachable: Boolean;
  Prefix: string;
  Candidate: string;
begin
  Result := False;
  if IsmsReachableAt(ABase, AResolved, Unreachable) then
    Exit(True);
  if Unreachable then
    Exit;
  for Prefix in kProxyPrefixes do
  begin
    if EndsWithPath(ABase, Prefix) then
      Continue;
    Candidate := ABase + Prefix;
    if IsmsReachableAt(Candidate, AResolved, Unreachable) then
      Exit(True);
    if Unreachable then
      Exit;
  end;
end;

procedure TApiClient.ResolvePublicBaseUrlIfNeeded;
var
  Resolved: string;
  Alt: string;
begin
  if FBaseUrlResolved then
    Exit;
  FBaseUrlResolved := True;
  if Trim(FBaseUrl) = '' then
    Exit;

  // Indy uses IPv4 for "localhost". On this machine Apache owns 127.0.0.1:8080
  // and ISMS answers on [::1]:8080 — try the IPv6 loopback first.
  if IsLoopbackHost(UrlHost(FBaseUrl)) and not UrlHostIsIPv6(FBaseUrl) then
    for Alt in LoopbackAlternatives(FBaseUrl) do
      if TryResolveBase(Alt, Resolved) then
      begin
        FBaseUrl := Resolved;
        Exit;
      end;

  if TryResolveBase(FBaseUrl, Resolved) then
    FBaseUrl := Resolved;
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
  ApplyIpVersionForUrl(FBaseUrl);
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

  if Trim(FBaseUrl) = '' then
  begin
    FLastError := 'Keine Server-URL konfiguriert.';
    Exit;
  end;

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
  ResolvePublicBaseUrlIfNeeded;
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
        AError := ReadApiError(Doc, '');
        if AError = '' then
        begin
          if Status = 404 then
            AError := 'Kein ISMS-Server unter dieser URL (HTTP 404).'
          else if FLastError <> '' then
            AError := FLastError
          else if Status > 0 then
            AError := Format('Login fehlgeschlagen (HTTP %d).', [Status])
          else
            AError := 'Login fehlgeschlagen. Server nicht erreichbar.';
        end;
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
  PreviousTimeout: Integer;
begin
  Result := nil;
  AStatus := 0;
  if not FileExists(AFilePath) then
  begin
    FLastError := 'Datei konnte nicht geöffnet werden: ' + AFilePath;
    Exit;
  end;

  ConfigureHttp;
  ResolvePublicBaseUrlIfNeeded;
  FHttp.Request.CustomHeaders.Clear;
  if FAccessToken <> '' then
    FHttp.Request.CustomHeaders.AddValue('Authorization', 'Bearer ' + FAccessToken);

  PreviousTimeout := FHttp.ReadTimeout;
  FHttp.ReadTimeout := kUploadReadTimeoutMs;
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
        AStatus := 0;
        try
          FHttp.Disconnect;
        except
        end;
      end;
    end;
  finally
    FHttp.ReadTimeout := PreviousTimeout;
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
