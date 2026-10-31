String iso(DateTime d) => d.toIso8601String().substring(0, 10);

DateTime hoje() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime? _data(Object? s) => s == null ? null : DateTime.parse(s as String);

class Conta {
  final int? id;
  final String descricao;
  final int valor; // centavos
  final DateTime vencimento;
  final bool recorrente;
  final DateTime? pagoEm;

  const Conta({
    this.id,
    required this.descricao,
    required this.valor,
    required this.vencimento,
    required this.recorrente,
    this.pagoEm,
  });

  Conta comId(int id) => Conta(
      id: id, descricao: descricao, valor: valor, vencimento: vencimento,
      recorrente: recorrente, pagoEm: pagoEm);

  Map<String, Object?> toMap() => {
        'id': id,
        'descricao': descricao,
        'valor': valor,
        'vencimento': iso(vencimento),
        'recorrente': recorrente ? 1 : 0,
        'pago_em': pagoEm == null ? null : iso(pagoEm!),
      };

  factory Conta.fromMap(Map<String, Object?> m) => Conta(
        id: m['id'] as int?,
        descricao: m['descricao'] as String,
        valor: m['valor'] as int,
        vencimento: DateTime.parse(m['vencimento'] as String),
        recorrente: m['recorrente'] == 1,
        pagoEm: _data(m['pago_em']),
      );
}

class Receita {
  final int? id;
  final String descricao;
  final int valor; // centavos, positivo
  final DateTime data;

  const Receita({this.id, required this.descricao, required this.valor, required this.data});

  Map<String, Object?> toMap() => {
        'id': id,
        'descricao': descricao,
        'valor': valor,
        'data': iso(data),
      };

  factory Receita.fromMap(Map<String, Object?> m) => Receita(
        id: m['id'] as int?,
        descricao: m['descricao'] as String,
        valor: m['valor'] as int,
        data: DateTime.parse(m['data'] as String),
      );
}
