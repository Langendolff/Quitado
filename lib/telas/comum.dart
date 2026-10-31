import 'package:flutter/material.dart';

import '../logica.dart';

const tnum = [FontFeature.tabularFigures()];

class SeletorMes extends StatelessWidget {
  final DateTime mes;
  final ValueChanged<DateTime> onChanged;
  const SeletorMes({super.key, required this.mes, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Mês anterior',
          onPressed: () => onChanged(DateTime(mes.year, mes.month - 1))),
      Text('${meses[mes.month - 1]} ${mes.year}', style: Theme.of(context).textTheme.titleLarge),
      IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Próximo mês',
          onPressed: () => onChanged(DateTime(mes.year, mes.month + 1))),
    ]);
  }
}

/// Card branco arredondado com itens separados por divisores.
class Grupo extends StatelessWidget {
  final List<Widget> children;
  const Grupo({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            children[i],
          ],
        ]),
      ),
    );
  }
}

class Vazio extends StatelessWidget {
  final String texto;
  const Vazio(this.texto, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
            child: Text(texto,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
      );
}

Future<bool> confirmar(BuildContext context, String titulo, String acao) async =>
    await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(titulo),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(acao)),
              ],
            )) ==
    true;

/// FutureBuilder com carregando/erro padrão.
Widget carregando<T>(Future<T> f, Widget Function(T) pronto) => FutureBuilder<T>(
      future: f,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Erro: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return pronto(snap.data as T);
      },
    );

/// Botão de ação principal no rodapé e nos formulários.
final botaoGrande = FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(52),
    padding: const EdgeInsets.symmetric(horizontal: 20),
    textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)));
