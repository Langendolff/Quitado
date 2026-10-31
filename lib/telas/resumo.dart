import 'package:flutter/material.dart';

import '../logica.dart';
import '../main.dart';
import '../models.dart';
import 'lancamentos.dart';

class ResumoTela extends StatefulWidget {
  const ResumoTela({super.key});
  @override
  State<ResumoTela> createState() => _ResumoTelaState();
}

class _ResumoTelaState extends State<ResumoTela> {
  DateTime _mes = DateTime(hoje().year, hoje().month);
  late Future<Resumo> _resumo = _carregar();

  Future<Resumo> _carregar() async => resumoMes(_mes.year, _mes.month,
      await db.lancamentosDoMes(_mes.year, _mes.month), await db.contasEmAberto());

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SeletorMes(mes: _mes, onChanged: (m) => setState(() { _mes = m; _resumo = _carregar(); })),
      Expanded(
        child: FutureBuilder(
          future: _resumo,
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text('Erro: ${snap.error}'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final r = snap.data!;
            final cats = r.porCategoria.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
            return ListView(padding: const EdgeInsets.all(8), children: [
              Card(
                child: Column(children: [
                  ListTile(title: const Text('Receitas'), trailing: Text(reais(r.receitas))),
                  ListTile(title: const Text('Gastos'), trailing: Text(reais(r.gastos))),
                  ListTile(
                      title: const Text('Saldo'),
                      trailing: Text(reais(r.saldo),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: r.saldo < 0 ? Colors.red : null))),
                  ListTile(title: const Text('Ainda a pagar'), trailing: Text(reais(r.aPagar))),
                ]),
              ),
              if (cats.isNotEmpty)
                Card(
                  child: Column(children: [
                    const ListTile(title: Text('Gastos por categoria')),
                    for (final e in cats)
                      ListTile(dense: true, title: Text(e.key), trailing: Text(reais(e.value))),
                  ]),
                ),
            ]);
          },
        ),
      ),
    ]);
  }
}
