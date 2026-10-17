# ThermalDesk

<img src="assets/branding/thermaldesk-abstract.png" alt="Logo ThermalDesk" width="160">

Aplicativo para criar e imprimir etiquetas em impressoras compatíveis com ZPL II.
O envio é feito pela rede, usando o IP e a porta da impressora (padrão: 9100).

Desenvolvido por LaynOS.

## Recursos

- Templates de produto, endereço, expedição, inventário, QR Code e identificação de cabos.
- Designer com textos, Code128, QR Codes, caixas e linhas.
- Modelos personalizados com campos editáveis, importação e exportação.
- Impressão individual ou em lote, histórico e dashboard.
- Cadastro de impressoras, tamanhos de etiqueta e resoluções de 200, 203 e 300 DPI.
- Prévia local, prévia online opcional, cópia e exportação de ZPL.
- Temas claro e escuro.

## Imprimir uma etiqueta

1. Cadastre o IP e a porta da impressora e teste a conexão.
2. Escolha o tamanho do papel e o DPI da impressora.
3. Selecione um template e preencha os campos.
4. Confira a prévia e toque em **Imprimir**.

O papel padrão é 30 × 100 mm. O template Básico usa EAN-13; Expedição e
Inventário usam Code128. No Inventário, deixar a data vazia usa a data do dia.

A prévia local funciona offline. As fontes podem diferir das usadas pela
impressora; zoom e rotação da prévia não alteram o ZPL enviado.

A **Prévia online (Labelary)** é opcional e vem desativada. Quando ativada,
envia o conteúdo da etiqueta por HTTPS ao serviço externo. Uma falha nessa
prévia não impede a impressão pela rede local.

O histórico guarda os últimos 100 trabalhos. A impressão em lote usa os
campos preenchidos no início do envio. **Parar** aguarda a etiqueta em curso
e cancela as próximas. Modelos personalizados têm um formulário próprio,
com seleção da quantidade de cópias.

## Criar e compartilhar modelos

Abra **Templates e designer → Criar etiqueta** ou **Meus templates e designer**
no formulário inicial.

1. Dê um nome ao modelo e informe as medidas em milímetros.
2. Adicione os elementos e ajuste posição, tamanho, fonte e alinhamento.
3. Use **Campo editável ao usar** para os valores que mudam a cada impressão.
4. Toque em **Salvar e usar template**.

Os modelos ficam em **Meus templates**. Preencher os campos para imprimir não
altera o modelo salvo. O editor permite arrastar, redimensionar, duplicar,
desfazer e refazer, com prévia local durante a edição.

Para compartilhar, escolha **Exportar modelo ThermalDesk** e envie o arquivo
`.thermaldesk.json`. Quem receber pode usar **Importar modelo**, revisar e salvar
uma cópia. O arquivo inclui o desenho e os valores de exemplo, mas não inclui
IP, porta ou histórico da impressora.

**Exportar ZPL** e **Copiar ZPL** produzem a etiqueta preenchida para uso em
outros aplicativos compatíveis. O designer importa modelos ThermalDesk;
não converte arquivos ZPL em modelos editáveis.

São aceitos até 100 modelos, 50 elementos por modelo e arquivos de 256 KB.
As medidas vão de 10 a 200 mm de largura e de 10 a 300 mm de altura, respeitando
a capacidade da impressora. A conversão para dots usa o DPI selecionado.

## Executar o projeto

Requisitos: Flutter 3.47 ou superior e Dart 3.13 ou superior.
Para Android, configure também o SDK Android e o JDK 21.

```sh
flutter pub get
flutter run
```

Para conferir o código e executar os testes:

```sh
flutter analyze
flutter test
```

A impressão por TCP requer uma plataforma nativa com acesso à rede da impressora.
Em ambientes sem interface gráfica, execute o app em um dispositivo Android
ou em outro computador com ambiente desktop.

## Compilar

### Android

Se necessário, configure os caminhos do JDK e do SDK:

```sh
flutter config --jdk-dir=/caminho/para/jdk-21
flutter config --android-sdk=/caminho/para/android-sdk
flutter doctor --android-licenses
```

Para gerar APKs de release separados por arquitetura:

```sh
flutter build apk --release --split-per-abi
```

Os arquivos ficam em `build/app/outputs/flutter-apk/`:

- `app-arm64-v8a-release.apk`
- `app-armeabi-v7a-release.apk`
- `app-x86_64-release.apk`

O projeto usa uma chave de teste nos builds locais. Configure sua chave de
assinatura antes de publicar na loja.

### Linux

Instale `clang`, `cmake`, `ninja-build`, `pkg-config` e `libgtk-3-dev` e execute:

```sh
flutter build linux --release
```

Distribua a pasta completa `build/linux/x64/release/bundle`.
A importação e a exportação de arquivos requerem uma sessão com
`xdg-desktop-portal` e um backend, como `xdg-desktop-portal-gtk`.

### Outras plataformas

O projeto também contém configurações para iOS, macOS e Windows. A compilação
de cada plataforma requer seu ambiente nativo. No iOS, a versão mínima é 14.

## Desenvolvimento

O app usa Flutter, Riverpod, SharedPreferences e file_picker. A comunicação
com a impressora é feita por socket TCP, enviando comandos ZPL II em UTF-8.

Melhorias planejadas: importação CSV para lotes, estatísticas adicionais no
dashboard e backup na nuvem.

Para contribuir, crie uma branch com a alteração, execute a análise e os testes
e abra um pull request descrevendo o que mudou.

## Licença

MIT.
