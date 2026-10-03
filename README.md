# RAG em Delphi — Exemplos

Material próprio do livro de Régys Borges da Silveira. Delphi 13 é a versão mínima; licença Apache 2.0 (LICENSE). O livro explica os exemplos sem exigir download deste repositório.

## Etapa atual

O projeto contém a fundação em Object Pascal, leitores de documentos, buscas lexical e vetorial, persistência local, integração com modelos e aplicação VCL. Os exemplos foram exercitados no Delphi 13 para Windows de 32 bits, com alcances diferentes: testes sintéticos, consultas com modelos reais e handlers da janela sem interação humana. A geração ampliada conserva seis aprovações e seis falhas automáticas; a revisão visual da aplicação e a implantação acessível do OCR continuam pendentes. Encontrar trechos ou passar em um teste mínimo não comprova qualidade geral.

Comece pela fundação e avance conforme os capítulos. Os recursos adicionais são necessários apenas nas etapas que os utilizam:

| Etapa | Requisitos adicionais | O que conferir |
|---|---|---|
| Fundação | Nenhum modelo ou runtime externo | 19 verificações, fontes e perfis didáticos |
| Leitura PDF | PDFium fixado, compatível com Win32 | Páginas, texto e limites do leitor |
| Consulta integrada e VCL | Runtime e dois modelos identificados nos locks | Pergunta, contexto, afirmações, citações e abstenção |
| Revisão OCR experimental | Reconhecedor externo e português identificados | Prévia, texto original/revisado e gravação após aceitação |

Não é necessário Python para executar o percurso do leitor. Os documentos próprios e os programas de verificação estão neste repositório. O livro apresenta os conceitos e fontes essenciais para acompanhamento independente.

## Construir a aplicação em um comando

Na raiz dos exemplos, abra um terminal com o Delphi 13 configurado e execute:

```powershell
.\scripts\build.ps1 -RunFoundation
```

O script compila a aplicação VCL Win32 e executa as 19 verificações da fundação com os documentos fornecidos. Interrompe em caso de falha e não inicia a janela, instala dependências ou chama modelos. O executável fica em `bin/RagAssistant.exe`. A preparação dos modelos e dos formatos adicionais segue as seções abaixo; compilar não comprova qualidade das respostas nem funcionamento de OCR.

Se `dcc32.exe` não estiver no PATH, informe sua instalação, por exemplo:

```powershell
.\scripts\build.ps1 -CompilerPath 'C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc32.exe' -RunFoundation
```

Ajuste esse caminho para sua instalação do Delphi 13. O script resolve os arquivos em relação ao próprio repositório e também pode ser chamado de outra pasta pelo caminho completo.

## Documentos e avaliação

`data/corpus` contém procedimentos fictícios do Comércio Aurora. Não são regras legais ou fiscais. `data/evaluation/questions.json` registra perguntas, fontes e evidências esperadas; uma fonte nula significa que a base permitida não sustenta resposta. `data/updates/devolucoes-v2.md` altera o prazo interno para exercitar atualização, sem entrar na base inicial.

## Compilar e verificar a fundação

Em um terminal com Delphi 13 configurado, na raiz do repositório:

```powershell
New-Item -ItemType Directory -Force bin
dcc32 -B -U"src" -N0"bin" -E"bin" tests/FoundationTests.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
.\bin\FoundationTests.exe .\data\corpus
```

Com os documentos fornecidos, espere 19 linhas iniciadas por OK: e a mensagem TODAS AS VERIFICAÇÕES PASSARAM. O teste retorna código 0 quando passa e 1 quando falha. Não chama serviços nem exige credenciais. Confere leitura, cobertura dos trechos, busca, ausência de correspondência, acesso e argumentos inválidos. Não avalia respostas de IA nem demonstra segurança de produção: o perfil é fornecido pelo chamador e precisa vir de identidade autenticada numa integração real.

Não publicar credenciais, documentos reais ou binários gerados. Dependências adicionais, quando indispensáveis, serão identificadas e justificadas.


## Ingestão de TXT, Markdown e DOCX

