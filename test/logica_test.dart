import 'package:contas/logica.dart';
import 'package:contas/models.dart';
import 'package:flutter_test/flutter_test.dart';

Conta conta(DateTime v, {int valor = 1000, DateTime? pagoEm}) => Conta(
    descricao: 'x', valor: valor, vencimento: v, recorrente: false, pagoEm: pagoEm);

Receita receita(int valor, DateTime d) => Receita(descricao: 'x', valor: valor, data: d);

void main() {
  test('proximoVencimento', () {
    expect(proximoVencimento(DateTime(2026, 1, 15)), DateTime(2026, 2, 15));
    expect(proximoVencimento(DateTime(2026, 1, 31)), DateTime(2026, 2, 28));
    expect(proximoVencimento(DateTime(2028, 1, 31)), DateTime(2028, 2, 29));
    expect(proximoVencimento(DateTime(2026, 12, 31)), DateTime(2027, 1, 31));
    expect(proximoVencimento(DateTime(2026, 2, 28)), DateTime(2026, 3, 28));
  });

  test('somarMeses', () {
    expect(somarMeses(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    expect(somarMeses(DateTime(2026, 1, 31), 2), DateTime(2026, 3, 31)); // não arrasta o dia 28
    expect(somarMeses(DateTime(2026, 11, 10), 3), DateTime(2027, 2, 10));
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
      receita(500000, DateTime(2026, 10, 5)),
      receita(20000, DateTime(2026, 10, 30)),
      receita(9999, DateTime(2026, 11, 1)),
    ], [
      conta(DateTime(2026, 9, 30), valor: 150000, pagoEm: DateTime(2026, 10, 1)), // conta pelo dia pago
      conta(DateTime(2026, 10, 10), valor: 10000, pagoEm: DateTime(2026, 9, 28)),
    ], [
      conta(DateTime(2026, 10, 25), valor: 20000),
      conta(DateTime(2026, 11, 2), valor: 3000),
    ]);
    expect(r.recebido, 520000);
    expect(r.pago, 150000);
    expect(r.sobrou, 370000);
    expect(r.aPagar, 20000);
  });

  test('Conta toMap/fromMap', () {
    final c = Conta(
        id: 3, descricao: 'Luz', valor: 15000, vencimento: DateTime(2026, 3, 5),
        recorrente: true, pagoEm: DateTime(2026, 3, 4));
    expect(Conta.fromMap(c.toMap()).toMap(), c.toMap());
    expect(c.toMap()['vencimento'], '2026-03-05');
  });
}
