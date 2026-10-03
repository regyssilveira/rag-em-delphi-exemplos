# Conferência semântica das respostas ampliadas

Esta atividade complementa `ExtendedAnswers` e os testes literais do capítulo 14. Não exige ferramenta adicional. Use um editor de texto e os três documentos fictícios de `data/corpus`.

1. Copie `data/evaluation/semantic-review-template.json` para uma pasta própria de resultados. Preserve a ficha original sem preenchimento.
2. Execute as 12 perguntas de `questions-extended.json` seguindo o README. Guarde os arquivos `extended-context-E01.json` e `extended-answer-E01.json`, e os pares equivalentes até E12, antes de outra execução.
3. Para cada pergunta, confira perfil, contexto realmente enviado e resposta bruta. Leia cada afirmação e todas as suas citações. Uma regra do documento que não chegou ao contexto não comprova suporte da resposta gerada.
4. Verifique primeiro se a citação pertence literalmente ao rótulo indicado. Depois aplique `manualCriterion`, comparando responsável, ação, objeto, condição, finalidade, negação, número e marco temporal. Os critérios aceitam paráfrases que conservem o significado; não exigem copiar a resposta de referência.
5. Preencha `reviewer`, `observedClaim`, `finding` e `reviewStatus`: `passed`, `failed` ou `inconclusive`. Registre o nome da configuração e a data em `finding`. Para várias afirmações, registre o resultado de cada uma; uma falha impede aprovar a resposta inteira.
6. Mantenha separados o resultado automático e a leitura manual. Um `OK` do avaliador não valida tudo; uma exceção do parser não é uma resposta correta de insuficiência. Registre ambos sem corrigir a resposta ou trocar seus rótulos.

A passagem de referência ajuda a conferir a regra, mas não substitui a leitura do documento completo. Para E09–E12 não há passagem permitida que responda à pergunta. Observe também recusas indevidas: o modelo pode declarar insuficiência apesar de receber evidência suficiente.

Exemplos de falhas: dizer que o supervisor **corrige o saldo** quando a fonte diz **aprova ou rejeita o ajuste**; proibir toda correção quando a fonte proíbe alterar **para esconder a diferença**; citar pendência de recebimento para responder sobre aprovação de estoque. Citações literais podem acompanhar todas essas afirmações sem sustentá-las.

Esta ficha contém critérios de avaliação, não resultados aprovados do assistente. A configuração publicada ainda possui reprovações no conjunto ampliado. Não altere as perguntas para fazê-las passar. Para documentos novos, crie outra ficha com referências próprias e preserve este conjunto como regressão.