`Rag.Ingestion.pas` usa System.Zip, APIs Windows e MSXML 6 do sistema, sem instalar Word ou biblioteca de terceiros. TXT/Markdown exigem UTF-8 válido. As quebras são normalizadas para LF; há limite didático de 16 MiB para texto e XML principal.

DOCX suporta o corpo principal Transitional em `word/document.xml`, parágrafos e tabelas simples. Cabeçalhos, rodapés e comentários não são extraídos. Não suporta DOCX Strict; rejeita no corpo revisões, imagens, campos, notas, controles de conteúdo, células mescladas e tabelas aninhadas quando detectados. DTD é proibida e resolução externa desativada. Esses controles não certificam segurança de qualquer ZIP/XML não confiável.

Na raiz do checkout, com bin existente e Delphi 13 configurado:

```powershell
dcc32 -B -U"src" -N0"bin" -E"bin" tests/IngestionTests.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
.\bin\IngestionTests.exe .\tests\fixtures
```

Os fixtures próprios estão prontos para uso; não exigem Python. As 14 verificações comparam texto, acentos, espaços, células e normalização e exercitam rejeições explícitas. Os programas de fundação e ingestão foram compilados e executados com sucesso no Delphi 13 Win32. Os demais recursos estão em seções próprias; estas 14 verificações avaliam somente ingestão.


## Extração de PDF

O leitor `Rag.Pdf.pas` preserva cada página e sua origem. PDFium é a única dependência externa deste incremento; a justificativa, procedência, hashes e licenças estão em `DEPENDENCIES.md` e `pdfium.lock.json`.

```powershell
.\scripts\setup-pdfium.ps1
dcc32 -B -U"src" -N0"bin" -E"bin" tests/PdfTests.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
$pdfiumDll = (Resolve-Path .\bin\pdfium\bin\pdfium.dll).Path
.\bin\PdfTests.exe $pdfiumDll .\tests\fixtures\pdf
```

As 21 verificações incluem páginas, acentos, negação, origem nos trechos, imagem sem camada textual, página branca, caminho Unicode e erros de DLL e PDF. O programa foi compilado e executado no Delphi 13 Win32. O leitor rejeita senha, limites excedidos e caracteres sem mapeamento Unicode ao converter páginas em documentos. Sem texto extraído não significa necessariamente página escaneada. Extração não reconstrói tabelas/colunas nem garante ordem visual. OCR será uma etapa específica.

## Busca lexical do capítulo 8

`Rag.Lexical.pas` implementa índice invertido e BM25 com recursos nativos Delphi. A pontuação considera somente a coleção permitida ao perfil. Não implementa autenticação nem certifica relevância de uma resposta. Compilar no ambiente Delphi 13 Win32 configurado, com `bin` existente:

```powershell
dcc32 -B -Usrc -N0bin -Ebin tests/LexicalTests.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
bin/LexicalTests.exe
dcc32 -B -Usrc -N0bin -Ebin tests/LexicalDemo.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
bin/LexicalDemo.exe data/corpus
```

São 15 verificações e quatro consultas no corpus próprio. A consulta operacional por ajuste e estoque pode recuperar devoluções sem fornecer a regra solicitada; encontrar candidatos não basta para responder. Parâmetros e limites estão descritos no capítulo. A função lexical inicial continua disponível em `Rag.Core` para comparação.

## Vetores e embeddings do capítulo 9

`Rag.Vectors.pas` contém matemática e busca exata locais. `Rag.Embeddings.pas` usa HTTP e JSON nativos Delphi com a interface `IEmbeddingProvider`. O adaptador desta prova chama apenas `http://127.0.0.1:11434`.

Os 20 testes matemáticos usam vetores sintéticos identificados. A demonstração usa embeddings reais: Ollama 0.30.5, `embeddinggemma:300m`, 768 dimensões, digest e prefixos em `embeddings.lock.json`. O modelo exige download e recursos locais; confira termos e requisitos em `DEPENDENCIES.md`. Não atualize a tag durante a operação. Digest diferente exige revalidação e reprocessamento da base.

```powershell
dcc32 -B -Usrc -N0bin -Ebin tests/VectorTests.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
bin/VectorTests.exe
ollama pull embeddinggemma:300m
dcc32 -B -Usrc -N0bin -Ebin tests/EmbeddingDemo.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
bin/EmbeddingDemo.exe data/corpus
```

