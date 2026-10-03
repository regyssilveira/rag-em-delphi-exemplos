program OcrServiceTests;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.Classes, System.IOUtils
  , System.Hash, Rag.Ocr, Rag.Types;

var Provider, Slow: IOcrProvider; Page, Blank:
  TOcrPage; Review: TOcrReview;
  Doc: TDocument; Exe, Data, Folder, Image, Original
    , BlankImage, ExeHash, DataHash, SlowExe: string
    ;
  Rejected: Boolean; Calls, Checks: Integer;
    InvalidExe: string;

procedure Check(Value: Boolean; const MessageText:
  string);
begin

  if not Value then raise Exception.Create(
    MessageText);
  Inc(Checks); Writeln('OK: ', MessageText);
end;

begin

  try

    if ParamCount <> 8 then raise Exception.Create(
      'Informe runtime, dados, ' +
      'pasta, imagem, origem, ' +
      'imagem branca e dois ' + 'helpers');
    Exe := ParamStr(1); Data := ParamStr(2); Folder
      := ParamStr(3); Image := ParamStr(4);
    Original := ParamStr(5); BlankImage := ParamStr(
      6); SlowExe := ParamStr(7);
    InvalidExe := ParamStr(8);
    ExeHash := THashSHA2.GetHashStringFromFile(Exe);
    DataHash := THashSHA2.GetHashStringFromFile(
      TPath.Combine(Data, 'por.traineddata'));
    Provider := TTesseractProcessProvider.Create(Exe
      , Data, Folder, ExeHash, DataHash);
    Page := Provider.Recognize(Image, Original, 2,
      nil);
    Check(Page.Text.Contains(
      'Somente o supervisor pode ' + 'liberar.'),
      'texto conhecido');
    Check((Page.Source = TPath.GetFullPath(Original)
      ) and (Page.PageNumber = 2)
      and Page.RecognitionIdentity.Contains(DataHash
        ), 'origem página e ' +
        'identidade preservadas');
    Review := TOcrReview.Create(Page);
    try

      Rejected := False;
      try Review.Document('operacional'); except on
        E: EInvalidOpException do Rejected := True;
        end;
      Check(Rejected, 'documento pendente ' +
        'recusado');
      Review.AcceptText(Page.Text);
      Doc := Review.Document('operacional');
      Check(Review.Accepted and (Doc.Source =
        Page.Source) and (Doc.PageNumber = 2)
        and (Doc.Text = Page.Text),
          'aceitação explícita ' +
          'preserva conteúdo e origem');
      Review.AcceptText('Texto corrigido pelo ' +
        'revisor.');
      Check(Review.Document('operacional').Text =
        'Texto corrigido pelo ' + 'revisor.',
        'correção explícita ' + 'aplicada');
      Check(Review.Page.Text = Page.Text,
        'texto reconhecido ' + 'original permanece '
        + 'disponível');
      Rejected := False;
      try Review.Document('inventado'); except on E:
        EArgumentException do Rejected := True; end;
      Check(Rejected, 'classificação ' +
        'desconhecida recusada');
    finally Review.Free; end;
    Blank := Provider.Recognize(BlankImage, Original
      , 3, nil);
    Check(Blank.Text.Trim.IsEmpty and (
      Blank.PageNumber = 3),
      'imagem branca não inventa ' + 'texto');
    Review := TOcrReview.Create(Blank);
    try

      Rejected := False;
      try Review.AcceptText(Blank.Text); except on E
        : EArgumentException do Rejected := True;
        end;
      Check(Rejected and not Review.Accepted,
        'texto vazio não aceito');
    finally Review.Free; end;
    Rejected := False;
    try Provider.Recognize(Image, Original, 2,
      function: Boolean begin Result := True; end);
    except on E: EOcrCancelled do Rejected := True;
      end;
    Check(Rejected, 'cancelamento anterior ao ' +
      'processo');
    Calls := 0; Rejected := False;
    try Provider.Recognize(Image, Original, 2,
      function: Boolean begin Inc(Calls); Result :=
        Calls >= 3; end);
    except on E: EOcrCancelled do Rejected := True;
      end;
    Check(Rejected and (Calls >= 3),
      'cancelamento após iniciar ' + 'processo');
    Rejected := False;
    try Provider.Recognize(Image + '.absent',
      Original, 2, nil);
    except on E: EReadError do Rejected := True; end
      ;
    Check(Rejected, 'imagem ausente recusada');
    Rejected := False;
    try Provider := TTesseractProcessProvider.Create
      (Exe, Data, Folder, StringOfChar('0', 64),
      DataHash);
    except on E: EReadError do Rejected := True; end
      ;
    Check(Rejected, 'executável incompatível ' +
      'recusado');
    Slow := TTesseractProcessProvider.Create(SlowExe
      , Data, Folder,
      THashSHA2.GetHashStringFromFile(SlowExe),
        DataHash, 100);
    Rejected := False;
    try Slow.Recognize(Image, Original, 2, nil);
      except on E: EOcrTimeout do Rejected := True;
      end;
    Check(Rejected, 'tempo excedido no helper ' +
      'sintético');
    Slow := TTesseractProcessProvider.Create(
      InvalidExe, Data, Folder,
      THashSHA2.GetHashStringFromFile(InvalidExe),
        DataHash);
    Rejected := False;
    try Slow.Recognize(Image, Original, 2, nil);
      except on E: EConvertError do Rejected := True
      ; end;
    Check(Rejected, 'UTF-8 inválido recusado ' +
      'no helper sintético');
    Writeln('CHECKS=', Checks);
  except on E: Exception do begin Writeln(E.Message)
    ; ExitCode := 1; end; end;
end.
