unit Rag.OcrReviewForm;
interface
uses System.SysUtils, System.Classes, Vcl.Forms, Vcl.Controls, Vcl.StdCtrls,
  Vcl.ExtCtrls, Rag.Ocr, Rag.Types, Rag.OcrBatch;
type
  TOcrReviewForm = class(TForm)
  private
    FReview: TOcrReview;
    FOriginal, FEdited: TMemo;
    FAccept, FSkip: TButton;
    FAccess: string;
    FDocument: TDocument;
    procedure Edited(Sender: TObject);
    procedure Accept(Sender: TObject);
    procedure Skip(Sender: TObject);
  public
    constructor CreateReview(AOwner: TComponent; const Page: TOcrPage;
      const ImagePath, Access: string);
    destructor Destroy; override;
    class function ReviewPage(AOwner: TComponent; const Page: TOcrPage;
      const ImagePath, Access: string; out Document: TDocument): Boolean; static;
    class function DecidePage(AOwner: TComponent; const Page: TOcrBatchPage;
      const Access: string): TOcrDecision; static;
    procedure RunHandlerChecks;
    procedure RunEmptyHandlerChecks;
  end;
implementation
uses Vcl.Dialogs, Vcl.Graphics;
constructor TOcrReviewForm.CreateReview(AOwner: TComponent; const Page: TOcrPage;
  const ImagePath, Access: string);
var Header: TLabel; Bottom, Content: TPanel; Preview: TImage;
  OriginalBox, EditedBox: TGroupBox; Cancel: TButton; Scroll: TScrollBox;
begin
  inherited CreateNew(AOwner);
  if (Access <> 'operacional') and (Access <> 'supervisor') then
    raise EArgumentException.Create('Classificação desconhecida');
  Caption := 'Conferir reconhecimento antes de importar'; Position := poScreenCenter;
  Width := 1100; Height := 740; Constraints.MinWidth := 960; Constraints.MinHeight := 660;
  Font.Name := 'Segoe UI'; Font.Size := 10;
  FReview := TOcrReview.Create(Page); FAccess := Access;
  Header := TLabel.Create(Self); Header.Parent := Self; Header.Align := alTop;
  Header.AutoSize := False; Header.Height := 60; Header.WordWrap := True;
  if Page.PageNumber = 0 then
    Header.Caption := 'Imagem: ' + Page.Source + '. Confira responsáveis, negações e números. Aceitar não grava a base.'
  else
    Header.Caption := Format('Origem: %s | Página: %d. Confira responsáveis, negações e números. Aceitar não grava a base.', [Page.Source, Page.PageNumber]);
  Bottom := TPanel.Create(Self); Bottom.Parent := Self; Bottom.Align := alBottom; Bottom.Height := 48;
  FAccept := TButton.Create(Self); FAccept.Parent := Bottom; FAccept.SetBounds(12, 10, 160, 28);
  FAccept.Caption := 'Aceitar texto revisado'; FAccept.OnClick := Accept;
  Cancel := TButton.Create(Self); Cancel.Parent := Bottom; Cancel.SetBounds(184, 10, 100, 28);
  Cancel.Caption := 'Cancelar'; Cancel.Cancel := True; Cancel.ModalResult := mrCancel;
  FSkip := TButton.Create(Self); FSkip.Parent := Bottom; FSkip.SetBounds(296, 10, 240, 28);
  FSkip.Caption := 'Ignorar sem texto reconhecido'; FSkip.Enabled := Trim(Page.Text) = ''; FSkip.OnClick := Skip;
  Scroll := TScrollBox.Create(Self); Scroll.Parent := Self; Scroll.Align := alRight; Scroll.Width := 380;
  Preview := TImage.Create(Self); Preview.Parent := Scroll; Preview.AutoSize := True;
  Preview.Picture.LoadFromFile(ImagePath);
  Content := TPanel.Create(Self); Content.Parent := Self; Content.Align := alClient;
  OriginalBox := TGroupBox.Create(Self); OriginalBox.Parent := Content; OriginalBox.Align := alTop;
  OriginalBox.Height := 220; OriginalBox.Caption := 'Texto reconhecido original';
  FOriginal := TMemo.Create(Self); FOriginal.Parent := OriginalBox; FOriginal.Align := alClient;
  FOriginal.ReadOnly := True; FOriginal.ScrollBars := ssVertical; FOriginal.Lines.Text := Page.Text;
  EditedBox := TGroupBox.Create(Self); EditedBox.Parent := Content; EditedBox.Align := alClient;
  EditedBox.Caption := 'Texto revisado para a base';
  FEdited := TMemo.Create(Self); FEdited.Parent := EditedBox; FEdited.Align := alClient;
  FEdited.ScrollBars := ssVertical; FEdited.OnChange := Edited; FEdited.Lines.Text := Page.Text;
  Edited(nil);
