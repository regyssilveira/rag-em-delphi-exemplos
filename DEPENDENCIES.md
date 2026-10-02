# Dependências dos exemplos

## PDFium para extração PDF

O texto e a lógica de recuperação continuam em Delphi 13. A leitura de PDF usa a API C de PDFium, com declarações Delphi próprias. A API Windows.Data.Pdf não fornece extração textual; escrever um interpretador geral de PDF não cabe na proposta de ensinar RAG. Essa é a exceção justificada à preferência por recursos nativos.

O pacote fixado em `pdfium.lock.json` é distribuído por bblanchon/pdfium-binaries, não é um binário oficial distribuído pelo projeto PDFium. Release `chromium/8076`, Windows x86, sem V8 e XFA, convenção C (`cdecl`). O script verifica hashes do arquivo e da DLL. Os hashes identificam a distribuição usada; não equivalem a auditoria independente de segurança.

Execute `scripts/setup-pdfium.ps1` na raiz do checkout. O script usa PowerShell, rede HTTPS e tar do Windows e instala apenas em `bin/pdfium`, ignorado pelo Git. Não altera PATH nem instala componentes no sistema. Não use esta DLL com executáveis de 64 bits; outra arquitetura precisa de pacote e validação correspondentes.

O pacote inclui LICENSE da distribuição e `licenses/` com avisos das dependências, inclusive PDFium. Preserve esses arquivos ao redistribuir o pacote. A Apache License 2.0 do repositório cobre o código próprio; não substitui as licenças do engine e suas dependências. Os binários não são versionados neste repositório.

## Dependências nativas

TXT, Markdown e DOCX utilizam recursos Delphi e Windows (incluindo MSXML 6); não exigem Word. Os documentos e fixtures são distribuídos prontos. Python e ReportLab foram usados apenas na produção editorial de fixtures, sem dependência de execução para o leitor.
