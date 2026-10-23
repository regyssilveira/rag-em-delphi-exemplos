# Seleção extrativa de parágrafos — validação delimitada

Implementação em avaliação, ainda não aprovada para substituir o percurso publicado.

O modo `RAG_GENERATION_PROVIDER=ollama-extractive` usa o mesmo modelo local fixado, mas solicita somente identificadores de passagens. O Delphi apresenta os parágrafos originais como afirmações e citações. Não há redação livre nem correção posterior do texto gerado. O modo `ollama` anterior permanece inalterado.

`BuildEvidenceContext` confere o vínculo exato do trecho ao documento preparado e recupera os parágrafos que o intersectam, sem unir páginas distintas. Linhas vazias e títulos Markdown delimitam parágrafos; isto não é um analisador Markdown completo. A revisão v2 conserva também título e seção como metadados para distinguir atividade e etapa, sem acrescentá-los à afirmação. Parágrafos acima de 1.000 unidades UTF-16 são omitidos e contabilizados, nunca cortados. O contexto conserva até 12 passagens dentro de 6.000 unidades serializadas, incluindo os títulos; a seleção admite até quatro. Uma omissão pode retirar evidência necessária.

O contrato elimina a transcrição de citações e a paráfrase na apresentação; a seleção ainda pode ser irrelevante, insuficiente, excessiva ou influenciada por instruções maliciosas. Ela precisa ser avaliada com perguntas respondíveis, negativas, restrições e novos processos. Não garante correção geral e não autentica o usuário.

Compile `tests/EvidenceSelectionTests.dpr` com `src` no caminho de busca. As 17 verificações determinísticas não usam modelos. Compile `tests/EvidenceSelectionEvaluation.dpr` e informe: pasta de corpus, arquivo de perguntas e pasta de saída nova. O avaliador rejeita um destino existente e preserva respostas brutas, contexto e afirmações. Interrompe na primeira falha de transporte e tem orçamento de dez minutos por conjunto. Para os documentos fictícios deste avaliador, `estoque.md` recebe supervisor e os demais operacional; essa classificação é preparação do teste, não inferência de permissão pelo código de produção.

Os documentos e critérios do corpus original não foram alterados. Uma aprovação só poderá ser declarada após concluir e revisar as execuções reais identificadas.