O runtime deve estar ativo; execute `ollama serve` em outro terminal somente se não houver serviço ativo. A pasta `bin` precisa existir. A demonstração retorna candidatos até para uma pergunta sem resposta na base: similaridade não garante suficiência da evidência. Os exemplos não exigem Python nem SDK de fornecedor.

## Conferir os modelos antes de consultar

Depois dos downloads das etapas 9 e 11, execute na raiz dos exemplos:

```powershell
.\scripts\check-models.ps1
if ($LASTEXITCODE -ne 0) { throw 'Corrija a configuração antes de consultar.' }
```

O diagnóstico consulta somente o serviço local e compara os nomes e digests dos modelos com `embeddings.lock.json` e `generation.lock.json`. São esperadas duas mensagens `OK:`. Não instala, atualiza ou gera respostas. Se o serviço estiver indisponível, um modelo faltar ou a identidade divergir, termina com código 1; conserve o diagnóstico e siga a configuração do livro. Não altere um digest para contornar a divergência. A aprovação não verifica a versão do runtime, memória disponível, qualidade ou uma máquina limpa. A listagem usa o endpoint documentado em https://docs.ollama.com/api/tags.

## Persistência e busca híbrida do capítulo 10

`Rag.Persistence` salva documentos, trechos, vetores e contrato em arquivos JSON locais. `Rag.Hybrid` combina posições das buscas lexical e vetorial, com filtros de acesso e detecção de versões conflitantes. Não exige biblioteca adicional.

```powershell
dcc32 -B -Usrc -N0bin -Ebin tests/PersistenceTests.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
bin/PersistenceTests.exe
dcc32 -B -Usrc -N0bin -Ebin tests/HybridTests.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
bin/HybridTests.exe
dcc32 -B -Usrc -N0bin -Ebin tests/CacheDemo.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
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
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
bin/ContextTests.exe
dcc32 -B -Usrc -N0bin -Ebin tests/ContextDemo.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
bin/ContextDemo.exe
```

Os 11 testes de seleção independem de runtime e base. `ContextDemo` exige a base final produzida por `CacheDemo --prepare data/corpus data/updates`, descrito acima; usa recuperação lexical local, sem chamadas ao modelo. Na prova, selecionou dois trechos de devoluções e conservou o prazo atualizado de três dias úteis. Caminhos de origem e comprimento serializado variam conforme o checkout.

JSON preserva separação e texto, mas não impede que um modelo siga instruções maliciosas do documento. Fontes selecionadas também podem ser insuficientes para responder. A integração de geração, validação de citações e avaliação aparece nas próximas seções; os 11 testes acima não a validam.

## Geração e avaliação exploratória

`Rag.Answers` exige afirmações com citações literais e resolve os rótulos usando o contexto local. Doze testes do contrato foram executados no Delphi 13. Uma citação existente não comprova que a afirmação decorre dela: a avaliação semântica continua necessária. A validação também rejeita citações que cortam uma palavra no início ou no fim. Usa classificação Unicode nativa para letras, números e marcas combinantes; procura outra ocorrência válida quando a primeira está cortada. Isso não exige uma frase completa nem verifica condições ou finalidade da afirmação.

`Rag.Generation` implementa `IAnswerProvider` com HTTP/JSON nativos e o modelo instrucional `qwen2.5:7b`. Configuração, digest e licença estão em `generation.lock.json`. Requer download adicional de aproximadamente 4,68 GB de artefatos e recursos de execução; não é garantia de requisitos mínimos de memória. Pesos não estão neste repositório. Não altere tags durante execução. A configuração passou dois casos controlados e oito perguntas didáticas; qualidade geral ainda exige avaliação própria.

```powershell
dcc32 -B -Usrc -N0bin -Ebin tests/AnswerTests.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
bin/AnswerTests.exe
ollama pull qwen2.5:7b
dcc32 -B -Usrc -N0bin -Ebin tests/GenerationProbe.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
bin/GenerationProbe.exe supported
bin/GenerationProbe.exe absent
dcc32 -B -Usrc -N0bin -Ebin tests/IntegratedDemo.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
bin/IntegratedDemo.exe data/corpus data/evaluation/questions.json
```

