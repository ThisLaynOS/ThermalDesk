# Relatório de refatoração ThermalDesk

Aplicada a identidade ThermalDesk ao pacote Dart, interface, documentação, nomes nativos e identificadores das plataformas. Android usa `com.laynos.thermaldesk`. O rodapé apresenta “ThermalDesk v2.1.0 • ZPL II | Feito com ❤️ por LaynOS”.

Os campos de IP começam vazios e a porta predefinida continua a ser 9100. Exemplos: Produto Exemplo, EAN de treze zeros, preços R$ 0,00 e QR Code https://exemplo.local. Os campos continuam editáveis.

Os logótipos anteriores e as fotografias sem utilização foram removidos; os ícones usam a nova logo abstrata aprovada, com fonte em `assets/branding/thermaldesk-abstract.png`.

## Validação

- Pesquisa em todos os ficheiros textuais atuais, incluindo ficheiros ocultos: nenhuma ocorrência da marca anterior ou dos termos corporativos solicitados; nenhum endereço IPv4 literal residual.
- Imports locais resolvidos; JSON e XML/plist/SVG analisados com sucesso.
- Preservados UTF-8, ^CI28, ^FB, ^BCN e envio por Socket. A auditoria funcional posterior corrigiu a aplicação do perfil, o tamanho dos códigos e a validação dos dados; consulte `AUDIT_REPORT.md`.
- Perfis originais de 200/203/300 DPI preservados; acrescentado o perfil 102×152 mm a 300 DPI. A leitura de configurações guardadas foi reforçada.
- git diff --check sem erros.
- Flutter 3.47.7 e Dart 3.13.5 instalados; Java 21 e SDK Android configurados.
- `flutter analyze`: sem problemas.
- `flutter test`: testes aprovados (46 após a auditoria funcional), cobrindo templates, dados predefinidos, envio TCP UTF-8 e abertura da interface/menu.
- `flutter build apk --debug`: APK gerado com identificador `com.laynos.thermaldesk` e nome ThermalDesk.
- `flutter build linux --release`: compilação concluída; aplicação executada e inspecionada num ecrã virtual.
- APIs descontinuadas de reordenação e seleção de tamanhos atualizadas; função privada sem uso removida.
- Requisitos mínimos declarados: Flutter 3.47 / Dart 3.13. Versão do produto declarada como 2.1.0+1.
- Validação física numa impressora não executada; o teste TCP usa um servidor local.

A confirmação refere-se à árvore de trabalho atual e aos termos pesquisados. O histórico Git não foi alterado e não está abrangido pela higienização.

## Ficheiros alterados ou adicionados

- `README.md`
- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/laynos/thermaldesk/MainActivity.kt`
- `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
- `assets/branding/thermaldesk-abstract.png`
- `ios/Runner.xcodeproj/project.pbxproj`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@1x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@2x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-57x57@1x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-57x57@2x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@1x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@2x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png`
- `ios/Runner/Info.plist`
- `lib/app.dart`
- `lib/main.dart`
- `lib/providers/history_provider.dart`
- `lib/providers/printer_provider.dart`
- `lib/services/thermaldesk_service.dart`
- `lib/services/zpl_exporter.dart`
- `lib/ui/home_page.dart`
- `lib/ui/pages/batch_print_page.dart`
- `lib/ui/pages/dashboard_page.dart`
- `lib/ui/pages/history_page.dart`
- `lib/ui/pages/printers_page.dart`
- `lib/ui/pages/settings_page.dart`
- `lib/ui/pages/template_picker_page.dart`
- `lib/ui/widgets/history_tile.dart`
- `lib/ui/widgets/preview_card.dart`
- `lib/ui/widgets/printer_form_card.dart`
- `linux/CMakeLists.txt`
- `linux/runner/my_application.cc`
- `macos/Runner.xcodeproj/project.pbxproj`
- `macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png`
- `macos/Runner/Configs/AppInfo.xcconfig`
- `pubspec.yaml`
- `web/favicon.png`
- `web/icons/Icon-192.png`
- `web/icons/Icon-512.png`
- `web/icons/Icon-maskable-192.png`
- `web/icons/Icon-maskable-512.png`
- `web/index.html`
- `web/manifest.json`
- `windows/CMakeLists.txt`
- `windows/runner/Runner.rc`
- `windows/runner/main.cpp`
- `windows/runner/resources/app_icon.ico`
- `REFACTOR_REPORT.md` (este relatório)

## Ficheiros removidos ou movidos

Os antigos ficheiros do serviço de impressão e da MainActivity foram movidos para os caminhos novos listados acima. Todos os nove recursos gráficos antigos em assets foram removidos.

## Ficheiros adicionais da preparação do ambiente

- `analysis_options.yaml`: exclusões de diretórios gerados aplicadas pelo Flutter.
- `android/gradle.properties`: opções de compatibilidade aplicadas pelo Flutter.
- `pubspec.lock`: dependências resolvidas com o SDK instalado.
- `test/app_test.dart`: teste da identidade e abertura do menu.
- `test/thermaldesk_service_test.dart`: testes dos templates, valores predefinidos e envio TCP.
- `README.md`: instruções de execução, validação e compilação nativa.

## Artefactos locais

- Android: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (APK otimizado para testes).
- Linux: `build/artifacts/ThermalDesk-2.1.0-linux-x64.tar.gz` (extrair e executar `bundle/ThermalDesk`).

Os artefactos e SDKs não são adicionados ao controlo de versão. Flutter e Dart
estão no PATH do ambiente; SDK Android em `/opt/android-sdk` e Flutter em
`/opt/flutter-sdk/flutter`. A configuração foi preparada para o utilizador `codespace`.
`flutter pub get`, `flutter analyze` e `flutter test` também passaram com o utilizador `codespace`.
O Chrome não está instalado; a validação foi feita nas plataformas nativas.
O Gradle emite avisos de futura descontinuação das versões atuais do Gradle,
AGP e Kotlin; a compilação Android concluiu com sucesso.

## Aplicação da logo abstrata aprovada

- Logo comum em `lib/ui/widgets/thermaldesk_logo.dart`, aplicada na AppBar, Drawer e Sobre, com fundo claro para contraste em ambos os temas.
- Nova logo no README e configuração de assets Flutter.
- Ícones regenerados para Android (incluindo adaptativos), iOS, macOS, Windows e Web.
- A janela Linux carrega a mesma logo a partir dos assets incluídos no bundle.
- Removidos os recursos provisórios de identidade anteriores.

Validação da nova identidade: análise sem problemas, quatro testes aprovados, APK e bundle Linux recompilados com sucesso após limpeza dos caches de compilação. A logo incluída em ambos os pacotes foi comparada byte a byte com o PNG aprovado. Interface Linux inspecionada em execução.
