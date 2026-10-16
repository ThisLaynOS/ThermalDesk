# Auditoria funcional do ThermalDesk

## Falhas encontradas e correções

| Área | Problema | Comportamento corrigido |
| --- | --- | --- |
| Preview online | Dimensões fixas de 4×6 inches / 8 dpmm; respostas antigas podiam substituir dados novos | Perfil partilhado com o ZPL, debounce, invalidação imediata e identificação das respostas |
| Privacidade e rede | Envio automático do conteúdo e fallback para HTTP | Renderização externa só após ativar a opção na UI, exclusivamente HTTPS; erros apresentados sem bloquear impressão local |
| Preview local | Layout separado do ZPL com rotação, textos e dados decorativos diferentes | Desenho dos comandos efetivamente gerados, sem dados fictícios, mantendo a indicação de aproximação |
| Usabilidade do preview | Etiquetas compridas difíceis de ler | Zoom, reposição e rotação apenas da visualização |
| Perfil de impressão | Tamanho/DPI da configuração não eram aplicados aos templates | ^PW/^LL e escala dos campos, fontes e códigos conforme o perfil, com área partilhada pelo preview |
| Códigos | QR Code com módulo excessivo e Code128 cortado em ofertas | Ajuste do módulo ao espaço e zona livre; validação impede imprimir dados que não cabem |
| Dados | Barcode permitia introduzir delimitadores ZPL; preços e porta sem validação suficiente | Sanitização dos campos, validação de Code128/QR/preços/IP/porta e prevenção do prefixo monetário duplicado |
| Socket | Erros após abrir conexão podiam deixar recursos abertos; flush/close sem limite | Validação antes de ligar, timeouts e encerramento em finally, mantendo envio RAW TCP com bytes UTF-8 |
| Lote | Controladores recriados em cada build; lista mutável durante envio; setState após sair do ecrã | Controladores com ciclo de vida próprio, snapshot do lote, cancelamento entre etiquetas e guardas de mounted |
| Concorrência de envio | Lote e envio individual podiam correr em simultâneo | Estado de envio partilhado; botão continua bloqueado enquanto um envio cancelado termina |
| Sequências | Quantidade sem limite e controladores sem dispose | Validação e limite de 1000 itens por lote; dispose dos recursos do diálogo |
| Persistência | Registos corrompidos e carregamento assíncrono podiam perder alterações | Recuperação por registo, ordem de gravação, espera do carregamento e limite de 100 trabalhos |
| Impressoras | Remover a ativa deixava a configuração apontada à impressora removida | Seleção de outra impressora válida e preservação de uma padrão |
| Configurações | DPI e tamanho podiam divergir; UI fechava antes de guardar | Seleção coerente de perfis, validação e espera da gravação com apresentação de falhas |
| Responsividade | Dashboard, templates e lote tinham overflows em telemóvel/tablet | Grelhas com altura suficiente, títulos flexíveis e barras adaptadas à largura |
| Exportação | Utilitário sem ação na interface; nome podia conter caminhos | Ação Exportar ZPL no desktop, nome restrito à pasta de exportação e timestamps com milissegundos |
| Plataformas Apple | Faltavam descrição de acesso à rede local e permissão de cliente no sandbox macOS | Chaves de privacidade e entitlements adicionados às configurações nativas |
| Câmara | Erros de disponibilidade/permissão sem orientação no idioma da aplicação | Mensagem de recuperação e possibilidade de introdução manual do código |

Os templates continuam disponíveis no ecrã principal. As ofertas não são listadas
no lote porque os respetivos campos de preço/validade não existem nessa página.
Não é enviada uma oferta com valores fictícios através do lote.

## Validação

- `flutter analyze`: sem problemas.
- `flutter test`: 46 testes aprovados, incluindo envio TCP UTF-8 real em loopback,
  persistência, respostas fora de ordem, alterações de template/perfil, zoom/rotação,
  cancelamento/navegação durante impressão e os sete ecrãs a 320/600/1280 px.
