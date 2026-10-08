# Geração remota de referência

A aplicação e a persistência continuam em Delphi 13/VCL e em arquivos locais. A inferência remota usa HTTPS/JSON nativos; nenhum SDK é necessário. O serviço externo é necessário para executar o modelo treinado, que não acompanha o Delphi. O adaptador Gemini é uma referência intercambiável, ainda sem aprovação de fidelidade no conjunto completo.

## Configurar no PowerShell

Escolha um modelo de texto disponível na sua conta, consultando a documentação oficial. Não use um alias `latest` para registrar uma avaliação reproduzível. O adaptador conserva o identificador solicitado e a versão efetivamente retornada pela API; serviço hospedado não permite fixar os pesos por digest como no exemplo local.

```powershell
$env:RAG_GENERATION_PROVIDER = 'gemini'
$env:RAG_GENERATION_MODEL = 'IDENTIFICADOR_DISPONIVEL_NA_SUA_CONTA'
$env:GEMINI_API_KEY = Read-Host 'Chave da API' -MaskInput
```

`-MaskInput` exige PowerShell 7. A variável fica apenas na sessão e nos processos iniciados por ela. Inicie a VCL ou os testes nessa mesma sessão. Não coloque a chave em código, comandos versionados, capturas de tela ou resultados de avaliação. O aplicativo não grava a chave.

Ao selecionar `gemini`, a aplicação envia pergunta e contexto preparado ao endpoint oficial, incluindo textos e metadados dos trechos permitidos. Documentos originais e persistência permanecem locais. Os embeddings continuam no Ollama local com o modelo já fixado em `embeddings.lock.json`.

## Compilar e conferir sem consumir API

Na raiz do repositório, com Delphi 13 configurado:

```powershell
dcc32 -B -Usrc -N0bin -Ebin tests/RemoteGenerationTests.dpr
./bin/RemoteGenerationTests.exe
```

São 17 verificações de contrato usando envelopes sintéticos. Elas não comprovam conectividade HTTPS nem qualidade de um modelo real.

## Avaliar a geração real

Inicie o Ollama com o modelo de embeddings do README. Na mesma sessão em que configurou as três variáveis, compile e execute os dois conjuntos originais:

```powershell
dcc32 -B -Usrc -N0bin -Ebin tests/ExtendedAnswers.dpr
./bin/ExtendedAnswers.exe ./data/corpus ./data/evaluation/questions-extended.json
dcc32 -B -Usrc -N0bin -Ebin tests/IntegratedDemo.dpr
./bin/IntegratedDemo.exe ./data/corpus ./data/evaluation/questions.json
```

Guarde os 12 pares `extended-context-E*.json` e `extended-answer-E*.json` produzidos em `bin`, os resultados e a configuração usada antes de executar novamente. Os envelopes guardam `modelVersion`, término e uso de tokens quando fornecidos pelo serviço. A aprovação depende também da leitura técnica descrita em `tests/SEMANTIC_REVIEW.md` e do percurso VCL. A presença de citações literais não prova que a afirmação conserva seu sentido.

Os limites gratuitos e preços dependem do modelo e da conta. A aplicação não habilita cobrança, não cria contas, não repete chamadas automaticamente e não troca silenciosamente de provedor. HTTP 401/403, 429 e outros erros permanecem falhas; não são apresentados como falta de evidência nos documentos.

Para voltar ao local, use `$env:RAG_GENERATION_PROVIDER = 'ollama'`. Ausência dessa variável também conserva o comportamento local. O provedor local atual continua com reprovações semânticas conhecidas no conjunto ampliado.

Fontes oficiais:

- [Contrato REST de geração](https://ai.google.dev/api/generate-content)
- [Autenticação por chave](https://ai.google.dev/gemini-api/docs/api-key)
- [Modelos disponíveis](https://ai.google.dev/gemini-api/docs/models)
- [Preços e modalidades gratuitas](https://ai.google.dev/gemini-api/docs/pricing)

## Executar automaticamente no Windows

Depois de cadastrar `GEMINI_API_KEY` nas variáveis de usuário, execute na raiz do repositório:

```powershell
./scripts/Invoke-RemoteEvaluation.ps1 -Model 'IDENTIFICADOR_DISPONIVEL_NA_CONTA'
```

O script carrega a chave diretamente das variáveis de usuário, sem mostrá-la e sem exigir reiniciar o terminal. Compila os dois avaliadores, guarda cada execução em pasta nova e espaça as chamadas em 15 segundos. O parâmetro `-IntervalMilliseconds` permite ampliar esse intervalo. A cota depende da conta e do modelo; o intervalo não garante disponibilidade do serviço nem ausência de outros limites.

HTTP 404 pode indicar modelo indisponível para a conta mesmo que ele apareça na listagem de modelos. HTTP 429 indica limite atingido; HTTP 503 pode indicar alta demanda. Os avaliadores interrompem na primeira falha de transporte, preservando o envelope de erro com a chave removida. Não habilitam cobrança nem repetem automaticamente a chamada. Casos semanticamente reprovados continuam sendo falhas mesmo quando há conectividade.

Na conta avaliada em 08/10/2026, o serviço informou também limite gratuito de 20 chamadas por dia para `gemini-3.5-flash`. O espaçamento resolve apenas a frequência por minuto; não amplia a cota diária. Esse valor é uma observação da execução, não uma condição garantida para todos os leitores. Não é necessário habilitar cobrança para usar o adaptador; uma avaliação pode precisar ser dividida entre dias, preservando configuração, artefatos e versão efetiva do modelo. A configuração ensaiada continua reprovada semanticamente, independentemente desse limite.
