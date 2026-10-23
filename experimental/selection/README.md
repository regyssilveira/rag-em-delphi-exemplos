# Protótipo de seleção extrativa — encerrado

Estas unidades preservam a implementação investigada em 23 de outubro de 2026. O modelo seleciona identificadores; a aplicação apresenta parágrafos originais, sem paráfrase. A versão v2 acrescenta título e seção para a seleção.

**Resultado terminal:** v1 = 9/12; v2 = 9/12. E04 teve abstenção indevida; E08 escolheu dados de conferência para registro de aprovação; E09 escolheu recebimento para correção de saldo. A configuração foi rejeitada. Não há troca do modo padrão, aprovação semântica ou teste futuro automático.

A implementação fica separada do projeto do livro. `Rag.ExtractiveAssistant` é um coordenador próprio do experimento; `src/Rag.Assistant` e `src/Rag.Generation` conservam o comportamento anterior. O lock e o registro de isolamento identificam o alcance. Não há nova biblioteca de terceiros.

Para conferir somente o contrato sem modelos, compile `tests/EvidenceSelectionTests.dpr` na raiz dos exemplos, usando Delphi 13 Win32 e `-U"experimental/selection;src"`, com diretórios de saída próprios. O programa contém 17 verificações. Os programas de avaliação e segurança permanecem para estudo; não indicam aprovação nem necessidade de repetir as rodadas rejeitadas.
