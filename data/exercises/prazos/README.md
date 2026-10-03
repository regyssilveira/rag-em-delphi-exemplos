# Exercício: prazos de processos diferentes

Documentos próprios e fictícios. Não representam prazo legal nem compromisso comercial real. Exercício proposto: nenhum resultado de modelos é declarado neste material.

1. Preserve a base dos capítulos em seu arquivo original. Na aplicação VCL, importe os três documentos de `data/corpus` para uma nova base e acrescente `entregas.md` desta pasta, classificado como operacional. Preserve a classificação supervisor de `estoque.md`. Prepare e reabra a nova base. O campo Acesso dentro do texto não seleciona sozinho a classificação de importação.
2. Faça as duas perguntas de `questions-prazos.json` com o perfil operacional e conserve respostas e fontes. A análise de devolução deve indicar dois dias úteis após o registro, com evidência de `devolucoes.md`. A entrega deve indicar até cinco dias úteis após a confirmação do agendamento, com evidência de `entregas.md`. A palavra até faz parte do limite, não de um prazo mínimo.
3. Para observar rankings, compile `tests/RetrievalEvaluation.dpr` com `src` no caminho de busca. Use três argumentos: sua nova base, `data/exercises/prazos/questions-prazos.json` e um relatório de saída separado. O runtime de embeddings deve estar disponível. Dois casos em três cortes produzem seis linhas em cases; isso não é geração de respostas.
4. Preencha `revisao.csv` em editor de texto ou planilha. Leia cada afirmação contra sua citação, incluindo número, unidade, marco inicial e condições. Uma citação literal do prazo de entrega não sustenta prazo de devolução. Não aprove somente por conter a palavra dias.
5. Se houver falha, registre se a passagem esperada ficou fora do contexto, se a atribuição foi recusada pelo contrato ou se a afirmação contradiz/amplia a passagem. Uma abstenção também precisa ser comparada com o contexto disponível. Não altere perguntas ou critérios depois de ver a resposta sem versionar uma nova rodada.

Use destinos novos para relatórios: os programas de diagnóstico podem substituir a saída indicada. Não use o caminho da base nem do arquivo de perguntas como destino. O programa ExtendedAnswers prepara um corpus fixo; use a VCL para gerar respostas deste exercício adicional.
