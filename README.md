# RAG em Delphi — Exemplos

Material próprio do livro de Régys Borges da Silveira. Delphi 13 é a versão mínima; licença Apache 2.0 (LICENSE). O livro explica os exemplos sem exigir download deste repositório.

## Etapa atual

Fundação em Object Pascal: leitura UTF-8, divisão com sobreposição, busca lexical simples e filtragem demonstrativa por perfil. Ainda não é o assistente completo: VCL, persistência, DOCX, PDF, OCR, embeddings e geração estão em desenvolvimento. A pontuação atual é uma referência didática por proporção de termos, não BM25 nem busca semântica. Encontrar termos não prova que a pergunta tem resposta.

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
