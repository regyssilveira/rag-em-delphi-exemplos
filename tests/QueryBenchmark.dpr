program QueryBenchmark;
{$APPTYPE CONSOLE}

uses System.SysUtils, System.IOUtils, System.JSON,
  System.Diagnostics,
  Rag.Vectors, Rag.Embeddings, Rag.Generation,
    Rag.Persistence,
  Rag.Assistant, Rag.Context, Rag.Answers,
    Rag.Presentation;

type

  TTimedEmbedding = class(TInterfacedObject,
    IEmbeddingProvider)
  private
    FInner: IEmbeddingProvider;
  public
    ElapsedMs: Double;
    Calls: Integer;
    constructor Create(const Inner:
      IEmbeddingProvider);
    function GetModelIdentity: string;
    function EmbedDocument(const Text: string):
      TEmbedding;
    function EmbedQuery(const Text: string):
      TEmbedding;
  end;

  TTimedAnswer = class(TInterfacedObject,
    IAnswerProvider)
  private
    FInner: IAnswerProvider;
  public
    ElapsedMs: Double;
    Calls: Integer;
    constructor Create(const Inner: IAnswerProvider)
      ;
    function GetModelIdentity: string;
    function GetLastResponse: string;
    function Generate(const Question: string;
      const Context: TPreparedContext):
        TValidatedAnswer;
  end;

constructor TTimedEmbedding.Create(const Inner:
  IEmbeddingProvider);
begin

  inherited Create;
  if Inner = nil then raise
    EArgumentException.Create('Provedor ausente');
  FInner := Inner;
end;

function TTimedEmbedding.GetModelIdentity: string;
begin Result := FInner.ModelIdentity; end;

function TTimedEmbedding.EmbedDocument(const Text:
  string): TEmbedding;
begin

  raise EInvalidOpException.Create(
    'Medição de consulta não ' +
    'prepara documentos');
end;

function TTimedEmbedding.EmbedQuery(const Text:
  string): TEmbedding;
var Watch: TStopwatch;
begin

  Inc(Calls);
  Watch := TStopwatch.StartNew;
  try Result := FInner.EmbedQuery(Text);
  finally ElapsedMs := ElapsedMs +
    Watch.Elapsed.TotalMilliseconds; end;
end;

constructor TTimedAnswer.Create(const Inner:
  IAnswerProvider);
begin

  inherited Create;
  if Inner = nil then raise
    EArgumentException.Create('Provedor ausente');
  FInner := Inner;
end;

function TTimedAnswer.GetModelIdentity: string;
begin Result := FInner.ModelIdentity; end;

function TTimedAnswer.GetLastResponse: string;
begin Result := FInner.LastResponse; end;

function TTimedAnswer.Generate(const Question:
  string;
  const Context: TPreparedContext): TValidatedAnswer
    ;
var Watch: TStopwatch;
begin

  Inc(Calls);
  Watch := TStopwatch.StartNew;
  try Result := FInner.Generate(Question, Context);
  finally ElapsedMs := ElapsedMs +
    Watch.Elapsed.TotalMilliseconds; end;
end;

const
  Model = 'embeddinggemma:300m';
  Digest = '85462619ee721b466c5927d109' +
    'd4cb765861907d5417b9109cae' + 'bc4e614679f1';
  Questions: array[0..1] of string = (
    'Quem pode liberar um ' + 'recebimento com ' +
      'divergência?',
    'Qual é a comissão do vendedor?');

var

  Report, Row: TJSONObject;
  Rows: TJSONArray;
  Embeddings: IEmbeddingProvider;
  Generator: IAnswerProvider;
  TimedEmbedding: TTimedEmbedding;
  TimedAnswer: TTimedAnswer;
  Base: TPreparedBase;
  Response: TAssistantResponse;
  WholeWatch, Watch: TStopwatch;
  ProviderMs, ReopenMs, QueryMs, PresentationMs:
    Double;
  Round, QuestionIndex, Repeats, Failed: Integer;
  Stage, DisplayText: string;
  Claim: TAnswerClaim;
  Evidence: TAnswerEvidence;
  FoundClaim, FoundEvidence, MinimumCheck: Boolean;
