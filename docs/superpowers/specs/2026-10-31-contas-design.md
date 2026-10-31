# Contas — Design

App pessoal para administrar contas a pagar (foco) e gastos/receitas (secundário).
Plataformas: Android (principal) e Linux desktop. Uma base de código Flutter.

## Decisões

- **Stack:** Flutter (já instalado). Android + Linux desktop.
- **Dados:** locais em SQLite, por dispositivo. Sem nuvem, sem login.
  - Android: `sqflite`. Linux: `sqflite_common_ffi` (mesma API).
- **Transferência entre aparelhos:** exportar/importar backup JSON.
- **Lembretes:**
  - Android: `flutter_local_notifications`, uma notificação por conta em aberto às 09:00, X dias antes do vencimento (X configurável, padrão 1).
  - Linux: sem notificação agendada (não suportado pelo plugin). Ao abrir o app, diálogo listando contas atrasadas e que vencem em até X dias.
- **Fora do escopo (v1):** gráficos, recorrência não mensal, nuvem/sync, senha, edição de categorias, Windows/macOS/iOS.

## Dados

Tabela `contas`:
| campo | tipo | nota |
|---|---|---|
| id | int PK | |
| descricao | text | obrigatório |
| valor | int | centavos (evita erro de ponto flutuante) |
| vencimento | text | ISO `YYYY-MM-DD` |
| recorrente | int | 0/1 — mensal |
| categoria | text | da lista fixa |
| pago_em | text null | null = em aberto |

Tabela `lancamentos`:
| campo | tipo | nota |
|---|---|---|
| id | int PK | |
| tipo | text | `receita` ou `gasto` |
| descricao | text | |
| valor | int | centavos, sempre positivo |
| data | text | ISO `YYYY-MM-DD` |
| categoria | text | |
| conta_id | int null | preenchido quando gerado ao pagar conta |

Categorias fixas no código: Moradia, Alimentação, Transporte, Saúde, Lazer, Salário, Outros.

Configuração (`shared_preferences`): `dias_aviso` (int, padrão 1).

## Telas

Barra inferior com 3 abas + ícone de configurações no topo.

1. **Contas** — contas em aberto ordenadas por vencimento. Vermelho = atrasada; amarelo = vence em até `dias_aviso` dias. "+" cria; toque edita/exclui; botão "Pagar".
2. **Lançamentos** — lançamentos do mês selecionado (seletor ‹ mês ›). "+" cria receita ou gasto avulso; toque edita/exclui.
3. **Resumo** — do mês selecionado: receitas, gastos, saldo, total por categoria (gastos), e total ainda a pagar (contas em aberto com vencimento no mês).
4. **Configurações** — dias de aviso; Exportar backup; Importar backup.

## Fluxos

**Pagar conta** (uma transação):
1. `pago_em = hoje`.
2. Cria lançamento `gasto` com mesma descrição/valor/categoria, `data = hoje`, `conta_id`.
3. Se recorrente: cria nova conta com vencimento = mesmo dia do mês seguinte, limitado ao último dia do mês (31/jan → 28 ou 29/fev; o dia original não é preservado — 28/fev → 28/mar).
4. Cancela lembrete da conta paga; agenda o da nova (Android).

**Excluir conta paga:** o lançamento gerado é mantido (é histórico de gasto).

**Mudar `dias_aviso`:** reagenda todos os lembretes (Android).

**Exportar:** JSON `{versao: 1, contas: [...], lancamentos: [...], dias_aviso}`. Android: menu de compartilhar (`share_plus`). Linux: diálogo "salvar como" (`file_selector`).

**Importar:** escolhe arquivo (`file_selector`), valida `versao` e estrutura; se inválido, mostra erro e não altera nada. Se válido, confirma "substituir todos os dados?", substitui em uma transação e reagenda lembretes.

## Erros

- Formulários: descrição obrigatória, valor > 0, data obrigatória.
- Importação inválida: nada é alterado (validação antes da transação).
- Permissão de notificação negada (Android 13+): app funciona normal; destaque visual continua.

## Testes

Testes de unidade (`flutter test`) para:
- Próximo vencimento: 15/jan→15/fev, 31/jan→28/fev, 31/jan/2028→29/fev, 31/dez→31/jan.
- Resumo do mês: receitas, gastos, saldo, por categoria, a pagar.
- Backup: exportar → importar reproduz os mesmos dados; JSON inválido é rejeitado.
- Pagar conta recorrente: marca paga, cria gasto, cria próxima (banco em memória via ffi).
