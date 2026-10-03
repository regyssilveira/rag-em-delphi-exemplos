unit Rag.Presentation;

interface

uses System.SysUtils, Rag.Answers;

type
  TAnswerFailure = (afServiceUnavailable,
    afInvalidResponse);

function FormatAnswer(const Answer: TValidatedAnswer
  ): string;
function FormatFailure(Failure: TAnswerFailure):
  string;

implementation

function OneLine(const Value: string): string;
var C: Char;
begin
  Result := '';
  for C in Value do
    if Ord(C) < 32 then Result := Result + ' '
    else Result := Result + C;
end;

function FormatAnswer(const Answer: TValidatedAnswer
  ): string;
var Builder: TStringBuilder; Claim: TAnswerClaim;
  Evidence: TAnswerEvidence;
begin
  if not Answer.HasAnswer then
  begin
    if Length(Answer.Claims) <> 0 then raise
      EArgumentException.Create(
      'Abstenção incoerente');
    Exit('Não encontrei evidência ' +
      'suficiente nas fontes ' + 'consultadas para '
      + 'responder.');
  end;
  if (Length(Answer.Claims) < 1) or (Length(
    Answer.Claims) > 8) then
    raise EArgumentException.Create(
      'Quantidade de afirmações ' + 'inválida');
  Builder := TStringBuilder.Create;
  try
    for Claim in Answer.Claims do
    begin
      if Claim.Text.Trim.IsEmpty or (Length(
        Claim.Evidence) < 1) or
        (Length(Claim.Evidence) > 6) then raise
          EArgumentException.Create(
          'Afirmação sem evidência');
      Builder.AppendLine(Claim.Text);
      for Evidence in Claim.Evidence do
      begin
        if Evidence.Source.LabelId.IsEmpty or
          Evidence.Source.Chunk.Source.IsEmpty or
          (Evidence.Source.Chunk.PageNumber < 0) or
            (Evidence.Source.Chunk.StartOffset < 1)
            or
          Evidence.Quote.Trim.IsEmpty or (
            Evidence.Source.Chunk.Text.IndexOf(
            Evidence.Quote) < 0) then
          raise EArgumentException.Create(
            'Origem ou citação inválida');
        Builder.Append('Fonte ').Append(OneLine(
          Evidence.Source.LabelId)).Append(': ');
        Builder.Append(OneLine(
          Evidence.Source.Chunk.Source));
        if Evidence.Source.Chunk.PageNumber > 0 then
          Builder.Append(' | página ').Append(
            Evidence.Source.Chunk.PageNumber);
        Builder.Append(' | trecho ').Append(OneLine(
          Evidence.Source.Chunk.Id));
        Builder.Append(' | posição ').Append(
          Evidence.Source.Chunk.StartOffset).
          AppendLine;
        Builder.Append('Citação: ').AppendLine(
          Evidence.Quote);
      end;
      Builder.AppendLine;
    end;
    Result := Builder.ToString.TrimRight;
  finally Builder.Free; end;
end;

function FormatFailure(Failure: TAnswerFailure):
  string;
begin
  case Failure of
    afServiceUnavailable: Result :=
      'Não foi possível ' + 'consultar o modelo. ' +
      'Verifique o serviço e ' + 'tente novamente.';
    afInvalidResponse: Result :=
      'A resposta recebida não ' +
      'passou pela validação. ' +
      'Nenhuma resposta foi ' + 'apresentada.';
  else raise EArgumentException.Create(
    'Falha desconhecida'); end;
end;

end.
