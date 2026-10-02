program ImportTests;

{$APPTYPE CONSOLE}

uses System.SysUtils, System.Classes, System.IOUtils, Rag.Types, Rag.Import;

procedure Check(Value: Boolean; const Name: string);
begin
  if not Value then raise Exception.Create('Falhou: ' + Name);
  Writeln('OK: ', Name);
end;

var Root, Pdfium, TemporaryDirectory: string; Documents, Updated: TArray<TDocument>;
  Before: string; Failed: Boolean;
begin
  try
    if ParamCount <> 2 then raise Exception.Create('Informe checkout e DLL PDFium');
    Root := ParamStr(1);
    Pdfium := ParamStr(2);
    Documents := MergeImportedDocuments(nil,
      [TPath.Combine(Root, 'data/corpus/recebimento.md'), TPath.Combine(Root, 'data/corpus/devolucoes.md')],
      'operacional', Pdfium);
    Check((Length(Documents) = 2) and (Documents[0].Id = 'recebimento.md'), 'arquivos mantêm identidade usada nos exercícios');
    Updated := MergeImportedDocuments(Documents, [TPath.Combine(Root, 'data/corpus/estoque.md')], 'supervisor', Pdfium);
    Check((Length(Updated) = 3) and (Updated[2].Access = 'supervisor') and
      (Length(Documents) = 2), 'adição conserva documentos anteriores e classificação');
    Before := Updated[0].Text;
    Updated := MergeImportedDocuments(Updated, [TPath.Combine(Root, 'data/corpus/recebimento.md')], 'supervisor', Pdfium);
    Check((Length(Updated) = 3) and (Updated[2].Text = Before) and (Updated[2].Access = 'supervisor'),
      'reimportação substitui origem e atualiza classificação');
    Updated := RemoveDocumentSource(Updated, TPath.Combine(Root, 'data/corpus/estoque.md'));
    Check(Length(Updated) = 2, 'remoção exclui origem selecionada');
    Updated := MergeImportedDocuments(nil, [TPath.Combine(Root, 'tests/fixtures/simple.docx')], 'operacional', Pdfium);
    Check((Length(Updated) = 1) and not Updated[0].Text.Trim.IsEmpty, 'DOCX importado pelos recursos nativos');
    Updated := MergeImportedDocuments(nil, [TPath.Combine(Root, 'tests/fixtures/pdf/digital.pdf')], 'operacional', Pdfium);
    Check((Length(Updated) = 2) and (Updated[1].PageNumber = 2), 'PDF digital conserva páginas');
    Updated := RemoveDocumentSource(Updated, TPath.Combine(Root, 'tests/fixtures/pdf/digital.pdf'));
    Check(Length(Updated) = 0, 'remoção de PDF exclui todas as páginas');
    Failed := False;
    try MergeImportedDocuments(Documents, [TPath.Combine(Root, 'tests/fixtures/pdf/mixed.pdf')], 'operacional', Pdfium);
    except on E: EReadError do Failed := E.Message.Contains('sem texto extraído'); end;
    Check(Failed and (Length(Documents) = 2), 'PDF sem texto não vira importação silenciosamente completa');
    Failed := False;
    try MergeImportedDocuments(Documents, [TPath.Combine(Root, 'data/corpus/recebimento.md')], 'visitante', Pdfium);
    except on E: EArgumentException do Failed := True; end;
    Check(Failed, 'classificação desconhecida recusada');
    Failed := False;
    try MergeImportedDocuments(Documents,
      [TPath.Combine(Root, 'data/corpus/recebimento.md'), TPath.Combine(Root, 'data/corpus/recebimento.md')], 'operacional', Pdfium);
    except on E: EArgumentException do Failed := True; end;
    Check(Failed, 'seleção duplicada recusada');
    TemporaryDirectory := TPath.Combine(Root, 'bin/import-fixtures');
    TDirectory.CreateDirectory(TemporaryDirectory);
    TFile.WriteAllText(TPath.Combine(TemporaryDirectory, 'recebimento.md'), 'Outra origem com mesmo nome.', TEncoding.UTF8);
    Failed := False;
    try MergeImportedDocuments(Documents, [TPath.Combine(TemporaryDirectory, 'recebimento.md')], 'operacional', Pdfium);
    except on E: EReadError do Failed := E.Message.Contains('Identidade repetida'); end;
    Check(Failed and (Documents[0].Text = Before), 'nomes iguais de origens diferentes não substituem dados');
  except on E: Exception do begin Writeln(E.Message); ExitCode := 1; end; end;
end.
