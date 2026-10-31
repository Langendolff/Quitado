import 'models.dart';

const meses = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho',
  'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];

DateTime proximoVencimento(DateTime v) {
  final ultimoDia = DateTime(v.year, v.month + 2, 0).day; // dia 0 = último do mês anterior
  return DateTime(v.year, v.month + 1, v.day > ultimoDia ? ultimoDia : v.day);
}

enum Situacao { atrasada, proxima, normal }

Situacao situacao(Conta c, DateTime hoje, int dias) {
  if (c.vencimento.isBefore(hoje)) return Situacao.atrasada;
  if (!c.vencimento.isAfter(DateTime(hoje.year, hoje.month, hoje.day + dias))) {
    return Situacao.proxima;
  }
  return Situacao.normal;
}

class Resumo {
  final int recebido, pago, aPagar;
  const Resumo(this.recebido, this.pago, this.aPagar);
  int get sobrou => recebido - pago;
}

int soma(Iterable<int> v) => v.fold(0, (a, b) => a + b);

Resumo resumoMes(int ano, int mes, List<Receita> receitas, List<Conta> pagas, List<Conta> abertas) {
  bool noMes(DateTime? d) => d != null && d.year == ano && d.month == mes;
  return Resumo(
    soma(receitas.where((r) => noMes(r.data)).map((r) => r.valor)),
    soma(pagas.where((c) => noMes(c.pagoEm)).map((c) => c.valor)),
    soma(abertas.where((c) => noMes(c.vencimento)).map((c) => c.valor)),
  );
}

String reais(int c) {
  final inteiro = (c.abs() ~/ 100)
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  final cent = (c.abs() % 100).toString().padLeft(2, '0');
  return '${c < 0 ? '-' : ''}R\$ $inteiro,$cent';
}

/// "1.234,56" → 123456. Sem vírgula, o ponto é decimal ("12.50" → 1250),
/// exceto milhar bem formado ("1.500" → 150000).
/// Retorna null se inválido, <= 0 ou absurdo (> 1e10).
int? lerCentavos(String t) {
  var s = t.trim();
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
    s = s.replaceAll('.', '');
  }
  final v = double.tryParse(s);
  if (v == null || !v.isFinite || v <= 0 || v > 1e10) return null;
  return (v * 100).round();
}

String centavosTexto(int c) => (c / 100).toStringAsFixed(2).replaceAll('.', ',');

String dataBr(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
