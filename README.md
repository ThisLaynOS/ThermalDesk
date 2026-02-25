🦓 Zebra Label Pro

Aplicativo Android para geração e impressão de etiquetas ZPL (Zebra Programming Language).

Desenvolvido para facilitar a criação de etiquetas de produto, inventário, expedição e códigos de barras de forma rápida, moderna e intuitiva.

v2.1.0 • ZPL II
Feito com ❤️ por LaynOS

📱 Preview

Tema Escuro e Tema Claro disponíveis.

Interface moderna

Pré-visualização em tempo real da etiqueta

Visualização do código ZPL gerado

Impressão via rede (IP + Porta)

Suporte a impressoras Zebra (ZPL II)

✨ Funcionalidades

🖨 Conexão com impressoras Zebra via TCP/IP

🏷 Geração automática de etiquetas 30x100mm

📦 Templates prontos:

Básico

Produto

Endereço

Expedição

Inventário

Preço

QR Code

Cabo/Fio

📊 Dashboard

📜 Histórico de impressões

📦 Impressão em lote

🌙 Tema Escuro / ☀️ Tema Claro

👀 Visualização do código ZPL antes de imprimir

📋 Copiar ZPL para área de transferência

🧠 Como funciona

O aplicativo gera automaticamente código ZPL estruturado como:

^XA
^PW360
^LL1200
^CI28
^FWR
...
^XZ

Cada campo (título, subtítulo, código de barras) é convertido dinamicamente em comandos ZPL.

🏷 Exemplo de Código Gerado
^XA
^PW360
^LL1200
^CI28
^FWR
^FO320,15^A0R,28,28^FB1170,2,,,L^FDTítulo do Produto^FS
^FO290,15^A0R,20,20^FB1170,2,,,L^FDSubtítulo^FS
^FO210,15^BCR,60,Y,N,N^FD000000000000^FS
^FWN
^XZ
🖨 Configuração da Impressora

Insira o IP da impressora

Defina a porta (geralmente 9100)

Selecione o DPI (200 ou 203)

Teste a conexão

Imprima 🚀

📐 Suporte de Etiqueta

Tamanho padrão: 30x100mm

DPI suportado: 200/203

Layout rotacionável (horizontal/vertical)

🚀 Roadmap

 Exportar arquivo .zpl

 Salvar templates personalizados

 Importar CSV para impressão em lote

 Estatísticas avançadas no Dashboard

 Backup na nuvem

 Suporte a múltiplos tamanhos de etiqueta

🛠 Tecnologias Utilizadas

(Preencha aqui conforme você usou)

Flutter / React Native / Compose

TCP Socket

Material Design 3

ZPL II

📦 Instalação

Em breve disponível via APK ou Play Store.

🤝 Contribuição

Pull Requests são bem-vindos.

Fork o projeto

Crie uma branch (feature/nova-feature)

Commit suas alterações

Abra um Pull Request

📄 Licença

Este projeto está sob a licença MIT.

⭐ Se você gostou do projeto

Deixe uma estrela no repositório 🙌
