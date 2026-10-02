# RAG em Delphi — Exemplos

Material próprio do livro de Régys Borges da Silveira. Delphi 13 é a versão mínima; licença Apache 2.0 (LICENSE). O livro explica os exemplos sem exigir download deste repositório.

## Etapa atual

Fundação em Object Pascal: leitura UTF-8 estrita, extração limitada de DOCX e PDF por página, divisão com sobreposição, busca lexical simples e filtragem demonstrativa por perfil. Ainda não é o assistente completo: VCL, persistência, OCR, embeddings e geração estão em desenvolvimento. A pontuação atual é uma referência didática por proporção de termos, não BM25 nem busca semântica. Encontrar termos não prova que a pergunta tem resposta.

## Documentos e avaliação

`data/corpus` contém procedimentos fictícios do Comércio Aurora. Não são regras legais ou fiscais. `data/evaluation/questions.json` registra perguntas, fontes e evidências esperadas; uma fonte nula significa que a base permitida não sustenta resposta. `data/updates/devolucoes-v2.md` altera o prazo interno para exercitar atualização, sem entrar na base inicial.

## Compilar e verificar a fundação

Em um terminal com Delphi 13 configurado, na raiz do repositório:

```powershell
New-Item -ItemType Directory -Force bin
dcc32 -B -U"src" -N0"bin" -E"bin" tests/FoundationTests.dpr
.\bin\FoundationTests.exe .\data\corpus
```

O teste retorna código 0 quando passa e 1 quando falha. Não chama serviços nem exige credenciais. Confere leitura, cobertura dos trechos, busca, ausência de correspondência, acesso e argumentos inválidos. Não avalia respostas de IA nem demonstra segurança de produção: o perfil é fornecido pelo chamador e precisa vir de identidade autenticada numa integração real.

Não publicar credenciais, documentos reais ou binários gerados. Dependências adicionais, quando indispensáveis, serão identificadas e justificadas.


## Ingestão de TXT, Markdown e DOCX

`Rag.Ingestion.pas` usa System.Zip, APIs Windows e MSXML 6 do sistema, sem instalar Word ou biblioteca de terceiros. TXT/Markdown exigem UTF-8 válido. As quebras são normalizadas para LF; há limite didático de 16 MiB para texto e XML principal.

DOCX suporta o corpo principal Transitional em `word/document.xml`, parágrafos e tabelas simples. Cabeçalhos, rodapés e comentários não são extraídos. Não suporta DOCX Strict; rejeita no corpo revisões, imagens, campos, notas, controles de conteúdo, células mescladas e tabelas aninhadas quando detectados. DTD é proibida e resolução externa desativada. Esses controles não certificam segurança de qualquer ZIP/XML não confiável.

Na raiz do checkout, com bin existente e Delphi 13 configurado:

```powershell
dcc32 -B -U"src" -N0"bin" -E"bin" tests/IngestionTests.dpr
.\bin\IngestionTests.exe .\tests\fixtures
```

Os fixtures próprios estão prontos para uso; não exigem Python. As 14 verificações comparam texto, acentos, espaços, células e normalização e exercitam rejeições explícitas. Os programas de fundação e ingestão foram compilados e executados com sucesso no Delphi 13 Win32. A geração de respostas, OCR e aplicação VCL continuam pendentes.


## Extração de PDF

O leitor `Rag.Pdf.pas` preserva cada página e sua origem. PDFium é a única dependência externa deste incremento; a justificativa, procedência, hashes e licenças estão em `DEPENDENCIES.md` e `pdfium.lock.json`.

```powershell
.\scripts\setup-pdfium.ps1
dcc32 -B -U"src" -N0"bin" -E"bin" tests/PdfTests.dpr
$pdfiumDll = (Resolve-Path .\bin\pdfium\bin\pdfium.dll).Path
.\bin\PdfTests.exe $pdfiumDll .\tests\fixtures\pdf
```

As 21 verificações incluem páginas, acentos, negação, origem nos trechos, imagem sem camada textual, página branca, caminho Unicode e erros de DLL e PDF. O programa foi compilado e executado no Delphi 13 Win32. O leitor rejeita senha, limites excedidos e caracteres sem mapeamento Unicode ao converter páginas em documentos. Sem texto extraído não significa necessariamente página escaneada. Extração não reconstrói tabelas/colunas nem garante ordem visual. OCR será uma etapa específica.

## Busca lexical do capítulo 8

`Rag.Lexical.pas` implementa índice invertido e BM25 com recursos nativos Delphi. A pontuação considera somente a coleção permitida ao perfil. Não implementa autenticação nem certifica relevância de uma resposta. Compilar no ambiente Delphi 13 Win32 configurado, com `bin` existente:

```powershell
dcc32 -B -Usrc -N0bin -Ebin tests/LexicalTests.dpr
bin/LexicalTests.exe
dcc32 -B -Usrc -N0bin -Ebin tests/LexicalDemo.dpr
bin/LexicalDemo.exe data/corpus
```

São 15 verificações e quatro consultas no corpus próprio. A consulta operacional por ajuste e estoque pode recuperar devoluções sem fornecer a regra solicitada; encontrar candidatos não basta para responder. Parâmetros e limites estão descritos no capítulo. A função lexical inicial continua disponível em `Rag.Core` para comparação.
