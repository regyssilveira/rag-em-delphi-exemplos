unit Rag.Generation.Gemini;

interface

uses System.SysUtils, Rag.Generation, Rag.Context, Rag.Answers;

type
  TGeminiAnswerProvider = class(TInterfacedObject, IAnswerProvider)
  private
    FApiKey, FModel, FActualModel, FLastResponse: string;
  public
    constructor Create(const ApiKey, Model: string);
    function Generate(const Question: string;
      const Context: TPreparedContext): TValidatedAnswer;
    function GetModelIdentity: string;
    function GetLastResponse: string;
    class function BuildRequest(const Question: string;
      const Context: TPreparedContext): string; static;
    class function DecodeResponse(const Payload: string;
      const Context: TPreparedContext;
      out ActualModel: string): TValidatedAnswer; static;
  end;

implementation

uses System.JSON, System.Classes, System.Net.HttpClient;

constructor TGeminiAnswerProvider.Create(const ApiKey, Model: string);
var C: Char;
begin
  inherited Create;
  if ApiKey.Trim.IsEmpty or ApiKey.Contains(#13) or ApiKey.Contains(#10) then
    raise EArgumentException.Create('Configure GEMINI_API_KEY localmente');
  if Model.IsEmpty or (Length(Model) > 100) then
    raise EArgumentException.Create('Configure RAG_GENERATION_MODEL');
  for C in Model do
    if not CharInSet(C, ['a'..'z', 'A'..'Z', '0'..'9', '-', '_', '.']) then
      raise EArgumentException.Create('Identificador de modelo inválido');
  FApiKey := ApiKey;
  FModel := Model;
end;

function TGeminiAnswerProvider.GetModelIdentity: string;
begin
  Result := 'gemini/' + FModel + '|answer-prompt-remote-v2';
  if FActualModel <> '' then Result := Result + '|actual=' + FActualModel;
end;

function TGeminiAnswerProvider.GetLastResponse: string;
begin
  Result := FLastResponse;
end;

class function TGeminiAnswerProvider.BuildRequest(const Question: string;
  const Context: TPreparedContext): string;
var Request, Input: TJSONObject; ContextValue: TJSONValue;
begin
  if Question.Trim.IsEmpty or (Length(Question) > 1000) or
    (Length(Context.Serialized) > 6000) then
    raise EArgumentException.Create('Entrada de geração fora dos limites');
  ContextValue := TJSONObject.ParseJSONValue(Context.Serialized);
  if not (ContextValue is TJSONObject) then
  begin
    ContextValue.Free;
    raise EArgumentException.Create('Contexto JSON inválido');
  end;
  Input := TJSONObject.Create;
  try
    Input.AddPair('question', Question);
    Input.AddPair('context', ContextValue);
    Request := TJSONObject.Create;
    try
      Request.AddPair('systemInstruction', TJSONObject.Create.AddPair('parts',
        TJSONArray.Create(TJSONObject.Create.AddPair('text', AnswerInstructions))));
      Request.AddPair('contents', TJSONArray.Create(
        TJSONObject.Create.AddPair('role', 'user').AddPair('parts',
          TJSONArray.Create(TJSONObject.Create.AddPair('text', Input.ToJSON)))));
      Request.AddPair('generationConfig', TJSONObject.Create
        .AddPair('temperature', TJSONNumber.Create(0))
        .AddPair('candidateCount', TJSONNumber.Create(1))
        .AddPair('maxOutputTokens', TJSONNumber.Create(4096))
        .AddPair('responseMimeType', 'application/json'));
      Result := Request.ToJSON;
    finally Request.Free; end;
  finally Input.Free; end;
end;

class function TGeminiAnswerProvider.DecodeResponse(const Payload: string;
  const Context: TPreparedContext; out ActualModel: string): TValidatedAnswer;
var Root, Candidates, Candidate, Parts, Part, Value: TJSONValue;
  AnswerText: string;
begin
  ActualModel := '';
  if Length(Payload) > 1048576 then
    raise EArgumentException.Create('Resposta excessiva');
  Root := TJSONObject.ParseJSONValue(Payload);
  try
    if not (Root is TJSONObject) then
      raise EArgumentException.Create('Envelope remoto inválido');
    if Root.FindValue('error') <> nil then
      raise EArgumentException.Create('Erro informado pelo provedor');
    Value := Root.FindValue('promptFeedback.blockReason');
    if Value <> nil then
      raise EArgumentException.Create('Solicitação bloqueada pelo provedor');
    Value := Root.FindValue('modelVersion');
    if not (Value is TJSONString) or Value.Value.Trim.IsEmpty then
      raise EArgumentException.Create('Versão efetiva do modelo ausente');
    ActualModel := Value.Value;
    Candidates := Root.FindValue('candidates');
    if not (Candidates is TJSONArray) or (TJSONArray(Candidates).Count <> 1) then
      raise EArgumentException.Create('Candidato remoto ausente ou ambíguo');
    Candidate := TJSONArray(Candidates).Items[0];
    Value := Candidate.FindValue('finishReason');
    if not (Value is TJSONString) or (Value.Value <> 'STOP') then
      raise EArgumentException.Create('Geração remota incompleta ou bloqueada');
    Parts := Candidate.FindValue('content.parts');
    if not (Parts is TJSONArray) or (TJSONArray(Parts).Count = 0) then
      raise EArgumentException.Create('Conteúdo remoto ausente');
    AnswerText := '';
    for Part in TJSONArray(Parts) do
    begin
      Value := Part.FindValue('thought');
      if Value <> nil then
      begin
        if not (Value is TJSONBool) then
          raise EArgumentException.Create('Marcador de raciocínio inválido');
        if TJSONBool(Value).AsBoolean then Continue;
      end;
      Value := Part.FindValue('text');
      if not (Value is TJSONString) then
        raise EArgumentException.Create('Parte remota não textual');
      AnswerText := AnswerText + Value.Value;
    end;
    Result := ParseAnswer(AnswerText, Context);
  finally Root.Free; end;
end;

function TGeminiAnswerProvider.Generate(const Question: string;
  const Context: TPreparedContext): TValidatedAnswer;
var Http: THTTPClient; Body: TStringStream; Response: IHTTPResponse;
  RequestText: string;
begin
  FLastResponse := '';
  FActualModel := '';
  RequestText := BuildRequest(Question, Context);
  if Length(Context.Sources) = 0 then Exit(Default(TValidatedAnswer));
  Http := THTTPClient.Create;
  try
    Http.ConnectionTimeout := 10000;
    Http.ResponseTimeout := 120000;
    Http.HandleRedirects := False;
    Http.ContentType := 'application/json';
    Http.CustomHeaders['x-goog-api-key'] := FApiKey;
    Body := TStringStream.Create(RequestText, TEncoding.UTF8);
    try
      try
        Response := Http.Post('https://generativelanguage.googleapis.com/v1beta/models/' +
          FModel + ':generateContent', Body);
      except
        on E: Exception do
          raise EAnswerTransportError.Create('Falha de conexão remota ou tempo limite');
      end;
    finally Body.Free; end;
    FLastResponse := Response.ContentAsString(TEncoding.UTF8).Replace(FApiKey, '[REDACTED]');
    if Length(FLastResponse) > 1048576 then
    begin
      FLastResponse := '';
      raise EAnswerTransportError.Create('Resposta remota excessiva');
    end;
    if Response.StatusCode <> 200 then
      raise EAnswerTransportError.CreateFmt('Geração remota: HTTP %d (sem repetição automática)',
        [Response.StatusCode]);
    Result := DecodeResponse(FLastResponse, Context, FActualModel);
  finally Http.Free; end;
end;

end.