- Todos os templates desenhados offline em teste, incluindo acentos e campos invertidos.
- Renderização HTTPS de exemplos genéricos de Produto, QR Code e Oferta validada
  contra a API real, com imagens de 406×243, 243×812 e 360×1200 dots, respetivamente.
- Ajustado o arredondamento das dimensões: o serviço usa DPI inteiro e trunca pixels;
  a conversão evita perder linhas/colunas devido à precisão do URL.
- Inspeção das imagens geradas confirmou o fim do corte do Code128 da oferta a 300 DPI.
- `git diff --check` e pesquisa de termos corporativos/IPs literais no código-fonte.

## Limites da validação

O preview local é uma aproximação dos comandos usados pelo projeto, não um emulador
completo de ZPL. Fontes e métricas do firmware podem diferir. A renderização online
exige internet e envia o conteúdo para o serviço externo, apenas quando ativada.
Não houve validação numa impressora física nem numa câmara física. Os ajustes
Apple foram verificados como configuração; este ambiente Linux não compila iOS/macOS.

## Peso do projeto

O APK anterior era um build debug universal de 163 MB. O diretório build e os SDKs
são ficheiros gerados, excluídos do Git. Os novos APKs usam release por arquitetura;
consulte os tamanhos dos artefactos no fim deste relatório. A assinatura dos builds
locais continua a ser de teste; a publicação numa loja requer configuração própria.

## Ficheiros principais

- `lib/models/label_profile.dart`, `lib/models/printer_config.dart`, `lib/models/label_job.dart`
- `lib/core/constants.dart`, `lib/core/label_validation.dart`
- `lib/services/thermaldesk_service.dart`, `lib/services/labelary_service.dart`, `lib/services/zpl_exporter.dart`
- `lib/providers/preview_provider.dart`, `lib/providers/printer_provider.dart`, `lib/providers/history_provider.dart`, `lib/providers/theme_provider.dart`
- `lib/ui/widgets/preview_card.dart`, `lib/ui/widgets/zpl_local_preview.dart`, `lib/ui/widgets/printer_form_card.dart`, `lib/ui/widgets/history_tile.dart`, `lib/ui/widgets/barcode_scanner_sheet.dart`
- `lib/ui/home_page.dart`, `lib/ui/pages/batch_print_page.dart`, `lib/ui/pages/settings_page.dart`, `lib/ui/pages/printers_page.dart`, `lib/ui/pages/dashboard_page.dart`, `lib/ui/pages/template_picker_page.dart`, `lib/ui/pages/history_page.dart`
- `ios/Runner/Info.plist`, `macos/Runner/Info.plist`, `macos/Runner/DebugProfile.entitlements`, `macos/Runner/Release.entitlements`
- `pubspec.yaml`, `pubspec.lock`, `README.md`, `REFACTOR_REPORT.md` e testes em `test/`

Referências de implementação: [API Labelary](https://labelary.com/service.html) e
[permissões de rede macOS no Flutter](https://docs.flutter.dev/platform-integration/macos/building).

## Artefactos validados

- Fonte atual (incluindo ficheiros novos, excluindo gerados): cerca de 1,75 MiB.
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`: 26.0 MB.
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`: 21.9 MB.
- `build/app/outputs/flutter-apk/app-x86_64-release.apk`: 28.6 MB.
- `build/artifacts/ThermalDesk-2.1.0-linux-x64.tar.gz`: 10.6 MB.
- APKs com identificador, nome, logo e ausência do atributo debuggable verificados. Linux recompilado e aberto em ecrã virtual sem exceções da aplicação.
- Cerca de 2,18 GB de duplicação no cache local Gradle eliminados por partilha de arquivos JAR/AAR byte a byte idênticos; caminhos e conteúdos do cache preservados.
- O build Android continua a emitir avisos de futura descontinuação das versões atuais do Gradle/AGP/Kotlin. A compilação release concluiu com sucesso.

## Designer de etiquetas

A evolução posterior está documentada em [DESIGNER_REPORT.md](DESIGNER_REPORT.md),
com templates personalizados, importação/exportação e 63 testes aprovados.
