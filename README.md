# MLUSB Flutter

App em Flutter que porta o **MLUSB Mounter** (`jp.co.medialogic.usbmounter`),
gerenciador de arquivos com utilitários de disco. Totalmente em português do Brasil,
com layout moderno e tema azul royal.

## Funcionalidades

### Arquivos (File Manager)
- Navegação de pastas
- Copiar, recortar e colar (com área de transferência)
- Renomear, excluir, nova pasta
- Propriedades do arquivo/pasta
- Compartilhar arquivos

### Disco (Utilitários)
- **Verificador de disco**: verifica a leitura da unidade e detecta erros
  (modos verificar/reparar)
- **Apagador de disco**: apaga todos os dados (rápido ou completo)
- **Formatador de disco**: inicializa/formata a unidade (FAT/exFAT)

> Observação: no app original, montar/formatar usb exigia privilégios de root.
> Neste port, as operações atuam sobre pastas/dispositivos selecionados de forma
> segura, mantendo a mesma experiência visual e de fluxo.

### Backup
- Backup e restauração de dados (Fotos, Músicas, Filmes, Documentos)
- Configurações: habilitar, intervalo (horas), subpasta e tipos de arquivo
- Progresso com contador de arquivos

## Como compilar localmente

```bash
flutter pub get
flutter run          # em um dispositivo/emulador
flutter build apk --release --split-per-abi --target-platform android-arm64
```

## APK via GitHub Actions

Ao enviar código para `main`, o workflow compila o APK assinado (arm64-v8a) e o
disponibiliza como artefato. Ao criar uma tag `v*`, publica um GitHub Release.

O APK gerado fica em:
`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

> O build usa a keystore configurada via Secrets do GitHub
> (`KEYSTORE_BASE64`, `KEY_ALIAS`, `KEY_PASSWORD`, `KEYSTORE_PASSWORD`).

## Estrutura

```
lib/
├── main.dart                      # Entrada do app (tema azul royal, saída)
├── screens/
│   ├── home_screen.dart           # Navegação inferior (3 abas)
│   ├── file_manager_screen.dart   # Gerenciador de arquivos
│   ├── utilitarios_screen.dart    # Verificar/apagar/formatar disco
│   └── backup_screen.dart         # Backup e restauração
├── services/
│   ├── gerenciador_arquivos.dart  # Operações de arquivo
│   ├── utilitarios_disco.dart     # Lógica dos utilitários de disco
│   ├── servico_backup.dart        # Backup/restauração
│   └── permissao_utils.dart       # Permissão de armazenamento
└── widgets/
    ├── theme_widgets.dart         # Cards/botões no tema azul
    ├── modal_progresso.dart       # Modal de progresso
    └── dialog_sair.dart           # Confirmação de saída
```