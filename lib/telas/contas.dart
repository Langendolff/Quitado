import 'package:flutter/material.dart';

import '../lembretes.dart';
import '../logica.dart';
import '../main.dart';
import '../models.dart';

class ContasTela extends StatefulWidget {
  const ContasTela({super.key});
  @override
  State<ContasTela> createState() => _ContasTelaState();
}

class _ContasTelaState extends State<ContasTela> {
  late Future<List<Conta>> _contas = db.contasEmAberto();

  void _recarregar() => setState(() => _contas = db.contasEmAberto());

  Future<void> _editar([Conta? c]) async {
    final mudou = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => ContaForm(conta: c)));
    if (mudou == true) _recarregar();
  }

  Future<void> _pagar(Conta c) async {
    final nova = await db.pagar(c, hoje());
    await Lembretes.cancelar(c.id!);
    if (nova != null) await Lembretes.agendar(nova, diasAviso);
    _recarregar();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${c.descricao} paga')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
          onPressed: () => _editar(), child: const Icon(Icons.add)),
      body: FutureBuilder(
        future: _contas,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Erro: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final contas = snap.data!;
          if (contas.isEmpty) return const Center(child: Text('Nenhuma conta em aberto'));
          final h = hoje();
          return ListView(children: [
            for (final c in contas)
              ListTile(
                tileColor: switch (situacao(c, h, diasAviso)) {
                  Situacao.atrasada => Colors.red.withValues(alpha: .15),
                  Situacao.proxima => Colors.amber.withValues(alpha: .2),
                  Situacao.normal => null,
                },
                leading: Icon(c.recorrente ? Icons.repeat : Icons.receipt_long),
                title: Text(c.descricao),
                subtitle: Text('${dataBr(c.vencimento)} · ${c.categoria}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(reais(c.valor)),
                  const SizedBox(width: 8),
                  FilledButton.tonal(onPressed: () => _pagar(c), child: const Text('Pagar')),
                ]),
                onTap: () => _editar(c),
              ),
          ]);
        },
      ),
    );
  }
}

class ContaForm extends StatefulWidget {
  final Conta? conta;
  const ContaForm({super.key, this.conta});
  @override
  State<ContaForm> createState() => _ContaFormState();
}

class _ContaFormState extends State<ContaForm> {
  final _form = GlobalKey<FormState>();
  late final _descricao = TextEditingController(text: widget.conta?.descricao);
  late final _valor = TextEditingController(
      text: widget.conta == null ? '' : centavosTexto(widget.conta!.valor));
  late DateTime _vencimento = widget.conta?.vencimento ?? hoje();
  late bool _recorrente = widget.conta?.recorrente ?? false;
  late String _categoria = widget.conta?.categoria ?? 'Outros';

  bool _salvando = false;

  Future<void> _salvar() async {
    if (_salvando || !_form.currentState!.validate()) return;
    _salvando = true;
    final c = Conta(
        id: widget.conta?.id, descricao: _descricao.text.trim(),
        valor: lerCentavos(_valor.text)!, vencimento: _vencimento,
        recorrente: _recorrente, categoria: _categoria);
    final id = await db.salvarConta(c);
    await Lembretes.cancelar(id);
    await Lembretes.agendar(c.comId(id), diasAviso);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _excluir() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Excluir conta?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
              ],
            ));
    if (ok != true) return;
    await db.excluirConta(widget.conta!.id!);
    await Lembretes.cancelar(widget.conta!.id!);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.conta == null ? 'Nova conta' : 'Editar conta'),
        actions: [
          if (widget.conta != null)
            IconButton(icon: const Icon(Icons.delete), onPressed: _excluir),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
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
            title: Text('Vencimento: ${dataBr(_vencimento)}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showDatePicker(
                  context: context, initialDate: _vencimento,
                  firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (d != null) setState(() => _vencimento = d);
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: _categoria,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: [for (final c in categorias) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() => _categoria = v!),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Repete todo mês'),
            value: _recorrente,
            onChanged: (v) => setState(() => _recorrente = v),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _salvar, child: const Text('Salvar')),
        ]),
      ),
    );
  }
}
