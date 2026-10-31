import 'package:sqflite/sqflite.dart';

import 'logica.dart';
import 'models.dart';

class Db {
  final Database _db;
  Db._(this._db);

  static Future<void> _criar(Database db) async {
    await db.execute('''CREATE TABLE contas(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      descricao TEXT NOT NULL,
      valor INTEGER NOT NULL,
      vencimento TEXT NOT NULL,
      recorrente INTEGER NOT NULL,
      pago_em TEXT)''');
    await db.execute('''CREATE TABLE receitas(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      descricao TEXT NOT NULL,
      valor INTEGER NOT NULL,
      data TEXT NOT NULL)''');
  }

  static Future<Db> abrir(DatabaseFactory f, String path) async {
    final db = await f.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) => _criar(db),
          // v1 → v2: modelo novo (saldo, sem categorias); dados v1 descartados de propósito
          onUpgrade: (db, _, _) async {
            await db.execute('DROP TABLE IF EXISTS lancamentos');
            await db.execute('DROP TABLE IF EXISTS contas');
            await _criar(db);
          },
        ));
    return Db._(db);
  }

  Future<void> fechar() => _db.close();

  String _prefixo(int ano, int mes) => '$ano-${mes.toString().padLeft(2, '0')}-%';

  Future<List<Conta>> contasEmAberto() async =>
      (await _db.query('contas', where: 'pago_em IS NULL', orderBy: 'vencimento, id'))
          .map(Conta.fromMap)
          .toList();

  Future<List<Conta>> pagasDoMes(int ano, int mes) async => (await _db.query('contas',
          where: 'pago_em LIKE ?', whereArgs: [_prefixo(ano, mes)], orderBy: 'pago_em DESC, id DESC'))
      .map(Conta.fromMap)
      .toList();

  /// Todas as receitas menos todas as contas pagas.
  Future<int> saldo() async => (await _db.rawQuery('''SELECT
      (SELECT COALESCE(SUM(valor), 0) FROM receitas) -
      (SELECT COALESCE(SUM(valor), 0) FROM contas WHERE pago_em IS NOT NULL) AS s''')).first['s'] as int;

  Future<int> _salvar(String tabela, Map<String, Object?> m) async {
    final id = m['id'] as int?;
    if (id == null) return _db.insert(tabela, m);
    await _db.update(tabela, m, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  Future<int> salvarConta(Conta c) => _salvar('contas', c.toMap());

  Future<void> excluirConta(int id) => _db.delete('contas', where: 'id = ?', whereArgs: [id]);

  Future<List<Receita>> receitasDoMes(int ano, int mes) async => (await _db.query('receitas',
          where: 'data LIKE ?', whereArgs: [_prefixo(ano, mes)], orderBy: 'data DESC, id DESC'))
      .map(Receita.fromMap)
      .toList();

  Future<int> salvarReceita(Receita r) => _salvar('receitas', r.toMap());

  Future<void> excluirReceita(int id) => _db.delete('receitas', where: 'id = ?', whereArgs: [id]);

  /// Paga todas numa transação. Ignora as já pagas (toque duplo).
  /// Retorna as próximas contas criadas pelas recorrentes.
  Future<List<Conta>> pagar(List<Conta> contas, DateTime dia) => _db.transaction((t) async {
        final novas = <Conta>[];
        for (final c in contas) {
          final n = await t.update('contas', {'pago_em': iso(dia)},
              where: 'id = ? AND pago_em IS NULL', whereArgs: [c.id]);
          if (n == 0 || !c.recorrente) continue;
          final nova = Conta(
              descricao: c.descricao, valor: c.valor,
              vencimento: proximoVencimento(c.vencimento), recorrente: true);
          novas.add(nova.comId(await t.insert('contas', nova.toMap())));
        }
        return novas;
      });

  Future<Map<String, Object?>> exportar(int diasAviso) async => {
        'versao': 2,
        'dias_aviso': diasAviso,
        'contas': await _db.query('contas'),
        'receitas': await _db.query('receitas'),
      };

  Future<int> importar(Map<String, Object?> d) async {
    if (d['versao'] != 2) throw const FormatException('Versão de backup desconhecida');
    final List<Conta> contas;
    final List<Receita> receitas;
    try {
      contas = (d['contas'] as List)
          .map((m) => Conta.fromMap(Map<String, Object?>.from(m as Map)))
          .toList();
      receitas = (d['receitas'] as List)
          .map((m) => Receita.fromMap(Map<String, Object?>.from(m as Map)))
          .toList();
    } catch (_) {
      throw const FormatException('Arquivo de backup inválido');
    }
    await _db.transaction((t) async {
      await t.delete('contas');
      await t.delete('receitas');
      for (final c in contas) {
        await t.insert('contas', c.toMap());
      }
      for (final r in receitas) {
        await t.insert('receitas', r.toMap());
      }
    });
    final dias = d['dias_aviso'];
    return dias is int ? dias : 1;
  }
}
