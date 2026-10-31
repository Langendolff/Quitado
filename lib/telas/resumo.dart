import 'package:flutter/material.dart';

import '../logica.dart';
import '../main.dart';
import '../models.dart';
import 'comum.dart';

class ResumoTela extends StatefulWidget {
  const ResumoTela({super.key});
  @override
  State<ResumoTela> createState() => _ResumoTelaState();
}

class _ResumoTelaState extends State<ResumoTela> {
  DateTime _mes = DateTime(hoje().year, hoje().month);
  late Future<(Resumo, List<Conta>)> _dados = _carregar();

  Future<(Resumo, List<Conta>)> _carregar() async {
    final pagas = await db.pagasDoMes(_mes.year, _mes.month);
    final r = resumoMes(_mes.year, _mes.month, await db.receitasDoMes(_mes.year, _mes.month),
        pagas, await db.contasEmAberto());
    return (r, pagas);
  }

  Widget _numero(BuildContext context, String rotulo, int valor, {Color? cor, bool destaque = false}) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        color: destaque ? cs.primary : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rotulo,
                style: t.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: destaque ? cs.onPrimary.withValues(alpha: .7) : cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(reais(valor),
                  style: t.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700, fontFeatures: tnum,
                      color: destaque ? cs.onPrimary : cor)),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return carregando(_dados, (d) {
      final (r, pagas) = d;
      return ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        SeletorMes(mes: _mes, onChanged: (m) => setState(() { _mes = m; _dados = _carregar(); })),
        const SizedBox(height: 8),
        Row(children: [
          _numero(context, 'Recebido', r.recebido, cor: cs.primary),
          const SizedBox(width: 12),
          _numero(context, 'Pago', r.pago),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _numero(context, 'Sobrou', r.sobrou, destaque: true),
          const SizedBox(width: 12),
          _numero(context, 'Ainda a pagar', r.aPagar, cor: r.aPagar > 0 ? cs.error : null),
        ]),
        const SizedBox(height: 24),
        Text('Pago no mês', style: t.titleMedium),
        const SizedBox(height: 8),
        if (pagas.isEmpty) const Vazio('Nada pago neste mês'),
        if (pagas.isNotEmpty)
          Grupo(children: [
            for (final c in pagas)
              ListTile(
                title: Text(c.descricao, style: t.titleSmall),
                subtitle: Text('Pago em ${dataBr(c.pagoEm!).substring(0, 5)}'),
                trailing: Text('− ${reais(c.valor)}', style: t.titleSmall?.copyWith(fontFeatures: tnum)),
              ),
          ]),
      ]);
    });
  }
}
