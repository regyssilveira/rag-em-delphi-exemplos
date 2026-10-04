# OCR e revisão — experimento

Este código próprio acompanha o capítulo 6. A janela principal oferece importação de PDF ou imagem com revisão; instalação do reconhecedor e aprovação visual continuam pendentes. A distribuição do reconhecedor externo continua em investigação; não há runtime nem dados linguísticos incluídos. Os hashes esperados do executável e de por.traineddata vêm de uma configuração conferida, não de texto fornecido pelo documento.

A leitura direta aceita PNG, JPEG e BMP com recursos do Windows: arquivo até 64 MiB, dimensões até 10.000 por eixo e área até vinte milhões de pixels. Transparência é composta sobre branco; JPEG com orientação de metadados diferente de 1 é recusado para salvar os pixels na posição de leitura. OcrImageTests recebe fixtures de imagem e pasta gravável; treze conferências nativas, sem modelos. As imagens próprias em tests/fixtures/images estão disponíveis sem Python para o leitor.

A base atual grava versão 2, com estado de revisão, identidade, texto reconhecido original e seu hash. O texto revisado alimenta os trechos. O leitor aceita também a versão 1 e não inventa histórico de OCR. Estado de revisão não autentica o revisor; hash não autentica o arquivo contra quem pode editá-lo.

Crie uma pasta bin gravável e compile OcrProvenanceTests.dpr com experimental/ocr e src no caminho de pesquisa. Execute com pasta de saída absoluta e raiz dos exemplos. As dezesseis conferências usam reconhecimento/vetores sintéticos e reabrem bin/integrated-base.json já preparado pelo percurso principal, sem chamar modelos. Preserve arquivos de teste se quiser comparar rodadas; os nomes de saída são substituídos.

Para OcrServiceTests, compile também os dois helpers e forneça runtime absoluto, tessdata absoluto, pasta de saída, imagem reconhecível, origem original, imagem branca e caminhos dos dois helpers. As quinze conferências combinam OCR real de imagens próprias com testes sintéticos de coordenação. Não representam precisão geral. Configure runtime e idioma por uma distribuição examinada antes de executar; o projeto não executa instaladores ou altera confiança do Windows.

Para OcrBatchTests.dpr, use experimental/ocr e src no caminho de pesquisa. Execute com cinco argumentos absolutos, nesta ordem: executável OCR, pasta tessdata, pasta de trabalho gravável, tests/fixtures/pdf/mixed.pdf e DLL PDFium. Este teste identifica os binários locais pelos hashes calculados na execução; isso não substitui a conferência da distribuição. As decisões de revisão são automatizadas e os vetores são sintéticos: as doze conferências demonstram coordenação, persistência e cancelamento, sem medir qualidade de respostas do modelo.

Para a janela principal, configure antes de iniciar RagAssistant.exe as variáveis de ambiente RAG_OCR_EXE (executável absoluto), RAG_OCR_DATA (pasta tessdata absoluta), RAG_OCR_WORK (pasta gravável existente), RAG_OCR_EXE_SHA256 (hash esperado do executável conferido) e RAG_OCR_DATA_SHA256 (hash esperado de por.traineddata). Os valores são configuração local do processo, não vêm do documento. A DLL PDFium permanece em bin/pdfium/bin/pdfium.dll. Não derive os hashes de um download desconhecido e trate-os como aprovação da distribuição. A opção Importar PDF ou imagem com revisão OCR reconhece em segundo plano, apresenta cada página que exige revisão e só depois prepara e grava a base. Cancelar a revisão preserva a base anterior.

OcrVclFlowProbe.dpr requer app, src e experimental/ocr no caminho de pesquisa. Recebe seis caminhos absolutos: PDF, executável OCR, pasta de idioma, pasta de trabalho, DLL PDFium e relatório. Usa OCR e embeddings reais; o runtime local de modelos deve estar ativo e o modelo de embeddings do percurso principal disponível. As escolhas de revisão são automatizadas. A base de teste tem nome próprio na pasta de trabalho; não mede qualidade de respostas nem legibilidade da tela.

OcrReviewFormProbe.dpr recebe o caminho absoluto de uma prévia BMP. Exercita os handlers sem mostrar a janela: correção e proveniência, aceitação desabilitada para texto vazio e descarte permitido somente quando o reconhecimento original está vazio. Não constitui revisão humana ou inspeção visual. O formulário mostra a prévia em tamanho original, com rolagem; texto reconhecido vazio não comprova que a página física esteja branca.


