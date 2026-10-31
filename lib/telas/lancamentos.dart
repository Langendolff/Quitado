import 'package:flutter/material.dart';

import '../logica.dart';
import '../main.dart';
import '../models.dart';

class SeletorMes extends StatelessWidget {
  final DateTime mes;
  final ValueChanged<DateTime> onChanged;
  const SeletorMes({super.key, required this.mes, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(DateTime(mes.year, mes.month - 1))),
      Text('${meses[mes.month - 1]} ${mes.year}', style: Theme.of(context).textTheme.titleMedium),
      IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(DateTime(mes.year, mes.month + 1))),
    ]);
  }
}

class LancamentosTela extends StatefulWidget {
  const LancamentosTela({super.key});
  @override
  State<LancamentosTela> createState() => _LancamentosTelaState();
}

class _LancamentosTelaState extends State<LancamentosTela> {
  DateTime _mes = DateTime(hoje().year, hoje().month);
  late Future<List<Lancamento>> _lancs = db.lancamentosDoMes(_mes.year, _mes.month);

  void _recarregar() =>
      setState(() => _lancs = db.lancamentosDoMes(_mes.year, _mes.month));

  Future<void> _editar([Lancamento? l]) async {
    final mudou = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => LancamentoForm(lancamento: l)));
    if (mudou == true) _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
          onPressed: () => _editar(), child: const Icon(Icons.add)),
      body: Column(children: [
        SeletorMes(mes: _mes, onChanged: (m) { _mes = m; _recarregar(); }),
        Expanded(
          child: FutureBuilder(
            future: _lancs,
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('Erro: ${snap.error}'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final lancs = snap.data!;
              if (lancs.isEmpty) return const Center(child: Text('Nenhum lançamento no mês'));
              return ListView(children: [
                for (final l in lancs)
                  ListTile(
                    leading: Icon(l.tipo == 'receita' ? Icons.arrow_downward : Icons.arrow_upward,
                        color: l.tipo == 'receita' ? Colors.green : Colors.red),
                    title: Text(l.descricao),
                    subtitle: Text('${dataBr(l.data)} · ${l.categoria}'),
                    trailing: Text(reais(l.tipo == 'receita' ? l.valor : -l.valor)),
                    onTap: () => _editar(l),
                  ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

class LancamentoForm extends StatefulWidget {
  final Lancamento? lancamento;
  const LancamentoForm({super.key, this.lancamento});
  @override
  State<LancamentoForm> createState() => _LancamentoFormState();
}

class _LancamentoFormState extends State<LancamentoForm> {
  final _form = GlobalKey<FormState>();
  late final _descricao = TextEditingController(text: widget.lancamento?.descricao);
  late final _valor = TextEditingController(
      text: widget.lancamento == null ? '' : centavosTexto(widget.lancamento!.valor));
  late String _tipo = widget.lancamento?.tipo ?? 'gasto';
  late DateTime _data = widget.lancamento?.data ?? hoje();
  late String _categoria = widget.lancamento?.categoria ?? 'Outros';

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    await db.salvarLancamento(Lancamento(
        id: widget.lancamento?.id, tipo: _tipo, descricao: _descricao.text.trim(),
        valor: lerCentavos(_valor.text)!, data: _data, categoria: _categoria,
        contaId: widget.lancamento?.contaId));
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _excluir() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Excluir lançamento?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
              ],
            ));
    if (ok != true) return;
    await db.excluirLancamento(widget.lancamento!.id!);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lancamento == null ? 'Novo lançamento' : 'Editar lançamento'),
        actions: [
          if (widget.lancamento != null)
            IconButton(icon: const Icon(Icons.delete), onPressed: _excluir),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'gasto', label: Text('Gasto')),
              ButtonSegment(value: 'receita', label: Text('Receita')),
            ],
            selected: {_tipo},
            onSelectionChanged: (s) => setState(() => _tipo = s.single),
          ),
          TextFormField(
            controller: _descricao,
            decoration: const InputDecoration(labelText: 'Descrição'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Obrigatório' : null,
          ),
          TextFormField(
            controller: _valor,
            decoration: const InputDecoration(labelText: 'Valor (R\$)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => lerCentavos(v ?? '') == null ? 'Valor inválido' : null,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Data: ${dataBr(_data)}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showDatePicker(
                  context: context, initialDate: _data,
                  firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (d != null) setState(() => _data = d);
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: _categoria,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: [for (final c in categorias) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() => _categoria = v!),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _salvar, child: const Text('Salvar')),
        ]),
      ),
    );
  }
}
