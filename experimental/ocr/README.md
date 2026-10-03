# OCR e revisão — experimento

Este código próprio acompanha o capítulo 6. Ainda não está conectado à janela principal. A distribuição do reconhecedor externo continua em investigação; não há runtime nem dados linguísticos incluídos. Os hashes esperados do executável e de por.traineddata vêm de uma configuração conferida, não de texto fornecido pelo documento.

A base atual grava versão 2, com estado de revisão, identidade, texto reconhecido original e seu hash. O texto revisado alimenta os trechos. O leitor aceita também a versão 1 e não inventa histórico de OCR. Estado de revisão não autentica o revisor; hash não autentica o arquivo contra quem pode editá-lo.

Crie uma pasta bin gravável e compile OcrProvenanceTests.dpr com experimental/ocr e src no caminho de pesquisa. Execute com pasta de saída absoluta e raiz dos exemplos. As dezesseis conferências usam reconhecimento/vetores sintéticos e reabrem bin/integrated-base.json já preparado pelo percurso principal, sem chamar modelos. Preserve arquivos de teste se quiser comparar rodadas; os nomes de saída são substituídos.

Para OcrServiceTests, compile também os dois helpers e forneça runtime absoluto, tessdata absoluto, pasta de saída, imagem reconhecível, origem original, imagem branca e caminhos dos dois helpers. As quinze conferências combinam OCR real de imagens próprias com testes sintéticos de coordenação. Não representam precisão geral. Configure runtime e idioma por uma distribuição examinada antes de executar; o projeto não executa instaladores ou altera confiança do Windows.

Para OcrBatchTests.dpr, use experimental/ocr e src no caminho de pesquisa. Execute com cinco argumentos absolutos, nesta ordem: executável OCR, pasta tessdata, pasta de trabalho gravável, tests/fixtures/pdf/mixed.pdf e DLL PDFium. Este teste identifica os binários locais pelos hashes calculados na execução; isso não substitui a conferência da distribuição. As decisões de revisão são automatizadas e os vetores são sintéticos: as doze conferências demonstram coordenação, persistência e cancelamento, sem medir qualidade de respostas do modelo.

OcrReviewFormProbe.dpr recebe o caminho absoluto de uma prévia BMP. Exercita os handlers sem mostrar a janela: correção e proveniência, aceitação desabilitada para texto vazio e descarte permitido somente quando o reconhecimento original está vazio. Não constitui revisão humana ou inspeção visual. O formulário mostra a prévia em tamanho original, com rolagem; texto reconhecido vazio não comprova que a página física esteja branca.