O runtime precisa estar ativo. A prova controlada usa um texto próprio com prazo de três dias úteis; a avaliação integrada usa os três documentos originais, onde o prazo é de dois dias úteis. Ela não modifica o corpus nem usa a base alterada do capítulo 10. Arquivos gerados ficam em `bin`.

A instrução inicial falhou na pergunta de comissão; a versão 2 aprovada na prova controlada exige conferir a informação solicitada e copiar literalmente. Dois casos aprovados não comprovam confiabilidade geral. `IntegratedDemo` informa os casos aprovados e rejeitados; a ocorrência da evidência esperada não substitui leitura de todas as afirmações.

O adaptador limita caracteres de entrada, solicita janela de 8.192 tokens e saída de até 512 tokens. Limite de caracteres não é contagem de tokens. Respostas cortadas por limite de saída são recusadas. O limite HTTP é conferido após receber a resposta. `LastResponse` contém saída bruta para diagnóstico: não registrar dados de documentos reais sem uma política adequada. Instâncias não devem ser compartilhadas entre chamadas concorrentes. Autenticação de usuários, resistência geral a instruções maliciosas e inspeção visual da VCL permanecem pendentes.

## Apresentação de respostas e mensagem Unicode

`Rag.Presentation` mostra afirmações acompanhadas de origem, página quando disponível, trecho, posição e citação. Ausência de evidência, serviço indisponível e resposta inválida têm mensagens distintas. Oito testes estruturais e dois casos de geração controlada foram executados em Delphi 13, incluindo a conferência específica do português na resposta positiva. Não é prova visual VCL nem validação semântica geral.

```powershell
dcc32 -B -Usrc -N0bin -Ebin tests/PresentationTests.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
bin/PresentationTests.exe
dcc32 -B -Usrc -N0bin -Ebin tests/PresentationDemo.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
bin/PresentationDemo.exe supported
bin/PresentationDemo.exe absent
dcc32 -B -Usrc -N0bin -Ebin tests/JsonMessageTests.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
bin/JsonMessageTests.exe
```

O teste de apresentação com modelo exige a configuração de geração já descrita. Os demais testes não exigem runtime. Quatro verificações de JSON demonstram a preservação de acentos e aspas na mensagem interna e no envelope HTTP. O conteúdo textual enviado ao modelo usa `EncodeBelow32`, evitando apresentar acentos como escapes Unicode.

Estado atual da geração: `qwen2.5:7b`, instrução versão 11, passou dois casos controlados e as oito perguntas. Os cinco casos positivos também exigem conteúdo mínimo em `claims.text`, além de fonte e citação literal. Os três casos sem regra permitida exigem abstenção. Essas verificações e a leitura das respostas não comprovam qualidade geral ou segurança de produção. Comparações anteriores falharam e permanecem registradas no projeto editorial.

## Coordenação para a interface

`Rag.Assistant.QueryPreparedBase` reúne recuperação, fusão, contexto e geração sem acessar controles de uma janela. Exige uma base consistente, perfil conhecido e contrato de embeddings compatível. Sem trechos permitidos, devolve ausência de resposta sem chamar os modelos. A base não deve ser alterada concorrentemente à consulta.

```powershell
dcc32 -B -Usrc -N0bin -Ebin tests/AssistantTests.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
bin/AssistantTests.exe
```

Oito verificações com provedores sintéticos identificados: chamadas/origem, coleção sem acesso, perfil desconhecido, pergunta vazia, modelo incompatível e cancelamento antes ou depois de chamadas. O cancelamento é cooperativo; não interrompe HTTP em andamento. São provas de coordenação, distintas da prova real pela janela descrita abaixo.

## Projeto VCL em produção

`app/RagAssistant.dpr` cria a janela sem arquivo DFM. A consulta usa um thread próprio e provedores privados; controles são atualizados no evento de conclusão, na thread principal. Enquanto há uma operação, novas operações e fechamento são recusados. Cancelamento é cooperativo: aguarda a chamada em andamento e descarta o resultado.

```powershell
dcc32 -B -U"src;experimental/ocr" -N0bin -Ebin app/RagAssistant.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
bin/RagAssistant.exe
```

