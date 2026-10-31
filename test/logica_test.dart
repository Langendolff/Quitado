import 'package:contas/logica.dart';
import 'package:contas/models.dart';
import 'package:flutter_test/flutter_test.dart';

Conta conta(DateTime v, {int valor = 1000}) => Conta(
    descricao: 'x', valor: valor, vencimento: v, recorrente: false, categoria: 'Outros');

Lancamento lanc(String tipo, int valor, String cat, DateTime d) =>
    Lancamento(tipo: tipo, descricao: 'x', valor: valor, data: d, categoria: cat);

void main() {
  test('proximoVencimento', () {
    expect(proximoVencimento(DateTime(2026, 1, 15)), DateTime(2026, 2, 15));
    expect(proximoVencimento(DateTime(2026, 1, 31)), DateTime(2026, 2, 28));
    expect(proximoVencimento(DateTime(2028, 1, 31)), DateTime(2028, 2, 29));
    expect(proximoVencimento(DateTime(2026, 12, 31)), DateTime(2027, 1, 31));
    expect(proximoVencimento(DateTime(2026, 2, 28)), DateTime(2026, 3, 28));
  });

  test('dinheiro', () {
    expect(reais(123456), 'R\$ 1.234,56');
    expect(reais(5), 'R\$ 0,05');
    expect(reais(-1000), '-R\$ 10,00');
    expect(lerCentavos('1.234,56'), 123456);
    expect(lerCentavos('12,5'), 1250);
    expect(lerCentavos('12.50'), 1250);
    expect(lerCentavos('0,29'), 29);
    expect(lerCentavos('0'), null);
    expect(lerCentavos('abc'), null);
    expect(lerCentavos('NaN'), null);
    expect(lerCentavos('Infinity'), null);
    expect(lerCentavos('1e20'), null);
    expect(lerCentavos('1.500'), 150000);
    expect(lerCentavos('1.234.567'), 123456700);
    expect(centavosTexto(123456), '1234,56');
  });

  test('situacao', () {
    final h = DateTime(2026, 10, 10);
    expect(situacao(conta(DateTime(2026, 10, 9)), h, 2), Situacao.atrasada);
    expect(situacao(conta(DateTime(2026, 10, 10)), h, 2), Situacao.proxima);
    expect(situacao(conta(DateTime(2026, 10, 12)), h, 2), Situacao.proxima);
    expect(situacao(conta(DateTime(2026, 10, 13)), h, 2), Situacao.normal);
  });

  test('resumoMes', () {
    final r = resumoMes(2026, 10, [
      lanc('receita', 500000, 'Salário', DateTime(2026, 10, 5)),
      lanc('gasto', 10000, 'Alimentação', DateTime(2026, 10, 6)),
      lanc('gasto', 5000, 'Alimentação', DateTime(2026, 10, 20)),
      lanc('gasto', 150000, 'Moradia', DateTime(2026, 10, 1)),
      lanc('gasto', 9999, 'Lazer', DateTime(2026, 11, 1)),
    ], [
      conta(DateTime(2026, 10, 25), valor: 20000),
      conta(DateTime(2026, 11, 2), valor: 3000),
    ]);
    expect(r.receitas, 500000);
    expect(r.gastos, 165000);
    expect(r.saldo, 335000);
    expect(r.porCategoria, {'Alimentação': 15000, 'Moradia': 150000});
    expect(r.aPagar, 20000);
  });

  test('Conta toMap/fromMap', () {
    final c = Conta(
        id: 3, descricao: 'Luz', valor: 15000, vencimento: DateTime(2026, 3, 5),
        recorrente: true, categoria: 'Moradia', pagoEm: DateTime(2026, 3, 4));
    expect(Conta.fromMap(c.toMap()).toMap(), c.toMap());
    expect(c.toMap()['vencimento'], '2026-03-05');
  });
}
