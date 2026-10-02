program AssistantTests;

{$APPTYPE CONSOLE}

uses System.SysUtils, Rag.Types, Rag.Persistence, Rag.Embeddings,
  Rag.Generation, Rag.Vectors, Rag.Context, Rag.Answers, Rag.Assistant;

type
  TFakeEmbedding = class(TInterfacedObject, IEmbeddingProvider)
    function GetModelIdentity: string;
    function EmbedDocument(const Text: string): TEmbedding;
    function EmbedQuery(const Text: string): TEmbedding;
  end;
  TFakeAnswer = class(TInterfacedObject, IAnswerProvider)
    function Generate(const Question: string; const Context: TPreparedContext): TValidatedAnswer;
    function GetModelIdentity: string;
    function GetLastResponse: string;
  end;

var EmbeddedCalls, GeneratedCalls: Integer;

function TFakeEmbedding.GetModelIdentity: string;
begin Result := 'SYNTHETIC-FOR-ORCHESTRATION'; end;
function TFakeEmbedding.EmbedDocument(const Text: string): TEmbedding;
begin Inc(EmbeddedCalls); Result := [1.0, 0.0]; end;
function TFakeEmbedding.EmbedQuery(const Text: string): TEmbedding;
begin Inc(EmbeddedCalls); Result := [1.0, 0.0]; end;
function TFakeAnswer.GetModelIdentity: string;
begin Result := 'FAKE-ANSWER-FOR-ORCHESTRATION'; end;
function TFakeAnswer.GetLastResponse: string;
begin Result := ''; end;
function TFakeAnswer.Generate(const Question: string; const Context: TPreparedContext): TValidatedAnswer;
begin
  Inc(GeneratedCalls);
  Result := Default(TValidatedAnswer);
  Result.HasAnswer := Length(Context.Sources) > 0;
  if Result.HasAnswer then
  begin
    SetLength(Result.Claims, 1);
    Result.Claims[0].Text := Context.Sources[0].Chunk.Text;
    SetLength(Result.Claims[0].Evidence, 1);
    Result.Claims[0].Evidence[0].Source := Context.Sources[0];
    Result.Claims[0].Evidence[0].Quote := Context.Sources[0].Chunk.Text;
  end;
end;

procedure Check(Value: Boolean; const Name: string);
begin
  if not Value then raise Exception.Create('FALHOU: ' + Name);
  Writeln('OK: ', Name);
end;

var
  Base: TPreparedBase;
  Documents: TArray<TDocument>;
  Embeddings: IEmbeddingProvider;
  Generator: IAnswerProvider;
  Stats: TUpdateStats;
  Response: TAssistantResponse;
  Failed: Boolean;
begin
  try
    Embeddings := TFakeEmbedding.Create;
    Generator := TFakeAnswer.Create;
    SetLength(Documents, 1);
    Documents[0].Id := 'EST';
    Documents[0].Source := 'estoque';
    Documents[0].Access := 'supervisor';
    Documents[0].Text := 'O supervisor aprova o ajuste após conferir a contagem.';
    Base := PrepareBase(Documents, Default(TPreparedBase), Embeddings, 2, 200, 20, Stats);
    EmbeddedCalls := 0;
    GeneratedCalls := 0;
    Response := QueryPreparedBase(Base, 'Quem aprova o ajuste?', 'operacional', nil, nil);
    Check(not Response.Answer.HasAnswer and (Length(Response.Context.Sources) = 0) and
      (EmbeddedCalls = 0) and (GeneratedCalls = 0), 'coleção sem acesso não chama modelos');
    Response := QueryPreparedBase(Base, 'Quem aprova o ajuste?', 'supervisor', Embeddings, Generator);
    Check((EmbeddedCalls = 1) and (GeneratedCalls = 1) and
      (Response.Context.Sources[0].Chunk.DocumentId = 'EST'), 'coordenação preserva origem e chama provedores');
    Failed := False;
    try QueryPreparedBase(Base, 'Quem aprova?', 'visitante', Embeddings, Generator);
    except on E: EArgumentException do Failed := True; end;
    Check(Failed, 'perfil desconhecido recusado');
    Failed := False;
    try QueryPreparedBase(Base, ' ', 'supervisor', Embeddings, Generator);
    except on E: EArgumentException do Failed := True; end;
    Check(Failed, 'pergunta vazia recusada');
    Base.ModelIdentity := 'OTHER-SYNTHETIC-MODEL';
    Failed := False;
    try QueryPreparedBase(Base, 'Quem aprova?', 'supervisor', Embeddings, Generator);
    except on E: EArgumentException do Failed := True; end;
    Check(Failed and (EmbeddedCalls = 1) and (GeneratedCalls = 1), 'modelo incompatível recusado antes de chamadas');
  except on E: Exception do begin Writeln(E.Message); ExitCode := 1; end; end;
end.
