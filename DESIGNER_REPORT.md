# Designer de etiquetas — ThermalDesk

Implementado um editor de etiquetas integrado ao catálogo, com prévia local em
cada edição, armazenamento de modelos e troca de arquivos entre instalações.

## Fluxo disponível

- **Templates e designer** no menu e **Meus templates e designer** no formulário.
- **Criar etiqueta**: papel em milímetros, textos, Code128, QR Codes, caixas e linhas.
- Seleção no canvas ou na lista; arrastar, redimensionar pelo canto, ajustar medidas,
  fonte e alinhamento; duplicar, excluir, trazer à frente, desfazer/refazer.
- Campos fixos ou editáveis no formulário de uso. É possível criar preços, datas,
  descrições e outros textos sem depender de um template de oferta predefinido.
- Salvar abre o formulário de uso e adiciona o modelo à aba **Meus templates**.
  Preenchimentos de impressão não alteram os exemplos do modelo salvo.
- Exportar `.thermaldesk.json` conserva os elementos e campos editáveis. Importar
  abre uma cópia para revisão e salvamento, com identidade nova.
- Exportar/copiar `.zpl` gera o documento preenchido, no DPI da impressora ativa,
  incluindo cópias. Outros aplicativos precisam aceitar ZPL II.
- O envio usa o serviço RAW TCP existente, o bloqueio compartilhado de impressão
  e o histórico. A quantidade aceita é de 1 a 1000 cópias.
- Produto, Preço, Oferta Gôndola e Oferta Vencimento deixam de aparecer nos
  seletores padrão, inclusive no lote. Seus índices e geradores antigos foram
  mantidos para compatibilidade; o novo tipo Personalizado foi acrescentado ao fim.

## Persistência e entrada de arquivos

Formato declarativo versionado `thermaldesk.label`, versão 1. São aceitos até
100 modelos, 50 elementos por modelo, 1024 caracteres por conteúdo e 256 KB por
arquivo. A leitura do arquivo é limitada durante o streaming. A validação rejeita
versões/tipos desconhecidos, medidas inválidas, elementos fora do papel, IDs
repetidos e caracteres de controle. O salvamento é serializado e só atualiza a
lista depois de confirmar a gravação. Registros inválidos não ocultam os válidos;
a galeria informa que houve registros não carregados.

O documento exportado contém nome, medidas, elementos e valores de exemplo.
Não contém configurações da impressora, IP, porta ou histórico. Textos são
codificados como bytes UTF-8 hexadecimais em `^FH_`/`^FD`; não são concatenados
como comandos. O designer não importa ZPL arbitrário nem executa instruções
provenientes do JSON. O renderizador local passou a interpretar os mesmos
campos hexadecimais para mostrar Unicode e símbolos corretamente.

## Validação

- `flutter analyze`: sem problemas.
- `flutter test`: **63 testes aprovados**, incluindo os 46 existentes.
- Novos testes: ida e volta do arquivo, identidade independente, três DPIs,
  escape de comandos/Unicode, importações inválidas, limites, geometria/códigos,
  cópias, campos fixos/editáveis, catálogo, persistência e recuperação.
- Testes de interface: mover/redimensionar/desfazer, atualização da prévia,
  salvar/reabrir, importar/revisar/salvar/exportar e impressão com valores atuais.
- Layout do designer nos modos editar e usar em 320, 600 e 1280 pixels; os testes
  anteriores das demais páginas continuam aprovados.
- Impressão do designer testada com serviço simulado; o teste TCP local anterior
  continua validando o serviço real. Não foi usada uma impressora física.

## Arquivos principais

Novos:

- `lib/models/custom_label.dart`
- `lib/providers/custom_labels_provider.dart`
- `lib/services/template_files.dart`
- `lib/ui/designer/label_designer_page.dart`
- `lib/ui/designer/label_canvas.dart`
- `lib/ui/designer/designer_fields.dart`
- `test/custom_label_test.dart`
- `test/label_designer_test.dart`

Integração:

- `lib/models/label_job.dart`
- `lib/services/thermaldesk_service.dart`
- `lib/ui/home_page.dart`
- `lib/ui/pages/template_picker_page.dart`
- `lib/ui/pages/batch_print_page.dart`
- `lib/ui/widgets/printer_form_card.dart`
- `lib/ui/widgets/zpl_local_preview.dart`
- `pubspec.yaml` / `pubspec.lock`
- `ios/Runner.xcodeproj/project.pbxproj`
- `macos/Runner/DebugProfile.entitlements`
- `macos/Runner/Release.entitlements`
- `test/thermaldesk_service_test.dart` / `test/local_preview_test.dart`
- `README.md`

## Compatibilidade e limites

A prévia local é aproximada; as métricas das fontes podem diferir do firmware.
O designer usa as medidas do modelo e o DPI da impressora ativa. Papel físico,
capacidade da impressora e legibilidade dos códigos devem ser verificados no
hardware. A interface bloqueia conteúdo/códigos incompatíveis com a área definida.
O modo de lote existente usa os templates padrão; personalizados têm seu próprio
formulário com cópias.

A integração de arquivos usa [file_picker 13.1.0](https://pub.dev/packages/file_picker).
O plugin requer iOS 14+, e o deployment target foi atualizado. No macOS, o
acesso de leitura/escrita é restrito aos arquivos selecionados pelo usuário,
conforme a [documentação do plugin Darwin](https://pub.dev/packages/file_picker_darwin).
Linux requer uma sessão com `xdg-desktop-portal` e backend de arquivos.
Compilação e execução de iOS/macOS/Windows não estão disponíveis neste ambiente Linux.
