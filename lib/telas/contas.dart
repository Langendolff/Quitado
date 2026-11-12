import 'package:flutter/material.dart';

import '../lembretes.dart';
import '../logica.dart';
import '../main.dart';
import '../models.dart';
import 'comum.dart';

String _ddmm(DateTime d) => dataBr(d).substring(0, 5);

Future<void> pagarContas(BuildContext context, List<Conta> contas, VoidCallback recarregar) async {
  final novas = await db.pagar(contas, hoje());
  for (final c in contas) {
    await Lembretes.cancelar(c.id!);
  }
  for (final n in novas) {
    await Lembretes.agendar(n, diasAviso);
  }
  recarregar();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(contas.length == 1 ? '${contas.single.descricao} paga' : '${contas.length} contas pagas'),
      action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () async {
            await desfazerPagamentos(contas);
            if (context.mounted) recarregar();
          })));
}

Future<void> desfazerPagamentos(List<Conta> contas) async {
  for (final c in contas) {
    await db.desfazerPagamento(c);
  }
  await Lembretes.reagendarTodos(await db.contasEmAberto(), diasAviso);
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

  Future<void> _pagar(List<Conta> contas) => pagarContas(context, contas, _recarregar);

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
  int _parcelas = 1;
  // parcelas alteradas à mão; as outras seguem valor e vencimento do topo
  final _valorParcela = <int, int>{};
  final _dataParcela = <int, DateTime>{};

  bool _salvando = false;

  int _valorDe(int i) => _valorParcela[i] ?? lerCentavos(_valor.text) ?? 0;
  DateTime _dataDe(int i) => _dataParcela[i] ?? somarMeses(_vencimento, i);

  Future<DateTime?> _escolherData(DateTime inicial) => showDatePicker(
      context: context, initialDate: inicial, firstDate: DateTime(2000), lastDate: DateTime(2100));

  Future<void> _salvar() async {
    if (_salvando || !_form.currentState!.validate()) return;
    _salvando = true;
    final descricao = _descricao.text.trim();
    final contas = _parcelas == 1
        ? [
            Conta(
                id: widget.conta?.id, descricao: descricao, valor: lerCentavos(_valor.text)!,
                vencimento: _vencimento, recorrente: _recorrente, origem: widget.conta?.origem)
          ]
        : [
            for (var i = 0; i < _parcelas; i++)
              Conta(
                  descricao: '$descricao (${i + 1}/$_parcelas)', valor: _valorDe(i),
                  vencimento: _dataDe(i), recorrente: false)
          ];
    for (final c in contas) {
      final id = await db.salvarConta(c);
      await Lembretes.cancelar(id);
      await Lembretes.agendar(c.comId(id), diasAviso);
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _pagarParte() async {
    final c = widget.conta!;
    final v = await pedirValor(context, 'Pagar uma parte', menorQue: c.valor);
    if (v == null) return;
    await db.pagarParte(c, v, hoje());
    await Lembretes.cancelar(c.id!);
    await Lembretes.agendar(Conta(
        id: c.id, descricao: c.descricao, valor: c.valor - v, vencimento: c.vencimento,
        recorrente: c.recorrente), diasAviso);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${reais(v)} pagos · faltam ${reais(c.valor - v)}')));
    Navigator.pop(context, true);
  }

  Future<void> _excluir() async {
    if (!await confirmar(context, 'Excluir conta?', 'Excluir')) return;
    await db.excluirConta(widget.conta!.id!);
    await Lembretes.cancelar(widget.conta!.id!);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final nova = widget.conta == null;
    final varias = _parcelas > 1;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(nova ? 'Nova conta' : 'Editar conta'),
        actions: [
          if (!nova)
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Excluir', onPressed: _excluir),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          TextFormField(
            controller: _descricao,
            autofocus: nova,
            decoration: const InputDecoration(labelText: 'Descrição'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Obrigatório' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _valor,
            decoration: InputDecoration(labelText: varias ? 'Valor da parcela' : 'Valor', prefixText: 'R\$ '),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: varias ? (_) => setState(() {}) : null,
            validator: (v) => lerCentavos(v ?? '') == null ? 'Valor inválido' : null,
          ),
          if (nova) ...[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: '1',
              decoration: const InputDecoration(labelText: 'Parcelas'),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final n = int.tryParse(v.trim());
                if (n != null && n >= 1 && n <= 360) setState(() => _parcelas = n);
              },
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                return n == null || n < 1 || n > 360 ? 'Entre 1 e 360' : null;
              },
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Column(children: [
              ListTile(
                title: Text(varias ? '1º vencimento' : 'Vencimento'),
                trailing: Text(dataBr(_vencimento)),
                onTap: () async {
                  final d = await _escolherData(_vencimento);
                  if (d != null) setState(() => _vencimento = d);
                },
              ),
              if (!varias) ...[
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Repete todo mês'),
                  value: _recorrente,
                  onChanged: (v) => setState(() => _recorrente = v),
                ),
              ],
            ]),
          ),
          if (varias) ...[
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Parcelas', style: t.titleMedium),
              Text('Total ${reais(soma([for (var i = 0; i < _parcelas; i++) _valorDe(i)]))}',
                  style: t.bodyMedium?.copyWith(fontFeatures: tnum)),
            ]),
            const SizedBox(height: 8),
            Grupo(children: [
              for (var i = 0; i < _parcelas; i++)
                ListTile(
                  title: Text('${i + 1}/$_parcelas'),
                  subtitle: Text('Vence ${dataBr(_dataDe(i))}'),
                  onTap: () async {
                    final d = await _escolherData(_dataDe(i));
                    if (d != null) setState(() => _dataParcela[i] = d);
                  },
                  trailing: TextButton(
                    onPressed: () async {
                      final v = await pedirValor(context, 'Parcela ${i + 1}', inicial: _valorDe(i));
                      if (v != null) setState(() => _valorParcela[i] = v);
                    },
                    child: Text(reais(_valorDe(i)), style: const TextStyle(fontFeatures: tnum)),
                  ),
                ),
            ]),
            const SizedBox(height: 4),
            Text('Toque na data ou no valor para mudar uma parcela.',
                style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 24),
          FilledButton(
              style: botaoGrande,
              onPressed: _salvar,
              child: Text(varias ? 'Criar $_parcelas parcelas' : 'Salvar')),
          if (!nova) ...[
            const SizedBox(height: 12),
            OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _pagarParte,
                child: const Text('Pagar uma parte')),
          ],
        ]),
      ),
    );
  }
}
