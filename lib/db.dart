import 'package:sqflite/sqflite.dart';

import 'logica.dart';
import 'models.dart';

class Db {
  final Database _db;
  Db._(this._db);

  static Future<Db> abrir(DatabaseFactory f, String path) async {
    final db = await f.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute('''CREATE TABLE contas(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              descricao TEXT NOT NULL,
              valor INTEGER NOT NULL,
              vencimento TEXT NOT NULL,
              recorrente INTEGER NOT NULL,
              categoria TEXT NOT NULL,
              pago_em TEXT)''');
            await db.execute('''CREATE TABLE lancamentos(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              tipo TEXT NOT NULL CHECK(tipo IN ('receita', 'gasto')),
              descricao TEXT NOT NULL,
              valor INTEGER NOT NULL,
              data TEXT NOT NULL,
              categoria TEXT NOT NULL,
              conta_id INTEGER)''');
          },
        ));
    return Db._(db);
  }

  Future<void> fechar() => _db.close();

  Future<List<Conta>> contasEmAberto() async =>
      (await _db.query('contas', where: 'pago_em IS NULL', orderBy: 'vencimento, id'))
          .map(Conta.fromMap)
          .toList();

  Future<int> _salvar(String tabela, Map<String, Object?> m) async {
    final id = m['id'] as int?;
    if (id == null) return _db.insert(tabela, m);
    await _db.update(tabela, m, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  Future<int> salvarConta(Conta c) => _salvar('contas', c.toMap());

  Future<void> excluirConta(int id) => _db.delete('contas', where: 'id = ?', whereArgs: [id]);

  Future<List<Lancamento>> lancamentosDoMes(int ano, int mes) async {
    final prefixo = '$ano-${mes.toString().padLeft(2, '0')}-%';
    return (await _db.query('lancamentos',
            where: 'data LIKE ?', whereArgs: [prefixo], orderBy: 'data DESC, id DESC'))
        .map(Lancamento.fromMap)
        .toList();
  }

  Future<int> salvarLancamento(Lancamento l) => _salvar('lancamentos', l.toMap());

  Future<void> excluirLancamento(int id) =>
      _db.delete('lancamentos', where: 'id = ?', whereArgs: [id]);

  Future<Conta?> pagar(Conta c, DateTime dia) => _db.transaction((t) async {
        await t.update('contas', {'pago_em': iso(dia)}, where: 'id = ?', whereArgs: [c.id]);
        await t.insert(
            'lancamentos',
            Lancamento(
                    tipo: 'gasto', descricao: c.descricao, valor: c.valor,
                    data: dia, categoria: c.categoria, contaId: c.id)
                .toMap());
        if (!c.recorrente) return null;
        final nova = Conta(
            descricao: c.descricao, valor: c.valor,
            vencimento: proximoVencimento(c.vencimento),
            recorrente: true, categoria: c.categoria);
        return nova.comId(await t.insert('contas', nova.toMap()));
      });

  Future<Map<String, Object?>> exportar(int diasAviso) async => {
        'versao': 1,
        'dias_aviso': diasAviso,
        'contas': await _db.query('contas'),
        'lancamentos': await _db.query('lancamentos'),
      };

  Future<int> importar(Map<String, Object?> d) async {
    if (d['versao'] != 1) throw const FormatException('Versão de backup desconhecida');
    final List<Conta> contas;
    final List<Lancamento> lancs;
    try {
      contas = (d['contas'] as List)
          .map((m) => Conta.fromMap(Map<String, Object?>.from(m as Map)))
          .toList();
      lancs = (d['lancamentos'] as List)
          .map((m) => Lancamento.fromMap(Map<String, Object?>.from(m as Map)))
          .toList();
    } catch (_) {
      throw const FormatException('Arquivo de backup inválido');
    }
    if (lancs.any((l) => l.tipo != 'receita' && l.tipo != 'gasto')) {
      throw const FormatException('Arquivo de backup inválido');
    }
    await _db.transaction((t) async {
      await t.delete('contas');
      await t.delete('lancamentos');
      for (final c in contas) {
        await t.insert('contas', c.toMap());
      }
      for (final l in lancs) {
        await t.insert('lancamentos', l.toMap());
      }
    });
    final dias = d['dias_aviso'];
    return dias is int ? dias : 1;
  }
}
