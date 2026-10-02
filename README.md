# RAG em Delphi — Exemplos

Material próprio do livro de Régys Borges da Silveira. Delphi 13 é a versão mínima; licença Apache 2.0 (LICENSE). O livro explica os exemplos sem exigir download deste repositório.

## Etapa atual

Fundação em Object Pascal: leitura UTF-8 estrita, extração limitada de DOCX, divisão com sobreposição, busca lexical simples e filtragem demonstrativa por perfil. Ainda não é o assistente completo: VCL, persistência, PDF, OCR, embeddings e geração estão em desenvolvimento. A pontuação atual é uma referência didática por proporção de termos, não BM25 nem busca semântica. Encontrar termos não prova que a pergunta tem resposta.

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

Os fixtures próprios estão prontos para uso; não exigem Python. As 14 verificações comparam texto, acentos, espaços, células e normalização e exercitam rejeições explícitas. Os programas de fundação e ingestão foram compilados e executados com sucesso no Delphi 13 Win32. A geração de respostas, PDF/OCR e aplicação VCL continuam pendentes.
