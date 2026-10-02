program JsonMessageTests;

{$APPTYPE CONSOLE}

uses System.SysUtils, System.JSON;

procedure Check(Value: Boolean; const Name: string);
begin
  if not Value then raise Exception.Create('FALHOU: ' + Name);
  Writeln('OK: ', Name);
end;

var
  Input, Envelope: TJSONObject;
  Parsed, ParsedInput: TJSONValue;
  Text, Content: string;
begin
  try
    Text := 'Não liberar. Três dias úteis. "Aspas"';
    Input := TJSONObject.Create;
    Envelope := TJSONObject.Create;
    try
      Input.AddPair('text', Text);
      Check(Input.ToJSON.Contains('\u00'), 'serialização padrão usa escapes Unicode');
      Content := Input.ToJSON([TJSONAncestor.TJSONOutputOption.EncodeBelow32]);
      Check(Content.Contains('Não liberar') and not Content.Contains('\u00'), 'conteúdo para o modelo mantém acentos legíveis');
      Envelope.AddPair('content', Content);
      Parsed := TJSONObject.ParseJSONValue(Envelope.ToJSON);
      try
        Check(Parsed.FindValue('content').Value = Content, 'envelope HTTP conserva a mensagem legível');
        ParsedInput := TJSONObject.ParseJSONValue(Parsed.FindValue('content').Value);
        try Check(ParsedInput.FindValue('text').Value = Text, 'aspas e Unicode preservados na dupla serialização');
        finally ParsedInput.Free; end;
      finally Parsed.Free; end;
    finally Envelope.Free; Input.Free; end;
  except on E: Exception do begin Writeln(E.Message); ExitCode := 1; end; end;
end.
