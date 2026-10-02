unit Rag.Embeddings;

interface

uses System.SysUtils, System.Classes, System.JSON, System.Net.HttpClient,
  Rag.Vectors;

type
  IEmbeddingProvider = interface
    ['{E7A06443-8421-4DB8-A9D0-79C80C5E1D0F}']
    function GetModelIdentity: string;
    function EmbedDocument(const Text: string): TEmbedding;
    function EmbedQuery(const Text: string): TEmbedding;
    property ModelIdentity: string read GetModelIdentity;
  end;

  TOllamaEmbeddingProvider = class(TInterfacedObject, IEmbeddingProvider)
  private
    FClient: THTTPClient;
    FModel, FDigest, FIdentity: string;
    FDimension: Integer;
    function Request(const Path, Body: string): TJSONValue;
    function Embed(const PreparedText: string): TEmbedding;
  public
    constructor Create(const Model, Digest: string; Dimension: Integer);
    destructor Destroy; override;
    function GetModelIdentity: string;
    function EmbedDocument(const Text: string): TEmbedding;
    function EmbedQuery(const Text: string): TEmbedding;
  end;

implementation

const
  Endpoint = 'http://127.0.0.1:11434';

function TOllamaEmbeddingProvider.Request(const Path, Body: string): TJSONValue;
var
  Input: TStringStream;
  Output: TMemoryStream;
  Response: IHTTPResponse;
  Bytes: TBytes;
begin
  Output := TMemoryStream.Create;
  Input := TStringStream.Create(Body, TEncoding.UTF8);
  try
    if Body = '' then Response := FClient.Get(Endpoint + Path, Output)
    else Response := FClient.Post(Endpoint + Path, Input, Output);
    if Response.StatusCode <> 200 then
      raise EReadError.CreateFmt('Runtime de embeddings retornou HTTP %d', [Response.StatusCode]);
    if (Output.Size = 0) or (Output.Size > 4 * 1024 * 1024) then
      raise EReadError.Create('Tamanho de resposta inválido');
    SetLength(Bytes, Output.Size);
    Output.Position := 0;
    Output.ReadBuffer(Bytes[0], Length(Bytes));
    Result := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetString(Bytes));
    if Result = nil then raise EReadError.Create('JSON inválido');
  finally
    Input.Free;
    Output.Free;
  end;
end;

constructor TOllamaEmbeddingProvider.Create(const Model, Digest: string; Dimension: Integer);
var
  Json: TJSONValue;
  Models: TJSONArray;
  Item: TJSONValue;
  Found: Boolean;
begin
  inherited Create;
  if Model.Trim.IsEmpty or Digest.Trim.IsEmpty or (Dimension <= 0) or (Dimension > 65536) then
    raise EArgumentException.Create('Contrato de modelo inválido');
  FModel := Model;
  FDigest := Digest;
  FDimension := Dimension;
  FIdentity := Model + '@' + Digest + '|retrieval-prefix-v1|dim=' + IntToStr(Dimension);
  FClient := THTTPClient.Create;
  FClient.ConnectionTimeout := 5000;
  FClient.ResponseTimeout := 60000;
  FClient.HandleRedirects := False;
  FClient.ContentType := 'application/json';
  Json := Request('/api/tags', '');
  try
    if not (Json is TJSONObject) or not (Json.FindValue('models') is TJSONArray) then
      raise EReadError.Create('Lista de modelos inválida');
    Models := Json.FindValue('models') as TJSONArray;
    Found := False;
    for Item in Models do
      if (Item.FindValue('name') <> nil) and (Item.FindValue('digest') <> nil) and
        (Item.FindValue('name').Value = Model) and (Item.FindValue('digest').Value = Digest) then Found := True;
    if not Found then raise EReadError.Create('Modelo ou digest diferente do contrato');
  finally Json.Free; end;
end;

destructor TOllamaEmbeddingProvider.Destroy;
begin
  FClient.Free;
  inherited;
end;

function TOllamaEmbeddingProvider.GetModelIdentity: string;
begin
  Result := FIdentity;
end;

function TOllamaEmbeddingProvider.Embed(const PreparedText: string): TEmbedding;
var
  Body: TJSONObject;
  Json: TJSONValue;
  Arrays, Values: TJSONArray;
  I: Integer;
begin
  Body := TJSONObject.Create;
  try
    Body.AddPair('model', FModel);
    Body.AddPair('input', PreparedText);
    Body.AddPair('truncate', TJSONBool.Create(False));
    Json := Request('/api/embed', Body.ToJSON);
    try
      if not (Json is TJSONObject) or not (Json.FindValue('embeddings') is TJSONArray) then
        raise EReadError.Create('Resposta de embeddings inválida');
      Arrays := Json.FindValue('embeddings') as TJSONArray;
      if (Arrays.Count <> 1) or not (Arrays.Items[0] is TJSONArray) then
        raise EReadError.Create('Quantidade de vetores inválida');
      Values := Arrays.Items[0] as TJSONArray;
      if Values.Count <> FDimension then raise EReadError.Create('Dimensão inesperada');
      SetLength(Result, Values.Count);
      for I := 0 to Values.Count - 1 do
      begin
        if not (Values.Items[I] is TJSONNumber) then raise EReadError.Create('Componente não numérico');
        Result[I] := (Values.Items[I] as TJSONNumber).AsDouble;
      end;
      NormalizeEmbedding(Result);
    finally Json.Free; end;
  finally Body.Free; end;
end;

function TOllamaEmbeddingProvider.EmbedDocument(const Text: string): TEmbedding;
begin
  if Text.Trim.IsEmpty then raise EArgumentException.Create('Documento vazio');
  Result := Embed('title: none | text: ' + Text);
end;

function TOllamaEmbeddingProvider.EmbedQuery(const Text: string): TEmbedding;
begin
  if Text.Trim.IsEmpty then raise EArgumentException.Create('Consulta vazia');
  Result := Embed('task: search result | query: ' + Text);
end;

end.