## Provider OCR nativo em preparação

`Rag.WindowsOcr.pas` implementa `IOcrProvider` com Windows.Media.Ocr, leitura WIC de PNG/JPEG/BMP, cancelamento, limite de espera, referência de página e identidade do idioma escolhido pelo Windows. Não usa Tesseract ou dados linguísticos externos. Exige identidade de pacote MSIX e reconhecedor instalado no Windows. Não é o provider padrão da janela nesta versão.

A unidade compilou em Delphi 13 Win32. `WindowsOcrGuardTests.dpr` aprovou três casos: tempo inválido, cancelamento inicial e origem inválida. Isso não comprova reconhecimento. `NativeOcrTests.dpr` é a prova preparada para execução empacotada com imagem de referência, imagem branca e caminho JSON de resultado; sua execução posterior passou com imagem de referência e blank.png em pacote completo, sem manifesto de identidade embutido no EXE. Não executar esse programa sem identidade de pacote para declarar implantação aprovada.

Uma prova anterior separada (`OcrImageProbe` do livro) executou Windows.Media.Ocr empacotado e preservou responsável, negação e prazo. Esse resultado não deve ser transferido automaticamente ao novo provider ou à interação VCL. A seleção do provider nativo está integrada à VCL empacotada; a prova dos handlers é registrada separadamente da interação humana.


Na raiz dos exemplos, em terminal Delphi 13 configurado:

```powershell
dcc32 -B -U"src;experimental/ocr" -N0"bin" -E"bin" experimental/ocr/WindowsOcrGuardTests.dpr
if ($LASTEXITCODE -ne 0) { throw 'Compilação dos testes nativos falhou.' }
.\bin\WindowsOcrGuardTests.exe
```

Resultado esperado: `PASSED=3`, código de saída zero. Não instala pacote, altera certificados ou executa reconhecimento. Para compilar a prova de reconhecimento, use o mesmo comando com `experimental/ocr/NativeOcrTests.dpr`; execução exige o pacote MSIX próprio. Os argumentos são imagem de referência, imagem branca e arquivo JSON de resultado, todos fora da pasta protegida de instalação. Os arquivos app/msix/AppxManifest.xml e scripts/package-native-ocr.ps1 fornecem a composição do pacote da aplicação; assinatura e instalação são etapas separadas.


## Provider nativo empacotado validado

Em 4 de outubro, NativeOcrTests executou em MSIX com identidade própria: preservou supervisor, negação e prazo no fixture ocr-reference.png; blank.png retornou texto vazio. empty.png é arquivo de zero bytes usado para testar recusa, não uma imagem branca. A execução usou pt-BR neste Windows.

O executável do pacote completo deve ser compilado sem o manifesto MSIX embutido usado em testes de identidade externa. A identidade é fornecida pelo AppxManifest.xml do pacote; o manifesto redundante causava acesso negado neste percurso. A VCL agora escolhe TWindowsOcrProvider quando executa com identidade de pacote; fora do pacote, conserva o provider externo configurado. Isso não aprova automaticamente a interação humana ou outra máquina.

## Composição do pacote da aplicação

Compile `scripts/build.ps1` e então execute `scripts/package-native-ocr.ps1 -MakeAppxPath <caminho-do-makeappx.exe-do-Windows-SDK>`. O Windows SDK fornece essa ferramenta; não é biblioteca ligada ao Delphi. O resultado `bin/RagAssistant.msix` contém apenas o EXE próprio, manifesto e ícones próprios, sem runtime Tesseract, modelos ou PDFium. O script não assina, não instala e não altera confiança.

Um MSIX de desenvolvimento precisa de assinatura que corresponda ao Publisher do manifesto e confiança no certificado na máquina de instalação. Não distribua chave privada ou certificado de teste pelo Git. Assinatura, instalação e primeira abertura em outra máquina precisam de validação própria. Dentro do pacote, a VCL usa Windows.Media.Ocr; fora do pacote, conserva Tesseract configurado, pela diferença de requisitos de implantação. Configure uma pasta gravável em RAG_OCR_WORK para o lote e revise o texto antes da gravação.

Validação integrada de 4 de outubro de 2026: OcrVclFlowProbe empacotado passou com ocr-reference.png (um documento) e mixed.pdf (dois documentos, incluindo página renderizada). Reconhecimento, embeddings, persistência e proveniência reais; cancelamento preservou a base e fechamento durante trabalho foi recusado. Não equivale a aprovação humana da janela.
