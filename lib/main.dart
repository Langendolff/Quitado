import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'db.dart';
import 'lembretes.dart';
import 'logica.dart';
import 'models.dart';
import 'telas/config.dart';
import 'telas/contas.dart';
import 'telas/lancamentos.dart';
import 'telas/resumo.dart';

// ponytail: globais; app de um usuário, sem necessidade de injeção de dependência
late final Db db;
late final SharedPreferences prefs;
int get diasAviso => prefs.getInt('dias_aviso') ?? 1;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  final dir = await getApplicationSupportDirectory();
  db = await Db.abrir(databaseFactory, '${dir.path}/contas.db');
  prefs = await SharedPreferences.getInstance();
  await Lembretes.iniciar();
  runApp(const App());
}

/// Linux não agenda notificações: ao abrir, lista atrasadas e próximas.
Future<void> avisoDesktop(BuildContext context) async {
  final h = hoje();
  final lista = (await db.contasEmAberto())
      .where((c) => situacao(c, h, diasAviso) != Situacao.normal)
      .toList();
  if (lista.isEmpty || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Contas para pagar'),
      content: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          for (final c in lista)
            Text('${dataBr(c.vencimento)}  ${c.descricao}  ${reais(c.valor)}',
                style: TextStyle(color: c.vencimento.isBefore(h) ? Colors.red : null)),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contas',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(colorSchemeSeed: Colors.teal, brightness: Brightness.dark),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _aba = 0;
  int _versao = 0; // muda após Configurações para recarregar a aba

  @override
  void initState() {
    super.initState();
    if (!Lembretes.suportado) {
      WidgetsBinding.instance.addPostFrameCallback((_) => avisoDesktop(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(const ['Contas', 'Lançamentos', 'Resumo'][_aba]),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const ConfigTela()));
              setState(() => _versao++);
            },
          ),
        ],
      ),
      body: KeyedSubtree(
        key: ValueKey('$_aba-$_versao'),
        child: const [ContasTela(), LancamentosTela(), ResumoTela()][_aba],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) => setState(() => _aba = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Contas'),
          NavigationDestination(icon: Icon(Icons.swap_vert), label: 'Lançamentos'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), label: 'Resumo'),
        ],
      ),
    );
  }
}
