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

`Rag.Generation` implementa `IAnswerProvider` com HTTP/JSON nativos e o modelo instrucional `qwen2.5:7b`. Configuração, digest e licença estão em `generation.lock.json`. Requer download adicional de aproximadamente 4,68 GB de artefatos e recursos de execução; não é garantia de requisitos mínimos de memória. Pesos não estão neste repositório. Não altere tags durante execução. A configuração passou dois casos controlados e oito perguntas didáticas; qualidade geral ainda exige avaliação própria.

```powershell
dcc32 -B -Usrc -N0bin -Ebin tests/AnswerTests.dpr
bin/AnswerTests.exe
ollama pull qwen2.5:7b
dcc32 -B -Usrc -N0bin -Ebin tests/GenerationProbe.dpr
bin/GenerationProbe.exe supported
bin/GenerationProbe.exe absent
dcc32 -B -Usrc -N0bin -Ebin tests/IntegratedDemo.dpr
bin/IntegratedDemo.exe data/corpus data/evaluation/questions.json
```

O runtime precisa estar ativo. A prova controlada usa um texto próprio com prazo de três dias úteis; a avaliação integrada usa os três documentos originais, onde o prazo é de dois dias úteis. Ela não modifica o corpus nem usa a base alterada do capítulo 10. Arquivos gerados ficam em `bin`.

A instrução inicial falhou na pergunta de comissão; a versão 2 aprovada na prova controlada exige conferir a informação solicitada e copiar literalmente. Dois casos aprovados não comprovam confiabilidade geral. `IntegratedDemo` informa os casos aprovados e rejeitados; a ocorrência da evidência esperada não substitui leitura de todas as afirmações.

O adaptador limita caracteres de entrada, solicita janela de 8.192 tokens e saída de até 512 tokens. Limite de caracteres não é contagem de tokens. Respostas cortadas por limite de saída são recusadas. O limite HTTP é conferido após receber a resposta. `LastResponse` contém saída bruta para diagnóstico: não registrar dados de documentos reais sem uma política adequada. Instâncias não devem ser compartilhadas entre chamadas concorrentes. Autenticação, resistência a instruções maliciosas e interface VCL ainda estão em produção.

## Apresentação de respostas e mensagem Unicode

`Rag.Presentation` mostra afirmações acompanhadas de origem, página quando disponível, trecho, posição e citação. Ausência de evidência, serviço indisponível e resposta inválida têm mensagens distintas. Oito testes estruturais e dois casos de geração controlada foram executados em Delphi 13, incluindo a conferência específica do português na resposta positiva. Não é prova visual VCL nem validação semântica geral.

```powershell
dcc32 -B -Usrc -N0bin -Ebin tests/PresentationTests.dpr
bin/PresentationTests.exe
dcc32 -B -Usrc -N0bin -Ebin tests/PresentationDemo.dpr
bin/PresentationDemo.exe supported
bin/PresentationDemo.exe absent
dcc32 -B -Usrc -N0bin -Ebin tests/JsonMessageTests.dpr
bin/JsonMessageTests.exe
```

O teste de apresentação com modelo exige a configuração de geração já descrita. Os demais testes não exigem runtime. Quatro verificações de JSON demonstram a preservação de acentos e aspas na mensagem interna e no envelope HTTP. O conteúdo textual enviado ao modelo usa `EncodeBelow32`, evitando apresentar acentos como escapes Unicode.

Estado atual da geração: `qwen2.5:7b`, instrução versão 11, passou dois casos controlados e as oito perguntas. Os cinco casos positivos também exigem conteúdo mínimo em `claims.text`, além de fonte e citação literal. Os três casos sem regra permitida exigem abstenção. Essas verificações e a leitura das respostas não comprovam qualidade geral ou segurança de produção. Comparações anteriores falharam e permanecem registradas no projeto editorial.

## Coordenação para a interface

`Rag.Assistant.QueryPreparedBase` reúne recuperação, fusão, contexto e geração sem acessar controles de uma janela. Exige uma base consistente, perfil conhecido e contrato de embeddings compatível. Sem trechos permitidos, devolve ausência de resposta sem chamar os modelos. A base não deve ser alterada concorrentemente à consulta.