begin

  try

    if ParamCount <> 3 then
      raise EArgumentException.Create(
        'Use QueryBenchmark.exe ' +
        'base.json relatório.json ' + 'repetições');
    if not TryStrToInt(ParamStr(3), Repeats) or (
      Repeats < 1) or (Repeats > 5) then
      raise EArgumentException.Create(
        'Repetições devem estar ' + 'entre 1 e 5');
    if SameFileName(TPath.GetFullPath(ParamStr(1)),
      TPath.GetFullPath(ParamStr(2))) then
      raise EArgumentException.Create(
        'Relatório não pode ' + 'substituir a base')
        ;
    Report := TJSONObject.Create;
    try

      Report.AddPair('scope',
        'Consulta síncrona pelo ' +
        'mesmo QueryPreparedBase ' +
        'da VCL. Inclui criação de ' +
        'provedores, reabertura, ' +
        'consulta e formatação ' +
        'textual; exclui ' +
        'preparação de documentos, ' +
        'fila/eventos/desenho da ' +
        'VCL, gravação do ' +
        'relatório e liberação dos ' +
        'provedores. Tempos não ' +
        'são requisitos mínimos ou ' +
        'garantia de qualidade.');
      Report.AddPair('repetitions',
        TJSONNumber.Create(Repeats));
      Report.AddPair('profile', 'operacional');
      Report.AddPair('warmupPerformed',
        TJSONBool.Create(False));
      Rows := TJSONArray.Create;
      Report.AddPair('measurements', Rows);
      Failed := 0;
      for Round := 1 to Repeats do
        for QuestionIndex := 0 to High(Questions) do
        begin

          Row := TJSONObject.Create;
          Rows.AddElement(Row);
          Row.AddPair('round', TJSONNumber.Create(
            Round));
          Row.AddPair('questionIndex',
            TJSONNumber.Create(QuestionIndex));
          Row.AddPair('question', Questions[
            QuestionIndex]);
          Row.AddPair('expectedAnswer',
            TJSONBool.Create(QuestionIndex = 0));
          Embeddings := nil;
          Generator := nil;
          TimedEmbedding := nil;
          TimedAnswer := nil;
          WholeWatch := TStopwatch.StartNew;
          Stage := 'providers';
          try

            Watch := TStopwatch.StartNew;
            TimedEmbedding := TTimedEmbedding.Create
            (
              TOllamaEmbeddingProvider.Create(Model,
            Digest, 768));
            Embeddings := TimedEmbedding;
            TimedAnswer := TTimedAnswer.Create(
            CreateAnswerProvider);
            Generator := TimedAnswer;
            ProviderMs :=
            Watch.Elapsed.TotalMilliseconds;
            Row.AddPair('providersMs',
            TJSONNumber.Create(ProviderMs));
            Row.AddPair('embeddingIdentity',
            Embeddings.ModelIdentity);
            Row.AddPair('answerIdentity',
            Generator.ModelIdentity);
            Stage := 'reopen';
            Watch := TStopwatch.StartNew;
            Base := LoadPreparedBase(ParamStr(1),
            Embeddings.ModelIdentity);
            ReopenMs :=
            Watch.Elapsed.TotalMilliseconds;
            Row.AddPair('reopenMs',
            TJSONNumber.Create(ReopenMs));
            Row.AddPair('chunks', TJSONNumber.Create
            (Length(Base.Items)));
            Stage := 'query';
            Watch := TStopwatch.StartNew;
            try

              Response := QueryPreparedBase(Base,
            Questions[QuestionIndex],
                'operacional', Embeddings, Generator
            );
            finally

              QueryMs :=
            Watch.Elapsed.TotalMilliseconds;
              Row.AddPair('queryMs',
            TJSONNumber.Create(QueryMs));
              Row.AddPair('embeddingMs',
            TJSONNumber.Create(
            TimedEmbedding.ElapsedMs));
              Row.AddPair('generationMs',
            TJSONNumber.Create(TimedAnswer.ElapsedMs
            ));
              Row.AddPair('otherQueryMs',
            TJSONNumber.Create(QueryMs -
                TimedEmbedding.ElapsedMs -
            TimedAnswer.ElapsedMs));
              Row.AddPair('embeddingCalls',
            TJSONNumber.Create(TimedEmbedding.Calls)
            );
              Row.AddPair('generationCalls',
            TJSONNumber.Create(TimedAnswer.Calls));
            end;
            Stage := 'presentation';
            Watch := TStopwatch.StartNew;
            DisplayText := FormatAnswer(
            Response.Answer);
            PresentationMs :=
            Watch.Elapsed.TotalMilliseconds;
            Row.AddPair('presentationMs',
            TJSONNumber.Create(PresentationMs));
            Row.AddPair('totalMs',
            TJSONNumber.Create(
            WholeWatch.Elapsed.TotalMilliseconds));
            Row.AddPair('hasAnswer',
            TJSONBool.Create(
            Response.Answer.HasAnswer));
            Row.AddPair('displayText', DisplayText);
            Row.AddPair('context',
            TJSONObject.ParseJSONValue(
            Response.Context.Serialized));
            FoundClaim := False;
            FoundEvidence := False;
            for Claim in Response.Answer.Claims do
            begin

              if Claim.Text.ToLower.Contains(
            'supervisor') then FoundClaim := True;
              for Evidence in Claim.Evidence do
                if (Evidence.Source.Chunk.DocumentId
            = 'recebimento.md') and
                  Evidence.Quote.Contains(
            'Somente o supervisor') then
            FoundEvidence := True;
            end;
            if QuestionIndex = 0 then
              MinimumCheck :=
            Response.Answer.HasAnswer and FoundClaim
            and FoundEvidence
            else

              MinimumCheck := not
            Response.Answer.HasAnswer and (Length(
            Response.Answer.Claims) = 0);
            Row.AddPair('minimumAnswerCheck',
            TJSONBool.Create(MinimumCheck));
            if not MinimumCheck then raise
            Exception.Create(
            'Conferência mínima de ' +
            'resposta falhou');
            Row.AddPair('status', 'completed');
          except

            on E: Exception do
            begin

              Inc(Failed);
              Row.AddPair('status', 'error');
              Row.AddPair('failedStage', Stage);
              Row.AddPair('errorClass', E.ClassName)
            ;
              Row.AddPair('error', E.Message);
              Row.AddPair('elapsedAtFailureMs',
            TJSONNumber.Create(
            WholeWatch.Elapsed.TotalMilliseconds));
            end;
          end;
          if Generator <> nil then Row.AddPair(
            'rawResponse', Generator.LastResponse);
          Generator := nil;
          Embeddings := nil;
          Writeln('ROUND=', Round, ' QUESTION=',
            QuestionIndex, ' STATUS=', Row.GetValue(
            'status').Value);
        end;
      Report.AddPair('failed', TJSONNumber.Create(
        Failed));
      TFile.WriteAllText(ParamStr(2), Report.ToJSON,
        TEncoding.UTF8);
      Writeln('MEASUREMENTS=', Rows.Count,
        ' FAILED=', Failed);
    finally Report.Free; end;
    if Failed > 0 then ExitCode := 1;
  except

    on E: Exception do
    begin Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 1; end;
  end;
end.
