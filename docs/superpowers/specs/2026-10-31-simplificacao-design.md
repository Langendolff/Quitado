# Contas v2 — Simplificação

Substitui partes de `2026-10-31-contas-design.md`. O que não está aqui continua igual
(lembretes, aviso no Linux, recorrência mensal, configurações, export/import).

## Ideia

Um **saldo acumulado**: receitas vão somando; pagar contas abate do saldo.
Não existem mais gastos avulsos nem categorias.

`saldo = soma(receitas.valor) − soma(contas.valor onde pago_em não é null)`
Calculado na hora, nunca armazenado.

## Dados (banco versão 2)

A migração 1→2 **apaga e recria as tabelas** (dados de teste descartados; aprovado).

Tabela `contas`: id, descricao, valor (centavos), vencimento (ISO), recorrente (0/1), pago_em (ISO ou null).
Sem `categoria`.

Tabela `receitas`: id, descricao, valor (centavos, > 0), data (ISO).
Substitui `lancamentos`.

Pagar conta não cria mais lançamento: só `pago_em = hoje` (+ próxima conta, se recorrente).

## Telas (barra inferior, 4 abas; engrenagem de configurações no topo)

1. **Início** — saldo grande no topo (cor de erro se negativo); botão "+ Receita";
   lista das contas atrasadas ou que vencem em até `dias_aviso` dias, cada uma com "Pagar".
   Vazia → "Nenhuma conta próxima".
2. **Contas** — todas as contas em aberto por vencimento (vermelho = atrasada, amarelo = próxima).
   "+" adiciona; toque edita/exclui; "Pagar" individual.
   Toque longo entra em modo seleção: checkboxes e barra inferior "Pagar N contas · R$ X".
   Pagar em lote = uma transação.
3. **Receitas** — seletor ‹ mês ›, total recebido no mês, lista das receitas do mês.
   "+" adiciona (descrição, valor, data = hoje por padrão); toque edita/exclui.
4. **Resumo** — seletor ‹ mês ›: recebido, pago, sobrou (recebido − pago),
   ainda a pagar (em aberto com vencimento no mês); lista das contas pagas no mês.

## Visual

Mockups das 4 telas feitos no FigCraft antes da implementação; o Flutter segue o mockup
(paleta, tipografia, cards). Tema claro e escuro.

## Backup

`{versao: 2, dias_aviso, contas: [...], receitas: [...]}`. Importar rejeita versão ≠ 2.

## Testes

- Saldo: receitas − pagas; contas em aberto não contam.
- Pagar em lote: marca todas, cria próximas das recorrentes, contas já pagas são ignoradas.
- Resumo do mês: recebido, pago, sobrou, a pagar.
- Backup v2: ida e volta; versão 1 / JSON inválido rejeitado.
- Próximo vencimento: testes atuais mantidos.
