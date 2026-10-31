import 'package:flutter/material.dart';

import '../logica.dart';
import '../main.dart';
import '../models.dart';
import 'comum.dart';
import 'contas.dart';
import 'receitas.dart';

class InicioTela extends StatefulWidget {
  final VoidCallback verContas;
  const InicioTela({super.key, required this.verContas});
  @override
  State<InicioTela> createState() => _InicioTelaState();
}

class _InicioTelaState extends State<InicioTela> {
  late Future<(int, List<Conta>)> _dados = _carregar();

  Future<(int, List<Conta>)> _carregar() async => (await db.saldo(), await db.contasEmAberto());

  void _recarregar() => setState(() => _dados = _carregar());

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return carregando(_dados, (d) {
      final (saldo, abertas) = d;
      final h = hoje();
      final fimDoMes = DateTime(h.year, h.month + 1, 0);
      final aPagarMes = soma(abertas.where((c) => !c.vencimento.isAfter(fimDoMes)).map((c) => c.valor));
      final proximas = abertas.where((c) => situacao(c, h, diasAviso) != Situacao.normal).toList();
      return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
        _CartaoSaldo(
          saldo: saldo,
          aPagarMes: aPagarMes,
          novaReceita: () async {
            if (await editarReceita(context)) _recarregar();
          },
        ),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Para pagar em breve', style: t.titleMedium),
          TextButton(onPressed: widget.verContas, child: const Text('Ver todas')),
        ]),
        const SizedBox(height: 4),
        if (proximas.isEmpty) const Vazio('Nenhuma conta próxima'),
        if (proximas.isNotEmpty)
          Grupo(children: [
            for (final c in proximas)
              ContaItem(
                conta: c,
                leading: ContaItem.faixa(context, c),
                trailing: FilledButton(
                    onPressed: () async {
                      await pagarContas(context, [c]);
                      _recarregar();
                    },
                    child: const Text('Pagar')),
                onTap: () async {
                  if (await editarConta(context, c)) _recarregar();
                },
              ),
          ]),
      ]);
    });
  }
}

class _CartaoSaldo extends StatelessWidget {
  final int saldo, aPagarMes;
  final VoidCallback novaReceita;
  const _CartaoSaldo({required this.saldo, required this.aPagarMes, required this.novaReceita});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const claro = Color(0xFFA8CDBD);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: saldo < 0
              ? const [Color(0xFF9A3412), Color(0xFF6B2309)]
              : const [Color(0xFF1E5B45), Color(0xFF143A2D)],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Saldo disponível', style: t.bodyMedium?.copyWith(color: claro, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(reais(saldo),
              style: const TextStyle(
                  fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -1,
                  color: Colors.white, fontFeatures: tnum)),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: Text(aPagarMes == 0 ? 'Nada a pagar este mês' : '${reais(aPagarMes)} a pagar este mês',
                style: t.bodySmall?.copyWith(color: claro)),
          ),
          FilledButton.icon(
            onPressed: novaReceita,
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE2F2EA), foregroundColor: const Color(0xFF143A2D)),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Receita'),
          ),
        ]),
      ]),
    );
  }
}
