import 'package:flutter/material.dart';

import '../lembretes.dart';
import '../logica.dart';
import '../main.dart';
import '../models.dart';
import 'comum.dart';

String _ddmm(DateTime d) => dataBr(d).substring(0, 5);

Future<void> pagarContas(BuildContext context, List<Conta> contas) async {
  final novas = await db.pagar(contas, hoje());
  for (final c in contas) {
    await Lembretes.cancelar(c.id!);
  }
  for (final n in novas) {
    await Lembretes.agendar(n, diasAviso);
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(contas.length == 1 ? '${contas.single.descricao} paga' : '${contas.length} contas pagas')));
}

Future<bool> editarConta(BuildContext context, [Conta? c]) async =>
    await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => ContaForm(conta: c))) == true;

class ContaItem extends StatelessWidget {
  final Conta conta;
  final Widget leading;
  final Widget? trailing;
  final VoidCallback? onTap, onLongPress;
  const ContaItem(
      {super.key, required this.conta, required this.leading, this.trailing, this.onTap, this.onLongPress});

  /// Faixa colorida pela situação (atrasada / próxima / normal).
  static Widget faixa(BuildContext context, Conta c) => Container(
      width: 4, height: 36,
      decoration: BoxDecoration(
          color: _cor(context, situacao(c, hoje(), diasAviso)) ?? Colors.transparent,
          borderRadius: BorderRadius.circular(2)));

  static Color? _cor(BuildContext context, Situacao s) => switch (s) {
        Situacao.atrasada => Theme.of(context).colorScheme.error,
        Situacao.proxima => Theme.of(context).colorScheme.tertiary,
        Situacao.normal => null,
      };

  String _quando(Situacao s, DateTime h) {
    final v = conta.vencimento;
    final txt = switch (s) {
      Situacao.atrasada => 'Atrasada · ${_ddmm(v)}',
      _ when v == h => 'Vence hoje',
      _ when v == DateTime(h.year, h.month, h.day + 1) => 'Vence amanhã · ${_ddmm(v)}',
      _ => 'Vence ${_ddmm(v)}',
    };
    return conta.recorrente ? '$txt · mensal' : txt;
  }

  @override
  Widget build(BuildContext context) {
    final h = hoje();
    final s = situacao(conta, h, diasAviso);
    final t = Theme.of(context).textTheme;
    final cor = _cor(context, s);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(conta.descricao, style: t.titleSmall),
              const SizedBox(height: 2),
              Text(_quando(s, h),
                  style: t.bodySmall?.copyWith(
                      color: cor, fontWeight: cor == null ? null : FontWeight.w500)),
            ]),
          ),
          Text(reais(conta.valor), style: t.titleSmall?.copyWith(fontFeatures: tnum)),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ]),
      ),
    );
  }
}

class ContasTela extends StatefulWidget {
  const ContasTela({super.key});
  @override
  State<ContasTela> createState() => _ContasTelaState();
}

class _ContasTelaState extends State<ContasTela> {
  late Future<List<Conta>> _contas = db.contasEmAberto();
  final _sel = <int>{};

  void _recarregar() => setState(() {
        _sel.clear();
        _contas = db.contasEmAberto();
      });

  void _alternar(Conta c) => setState(() => _sel.contains(c.id) ? _sel.remove(c.id) : _sel.add(c.id!));

  Future<void> _pagar(List<Conta> contas) async {
    await pagarContas(context, contas);
    _recarregar();
  }

  Widget _check(BuildContext context, bool on) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22, height: 22,
      decoration: BoxDecoration(
        color: on ? cs.primary : null,
        border: on ? null : Border.all(color: cs.outline, width: 2),
        borderRadius: BorderRadius.circular(7),
      ),
      child: on ? Icon(Icons.check, size: 16, color: cs.onPrimary) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return carregando(_contas, (contas) {
      final selecionando = _sel.isNotEmpty;
      final escolhidas = contas.where((c) => _sel.contains(c.id)).toList();
      return Scaffold(
        floatingActionButton: selecionando
            ? null
            : FloatingActionButton(
                tooltip: 'Nova conta',
                onPressed: () async {
                  if (await editarConta(context)) _recarregar();
                },
                child: const Icon(Icons.add)),
        bottomNavigationBar: !selecionando
            ? null
            : Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton(
                  style: botaoGrande,
                  onPressed: () => _pagar(escolhidas),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Pagar ${escolhidas.length} conta${escolhidas.length == 1 ? '' : 's'}'),
                    Text(reais(soma(escolhidas.map((c) => c.valor))),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: tnum)),
                  ]),
                ),
              ),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 96), children: [
          SizedBox(
            height: 40,
            child: selecionando
                ? Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('${_sel.length} selecionada${_sel.length == 1 ? '' : 's'}', style: t.titleMedium),
                    TextButton(onPressed: () => setState(_sel.clear), child: const Text('Cancelar')),
                  ])
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        contas.isEmpty
                            ? 'Nenhuma conta em aberto'
                            : '${contas.length} em aberto · ${reais(soma(contas.map((c) => c.valor)))}'
                                '  ·  segure para selecionar',
                        style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  ),
          ),
          const SizedBox(height: 8),
          if (contas.isNotEmpty)
            Grupo(children: [
              for (final c in contas)
                ContaItem(
                  conta: c,
                  leading: selecionando ? _check(context, _sel.contains(c.id)) : ContaItem.faixa(context, c),
                  trailing: selecionando
                      ? null
                      : FilledButton(onPressed: () => _pagar([c]), child: const Text('Pagar')),
                  onTap: selecionando
                      ? () => _alternar(c)
                      : () async {
                          if (await editarConta(context, c)) _recarregar();
                        },
                  onLongPress: () => _alternar(c),
                ),
            ]),
        ]),
      );
    });
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

  bool _salvando = false;

  Future<void> _salvar() async {
    if (_salvando || !_form.currentState!.validate()) return;
    _salvando = true;
    final c = Conta(
        id: widget.conta?.id, descricao: _descricao.text.trim(),
        valor: lerCentavos(_valor.text)!, vencimento: _vencimento, recorrente: _recorrente);
    final id = await db.salvarConta(c);
    await Lembretes.cancelar(id);
    await Lembretes.agendar(c.comId(id), diasAviso);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _excluir() async {
    if (!await confirmar(context, 'Excluir conta?', 'Excluir')) return;
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
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Excluir', onPressed: _excluir),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          TextFormField(
            controller: _descricao,
            autofocus: widget.conta == null,
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
            child: Column(children: [
              ListTile(
                title: const Text('Vencimento'),
                trailing: Text(dataBr(_vencimento)),
                onTap: () async {
                  final d = await showDatePicker(
                      context: context, initialDate: _vencimento,
                      firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (d != null) setState(() => _vencimento = d);
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Repete todo mês'),
                value: _recorrente,
                onChanged: (v) => setState(() => _recorrente = v),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          FilledButton(style: botaoGrande, onPressed: _salvar, child: const Text('Salvar')),
        ]),
      ),
    );
  }
}
