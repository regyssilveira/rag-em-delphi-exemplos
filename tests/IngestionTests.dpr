program IngestionTests;

{$APPTYPE CONSOLE}

uses System.SysUtils, System.IOUtils, Rag.Types, Rag.Core, Rag.Ingestion;

var FixturePath: string;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then raise Exception.Create('FALHOU: ' + MessageText);
  Writeln('OK: ', MessageText);
end;

procedure CheckRejected(const Name, ExpectedMessage: string);
var Rejected: Boolean; Document: TDocument;
begin
  Rejected := False;
  try
    Document := LoadDocument(TPath.Combine(FixturePath, Name), 'operacional');
  except
    on Error: Exception do
      if (ExpectedMessage = '') or (Pos(ExpectedMessage, Error.Message) > 0) then
        Rejected := True
      else raise;
  end;
  Check(Rejected, 'arquivo rejeitado: ' + Name);
end;

var Document: TDocument; TextValue: string;
begin
  try
    if ParamCount <> 1 then raise Exception.Create('Informe tests/fixtures');
    FixturePath := ParamStr(1);
    TextValue := ReadUtf8Text(TPath.Combine(FixturePath, 'utf8.txt'));
    Check(TextValue = ReadUtf8Text(TPath.Combine(FixturePath, 'normalized.txt')), 'BOM removido e quebras normalizadas');
    Document := LoadDocument(TPath.Combine(FixturePath, 'simple.docx'), 'operacional');
    Check(Document.Text = ReadUtf8Text(TPath.Combine(FixturePath, 'expected.txt')), 'DOCX preserva texto, ordem, espaços e células');
    Check(Document.Id = 'simple.docx', 'identificador técnico preservado');
    Check(Document.Access = 'operacional', 'acesso definido pelo chamador');
    CheckRejected('invalid-utf8.txt', 'UTF-8');
    CheckRejected('text-with-null.txt', 'nulo');
    CheckRejected('revision.docx', 'fora do escopo');
    CheckRejected('merged.docx', 'fora do escopo');
    CheckRejected('missing.docx', 'word/document.xml');
    CheckRejected('invalid-xml.docx', 'XML inválido');
    CheckRejected('dtd.docx', 'XML inválido');
    CheckRejected('wrong-namespace.docx', 'corpo');
    CheckRejected('unsupported.pdf', 'Formato ainda não suportado');
    CheckRejected('absent.txt', 'Documento não encontrado');
    Writeln('TODAS AS VERIFICAÇÕES DE INGESTÃO PASSARAM');
  except
    on Error: Exception do begin Writeln(Error.Message); ExitCode := 1; end;
  end;
end.