Esta etapa abre uma base já preparada, como `bin/integrated-base.json`, criada pelo exemplo de avaliação. O percurso pela janela foi executado com modelos reais em modo de teste oculto: recebimento com fonte, abstenção operacional sobre ajuste, consulta como supervisor, conferência da passagem, limpeza ao mudar perfil e cancelamento imediato. Não equivale a inspeção visual nem interação humana. O perfil é didático e não autentica um usuário do ERP.

O modo `--flow-check` conserva no relatório a coleção `responses`, com identificador de operação, status, resposta exibida e contexto completo. Consultas registram pergunta e perfil; importações deixam a pergunta vazia e registram a classificação escolhida. Os estados de cancelamento e falha continuam distinguíveis. Use esse relatório com o corpus fictício para comparar cada afirmação com as passagens disponíveis; ele contém texto dos documentos e não é um log automático da aplicação em uso normal. O registro não equivale ao envelope bruto do modelo nem aprova suporte semântico.

A janela também importa e atualiza documentos, prepara embeddings e grava a base local em segundo plano. `Rag.Import` já compõe leitura, reimportação e remoção de fontes, sem gravar a base. Quatorze verificações cobrem DOCX, PDF digital, classificação, nomes repetidos, remoção de todas as páginas e rejeição explícita de páginas sem texto. Requer o PDFium fixado para os casos PDF. O botão comum recusa páginas sem texto; o percurso OCR experimental usa outro botão e revisão explícita.

```powershell
dcc32 -B -Usrc -N0bin -Ebin tests/ImportTests.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
bin/ImportTests.exe . (Resolve-Path 'bin/pdfium/bin/pdfium.dll').Path
```

A composição de importação limita o texto agregado a 500.000 unidades UTF-16, antes da preparação dos embeddings. O limite conta a coleção resultante, descontando a origem substituída na reimportação. É um limite didático de entrada, não uma garantia de memória máxima nem de tamanho do JSON final; os leitores ainda têm seus próprios limites e materializam o arquivo atual antes dessa conferência. Três verificações adicionais cobrem o limite exato, excesso agregado e reimportação sem contagem duplicada.

## Edição da base e catálogo administrativo

`Rag.BaseEditor` conecta importação, preparação e confirmação da gravação. Dez verificações de serviço cobrem criação, reutilização, atualização, cancelamento, falha e remoção. Os embeddings desses testes são sintéticos. Remoção não chama o modelo e preserva os arquivos originais.

```powershell
dcc32 -B -Usrc -N0bin -Ebin tests/BaseEditorTests.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
bin/BaseEditorTests.exe .
```

Na janela, digite um destino JSON dentro de uma pasta gravável existente para criar a base. Selecione a classificação dos documentos antes de importar; ela é distinta do perfil da pergunta. Carregue o catálogo de origens para remover uma origem completa. A confirmação identifica o arquivo original, que permanece no disco. Depois de importar ou remover, recarregue o catálogo.

O catálogo é administrativo e lista todas as origens, inclusive as reservadas ao supervisor. Ao integrar ao ERP, exija autorização administrativa própria. Os seletores são didáticos e não autenticam usuários. Não há coordenação entre duas instâncias gravando a mesma base.

O worker permanece com `FreeOnTerminate = False`; a conclusão agenda sua liberação na thread principal por `ForceQueue`. Cancelamento é cooperativo. Uma gravação já confirmada é apresentada como concluída mesmo se chegar um pedido tardio de cancelamento.

Provas por handlers em janela oculta não aprovam layout ou interação física com os diálogos. OCR ainda está em produção. Consulte as limitações de formato, tamanho e identidade antes de importar seus próprios documentos.

## Avaliação ampliada, segurança e medição local

Os programas abaixo compilam no Delphi 13 Win32, com `src` no caminho de pesquisa. Execute da raiz deste repositório. Os programas de avaliação e geração precisam dos modelos locais identificados anteriormente; os testes do arquivo e o microbenchmark não chamam modelos.

