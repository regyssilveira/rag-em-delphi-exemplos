# Verificação manual do aplicativo VCL

Este roteiro complementa os testes de serviços e de eventos. Não está marcado como executado. Use uma cópia dos documentos fictícios e uma base descartável, preservando os originais.

## Preparação

Siga o README para compilar com Delphi 13 e preparar a base local. Registre o commit, edição do Windows, escala de tela, compilador, modelos e resultado de cada caso. Inicie `bin/RagAssistant.exe` normalmente, sem `--flow-check` ou `--admin-check`.

## Casos

| Caso | Ação pela janela | Resultado a conferir |
|---|---|---|
| M01 | Abrir a janela em escalas de 100%, 150% e 200%; reduzir até o tamanho mínimo. | Botões, campos, textos e lista de fontes continuam acessíveis; nenhum controle impede a leitura de outro. Registre cada escala separadamente. |
| M02 | Selecionar a base pelo diálogo; cancelar o diálogo e repetir confirmando a escolha. | Cancelar preserva a seleção anterior; confirmar mostra o caminho escolhido. |
| M03 | Consultar uma regra de recebimento e selecionar cada fonte. | A passagem e a identificação correspondem à fonte escolhida. Compare também cada afirmação com a passagem; uma citação válida não garante resposta correta. |
| M04 | Trocar o perfil após uma consulta. | Resposta, fontes e passagem anterior são limpas. A consulta seguinte respeita o novo perfil. |
| M05 | Importar cópias de TXT/Markdown, DOCX e PDF digital. | A base registra as origens, o texto e a classificação escolhida; o PDF mantém sua referência de página. Cancelar o diálogo não importa arquivo. |
| M06 | Reimportar uma origem modificada e remover outra, confirmando e cancelando o diálogo de remoção em tentativas separadas. | Reimportação substitui a origem sem duplicá-la; cancelamento preserva a base; confirmação remove somente a origem selecionada e não apaga o arquivo documental. |
| M07 | Fechar e reabrir o aplicativo, selecionando a mesma base. | Importações, atualização e remoção persistem. Não exigir lembrança automática do caminho: a persistência testada é a base documental. |
| M08 | Iniciar uma consulta e solicitar cancelamento imediatamente; repetir durante uma chamada em andamento. | Pedido de cancelamento permanece visível; a janela não apresenta a resposta cancelada. A chamada HTTP pode terminar ou atingir seu limite antes da liberação dos controles. |
| M09 | Tentar fechar enquanto há operação ativa; cancelar, aguardar e fechar novamente. | Primeiro fechamento é recusado com indicação de espera; depois da conclusão a janela fecha sem erro. |
| M10 | Selecionar base inválida, arquivo ausente e executar consulta com runtime indisponível. | A janela informa falha e libera os controles; a falha não aparece como resposta válida de informação insuficiente. |
| M11 | Importar imagem ou PDF digitalizado pelo percurso de OCR, com runtime validado e configurado. | Texto é apresentado para revisão antes da gravação; rejeitar/cancelar não grava documento; aceitar grava a revisão na base local. Se a instalação do OCR não estiver validada, registrar bloqueado. |

## Registro

Para cada caso, registre `aprovado`, `reprovado` ou `bloqueado`, resultado observado e evidência (captura quando visual). Não altere uma resposta do modelo antes de avaliá-la. Use também [a revisão semântica](SEMANTIC_REVIEW.md) para as respostas. Testes automáticos, compilação e execução sem erro não substituem os casos manuais acima.
