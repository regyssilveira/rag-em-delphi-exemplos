program RemoteGenerationTests;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.JSON, Rag.Context, Rag.Answers,
  Rag.Generation, Rag.Generation.Gemini;
var Context: TPreparedContext; Count: Integer;
function Envelope(const Text, Reason: string): string;
var Root, Candidate: TJSONObject;
begin
 Root := TJSONObject.Create;
 try
  Root.AddPair('modelVersion','fixture-model-v1');
  Candidate := TJSONObject.Create;
  Root.AddPair('candidates',TJSONArray.Create(Candidate));
  Candidate.AddPair('finishReason',Reason);
  Candidate.AddPair('content',TJSONObject.Create.AddPair('parts',
    TJSONArray.Create(TJSONObject.Create.AddPair('text',Text))));
  Result := Root.ToJSON;
 finally Root.Free; end;
end;
procedure Reject(const Name, Payload: string);
var Model: string; Rejected: Boolean;
begin
 Rejected := False;
 try TGeminiAnswerProvider.DecodeResponse(Payload,Context,Model);
 except on E: Exception do Rejected := True; end;
 if not Rejected then raise Exception.Create('Aceitou: '+Name);
 Inc(Count); Writeln('OK: ',Name);
end;
procedure Accept(const Name, Payload: string; HasAnswer: Boolean);
var Model: string; Answer: TValidatedAnswer;
begin
 Answer := TGeminiAnswerProvider.DecodeResponse(Payload,Context,Model);
 if (Answer.HasAnswer <> HasAnswer) or (Model <> 'fixture-model-v1') then
  raise Exception.Create('Contrato divergente: '+Name);
 Inc(Count); Writeln('OK: ',Name);
end;
var Json, Candidate, Parts: TJSONValue; Payload, Good, Request: string;
 Provider: IAnswerProvider; Rejected: Boolean;
begin
 try
  SetLength(Context.Sources,1);
  Context.Sources[0].LabelId := 'F1';
  Context.Sources[0].Chunk.Text := 'O recebimento fica pendente até a decisão do supervisor.';
  Context.Sources[0].Chunk.Access := 'operacional';
  Context.Serialized := '{"format":"rag-context-v1","sources":[{"label":"F1",'+
   '"text":"O recebimento fica pendente até a decisão do supervisor."}]}';
  Good := '{"status":"answered","claims":[{"text":"O recebimento fica pendente.",'+
   '"evidence":[{"label":"F1","quote":"O recebimento fica pendente"}]}]}';
  Accept('resposta e citação válida',Envelope(Good,'STOP'),True);
  Accept('insuficiência explícita',Envelope('{"status":"insufficient","claims":[]}','STOP'),False);
  Reject('truncamento',Envelope(Good,'MAX_TOKENS'));
  Reject('bloqueio',Envelope(Good,'SAFETY'));
  Reject('JSON do modelo inválido',Envelope('não é JSON','STOP'));
  Reject('citação inventada',Envelope(Good.Replace('fica pendente"','fica encerrado"'),'STOP'));
  Reject('rótulo não autorizado',Envelope(Good.Replace('"F1"','"F2"'),'STOP'));
  Reject('candidato ausente','{"modelVersion":"fixture-model-v1","candidates":[]}');
  Reject('erro de API','{"error":{"message":"fixture"}}');
  Reject('bloqueio de prompt','{"promptFeedback":{"blockReason":"SAFETY"}}');
  Reject('versão ausente',Envelope(Good,'STOP').Replace('"modelVersion":"fixture-model-v1",',''));
  Json := TJSONObject.ParseJSONValue(Envelope(Good,'STOP'));
  try
   Candidate := TJSONArray(Json.FindValue('candidates')).Items[0];
   Parts := Candidate.FindValue('content.parts');
   TJSONArray(Parts).AddElement(TJSONObject.Create.AddPair('functionCall',TJSONObject.Create));
   Reject('parte não textual',Json.ToJSON);
  finally Json.Free; end;
  Json := TJSONObject.ParseJSONValue(Envelope(Good,'STOP'));
  try
   TJSONArray(Json.FindValue('candidates')).AddElement(
    TJSONObject.ParseJSONValue('{"finishReason":"STOP"}'));
   Reject('múltiplos candidatos',Json.ToJSON);
  finally Json.Free; end;
  Json := TJSONObject.ParseJSONValue(Envelope(Good,'STOP'));
  try
   Parts := TJSONArray(Json.FindValue('candidates')).Items[0].FindValue('content.parts');
   TJSONArray(Parts).AddElement(TJSONObject.Create.AddPair('thought',TJSONBool.Create(True)).AddPair('text','nota interna'));
   Accept('não concatena raciocínio',Json.ToJSON,True);
  finally Json.Free; end;
  Request := TGeminiAnswerProvider.BuildRequest('Posso encerrar?',Context);
  Json := TJSONObject.ParseJSONValue(Request);
  try
   if Json.FindValue('generationConfig.responseMimeType').Value <> 'application/json' then
    raise Exception.Create('Formato incorreto');
   Payload := TJSONArray(Json.FindValue('contents')).Items[0].ToJSON;
   if not Payload.Contains('Posso encerrar?') or not Payload.Contains('fica pendente') then
    raise Exception.Create('Pergunta ou contexto alterado');
   if Request.Contains('GEMINI_API_KEY') then raise Exception.Create('Credencial no corpo');
   Inc(Count);Writeln('OK: pergunta e contexto no contrato REST');
  finally Json.Free; end;
  Rejected := False;
  try Provider := TGeminiAnswerProvider.Create('', 'fixture-model');
  except on E: EArgumentException do Rejected := True; end;
  if not Rejected then raise Exception.Create('Credencial ausente aceita');
  Inc(Count);Writeln('OK: credencial ausente');
  Rejected := False;
  try Provider := TGeminiAnswerProvider.Create('fixture','../../outro?key=x');
  except on E: EArgumentException do Rejected := True; end;
  if not Rejected then raise Exception.Create('Modelo inseguro aceito');
  Inc(Count);Writeln('OK: modelo com URL inválida');
  Writeln('PASSED=',Count,' FAILED=0');
 except on E: Exception do begin Writeln('FAIL: ',E.Message);ExitCode:=1;end; end;
end.
