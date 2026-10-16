# ThermalDesk

<img src="assets/branding/thermaldesk-abstract.png" alt="Logo ThermalDesk" width="160">

Aplicativo Android para geração e impressão de etiquetas ZPL II via socket TCP puro (RAW TCP 9100).

Desenvolvido para facilitar a criação de etiquetas de produto,
inventário, expedição e códigos de barras de forma rápida, moderna e
intuitiva.

> ThermalDesk v2.1.0 • ZPL II | Feito com ❤️ por LaynOS

------------------------------------------------------------------------

## Executar e validar

Ambiente validado com Flutter 3.47.7 (stable), Dart 3.13.5 e Java 21.
Requisitos mínimos: Flutter 3.47 e Dart 3.13.

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d linux
```

Para Android, configure o SDK Android e um JDK 21:

```sh
flutter config --jdk-dir=/caminho/para/jdk-21
flutter config --android-sdk=/caminho/para/android-sdk
flutter doctor --android-licenses
flutter build apk --debug
```

O APK de teste fica em `build/app/outputs/flutter-apk/app-debug.apk`.
Para obter APKs menores, otimizados e separados por arquitetura:

```sh
flutter build apk --release --split-per-abi
```

Os ficheiros ficam em `build/app/outputs/flutter-apk/`. Para a maioria dos
telemóveis Android atuais, use `app-arm64-v8a-release.apk`. Estes builds locais
usam a assinatura de teste configurada no projeto; configure a sua assinatura
antes de publicar numa loja.
Para compilar no Linux, instale `clang`, `cmake`, `ninja-build`,
`pkg-config` e `libgtk-3-dev`, e execute `flutter build linux --release`.
Distribua a pasta completa `build/linux/x64/release/bundle`.

A impressão RAW TCP exige uma plataforma nativa com acesso à rede da
impressora. No Codespaces sem ambiente gráfico, use um dispositivo Android
ligado ou execute a versão desktop num computador com interface gráfica.
Configure o IP e a porta da impressora na aplicação; a porta inicial é 9100.

------------------------------------------------------------------------

## Preview e impressão

A prévia local funciona offline e desenha os comandos ZPL gerados pela aplicação,
com as dimensões e a resolução configuradas. As fontes do firmware podem ter
métricas diferentes: trata-se de uma aproximação, com zoom e rotação de visualização.
Girar a prévia não altera a etiqueta enviada à impressora.

A opção **Prévia online (Labelary)** fica desligada inicialmente. Ao ativá-la,
o conteúdo da etiqueta é enviado por HTTPS ao serviço externo. O serviço
renderiza o ZPL com o perfil escolhido; falhas de rede mantêm a prévia local
e não impedem a impressão por TCP.

O IP e a porta são validados antes do envio. QR Codes e códigos de barras que
não cabem são assinalados e impedem a impressão. No designer, as dimensões
do template definem a área de impressão; carregue papel com essas medidas.

O histórico é limitado a 100 trabalhos. O lote usa uma cópia dos dados no início
do envio; **Parar** impede a próxima etiqueta e aguarda o envio em curso.
A impressão em lote usa os templates padrão. Os modelos personalizados têm
seu próprio formulário de preenchimento e quantidade de cópias.

------------------------------------------------------------------------

## Designer de etiquetas

Abra **Menu → Templates e designer → Criar etiqueta**. Também há um botão
**Meus templates e designer** no formulário inicial.

1. Dê um nome ao modelo e defina largura e altura em milímetros.
2. Adicione **Texto**, **Código de barras (Code128)**, **QR Code**, **Caixa** ou **Linha**.
3. Selecione um elemento na etiqueta ou na lista. Arraste para mover; arraste
   o canto para redimensionar. Os campos permitem medidas precisas, tamanho
   de fonte, alinhamento e espessura da borda. Há desfazer/refazer e duplicação.
4. Ative **Campo editável ao usar** e dê um nome ao campo quando quiser trocar
   seu conteúdo a cada impressão. Desative para manter um texto fixo.
5. Toque em **Salvar e usar template**. Ele fica em **Meus templates**, inclusive
   depois de fechar e abrir o aplicativo. Preencha os campos, escolha as cópias
   e imprima. Alterar o preenchimento não modifica o modelo salvo.

A prévia do designer é **local, offline e atualizada durante a edição**. As
fontes são aproximadas, e a impressão física deve ser conferida na impressora.
O tamanho é armazenado em milímetros e convertido no DPI da impressora ativa
(200, 203 ou 300). O designer não envia o conteúdo a serviços externos.

**Compartilhar com outro ThermalDesk:** no menu de exportação, escolha
**Exportar modelo ThermalDesk**. Envie o arquivo `.thermaldesk.json` ao amigo.
Ele abre **Templates → Importar modelo**, revisa e salva. A importação cria uma
nova cópia e preserva os templates existentes. Os arquivos não contêm IP,
porta, histórico ou outras configurações da impressora. Os valores de exemplo
fazem parte do arquivo compartilhado.

**Usar em outro aplicativo ZPL:** escolha **Exportar ZPL** ou **Copiar ZPL**.
Esse arquivo contém a etiqueta preenchida, no DPI atual e com a quantidade de
cópias escolhida. O aplicativo de destino precisa aceitar ZPL II. A importação
no designer aceita o formato editável ThermalDesk; não reconstrói modelos a
partir de ZPL arbitrário.

Limites: 100 modelos, 50 elementos por etiqueta, 256 KB por arquivo importado,
largura de 10–200 mm e altura de 10–300 mm. O limite real de papel depende da
impressora. A importação valida formato, versão, medidas e conteúdo; textos
são escapados em UTF-8 com `^FH` para impedir injeção de comandos.

Produto, Oferta Gôndola e Oferta Vencimento foram removidos, inclusive o ZPL.
Preço continua fora do catálogo padrão. Preços e validade podem ser criados
como campos no designer. Um histórico antigo desses modelos abre como Básico
e conserva o ZPL que já tinha sido gravado.

O seletor de arquivos funciona nativamente em Android, iOS, Windows, macOS e
Linux. No Linux, é necessária uma sessão com `xdg-desktop-portal` e um backend
(como `xdg-desktop-portal-gtk`). iOS requer 14 ou superior; no macOS foi
habilitado o acesso de leitura/escrita apenas aos arquivos escolhidos pelo usuário.

## 📱 Preview

-   Interface moderna
-   Tema Escuro e Tema Claro
-   Pré-visualização em tempo real da etiqueta
-   Visualização do código ZPL gerado
-   Impressão via rede (IP + Porta)
-   Suporte a impressoras compatíveis com ZPL II (ZPL II)

------------------------------------------------------------------------

## ✨ Funcionalidades

-   🖨 Conexão com impressoras compatíveis com ZPL II via TCP/IP
-   🏷 Geração automática de etiquetas 30x100mm
-   📦 Templates prontos:
    -   Básico
    -   Endereço
    -   Expedição
    -   Inventário
    -   QR Code
    -   Cabo/Fio
-   🎨 Designer de etiquetas com textos, Code128, QR Codes, caixas e linhas
-   💾 Templates personalizados, campos editáveis e importação/exportação
-   📊 Dashboard
-   📜 Histórico de impressões
-   📦 Impressão em lote
-   🌙 Tema Escuro / ☀️ Tema Claro
-   👀 Visualização do código ZPL antes de imprimir
-   📋 Copiar ZPL para área de transferência

------------------------------------------------------------------------

## 🧠 Como funciona

O aplicativo gera automaticamente código ZPL estruturado como:

    ^XA
    ^PW360
    ^LL1200
    ^CI28
    ^FWR
    ...
    ^XZ

Cada campo (título, subtítulo, código de barras) é convertido
dinamicamente em comandos ZPL.

------------------------------------------------------------------------

## 🏷 Exemplo de Código Gerado

    ^XA
    ^PW360
    ^LL1200
    ^CI28
    ^FWR
    ^FO320,15^A0R,28,28^FB1170,2,,,L^FDProduto Exemplo^FS
    ^FO290,15^A0R,20,20^FB1170,2,,,L^FDSubtítulo^FS
    ^FO210,15^BCR,60,Y,N,N^FD0000000000000^FS
    ^FWN
    ^XZ

------------------------------------------------------------------------

## 🖨 Configuração da Impressora

1.  Insira o IP da impressora
2.  Defina a porta (geralmente `9100`)
3.  Selecione o DPI (200, 203 ou 300)
4.  Teste a conexão
5.  Imprima 🚀

------------------------------------------------------------------------

## 📐 Suporte de Etiqueta

-   Tamanho padrão: 30x100mm
-   DPI suportado: 200/203/300
-   Layout rotacionável (horizontal/vertical)

------------------------------------------------------------------------

## 🚀 Roadmap

-   [x] Exportar arquivo `.zpl` no desktop
-   [x] Salvar, editar e compartilhar templates personalizados
-   [ ] Importar CSV para impressão em lote
-   [ ] Estatísticas avançadas no Dashboard
-   [ ] Backup na nuvem
-   [x] Suporte a múltiplos tamanhos de etiqueta

------------------------------------------------------------------------

## 🛠 Tecnologias Utilizadas

-   Flutter / Dart
-   Riverpod / SharedPreferences
-   file_picker (seletor de arquivos nativo)
-   TCP Socket
-   Material Design 3
-   ZPL II

------------------------------------------------------------------------

## 🤝 Contribuição

Pull Requests são bem-vindos.

1.  Fork o projeto
2.  Crie uma branch (`feature/nova-feature`)
3.  Commit suas alterações
4.  Abra um Pull Request

------------------------------------------------------------------------

## 📄 Licença

Este projeto está sob a licença MIT.

------------------------------------------------------------------------

# ⭐ Se você gostou do projeto

Deixe uma estrela no repositório 🙌