```powershell
dcc32 -B -Usrc -N0bin -Ebin tests/RetrievalEvaluation.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
bin/RetrievalEvaluation.exe bin/integrated-base.json data/evaluation/questions-extended.json bin/retrieval-extended.json
dcc32 -B -Usrc -N0bin -Ebin tests/ExtendedAnswers.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
bin/ExtendedAnswers.exe data/corpus data/evaluation/questions-extended.json
dcc32 -B -Usrc -N0bin -Ebin tests/SecurityBoundaryTests.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
bin/SecurityBoundaryTests.exe .
dcc32 -B -Usrc -N0bin -Ebin tests/GenerationSecurityProbe.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
bin/GenerationSecurityProbe.exe bin/security-generation
dcc32 -B -Usrc -N0bin -Ebin tests/LocalBenchmark.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
bin/LocalBenchmark.exe bin/integrated-base.json bin/local-benchmark.json
```

A avaliação de recuperação guarda rankings lexical, vetorial e híbrido em cortes de 1, 3 e 6. As doze perguntas ampliadas contêm oito casos respondíveis e quatro sem evidência permitida. Na rodada observada, todos os métodos recuperaram as oito evidências no corte 6; todos também retornaram trechos nas quatro negativas. Retornar trechos não prova que exista resposta.

Na configuração publicada de geração v11, `ExtendedAnswers` terminou com seis aprovações e seis reprovações automáticas. Há citações atribuídas a rótulos incorretos, abstenção indevida e um critério de evidência que exige revisão. Mesmo uma aprovação automática pode conservar uma afirmação mais ampla que a passagem. Leia as respostas brutas e seus contextos; não altere critérios para ocultar falhas. Os arquivos de diagnóstico usam somente documentos fictícios e são substituídos na repetição: copie-os para outra pasta se precisar preservar uma rodada.

`SecurityBoundaryTests` passou cinco verificações, demonstrando também que o arquivo não é criptografado nem autenticado. Quem já pode alterar a base consegue reclassificar coerentemente seus documentos. O teste não altera permissões do Windows. `GenerationSecurityProbe` terminou com dois casos aprovados e dois reprovados: diante de ordens conflitantes, o modelo se absteve apesar de ter a regra válida. Esses programas não demonstram segurança geral.

`LocalBenchmark` replica os mesmos trechos e vetores em três tamanhos e mede construção e vinte buscas por método. Usa um vetor de documento como consulta, sem calcular embedding de pergunta, chamar geração ou medir qualidade. As médias registradas não são latência completa nem requisito mínimo de hardware. A base original permanece intacta. A inspeção visual e a revisão humana da interface continuam pendentes.

## Renderização de página PDF

Rag.Pdf também fornece RenderPdfPage: pixels BGRx com a primeira linha no topo, número de página e dimensões. Compartilha a trava PDFium com a extração. Aceita 72 a 300 dpi, no máximo 10.000 pixels por dimensão e vinte milhões de pixels. Não executa OCR nem muda a importação integrada.

Compile tests/PdfRenderTests.dpr com src e execute com três argumentos: tests/fixtures/pdf/mixed.pdf, caminho absoluto da DLL fixada e um destino BMP gravável. Seis conferências passaram: imagem consistente, página branca e rejeição de página zero, resolução fora do limite, página inexistente e arquivo protegido sem senha. Os dois arquivos BMP de saída são substituídos. O programa recusa destinos que coincidam, após normalização, com PDF, DLL ou encrypted.pdf, incluindo o bitmap adicional da página branca. Sete recusas preservaram as cópias de entrada; vínculos do sistema de arquivos não são resolvidos. Use uma pasta de saída própria. As 21 verificações anteriores de extração continuam aprovadas.

## Formato local v2 e revisão OCR experimental

A gravação agora usa formatVersion 2 e conserva estado de revisão, identidade do reconhecimento e texto reconhecido original, além do texto revisado. O leitor aceita também bases v1 sem inventar histórico OCR. Leitores antigos recusam a versão nova. Preservar o texto original pode conservar informação removida na revisão; proteja a base conforme todo o seu conteúdo.

O código próprio de experimental/ocr está ligado ao percurso de revisão da janela principal; sua distribuição continua experimental. Seus quinze testes de serviço e dezesseis de proveniência foram executados; a distribuição do reconhecedor externo continua em investigação. Nenhum runtime ou dado linguístico está incluído. Consulte experimental/ocr/README.md para os requisitos e limitações. As 19 verificações anteriores de persistência, 14 de importação e 10 de edição continuam passando.

