# Dependências dos exemplos

## PDFium para extração PDF

O texto e a lógica de recuperação continuam em Delphi 13. A leitura de PDF usa a API C de PDFium, com declarações Delphi próprias. A API Windows.Data.Pdf não fornece extração textual; escrever um interpretador geral de PDF não cabe na proposta de ensinar RAG. Essa é a exceção justificada à preferência por recursos nativos.

O pacote fixado em `pdfium.lock.json` é distribuído por bblanchon/pdfium-binaries, não é um binário oficial distribuído pelo projeto PDFium. Release `chromium/8076`, Windows x86, sem V8 e XFA, convenção C (`cdecl`). O script verifica hashes do arquivo e da DLL. Os hashes identificam a distribuição usada; não equivalem a auditoria independente de segurança.

Execute `scripts/setup-pdfium.ps1` na raiz do checkout. O script usa PowerShell, rede HTTPS e tar do Windows e instala apenas em `bin/pdfium`, ignorado pelo Git. Não altera PATH nem instala componentes no sistema. Não use esta DLL com executáveis de 64 bits; outra arquitetura precisa de pacote e validação correspondentes.

O pacote inclui LICENSE da distribuição e `licenses/` com avisos das dependências, inclusive PDFium. Preserve esses arquivos ao redistribuir o pacote. A Apache License 2.0 do repositório cobre o código próprio; não substitui as licenças do engine e suas dependências. Os binários não são versionados neste repositório.

## Dependências nativas

TXT, Markdown e DOCX utilizam recursos Delphi e Windows (incluindo MSXML 6); não exigem Word. Os documentos e fixtures são distribuídos prontos. Python e ReportLab foram usados apenas na produção editorial de fixtures, sem dependência de execução para o leitor.

## Runtime e modelo de embeddings

O código de integração usa somente Delphi, HTTP e JSON nativos. A biblioteca padrão não inclui pesos treinados para representar semanticamente o corpus. O runtime Ollama executa o modelo externo; o contrato permite substituir o adaptador mediante configuração e validação próprias. Esta opção foi usada para acesso local sem chave de API, sem promoção de fornecedor.

- Runtime observado: Ollama 0.30.5. Licença MIT do projeto: https://github.com/ollama/ollama/blob/main/LICENSE.
- Modelo observado: `embeddinggemma:300m`, BF16, 768 componentes. Artefatos aproximadamente 622 MB; não é estimativa de memória total de execução. Configuração, digest e prefixos em `embeddings.lock.json`.
- Termos próprios dos pesos: Gemma Terms of Use, https://ai.google.dev/gemma/terms. A licença Apache 2.0 dos exemplos não substitui esses termos. A prova não redistribui pesos.
- Cartão do modelo: https://ai.google.dev/gemma/docs/embeddinggemma/model_card. API: https://docs.ollama.com/api/embed.
- Download inicial exige rede; a inferência da prova usa endpoint local. Tempo e recursos dependem da máquina. Não há promessa de suporte universal, gratuidade de outros serviços, precisão geral ou adequação automática à indústria.

O adaptador confere o digest na construção e usa truncamento desativado. Não existe bloqueio transacional contra alterações de tag por outro processo; evite atualizar o modelo durante preparação/consulta. Para outro modelo, não reutilize os vetores só porque a dimensão coincide.

## Modelo de geração

`qwen2.5:7b` é a configuração instrucional executada nos casos didáticos, por HTTP/JSON nativos Delphi. O Delphi não inclui os pesos treinados nem o runtime de inferência; essa é a razão da dependência externa. O adaptador `IAnswerProvider` permite outra implementação, sujeita a validação própria. A seleção considerou acesso sem chave, licença e resultados da avaliação, sem promoção de fornecedor.

