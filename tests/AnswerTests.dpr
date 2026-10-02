program AnswerTests;

{$APPTYPE CONSOLE}

uses System.SysUtils, Rag.Types, Rag.Context, Rag.Answers;

var Context: TPreparedContext; Ranked: TArray<TSearchResult>; Answer: TValidatedAnswer;

procedure Reject(const Payload, Name: string);
var Failed: Boolean;
begin
  Failed := False;
  try ParseAnswer(Payload, Context);
  except on E: EArgumentException do Failed := True; end;
  if not Failed then raise Exception.Create('FALHOU: ' + Name);
  Writeln('OK: ', Name);
end;

begin
  try
    SetLength(Ranked, 1);
    Ranked[0].Chunk.Id := 'DEV:1';
    Ranked[0].Chunk.DocumentId := 'DEV';
    Ranked[0].Chunk.Source := 'devolucoes.md';
    Ranked[0].Chunk.Access := 'operacional';
    Ranked[0].Chunk.StartOffset := 1;
    Ranked[0].Chunk.Text := 'O prazo interno é de três dias úteis. Não liberar estoque automaticamente.';
    Context := BuildContext(Ranked, 'operacional', 2000);
    Answer := ParseAnswer('{"status":"answered","claims":[{"text":"O prazo é de três dias úteis.","evidence":[{"label":"F1","quote":"O prazo interno é de três dias úteis."}]}]}', Context);
    if not Answer.HasAnswer or (Answer.Claims[0].Evidence[0].Source.Chunk.Id <> 'DEV:1') then
      raise Exception.Create('Resolução de fonte falhou');
    Writeln('OK: afirmação resolve origem pelo contexto local');
    Answer := ParseAnswer('{"status":"insufficient","claims":[]}', Context);
    if Answer.HasAnswer then raise Exception.Create('Abstenção falhou');
    Writeln('OK: abstenção sem afirmações');
    Reject('{"status":"answered","claims":[]}', 'resposta sem afirmações rejeitada');
    Reject('{"status":"insufficient","claims":[{}]}', 'abstenção com conteúdo rejeitada');
    Reject('{"status":"answered","claims":[{"text":"O prazo é de três dias úteis.","evidence":[{"label":"F99","quote":"O prazo interno é de três dias úteis."}]}]}', 'fonte inventada rejeitada');
    Reject('{"status":"answered","claims":[{"text":"O prazo é de três dias úteis.","evidence":[{"label":"F1","quote":"O prazo é de cinco dias úteis."}]}]}', 'citação inventada rejeitada');
    Reject('{"status":"answered","status":"answered","claims":[]}', 'campo duplicado rejeitado');
    Reject('{"status":"insufficient","claims":[],"extra":1}', 'campo adicional rejeitado');
    Reject('BROKEN', 'JSON inválido rejeitado');
    Reject('{"status":"answered","claims":[{"text":"O prazo é de três dias úteis.","evidence":[]}]}', 'afirmação sem citações rejeitada');
    Reject('{"status":"answered","claims":[{"text":"O prazo é de três dias úteis.","evidence":[{"label":"F1","quote":"O prazo"}]}]}', 'citação curta rejeitada');
    Reject('{"status":"answered","claims":[{"text":"O prazo é de três dias úteis.","evidence":[{"label":"F1","quote":"O prazo interno é de três dias úteis."},{"label":"F1","quote":"O prazo interno é de três dias úteis."}]}]}', 'mesma fonte repetida rejeitada');
  except on E: Exception do begin Writeln(E.Message); ExitCode := 1; end; end;
end.
