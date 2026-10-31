const categorias = ['Moradia', 'Alimentação', 'Transporte', 'Saúde', 'Lazer', 'Salário', 'Outros'];

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
  final String categoria;
  final DateTime? pagoEm;

  const Conta({
    this.id,
    required this.descricao,
    required this.valor,
    required this.vencimento,
    required this.recorrente,
    required this.categoria,
    this.pagoEm,
  });

  Conta comId(int id) => Conta(
      id: id, descricao: descricao, valor: valor, vencimento: vencimento,
      recorrente: recorrente, categoria: categoria, pagoEm: pagoEm);

  Map<String, Object?> toMap() => {
        'id': id,
        'descricao': descricao,
        'valor': valor,
        'vencimento': iso(vencimento),
        'recorrente': recorrente ? 1 : 0,
        'categoria': categoria,
        'pago_em': pagoEm == null ? null : iso(pagoEm!),
      };

  factory Conta.fromMap(Map<String, Object?> m) => Conta(
        id: m['id'] as int?,
        descricao: m['descricao'] as String,
        valor: m['valor'] as int,
        vencimento: DateTime.parse(m['vencimento'] as String),
        recorrente: m['recorrente'] == 1,
        categoria: m['categoria'] as String,
        pagoEm: _data(m['pago_em']),
      );
}

class Lancamento {
  final int? id;
  final String tipo; // 'receita' | 'gasto'
  final String descricao;
  final int valor; // centavos, positivo
  final DateTime data;
  final String categoria;
  final int? contaId;

  const Lancamento({
    this.id,
    required this.tipo,
    required this.descricao,
    required this.valor,
    required this.data,
    required this.categoria,
    this.contaId,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'tipo': tipo,
        'descricao': descricao,
        'valor': valor,
        'data': iso(data),
        'categoria': categoria,
        'conta_id': contaId,
      };

  factory Lancamento.fromMap(Map<String, Object?> m) => Lancamento(
        id: m['id'] as int?,
        tipo: m['tipo'] as String,
        descricao: m['descricao'] as String,
        valor: m['valor'] as int,
        data: DateTime.parse(m['data'] as String),
        categoria: m['categoria'] as String,
        contaId: m['conta_id'] as int?,
      );
}