- Runtime observado: Ollama 0.30.5, licença MIT já identificada acima.
- Pesos: Qwen2.5-7B-Instruct, distribuição Q4_K_M identificada por digest em `generation.lock.json`, licença Apache-2.0. Cartão oficial: https://huggingface.co/Qwen/Qwen2.5-7B-Instruct. Distribuição usada: https://ollama.com/library/qwen2.5:7b.
- Artefatos observados: 4.683.087.332 bytes, além dos pesos de embeddings. Tamanho em disco não indica memória total necessária nem requisitos mínimos comprovados. Download inicial exige rede; o percurso validado usa execução local. Pesos não acompanham o Git.
- Dois casos controlados e oito perguntas aprovados nessa configuração. Não é promessa de precisão geral, segurança, desempenho ou suporte universal. O modelo menor comparado citou o prazo, mas omitiu o valor na afirmação e foi rejeitado.
- Atualizar modelo, runtime, instrução, parâmetros ou critérios exige conferir identidade e repetir avaliação. A licença do código próprio não substitui os termos do runtime e dos pesos.

## Reconhecedor OCR em investigação

A revisão e a coordenação são código próprio Delphi. A leitura direta de PNG/JPEG/BMP usa Windows Imaging Component nativo; a renderização de PDF usa PDFium. O reconhecimento externo é investigado para o percurso VCL sem identidade de pacote: a API Windows.Media.Ocr tem requisito de implantação que ainda não foi validado no livro. Isso não significa que o reconhecimento nativo seja impossível em uma aplicação empacotada.

A prova usa Tesseract 5.5.3.20260724 x64 e Leptonica 1.87.0, em processo separado do aplicativo Delphi Win32. Não liga DLLs de reconhecimento diretamente ao programa Delphi. O pacote foi extraído para a prova, sem executar o instalador. Fonte da distribuição: release do projeto em https://github.com/tesseract-ocr/tesseract/releases/tag/5.5.3. Hashes do instalador, dos 34 artefatos na cadeia observada e do idioma estão em ocr.experimental.lock.json. A assinatura retornou UnknownError no computador de validação; o hash publicado coincidiu. Nenhum desses resultados aprova a assinatura ou a distribuição inteira.

Os dados de português vêm de tessdata_fast, revisão fixa identificada no lock. O arquivo dessa revisão coincide byte a byte com o usado nas provas. A licença Apache-2.0 do projeto e dos dados pode ser consultada em https://github.com/tesseract-ocr/tesseract/blob/5.5.3/LICENSE e https://github.com/tesseract-ocr/tessdata_fast/blob/main/LICENSE. Ela não descreve automaticamente todas as bibliotecas incluídas na distribuição.

A leitura estática de imports encontrou 34 arquivos da distribuição e onze nomes externos presentes em System32. A enumeração dos módulos do processo próprio de prova observou os mesmos 34 arquivos da distribuição. Isso confere a cadeia dessa execução; não autoriza remover os demais arquivos do pacote ou declarar um conjunto mínimo para todos os recursos. Bibliotecas e ferramentas adicionais continuam sujeitas à própria identificação.

Leptonica tem aviso próprio de redistribuição, em https://github.com/DanBloomberg/leptonica/blob/1.87.0/leptonica-license.txt. A cadeia inclui libjbig-0.dll por libtiff/Leptonica; o projeto JBIG-KIT descreve GPL e alternativas em https://www.cl.cam.ac.uk/~mgk25/jbigkit/. GNU libstdc++ tem termos e exceção de runtime próprios, em https://gcc.gnu.org/onlinedocs/libstdc++/manual/license.html. Esses avisos precisam ser conferidos para o build e a forma de distribuição pretendidos; a lista não conclui compatibilidade jurídica do conjunto.

A revisão de licenças transitivas e a implantação acessível ainda não terminaram. O repositório contém código próprio, fixtures e identificações, sem redistribuir runtime ou dados linguísticos. Os hashes do lock identificam a compatibilidade experimental e não substituem a conferência de procedência ou licença.
