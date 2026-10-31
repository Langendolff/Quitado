import 'dart:convert';

import 'package:contas/db.dart';
import 'package:contas/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Db db;
  setUpAll(sqfliteFfiInit);
  setUp(() async => db = await Db.abrir(databaseFactoryFfi, inMemoryDatabasePath));
  tearDown(() => db.fechar());

  Conta conta({bool recorrente = false, DateTime? venc}) => Conta(
      descricao: 'Luz', valor: 15000, vencimento: venc ?? DateTime(2026, 10, 20),
      recorrente: recorrente, categoria: 'Moradia');

  test('pagar conta avulsa marca paga e cria gasto', () async {
    final id = await db.salvarConta(conta());
    final nova = await db.pagar(conta().comId(id), DateTime(2026, 10, 18));
    expect(nova, isNull);
    expect(await db.contasEmAberto(), isEmpty);
    final lancs = await db.lancamentosDoMes(2026, 10);
    expect(lancs, hasLength(1));
    expect(lancs.single.tipo, 'gasto');
    expect(lancs.single.valor, 15000);
    expect(lancs.single.contaId, id);
  });

  test('pagar conta recorrente cria a do mês seguinte', () async {
    final c = conta(recorrente: true, venc: DateTime(2026, 1, 31));
    final id = await db.salvarConta(c);
    final nova = await db.pagar(c.comId(id), DateTime(2026, 1, 30));
    expect(nova!.id, isNotNull);
    expect(nova.vencimento, DateTime(2026, 2, 28));
    final abertas = await db.contasEmAberto();
    expect(abertas.map((c) => c.toMap()), [nova.toMap()]);
  });

  test('editar e excluir', () async {
    final id = await db.salvarConta(conta());
    await db.salvarConta(Conta(
        id: id, descricao: 'Água', valor: 8000, vencimento: DateTime(2026, 10, 20),
        recorrente: false, categoria: 'Moradia'));
    expect((await db.contasEmAberto()).single.descricao, 'Água');
    await db.excluirConta(id);
    expect(await db.contasEmAberto(), isEmpty);
  });

  test('backup ida e volta', () async {
    await db.salvarConta(conta(recorrente: true));
    await db.salvarLancamento(Lancamento(
        tipo: 'receita', descricao: 'Salário', valor: 500000,
        data: DateTime(2026, 10, 5), categoria: 'Salário'));
    final json = jsonEncode(await db.exportar(3));
    final antesContas = (await db.contasEmAberto()).map((c) => c.toMap()).toList();
    final antesLancs = (await db.lancamentosDoMes(2026, 10)).map((l) => l.toMap()).toList();

    await db.salvarConta(conta()); // sujeira que deve sumir
    final dias = await db.importar(jsonDecode(json) as Map<String, Object?>);

    expect(dias, 3);
    expect((await db.contasEmAberto()).map((c) => c.toMap()).toList(), antesContas);
    expect((await db.lancamentosDoMes(2026, 10)).map((l) => l.toMap()).toList(), antesLancs);
  });

  test('backup inválido não altera nada', () async {
    await db.salvarConta(conta());
    expect(() => db.importar({'versao': 2, 'contas': [], 'lancamentos': []}),
        throwsFormatException);
    expect(() => db.importar({'versao': 1, 'contas': [{'x': 1}], 'lancamentos': []}),
        throwsFormatException);
    expect(
        () => db.importar({
              'versao': 1,
              'contas': [],
              'lancamentos': [
                {'id': 1, 'tipo': 'outro', 'descricao': 'a', 'valor': 1,
                 'data': '2026-10-01', 'categoria': 'Outros', 'conta_id': null}
              ]
            }),
        throwsFormatException);
    expect(await db.contasEmAberto(), hasLength(1));
  });
}
