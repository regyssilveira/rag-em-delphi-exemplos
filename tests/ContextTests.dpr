program ContextTests;

{$APPTYPE CONSOLE}

uses System.SysUtils, System.JSON, Rag.Types, Rag.Context;

procedure Check(Value: Boolean; const MessageText: string);
begin
  if not Value then raise Exception.Create('FALHOU: ' + MessageText);
  Writeln('OK: ', MessageText);
end;

function Item(const Id, Text, Access: string): TSearchResult;
begin
  Result := Default(TSearchResult);
  Result.Chunk.Id := Id;
  Result.Chunk.DocumentId := 'DOC';
  Result.Chunk.Source := 'procedimento.pdf';
  Result.Chunk.Text := Text;
  Result.Chunk.Access := Access;
  Result.Chunk.PageNumber := 2;
  Result.Chunk.StartOffset := 1;
end;

var
  Ranked: TArray<TSearchResult>;
  Context, Single: TPreparedContext;
  Json: TJSONValue;
  Failed: Boolean;
begin
  try
    Ranked := [Item('A', 'Não liberar estoque.', 'supervisor'),
      Item('B', 'Analisar em três dias úteis.', 'operacional')];
    Context := BuildContext(Ranked, 'operacional', 2000);
    Check((Length(Context.Sources) = 1) and (Context.SkippedForbidden = 1) and
      not Context.Serialized.Contains('Não liberar estoque'), 'restrição aplicada antes de serializar');
    Check((Context.Sources[0].LabelId = 'F1') and
      (Context.Sources[0].Chunk.PageNumber = 2) and
      (Context.Sources[0].Chunk.Id = 'B'), 'rótulo aponta para origem e página');
    Single := BuildContext([Ranked[1]], 'operacional', 2000);
    Context := BuildContext([Ranked[1]], 'operacional', Length(Single.Serialized));
    Check(Context.Serialized = Single.Serialized, 'limite exato aceita trecho inteiro');
    Context := BuildContext([Ranked[1]], 'operacional', Length(Single.Serialized) - 1);
    Check((Length(Context.Sources) = 0) and (Context.SkippedBudget = 1), 'não corta regra para caber');
    Ranked := [Item('LONG', StringOfChar('x', 5000), 'operacional'), Ranked[1]];
    Context := BuildContext(Ranked, 'operacional', 1000);
    Check((Length(Context.Sources) = 1) and (Context.Sources[0].Chunk.Id = 'B'), 'trecho grande não impede candidato seguinte');
    Ranked := [Item('A', 'primeiro', 'operacional'), Item('B', 'segundo', 'operacional')];
    Context := BuildContext(Ranked, 'operacional', 2000, 1);
    Check((Length(Context.Sources) = 1) and (Context.SkippedBudget = 1), 'limite de quantidade preserva ordem');
    Ranked := [Item('A', '''
Texto "com aspas" e
linha nova.
''', 'operacional')];
    Context := BuildContext(Ranked, 'operacional', 2000);
    Json := TJSONObject.ParseJSONValue(Context.Serialized);
    try
      Check((Json <> nil) and (Json.FindValue('sources[0].text').Value = Ranked[0].Chunk.Text), 'JSON conserva texto e separadores');
    finally Json.Free; end;
    Failed := False;
    try BuildContext([Ranked[0], Ranked[0]], 'operacional', 2000);
    except on E: EArgumentException do Failed := True; end;
    Check(Failed, 'duplicata não ganha dois rótulos');
    Failed := False;
    try BuildContext(Ranked, 'visitante', 2000);
    except on E: EArgumentException do Failed := True; end;
    Check(Failed, 'perfil desconhecido rejeitado');
    Ranked[0].Chunk.Text := Char($D800);
    Failed := False;
    try BuildContext(Ranked, 'operacional', 2000);
    except on E: EArgumentException do Failed := True; end;
    Check(Failed, 'par Unicode incompleto rejeitado');
    Context := BuildContext(nil, 'operacional', 128);
    Check((Length(Context.Sources) = 0) and (Length(Context.Serialized) <= 128), 'base sem candidatos tem contexto vazio válido');
  except on E: Exception do begin Writeln(E.Message); ExitCode := 1; end; end;
end.
