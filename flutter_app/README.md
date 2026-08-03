# Gestor de Plantel — Flutter

Versão nativa do Gestor de Plantel Futebol de 7 para **Android** e **Windows**.

## O que mantém da versão web

- jogadores: nome, ano, número, posição principal e secundária;
- abreviaturas GR, DD, DE, DC, MC, ED, EE, PL e AV;
- ações Inicial / Suplente / Reserva;
- cartões no campo com arrasto, redimensionamento e tamanho de letra;
- vista Plantel com disposição própria memorizada;
- edição e eliminação de jogadores;
- reordenação da lista por arrasto;
- gravação local imediata e sincronização com o mesmo JSONBlob;
- o botão Partilhar só partilha depois de confirmar a gravação online da versão mais recente;
- possibilidade de abrir outro plantel através do ID ou do link `#db=...`;
- importação de backup JSON da versão web.

## Plantel predefinido

A aplicação abre por defeito o plantel:

`019fb865-7007-7bb3-9f93-68f50bf7daa6`

O ID pode ser alterado dentro da aplicação em **Abrir outro plantel**.

## Desenvolvimento

A raiz do projeto Flutter é esta pasta. Para criar os ficheiros nativos de plataforma num computador com Flutter instalado:

```bash
flutter create --platforms=android,windows --project-name plantel_futebol7 .
flutter pub get
```

Depois:

```bash
flutter run -d windows
```

ou, com um Android ligado/emulador:

```bash
flutter run
```

## Compilar

Android:

```bash
flutter build apk --release
```

Windows:

```bash
flutter build windows --release
```

O workflow do GitHub Actions em `.github/workflows/build-flutter-app.yml` compila automaticamente os dois formatos e publica-os como artefactos da execução.
