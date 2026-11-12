<p align="center">
  <img src="docs/icone.png" width="112" alt="Ícone do Quitado">
</p>

<h1 align="center">Quitado</h1>

<p align="center">
  Controle simples de contas a pagar — sem conta, sem nuvem, sem anúncio.
</p>

<p align="center">
  <a href="https://github.com/Langendolff/quitado/releases/latest"><img src="https://img.shields.io/github/v/release/Langendolff/quitado?label=download&color=1E5B45" alt="Última versão"></a>
  <img src="https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/plataformas-Android%20%7C%20Linux-1E5B45" alt="Plataformas">
</p>

<p align="center">
  <img src="docs/screenshots/inicio.png" width="200" alt="Início">
  <img src="docs/screenshots/contas.png" width="200" alt="Contas">
  <img src="docs/screenshots/receitas.png" width="200" alt="Receitas">
  <img src="docs/screenshots/resumo.png" width="200" alt="Resumo">
</p>

## Funcionalidades

- **Saldo acumulado:** tudo que entrou menos tudo que foi pago, sempre à vista na tela inicial.
- **Contas recorrentes e parceladas:** ao pagar uma conta mensal, a próxima já é criada; parcelas podem ter valores diferentes.
- **Lembretes:** notificação no Android antes do vencimento (o número de dias é configurável); no Linux, um aviso ao abrir o app.
- **Pagar em lote ou só uma parte:** segure para selecionar várias contas, ou pague um valor parcial e o restante continua em aberto.
- **Desfazer pagamento:** toque em uma conta paga no Resumo para reabri-la.
- **Resumo do mês:** recebido, pago, quanto sobrou e quanto ainda falta pagar.
- **Backup:** exporte e restaure todos os dados num arquivo JSON.
- **Privado:** os dados ficam só no aparelho (SQLite). Nenhum acesso à internet.

## Instalação

Baixe o arquivo da [última versão](https://github.com/Langendolff/quitado/releases/latest):

| Plataforma | Arquivo | Como instalar |
|---|---|---|
| Android | `quitado-<versão>.apk` | Abra o APK no celular e permita a instalação de fontes desconhecidas. |
| Linux (x64) | `quitado-<versão>-linux-x64.tar.gz` | Extraia e execute `quitado/contas`. |

## Compilando

Requer o [Flutter](https://docs.flutter.dev/get-started/install) 3.44 ou mais recente.

```sh
flutter pub get
flutter test               # testes
flutter run                # roda no aparelho conectado ou no desktop
flutter build apk          # gera o APK de release
flutter build linux        # gera o binário Linux
```

## Estrutura

```
lib/
  main.dart        # tema, navegação e inicialização
  db.dart          # SQLite: esquema, migrações, pagamentos e backup
  logica.dart      # regras puras (situação da conta, datas, valores)
  lembretes.dart   # notificações agendadas
  telas/           # Início, Contas, Receitas, Resumo e Configurações
test/              # testes da lógica e do banco
```
