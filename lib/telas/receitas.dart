import 'package:flutter/material.dart';

import '../logica.dart';
import '../main.dart';
import '../models.dart';
import 'comum.dart';

Future<bool> editarReceita(BuildContext context, [Receita? r]) async =>
    await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => ReceitaForm(receita: r))) ==
    true;

class ReceitasTela extends StatefulWidget {
  const ReceitasTela({super.key});
  @override
  State<ReceitasTela> createState() => _ReceitasTelaState();
}

class _ReceitasTelaState extends State<ReceitasTela> {
  DateTime _mes = DateTime(hoje().year, hoje().month);
  late Future<List<Receita>> _receitas = db.receitasDoMes(_mes.year, _mes.month);

  void _recarregar() => setState(() => _receitas = db.receitasDoMes(_mes.year, _mes.month));

  Future<void> _editar([Receita? r]) async {
    if (await editarReceita(context, r)) _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: FilledButton.icon(
            style: botaoGrande,
            onPressed: () => _editar(), icon: const Icon(Icons.add), label: const Text('Nova receita')),
      ),
      body: carregando(_receitas, (receitas) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              SeletorMes(mes: _mes, onChanged: (m) { _mes = m; _recarregar(); }),
              const SizedBox(height: 8),
              Card(
                color: cs.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Recebido no mês',
                        style: t.bodyMedium?.copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(reais(soma(receitas.map((r) => r.valor))),
                        style: t.headlineMedium?.copyWith(
                            color: cs.onPrimaryContainer, fontWeight: FontWeight.w700,
                            letterSpacing: -0.8, fontFeatures: tnum)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              if (receitas.isEmpty) const Vazio('Nenhuma receita no mês'),
              if (receitas.isNotEmpty)
                Grupo(children: [
                  for (final r in receitas)
                    ListTile(
                      leading: Container(
                        width: 40, height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: cs.surface, borderRadius: BorderRadius.circular(12)),
                        child: Text(r.data.day.toString().padLeft(2, '0'), style: t.titleSmall),
                      ),
                      title: Text(r.descricao, style: t.titleSmall),
                      trailing: Text('+ ${reais(r.valor)}',
                          style: t.titleSmall?.copyWith(color: cs.primary, fontFeatures: tnum)),
                      onTap: () => _editar(r),
                    ),
                ]),
            ],
          )),
    );
  }
}

class ReceitaForm extends StatefulWidget {
  final Receita? receita;
  const ReceitaForm({super.key, this.receita});
  @override
  State<ReceitaForm> createState() => _ReceitaFormState();
}

class _ReceitaFormState extends State<ReceitaForm> {
  final _form = GlobalKey<FormState>();
  late final _descricao = TextEditingController(text: widget.receita?.descricao);
  late final _valor = TextEditingController(
      text: widget.receita == null ? '' : centavosTexto(widget.receita!.valor));
  late DateTime _data = widget.receita?.data ?? hoje();

  bool _salvando = false;

  Future<void> _salvar() async {
    if (_salvando || !_form.currentState!.validate()) return;
    _salvando = true;
    await db.salvarReceita(Receita(
        id: widget.receita?.id, descricao: _descricao.text.trim(),
        valor: lerCentavos(_valor.text)!, data: _data));
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _excluir() async {
    if (!await confirmar(context, 'Excluir receita?', 'Excluir')) return;
    await db.excluirReceita(widget.receita!.id!);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receita == null ? 'Nova receita' : 'Editar receita'),
        actions: [
          if (widget.receita != null)
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Excluir', onPressed: _excluir),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          TextFormField(
            controller: _descricao,
            autofocus: widget.receita == null,
            decoration: const InputDecoration(labelText: 'Descrição'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Obrigatório' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _valor,
            decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ '),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => lerCentavos(v ?? '') == null ? 'Valor inválido' : null,
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Data'),
              trailing: Text(dataBr(_data)),
              onTap: () async {
                final d = await showDatePicker(
                    context: context, initialDate: _data,
                    firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (d != null) setState(() => _data = d);
              },
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(style: botaoGrande, onPressed: _salvar, child: const Text('Salvar')),
        ]),
      ),
    );
  }
}
