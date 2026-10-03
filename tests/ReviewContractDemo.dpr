program ReviewContractDemo;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.JSON, Rag.Context,
  Rag.Answers;

var Accepted, Rejected: Integer;

procedure RunCase(Number: Integer;
  const Passage, ClaimText, Quote: string;
  ExpectedLiteral: Boolean);
var Context: TPreparedContext; Answer: TValidatedAnswer;
  Root, Claim, Evidence: TJSONObject;
  Claims, Items: TJSONArray; Passed: Boolean;
begin
  Context := Default(TPreparedContext);
  SetLength(Context.Sources, 1);
  Context.Sources[0].LabelId := 'F1';
  Context.Sources[0].Chunk.Text := Passage;
  Context.Sources[0].Chunk.Id := 'synthetic:' +
    IntToStr(Number);
  Context.Sources[0].Chunk.DocumentId :=
    'synthetic-review.md';
  Context.Sources[0].Chunk.Source :=
    'synthetic-review.md';
  Root := TJSONObject.Create;
  try
    Root.AddPair('status', 'answered');
    Claims := TJSONArray.Create;
    Root.AddPair('claims', Claims);
    Claim := TJSONObject.Create;
    Claims.AddElement(Claim);
    Claim.AddPair('text', ClaimText);
    Items := TJSONArray.Create;
    Claim.AddPair('evidence', Items);
    Evidence := TJSONObject.Create;
    Items.AddElement(Evidence);
    Evidence.AddPair('label', 'F1');
    Evidence.AddPair('quote', Quote);
    Passed := False;
    try
      Answer := ParseAnswer(Root.ToJSON, Context);
      Passed := Answer.HasAnswer;
    except on E: EArgumentException do
      Writeln('CASE=', Number, ' ERROR=', E.Message);
    end;
    if Passed <> ExpectedLiteral then
      raise Exception.Create('Literal check diverged');
    if Passed then
    begin
      Inc(Accepted);
      Writeln('CASE=', Number, ' LITERAL=accepted');
    end
    else
    begin
      Inc(Rejected);
      Writeln('CASE=', Number, ' LITERAL=rejected');
    end;
    Writeln('CLAIM: ', ClaimText);
    Writeln('PASSAGE: ', Passage);
    Writeln('QUOTE: ', Quote);
  finally Root.Free; end;
end;

const
  Registration = 'O operador registra produto, ' +
    'quantidade, motivo e condição do item devolvido.';
  Purchase = 'O operador não altera o pedido ' +
    'para esconder a diferença.';
  Approval = 'O supervisor aprova ou rejeita o ' +
    'ajuste de estoque após conferir a evidência ' +
    'da contagem.';
  Deadline = 'O prazo interno para analisar uma ' +
    'devolução é de dois dias úteis após o registro.';
begin
  try
    Writeln('SYNTHETIC MANUAL REVIEW EXERCISE');
    RunCase(1, Registration,
      'O cliente registra produto, quantidade ' +
      'e motivo.', Registration, True);
    RunCase(2, Purchase,
      'Após registrar a divergência, o operador ' +
      'pode alterar o pedido.', Purchase, True);
    RunCase(3, Approval,
      'O supervisor corrige o saldo depois ' +
      'da contagem física.', Approval, True);
    RunCase(4, Deadline, Deadline, Deadline, True);
    RunCase(5, Registration, Registration,
      'O cliente registra produto, quantidade, ' +
      'motivo e condição do item devolvido.', False);
    Writeln('LITERAL_ACCEPTED=', Accepted,
      ' LITERAL_REJECTED=', Rejected);
    Writeln('SEMANTIC_REVIEW_REQUIRED');
  except on E: Exception do
    begin Writeln(E.Message); ExitCode := 1; end;
  end;
end.
