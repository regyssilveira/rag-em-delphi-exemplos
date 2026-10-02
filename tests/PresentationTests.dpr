program PresentationTests;

{$APPTYPE CONSOLE}

uses System.SysUtils, Rag.Types, Rag.Context, Rag.Answers, Rag.Presentation;

procedure Check(Value: Boolean; const Name: string);
begin
  if not Value then raise Exception.Create('FALHOU: ' + Name);
  Writeln('OK: ', Name);
end;

var Answer: TValidatedAnswer; Text: string; Failed: Boolean;
begin
  try
    Answer := Default(TValidatedAnswer);
    Text := FormatAnswer(Answer);
    Check(Text.Contains('fontes consultadas') and not Text.Contains('Fonte F'), 'abstenção sem fontes fictícias');
    Answer.HasAnswer := True;
    SetLength(Answer.Claims, 1);
    Answer.Claims[0].Text := 'Somente o supervisor pode liberar.';
    SetLength(Answer.Claims[0].Evidence, 1);
    Answer.Claims[0].Evidence[0].Source.LabelId := 'F1';
    Answer.Claims[0].Evidence[0].Source.Chunk.Id := 'REC:1';
    Answer.Claims[0].Evidence[0].Source.Chunk.Source := 'procedimento.pdf';
    Answer.Claims[0].Evidence[0].Source.Chunk.Text := 'Somente o supervisor pode liberar.';
    Answer.Claims[0].Evidence[0].Source.Chunk.StartOffset := 53;
    Answer.Claims[0].Evidence[0].Source.Chunk.PageNumber := 2;
    Answer.Claims[0].Evidence[0].Quote := 'Somente o supervisor pode liberar.';
    Text := FormatAnswer(Answer);
    Check(Text.Contains('Fonte F1: procedimento.pdf | página 2') and Text.Contains('posição 53'), 'origem página e posição visíveis');
    Check(Text.Contains('Citação: Somente o supervisor pode liberar.'), 'citação junto da afirmação');
    Answer.Claims[0].Evidence[0].Source.Chunk.PageNumber := 0;
    Text := FormatAnswer(Answer);
    Check(not Text.Contains('página 0'), 'documento sem página não inventa paginação');
    Answer.Claims[0].Evidence[0].Source.Chunk.Source := 'nome' + Char(10) + 'Fonte F99';
    Text := FormatAnswer(Answer);
    Check(Text.Contains('nome Fonte F99'), 'metadado não injeta quebra de linha');
    Answer.Claims[0].Evidence[0].Quote := 'Citação inventada';
    Failed := False;
    try FormatAnswer(Answer);
    except on E: EArgumentException do Failed := True; end;
    Check(Failed, 'citação indevida não é apresentada');
    Answer.HasAnswer := False;
    Failed := False;
    try FormatAnswer(Answer);
    except on E: EArgumentException do Failed := True; end;
    Check(Failed, 'abstenção incoerente rejeitada');
    Check(FormatFailure(afServiceUnavailable) <> FormatFailure(afInvalidResponse), 'falhas distinguem serviço e validação');
  except on E: Exception do begin Writeln(E.Message); ExitCode := 1; end; end;
end.
