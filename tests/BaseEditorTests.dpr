program BaseEditorTests;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.Classes, System.IOUtils, Rag.BaseEditor,
  Rag.Persistence, Rag.Embeddings, Rag.Vectors;
type TFake = class(TInterfacedObject, IEmbeddingProvider)
  function GetModelIdentity: string;
  function EmbedDocument(const Text: string): TEmbedding;
  function EmbedQuery(const Text: string): TEmbedding;
end;
var Calls: Integer; FailEmbedding: Boolean;
function TFake.GetModelIdentity: string;
begin Result := 'SYNTHETIC-BASE-EDITOR'; end;
function TFake.EmbedDocument(const Text: string): TEmbedding;
begin Inc(Calls); if FailEmbedding then raise EReadError.Create('Falha simulada'); Result := [1.0, 0.0]; end;
function TFake.EmbedQuery(const Text: string): TEmbedding;
begin Result := [1.0, 0.0]; end;
procedure Check(Value: Boolean; const Name: string);
begin if not Value then raise Exception.Create(Name); Writeln('OK: ', Name); end;
var Folder, Input, Dest, Before: string; Provider: IEmbeddingProvider;
  Base: TPreparedBase; Stats: TUpdateStats; Failed: Boolean;
begin
try
  Folder := TPath.Combine(ParamStr(1), 'bin/base-editor-fixtures');
  TDirectory.CreateDirectory(Folder);
  Input := TPath.Combine(Folder, 'documento.txt'); Dest := TPath.Combine(Folder, 'base.json');
  if TFile.Exists(Dest) then TFile.Delete(Dest);
  TFile.WriteAllText(Input, 'O supervisor aprova a contagem.', TEncoding.UTF8);
  Provider := TFake.Create;
  Base := ImportPrepareSave(Dest, [Input], 'operacional', '', Provider, 2, 200, 20, Stats);
  Check(TFile.Exists(Dest) and (Stats.Embedded = 1), 'importação prepara e salva');
  Base := LoadPreparedBase(Dest, Provider.ModelIdentity);
  Check((Length(Base.Documents) = 1) and (Base.Documents[0].Access = 'operacional'), 'reabertura confere dados gravados');
  Base := ImportPrepareSave(Dest, [Input], 'supervisor', '', Provider, 2, 200, 20, Stats);
  Check((Stats.Reused = 1) and (Stats.Embedded = 0) and (Base.Documents[0].Access = 'supervisor'), 'reclassificação reutiliza vetor');
  Before := TFile.ReadAllText(Dest, TEncoding.UTF8);
  TFile.WriteAllText(Input, 'Texto alterado que exige novo vetor.', TEncoding.UTF8);
  Calls := 0; Failed := False;
  try ImportPrepareSave(Dest, [Input], 'operacional', '', Provider, 2, 200, 20, Stats,
    function: Boolean begin Result := Calls > 0; end);
  except on E: EAbort do Failed := True; end;
  Check(Failed and (Calls = 1) and (TFile.ReadAllText(Dest, TEncoding.UTF8) = Before), 'cancelamento após chamada preserva arquivo anterior');
  FailEmbedding := True; Failed := False;
  try ImportPrepareSave(Dest, [Input], 'operacional', '', Provider, 2, 200, 20, Stats);
  except on E: EReadError do Failed := True; end;
  Check(Failed and (TFile.ReadAllText(Dest, TEncoding.UTF8) = Before), 'falha do modelo preserva arquivo anterior');
  FailEmbedding := False;
  Base := ImportPrepareSave(Dest, [Input], 'operacional', '', Provider, 2, 200, 20, Stats);
  Check((Stats.Embedded = 1) and (Stats.Reused = 0) and (Base.Documents[0].Text.Contains('alterado')), 'atualização prepara e substitui base');
  Before := TFile.ReadAllText(Dest, TEncoding.UTF8); Failed := False;
  try RemoveSourceAndSave(Dest, Input, Provider.ModelIdentity,
    function: Boolean begin Result := True; end);
  except on E: EAbort do Failed := True; end;
  Check(Failed and (TFile.ReadAllText(Dest, TEncoding.UTF8) = Before), 'cancelamento de remoção preserva base');
  Failed := False;
  try RemoveSourceAndSave(Dest, Input + '.ausente', Provider.ModelIdentity);
  except on E: EArgumentException do Failed := True; end;
  Check(Failed and (TFile.ReadAllText(Dest, TEncoding.UTF8) = Before), 'remoção de origem ausente recusada');
  Calls := 0;
  Base := RemoveSourceAndSave(Dest, Input, Provider.ModelIdentity);
  Check((Length(Base.Documents) = 0) and (Length(Base.Items) = 0) and (Calls = 0) and TFile.Exists(Input),
    'remoção salva base vazia sem modelo nem exclusão do original');
  Base := LoadPreparedBase(Dest, Provider.ModelIdentity);
  Check(Length(Base.Items) = 0, 'base vazia reabre após remoção');
except on E: Exception do begin Writeln(E.Message); ExitCode := 1; end; end;
end.