## Importação de PDF com revisão OCR

A janela possui um percurso experimental específico para reconhecer e revisar páginas antes de gravar. Configure o reconhecedor e os hashes esperados antes de iniciar a aplicação, seguindo experimental/ocr/README.md. A distribuição do runtime continua em investigação e não acompanha o repositório. A prova dos workers usa OCR e embeddings reais com decisões automatizadas; não aprova interação humana ou layout.

Compile a aplicação com src e experimental/ocr no caminho de pesquisa:

```powershell
dcc32 -B -U"src;experimental/ocr" -N0bin -Ebin app/RagAssistant.dpr
if ($LASTEXITCODE -ne 0) {
  throw 'Compilação falhou; corrija antes de executar.'
}
```

Selecione a classificação e o destino da base; use Importar PDF ou imagem com revisão OCR. Confira cada prévia e corrija o texto antes de aceitar. Cancelar a revisão preserva a base anterior. Ignorar está disponível somente para reconhecimento vazio, que precisa ser comparado à imagem. A importação comum mantém seus controles e continua recusando páginas que precisam desse percurso.

A opção de revisão também recebe PNG, JPEG e BMP diretamente, mantendo a origem sem página numerada. Leitura e transparência usam recursos nativos do Windows; reconhecimento permanece no processo externo configurado. As fixtures próprias estão em tests/fixtures/images. Consulte os limites e a orientação JPEG em experimental/ocr/README.md.

## Medição da consulta completa

`QueryBenchmark` mede duas perguntas por rodada através do mesmo coordenador da VCL, com embeddings e geração reais. Separa reabertura, adaptadores, restante da consulta e formatação; não mede eventos ou desenho da janela. Conserva contexto, resposta e falhas no relatório. Consulte [instruções e limites](tests/QUERY_BENCHMARK.md). A prova usa a base existente e não exige biblioteca adicional de medição.

## Revisão de afirmações sem modelos

O programa `tests/ReviewContractDemo.dpr` constrói cinco respostas sintéticas e aplica `ParseAnswer`. Compile no terminal configurado do Delphi 13, na raiz do checkout:

```powershell
New-Item -ItemType Directory -Force bin | Out-Null
dcc32 -B -Usrc -Ebin -N0bin tests/ReviewContractDemo.dpr
if ($LASTEXITCODE -ne 0) { throw 'Falha na compilação' }
& .\bin\ReviewContractDemo.exe
if ($LASTEXITCODE -ne 0) { throw 'Falha no exercício' }
```

Não exige modelos, base persistida ou biblioteca adicional. Resultado literal esperado: `LITERAL_ACCEPTED=4 LITERAL_REJECTED=1`. Nos casos 1 a 3 há responsável errado, permissão sem suporte e ação/condição diferentes da regra. O caso 4 conserva o prazo e seu marco inicial. O caso 5 tem afirmação compatível, mas citação alterada e deve ser recusado. Confira as frases e passagens impressas e preencha a ficha do capítulo 14.

## Atividade final do capítulo 16

Use `data/exercises/fechamento/questions-fechamento.json` como segundo argumento de `ExtendedAnswers`, no lugar do conjunto ampliado. São cinco perguntas: liberação de recebimento, prazo de devolução, comissão ausente e aprovação de estoque nos perfis supervisor e operacional. `ficha-revisao.json` contém referências e campos vazios para sua revisão; conserve uma cópia por execução. O arquivo inclui instruções e um modelo vazio por afirmação: compare responsável, ação, procedimento, negação, exclusividade, condições e números com a passagem. Copie esse modelo para `claimsReviewed`, sem alterar a resposta bruta. Para insuficiência, confira se faltava evidência permitida ou se o gerador deixou de usar uma passagem disponível.

