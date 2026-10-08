program PresentationDemo;

{$APPTYPE CONSOLE}

uses System.SysUtils, Rag.Types, Rag.Context,
  Rag.Answers,
  Rag.Generation, Rag.Presentation;

var
  Ranked: TArray<TSearchResult>;
  Context: TPreparedContext;
  Provider: IAnswerProvider;
  Answer: TValidatedAnswer;
  Question: string;
begin
  try
    if ParamCount <> 1 then raise Exception.Create(
      'Use supported ou absent');
    if ParamStr(1) = 'supported' then Question :=
      'Quem pode liberar um ' + 'recebimento com ' +
      'divergência?'
    else if ParamStr(1) = 'absent' then Question :=
      'Qual é a comissão do ' + 'vendedor?'
    else raise Exception.Create('Caso desconhecido')
      ;
    SetLength(Ranked, 1);
    Ranked[0].Chunk.Id := 'REC:1';
    Ranked[0].Chunk.DocumentId := 'REC';
    Ranked[0].Chunk.Source :=
      'procedimento-ficticio';
    Ranked[0].Chunk.Access := 'operacional';
    Ranked[0].Chunk.StartOffset := 1;
    Ranked[0].Chunk.Text :=
      'Somente o supervisor pode ' +
      'liberar um recebimento ' + 'com divergência.'
      ;
    Context := BuildContext(Ranked, 'operacional',
      2000);
    Provider := CreateAnswerProvider;
    Answer := Provider.Generate(Question, Context);
    if Answer.HasAnswer <> (ParamStr(1) =
      'supported') then
      raise Exception.Create(
        'Estado inesperado na prova');
    if Answer.HasAnswer and not Answer.Claims[0].
      Text.Contains('pode liberar') then
      raise Exception.Create(
        'A resposta controlada ' +
        'deve conservar a regra em ' + 'português');
    Writeln(FormatAnswer(Answer));
    Writeln('OK: apresentação ', ParamStr(1));
  except on E: Exception do
    begin
      if Provider <> nil then Writeln(
        Provider.LastResponse);
      Writeln(E.Message);
      ExitCode := 1;
    end;
  end;
end.
