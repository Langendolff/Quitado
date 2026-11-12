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

  Conta conta({bool recorrente = false, DateTime? venc, int valor = 15000}) => Conta(
      descricao: 'Luz', valor: valor, vencimento: venc ?? DateTime(2026, 10, 20),
      recorrente: recorrente);

  Future<Conta> nova({bool recorrente = false, DateTime? venc, int valor = 15000}) async {
    final c = conta(recorrente: recorrente, venc: venc, valor: valor);
    return c.comId(await db.salvarConta(c));
  }

  test('saldo: receitas menos pagas, abertas não contam', () async {
    expect(await db.saldo(), 0);
    await db.salvarReceita(Receita(descricao: 'Salário', valor: 500000, data: DateTime(2026, 10, 5)));
    final a = await nova(valor: 15000);
    await nova(valor: 99999); // em aberto
    await db.pagar([a], DateTime(2026, 10, 18));
    expect(await db.saldo(), 485000);
  });

  test('pagar em lote marca todas e cria próximas das recorrentes', () async {
    final a = await nova();
    final b = await nova(recorrente: true, venc: DateTime(2026, 1, 31));
    final novas = await db.pagar([a, b], DateTime(2026, 1, 30));
    expect(novas, hasLength(1));
    expect(novas.single.id, isNotNull);
    expect(novas.single.vencimento, DateTime(2026, 2, 28));
    expect((await db.contasEmAberto()).map((c) => c.toMap()), [novas.single.toMap()]);
    expect(await db.pagasDoMes(2026, 1), hasLength(2));
  });

  test('pagar duas vezes paga uma só', () async {
    final c = await nova(recorrente: true);
    await db.pagar([c], DateTime(2026, 10, 18));
    final segunda = await db.pagar([c], DateTime(2026, 10, 18));
    expect(segunda, isEmpty);
    expect(await db.pagasDoMes(2026, 10), hasLength(1));
    expect(await db.contasEmAberto(), hasLength(1));
  });

  test('desfazer pagamento volta pra aberto e some com a próxima recorrente', () async {
    final c = await nova(recorrente: true);
    await db.pagar([c], DateTime(2026, 10, 18));
    await db.desfazerPagamento(c);
    expect((await db.contasEmAberto()).map((c) => c.toMap()), [c.toMap()]);
    expect(await db.saldo(), 0);
  });

  test('pagar parte, pagar o resto, desfazer a parte', () async {
    final c = await nova(recorrente: true, valor: 10000);
    await db.pagarParte(c, 3000, DateTime(2026, 10, 10));
    await expectLater(() => db.pagarParte(c, 7000, DateTime(2026, 10, 10)), throwsStateError);
    final resto = (await db.contasEmAberto()).single;
    expect(resto.valor, 7000);
    expect(await db.saldo(), -3000);

    final parte = (await db.pagasDoMes(2026, 10)).single;
    await db.desfazerPagamento(parte);
    expect((await db.contasEmAberto()).single.valor, 10000);
    expect(await db.pagasDoMes(2026, 10), isEmpty);

    await db.pagarParte(c, 3000, DateTime(2026, 10, 10));
    final proxima = (await db.pagar([(await db.contasEmAberto()).single], DateTime(2026, 10, 18))).single;
    expect(proxima.valor, 10000); // volta ao valor cheio
    expect(await db.saldo(), -10000);
  });

  test('editar e excluir', () async {
    final c = await nova();
    await db.salvarConta(Conta(
        id: c.id, descricao: 'Água', valor: 8000, vencimento: DateTime(2026, 10, 20),
        recorrente: false));
    expect((await db.contasEmAberto()).single.descricao, 'Água');
    await db.excluirConta(c.id!);
    expect(await db.contasEmAberto(), isEmpty);
  });

  test('backup ida e volta', () async {
    await nova(recorrente: true);
    await db.salvarReceita(Receita(descricao: 'Salário', valor: 500000, data: DateTime(2026, 10, 5)));
    await db.pagar([await nova()], DateTime(2026, 10, 18));
    final antes = jsonEncode(await db.exportar(3));

    await nova(); // sujeira que deve sumir
    final dias = await db.importar(jsonDecode(antes) as Map<String, Object?>);

    expect(dias, 3);
    expect(jsonEncode(await db.exportar(3)), antes);
  });

  test('backup inválido não altera nada', () async {
    await nova();
    await expectLater(() => db.importar({'versao': 1, 'contas': [], 'lancamentos': []}),
        throwsFormatException);
    await expectLater(() => db.importar({'versao': 2, 'contas': [{'x': 1}], 'receitas': []}),
        throwsFormatException);
    await expectLater(() => db.importar({'versao': 2, 'contas': []}), throwsFormatException);
    expect(await db.contasEmAberto(), hasLength(1));
  });

  test('migração v1 → v2 recria as tabelas', () async {
    final path = '${(await databaseFactoryFfi.getDatabasesPath())}/migracao_test.db';
    await databaseFactoryFfi.deleteDatabase(path);
    final v1 = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(version: 1, onCreate: (d, _) async {
          await d.execute('CREATE TABLE contas(id INTEGER PRIMARY KEY, categoria TEXT)');
          await d.execute('CREATE TABLE lancamentos(id INTEGER PRIMARY KEY)');
          await d.insert('contas', {'categoria': 'Outros'});
        }));
    await v1.close();
    final v2 = await Db.abrir(databaseFactoryFfi, path);
    expect(await v2.contasEmAberto(), isEmpty);
    expect(await v2.saldo(), 0);
    await v2.fechar();
    await databaseFactoryFfi.deleteDatabase(path);
  });

  test('migração v2 → v3 mantém os dados', () async {
    final path = '${(await databaseFactoryFfi.getDatabasesPath())}/migracao_v3_test.db';
    await databaseFactoryFfi.deleteDatabase(path);
    final v2 = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(version: 2, onCreate: (d, _) async {
          await d.execute('CREATE TABLE contas(id INTEGER PRIMARY KEY AUTOINCREMENT, descricao TEXT NOT NULL, '
              'valor INTEGER NOT NULL, vencimento TEXT NOT NULL, recorrente INTEGER NOT NULL, pago_em TEXT)');
          await d.execute('CREATE TABLE receitas(id INTEGER PRIMARY KEY AUTOINCREMENT, descricao TEXT NOT NULL, '
              'valor INTEGER NOT NULL, data TEXT NOT NULL)');
          await d.insert('contas', {'descricao': 'Luz', 'valor': 100, 'vencimento': '2026-10-20', 'recorrente': 1});
        }));
    await v2.close();
    final v3 = await Db.abrir(databaseFactoryFfi, path);
    final c = (await v3.contasEmAberto()).single;
    expect(c.descricao, 'Luz');
    expect((await v3.pagar([c], DateTime(2026, 10, 18))).single.origem, c.id);
    await v3.fechar();
    await databaseFactoryFfi.deleteDatabase(path);
  });
}