end;
procedure TOcrReviewForm.Skip(Sender: TObject);
begin
  if not FReview.Page.Text.Trim.IsEmpty then raise EInvalidOpException.Create('Página contém texto reconhecido');
  ModalResult := mrIgnore;
end;
class function TOcrReviewForm.DecidePage(AOwner: TComponent; const Page: TOcrBatchPage;
  const Access: string): TOcrDecision;
var Dialog: TOcrReviewForm; Choice: Integer;
begin
  Result := Default(TOcrDecision); Result.Kind := odCancel;
  Dialog := TOcrReviewForm.CreateReview(AOwner, Page.Recognition, Page.PreviewPath, Access);
  try
    Choice := Dialog.ShowModal;
    if Choice = mrOk then
    begin Result.Kind := odAccept; Result.ReviewedText := Dialog.FReview.ReviewedText; end
    else if Choice = mrIgnore then Result.Kind := odSkipWithoutText;
  finally Dialog.Free; end;
end;
destructor TOcrReviewForm.Destroy;
begin FReview.Free; inherited; end;
procedure TOcrReviewForm.Edited(Sender: TObject);
begin FAccept.Enabled := Trim(FEdited.Text) <> ''; end;
procedure TOcrReviewForm.Accept(Sender: TObject);
begin
  try
    FReview.AcceptText(FEdited.Text);
    FDocument := FReview.Document(FAccess);
    ModalResult := mrOk;
  except on E: Exception do MessageDlg(E.Message, mtError, [mbOK], 0); end;
end;
class function TOcrReviewForm.ReviewPage(AOwner: TComponent; const Page: TOcrPage;
  const ImagePath, Access: string; out Document: TDocument): Boolean;
var Dialog: TOcrReviewForm;
begin
  Document := Default(TDocument);
  Dialog := TOcrReviewForm.CreateReview(AOwner, Page, ImagePath, Access);
  try
    Result := Dialog.ShowModal = mrOk;
    if Result then Document := Dialog.FDocument;
  finally Dialog.Free; end;
end;
procedure TOcrReviewForm.RunHandlerChecks;
begin
  if not FOriginal.ReadOnly then raise Exception.Create('Original editável');
  if FSkip.Enabled then raise Exception.Create('Página com texto pode ser ignorada como vazia');
  FEdited.Text := ''; Edited(nil);
  if FAccept.Enabled then raise Exception.Create('Texto vazio aceito');
  FEdited.Text := 'Correção conferida pelo revisor.'; Edited(nil); Accept(nil);
  if (ModalResult <> mrOk) or not FDocument.WasOcrReviewed
    or (FDocument.RecognizedText <> FReview.Page.Text)
    or (FDocument.Source <> FReview.Page.Source) then raise Exception.Create('Revisão incoerente');
end;
procedure TOcrReviewForm.RunEmptyHandlerChecks;
begin
  if FAccept.Enabled or not FSkip.Enabled then raise Exception.Create('Decisões de página sem texto incoerentes');
  Skip(nil);
  if (ModalResult <> mrIgnore) or FReview.Accepted then raise Exception.Create('Ignorar página gerou revisão aceita');
end;
end.