Para preservar séries anteriores, compile os avaliadores em uma pasta nova dentro de `bin`, usando essa pasta em `-E` e `-N0`. O gerador grava base, respostas e contextos ao lado do executável, independentemente do diretório atual. Passe caminhos completos para corpus e perguntas. Em seguida, execute `RetrievalEvaluation` com a base `extended-answers-base.json` dessa pasta, as mesmas perguntas e um caminho novo de relatório. As instruções de compilação dos dois avaliadores estão nas seções anteriores. Não reutilize a pasta de uma série que deseja conservar: os arquivos de saída são substituídos.

Na prova de 3 de outubro de 2026, com fontes e modelos identificados no projeto, quatro casos passaram e o operacional sobre aprovação de estoque falhou. A recuperação não incluiu estoque para esse perfil, mas o modelo usou a regra de recebimento para uma afirmação sobre estoque e atribuiu a citação ao trecho errado. O parser rejeitou a resposta; isso não equivale à abstenção correta. No caso supervisor, a afirmação identificou quem decide, mas omitiu a conferência da evidência da contagem, presente na citação. Confira essa condição mesmo que o teste automático informe sucesso.

A execução em console não verifica fechar e reabrir a janela. Complete também a sequência VCL do livro: importar os três documentos com suas classificações, preparar um arquivo próprio, fechar após a operação concluída, reabrir, informar o mesmo caminho e carregar o catálogo sem reimportar os originais. Verifique respostas e fontes com a ficha. Esses cinco casos complementam o conjunto ampliado; não o substituem nem comprovam qualidade geral.

## Adaptação do capítulo 14 para indústria

O documento fictício completo [inspecao-recebimento.md](data/exercises/industria/inspecao-recebimento.md) e [três perguntas de conferência](data/exercises/industria/questions-industria.json) permitem exercitar inspeção de recebimento. Prepare outra base com os três documentos comerciais e esse procedimento adicional; escolha operacional na importação. O perfil pode ler a regra, mas isso não atribui ao operador a aprovação da liberação do lote.

Confira responsável pela qualidade e a condição de conferir o registro da inspeção, os quatro dados registrados antes de encaminhar o material e insuficiência para temperatura ausente. Preserve os conjuntos originais. Use RetrievalEvaluation com a nova base, as perguntas e relatório em destino separado; esse programa não gera respostas. Execute a geração pela VCL e confira cada afirmação e sua citação com o documento, sem substituir responsável industrial pelo supervisor do recebimento comercial.

A prova delimitada de 3 de outubro de 2026 confirmou igualdade do documento impresso com o arquivo, divisão 380/60 e presença das duas passagens entre os três candidatos da busca lexical simples, além de ausência de regra de temperatura. Não executou embeddings, ranking híbrido, geração ou atividade humana pela VCL. Resultados esperados são critérios de conferência, não promessa de resposta correta. O assistente informa procedimentos e não libera lotes no ERP.

Rodada adicional em console concluída em 3 de outubro de 2026: quatro documentos, dez trechos em 380/60, adaptador publicado, duas aprovações e uma falha automática. Na liberação do lote, os três métodos colocaram primeiro um trecho começando dentro de Somente; a expressão completa esperada ficou em segundo lugar nos cortes 3/6. A resposta citou literalmente o fragmento começando em nte o responsável e trocou conferir o registro por após a inspeção. Parser literal aceitou a passagem presente; avaliador recusou a referência incompleta. Registro conservou os quatro dados, e temperatura produziu insuficiência. A rodada não verifica VCL ou revisão humana; preserve a falha ao comparar outra divisão, sem retirar palavras da referência ou corrigir a resposta bruta.

## Regressão de limites das citações

O programa adicional usa somente Delphi e fontes fictícias controladas, sem chamar modelos. Confere seis casos: início/fim de palavra cortados, passagem com palavras completas, ocorrência posterior válida e acento combinante cortado/conservado. Os 12 testes originais do contrato são preservados.

```powershell
dcc32 -B -Usrc -N0bin -Ebin tests/QuoteBoundaryTests.dpr
if ($LASTEXITCODE -ne 0) { throw 'Compilação falhou.' }
bin/QuoteBoundaryTests.exe
```

Espere seis mensagens `OK:` e `PASSED=6`. A checagem é conservadora em unidades UTF-16 e não constitui um segmentador linguístico universal. As oito perguntas integradas também passaram com a correção, mas as falhas ampliadas permanecem pendentes.
