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

## Vetores e embeddings do capítulo 9

`Rag.Vectors.pas` contém matemática e busca exata locais. `Rag.Embeddings.pas` usa HTTP e JSON nativos Delphi com a interface `IEmbeddingProvider`. O adaptador desta prova chama apenas `http://127.0.0.1:11434`.

Os 20 testes matemáticos usam vetores sintéticos identificados. A demonstração usa embeddings reais: Ollama 0.30.5, `embeddinggemma:300m`, 768 dimensões, digest e prefixos em `embeddings.lock.json`. O modelo exige download e recursos locais; confira termos e requisitos em `DEPENDENCIES.md`. Não atualize a tag durante a operação. Digest diferente exige revalidação e reprocessamento da base.

```powershell
dcc32 -B -Usrc -N0bin -Ebin tests/VectorTests.dpr
bin/VectorTests.exe
ollama pull embeddinggemma:300m
dcc32 -B -Usrc -N0bin -Ebin tests/EmbeddingDemo.dpr
bin/EmbeddingDemo.exe data/corpus
```

O runtime deve estar ativo; execute `ollama serve` em outro terminal somente se não houver serviço ativo. A pasta `bin` precisa existir. A demonstração retorna candidatos até para uma pergunta sem resposta na base: similaridade não garante suficiência da evidência. Os exemplos não exigem Python nem SDK de fornecedor.

## Persistência e busca híbrida do capítulo 10

`Rag.Persistence` salva documentos, trechos, vetores e contrato em arquivos JSON locais. `Rag.Hybrid` combina posições das buscas lexical e vetorial, com filtros de acesso e detecção de versões conflitantes. Não exige biblioteca adicional.

```powershell
dcc32 -B -Usrc -N0bin -Ebin tests/PersistenceTests.dpr
bin/PersistenceTests.exe
dcc32 -B -Usrc -N0bin -Ebin tests/HybridTests.dpr
bin/HybridTests.exe
dcc32 -B -Usrc -N0bin -Ebin tests/CacheDemo.dpr
bin/CacheDemo.exe --prepare data/corpus data/updates
bin/CacheDemo.exe --offline
```

São 19 verificações de persistência com provedor sintético e 12 de fusão. `--prepare` usa o modelo real fixado no capítulo 9 e exige o runtime ativo. A prova cria oito vetores, reutiliza os oito após reabrir, atualiza devoluções de dois para três dias úteis e remove o documento de estoque da base final. Os arquivos gerados ficam em `bin`, fora do Git. O corpus original não é alterado.

`--offline` reabre a base final e usa o vetor da pergunta de prazo previamente salvo; não faz chamadas ao runtime. Pode ser executado depois de encerrar o servidor que você iniciou para a prova. Perguntas novas ainda exigem preparar seus vetores. O exemplo não gera respostas. O arquivo de consulta é um artefato de demonstração, não um cache geral de produção.

A base é limitada a 16 MiB e não é criptografada nem autenticada. Gravação por temporário não coordena escritores e não constitui prova contra toda queda de energia. Identificadores de documentos devem ser únicos. Confira contratos e limites no livro antes de adaptar a importação ao ERP.

## Preparação do contexto

`Rag.Context` seleciona trechos inteiros, aplica acesso antes da serialização e associa rótulos `F1`, `F2` etc. às fontes completas. O limite mede unidades UTF-16 do JSON serializado, incluindo metadados, e não tokens do modelo.

```powershell
dcc32 -B -Usrc -N0bin -Ebin tests/ContextTests.dpr
bin/ContextTests.exe
dcc32 -B -Usrc -N0bin -Ebin tests/ContextDemo.dpr
bin/ContextDemo.exe
```

Os 11 testes de seleção independem de runtime e base. `ContextDemo` exige a base final produzida por `CacheDemo --prepare data/corpus data/updates`, descrito acima; usa recuperação lexical local, sem chamadas ao modelo. Na prova, selecionou dois trechos de devoluções e conservou o prazo atualizado de três dias úteis. Caminhos de origem e comprimento serializado variam conforme o checkout.

JSON preserva separação e texto, mas não impede que um modelo siga instruções maliciosas do documento. Fontes selecionadas também podem ser insuficientes para responder. A integração de geração, validação de citações e avaliação de respostas ainda está em produção.

## Geração e avaliação exploratória

`Rag.Answers` exige afirmações com citações literais e resolve os rótulos usando o contexto local. Doze testes do contrato foram executados no Delphi 13. Uma citação existente não comprova que a afirmação decorre dela: a avaliação semântica continua necessária.

`Rag.Generation` implementa `IAnswerProvider` com HTTP/JSON nativos e o candidato `qwen3:1.7b`. Configuração, digest e licença estão em `generation.lock.json`. Requer download adicional de aproximadamente 1,36 GB de artefatos e recursos de execução; não é garantia de requisitos mínimos de memória. Pesos não estão neste repositório. Não altere tags durante execução. O estado da seleção ainda é exploratório.

```powershell
dcc32 -B -Usrc -N0bin -Ebin tests/AnswerTests.dpr
bin/AnswerTests.exe
ollama pull qwen3:1.7b
dcc32 -B -Usrc -N0bin -Ebin tests/GenerationProbe.dpr
bin/GenerationProbe.exe supported
bin/GenerationProbe.exe absent
dcc32 -B -Usrc -N0bin -Ebin tests/IntegratedDemo.dpr
bin/IntegratedDemo.exe data/corpus data/evaluation/questions.json
```

O runtime precisa estar ativo. A prova controlada usa um texto próprio com prazo de três dias úteis; a avaliação integrada usa os três documentos originais, onde o prazo é de dois dias úteis. Ela não modifica o corpus nem usa a base alterada do capítulo 10. Arquivos gerados ficam em `bin`.

A instrução inicial falhou na pergunta de comissão; a versão 2 aprovada na prova controlada exige conferir a informação solicitada e copiar literalmente. Dois casos aprovados não comprovam confiabilidade geral. `IntegratedDemo` informa os casos aprovados e rejeitados; a ocorrência da evidência esperada não substitui leitura de todas as afirmações.

O adaptador limita caracteres de entrada, solicita janela de 8.192 tokens e saída de até 512 tokens. Limite de caracteres não é contagem de tokens. Respostas cortadas por limite de saída são recusadas. O limite HTTP é conferido após receber a resposta. `LastResponse` contém saída bruta para diagnóstico: não registrar dados de documentos reais sem uma política adequada. Instâncias não devem ser compartilhadas entre chamadas concorrentes. Autenticação, resistência a instruções maliciosas e interface VCL ainda estão em produção.