```powershell
dcc32 -B -Usrc -N0bin -Ebin tests/AssistantTests.dpr
bin/AssistantTests.exe
```

Oito verificações com provedores sintéticos identificados: chamadas/origem, coleção sem acesso, perfil desconhecido, pergunta vazia, modelo incompatível e cancelamento antes ou depois de chamadas. O cancelamento é cooperativo; não interrompe HTTP em andamento. São provas de coordenação, distintas da prova real pela janela descrita abaixo.

## Projeto VCL em produção

`app/RagAssistant.dpr` cria a janela sem arquivo DFM. A consulta usa um thread próprio e provedores privados; controles são atualizados no evento de conclusão, na thread principal. Enquanto há uma operação, novas operações e fechamento são recusados. Cancelamento é cooperativo: aguarda a chamada em andamento e descarta o resultado.

```powershell
dcc32 -B -Usrc -N0bin -Ebin app/RagAssistant.dpr
bin/RagAssistant.exe
```

Esta etapa abre uma base já preparada, como `bin/integrated-base.json`, criada pelo exemplo de avaliação. O percurso pela janela foi executado com modelos reais em modo de teste oculto: recebimento com fonte, abstenção operacional sobre ajuste, consulta como supervisor, conferência da passagem, limpeza ao mudar perfil e cancelamento imediato. Não equivale a inspeção visual nem interação humana. O perfil é didático e não autentica um usuário do ERP.

A janela também importa e atualiza documentos, prepara embeddings e grava a base local em segundo plano. `Rag.Import` já compõe leitura, reimportação e remoção de fontes, sem gravar a base. Quatorze verificações cobrem DOCX, PDF digital, classificação, nomes repetidos, remoção de todas as páginas e rejeição explícita de páginas sem texto. Requer o PDFium fixado para os casos PDF. OCR permanece pendente.

```powershell
dcc32 -B -Usrc -N0bin -Ebin tests/ImportTests.dpr
bin/ImportTests.exe . (Resolve-Path 'bin/pdfium/bin/pdfium.dll').Path
```

A composição de importação limita o texto agregado a 500.000 unidades UTF-16, antes da preparação dos embeddings. O limite conta a coleção resultante, descontando a origem substituída na reimportação. É um limite didático de entrada, não uma garantia de memória máxima nem de tamanho do JSON final; os leitores ainda têm seus próprios limites e materializam o arquivo atual antes dessa conferência. Três verificações adicionais cobrem o limite exato, excesso agregado e reimportação sem contagem duplicada.

## Edição da base e catálogo administrativo

`Rag.BaseEditor` conecta importação, preparação e confirmação da gravação. Dez verificações de serviço cobrem criação, reutilização, atualização, cancelamento, falha e remoção. Os embeddings desses testes são sintéticos. Remoção não chama o modelo e preserva os arquivos originais.

```powershell
dcc32 -B -Usrc -N0bin -Ebin tests/BaseEditorTests.dpr
bin/BaseEditorTests.exe .
```

Na janela, digite um destino JSON dentro de uma pasta gravável existente para criar a base. Selecione a classificação dos documentos antes de importar; ela é distinta do perfil da pergunta. Carregue o catálogo de origens para remover uma origem completa. A confirmação identifica o arquivo original, que permanece no disco. Depois de importar ou remover, recarregue o catálogo.

O catálogo é administrativo e lista todas as origens, inclusive as reservadas ao supervisor. Ao integrar ao ERP, exija autorização administrativa própria. Os seletores são didáticos e não autenticam usuários. Não há coordenação entre duas instâncias gravando a mesma base.

O worker permanece com `FreeOnTerminate = False`; a conclusão agenda sua liberação na thread principal por `ForceQueue`. Cancelamento é cooperativo. Uma gravação já confirmada é apresentada como concluída mesmo se chegar um pedido tardio de cancelamento.

Provas por handlers em janela oculta não aprovam layout ou interação física com os diálogos. OCR ainda está em produção. Consulte as limitações de formato, tamanho e identidade antes de importar seus próprios documentos.
