# Imagens próprias de conferência

O documento fictício ocr-reference é disponibilizado em BMP, PNG e JPEG. As três linhas são:

Somente o supervisor pode liberar o recebimento.
Itens devolvidos não retornam automaticamente ao estoque.
O prazo interno é de 2 dias úteis.

São regras didáticas fictícias, sem validade como procedimento de uma empresa ou obrigação legal. As imagens foram produzidas para teste; não são fotografias de documentos reais. PNG e BMP conservam os mesmos pixels opacos; JPEG foi codificado com compressão e não promete igualdade de pixels.

alpha.png contém dois pixels para conferir composição sobre branco. rotated.jpg conserva os pixels da referência e declara orientação 6 nos metadados; o leitor atual deve recusá-lo. too-wide.png mede 10.001 por 1; too-many-pixels.png mede 5.000 por 4.001. unsupported.gif e empty.png conferem rejeições. invalid.png é uma entrada malformada disponibilizada para investigação adicional, sem caso configurado nas treze verificações atuais.

Compile experimental/ocr/OcrImageTests.dpr com experimental/ocr e src no caminho de pesquisa. Informe esta pasta e uma pasta própria gravável. CHECKS=13 confirma as verificações nativas; não chama OCR ou modelos. A prova VCL usa reconhecimento e embeddings reais, com decisões automatizadas. O leitor não precisa de Python para executar os exemplos.

- blank.png: imagem branca válida, 1200 x 420 pixels, sem texto. Distinguir de empty.png, que tem zero bytes e deve ser recusado pelo leitor.
