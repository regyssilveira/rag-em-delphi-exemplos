# Medição de consulta completa

Compile `tests/QueryBenchmark.dpr` no Delphi 13 Win32 com `src` no caminho de pesquisa. Usa o mesmo `QueryPreparedBase` da aplicação e os adaptadores publicados, sem biblioteca adicional para medição. Requer o runtime e os dois modelos fixados já configurados, além da base preparada pelos exemplos. Não prepara documentos nem altera a base.

```powershell
dcc32 -B -Usrc -N0bin -Ebin tests/QueryBenchmark.dpr
bin/QueryBenchmark.exe bin/integrated-base.json bin/query-benchmark-rodada-1.json 3
```

São duas perguntas operacionais por rodada: responsável por liberar recebimento divergente e comissão do vendedor ausente. O terceiro argumento aceita de uma a cinco rodadas. Com três, espere seis medições e `FAILED=0`; respostas e citações passam pelo mesmo contrato da aplicação. O relatório substitui o destino indicado. Use nomes próprios para preservar rodadas; o programa recusa destino igual ao caminho da base.

O JSON conserva tempos individuais, identidades, contexto, saída bruta e texto formatado. `providersMs` inclui a conferência de modelo do provedor de embeddings; `reopenMs` inclui leitura e validação da base; `queryMs` mede a função completa, incluindo a construção dos índices. `embeddingMs` e `generationMs` medem os adaptadores, incluindo HTTP e validações, não apenas a inferência do servidor. `otherQueryMs` é a diferença entre consulta total e essas duas chamadas, abrangendo o restante do coordenador. Não é uma medição isolada da busca. `presentationMs` mede formatação de texto, sem desenhar a janela.

`totalMs` cobre criação dos provedores, reabertura, consulta e formatação. Não inclui fila, eventos ou desenho da VCL, preparação documental, gravação do relatório e liberação dos provedores. Não há aquecimento programado nem descarregamento forçado dos modelos. Registre quais modelos já estavam carregados; a primeira rodada não deve ser rotulada automaticamente como fria. Repetições são sequenciais e ordenadas, sem demonstrar simultaneidade ou produção.

Se houver erro, a linha registra etapa e mensagem, e o programa continua os casos seguintes. Não apresente uma duração de erro como tempo de resposta válida. `minimumAnswerCheck` confere o supervisor e uma citação esperada no positivo, ou abstenção sem afirmações no negativo. Essa conferência limitada não aprova qualidade semântica geral, que continua reprovada no conjunto ampliado.

As saídas conservam textos das perguntas e documentos. Esta prova usa documentos fictícios próprios. Tempos observados não estabelecem requisito mínimo de hardware nem prazo garantido. Compare condições, fontes, resultados e casos individuais antes de calcular médias.
