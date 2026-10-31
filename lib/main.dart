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
import 'telas/inicio.dart';
import 'telas/receitas.dart';
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
                style: TextStyle(color: c.vencimento.isBefore(h) ? Theme.of(ctx).colorScheme.error : null)),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
    ),
  );
}

/// Paleta dos mockups (docs/design/contas-v2.figcraft).
ThemeData tema(Brightness b) {
  final escuro = b == Brightness.dark;
  final cs = ColorScheme(
    brightness: b,
    primary: escuro ? const Color(0xFF7CC4A4) : const Color(0xFF1E5B45),
    onPrimary: escuro ? const Color(0xFF0F2A20) : Colors.white,
    primaryContainer: escuro ? const Color(0xFF1E3D31) : const Color(0xFFE2F2EA),
    onPrimaryContainer: escuro ? const Color(0xFFCDEBDD) : const Color(0xFF143A2D),
    secondary: escuro ? const Color(0xFF7CC4A4) : const Color(0xFF1E5B45),
    onSecondary: escuro ? const Color(0xFF0F2A20) : Colors.white,
    tertiary: escuro ? const Color(0xFFE3B341) : const Color(0xFFA16207),
    onTertiary: escuro ? Colors.black : Colors.white,
    error: escuro ? const Color(0xFFF08A5D) : const Color(0xFFC2410C),
    onError: escuro ? Colors.black : Colors.white,
    surface: escuro ? const Color(0xFF121614) : const Color(0xFFF5F3EE),
    onSurface: escuro ? const Color(0xFFE8ECE9) : const Color(0xFF16211C),
    onSurfaceVariant: escuro ? const Color(0xFF9AA39E) : const Color(0xFF6B756F),
    surfaceContainerLowest: escuro ? const Color(0xFF1B201D) : Colors.white,
    surfaceContainerLow: escuro ? const Color(0xFF1B201D) : Colors.white,
    surfaceContainer: escuro ? const Color(0xFF1B201D) : Colors.white,
    surfaceContainerHigh: escuro ? const Color(0xFF222825) : Colors.white,
    outline: escuro ? const Color(0xFF4A524D) : const Color(0xFFC9C4BA),
    outlineVariant: escuro ? const Color(0xFF2A302C) : const Color(0xFFEFECE6),
  );
  final redondo = RoundedRectangleBorder(borderRadius: BorderRadius.circular(999));
  return ThemeData(
    colorScheme: cs,
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
      titleSmall: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
    ),
    scaffoldBackgroundColor: cs.surface,
    appBarTheme: AppBarTheme(
        backgroundColor: cs.surface, surfaceTintColor: Colors.transparent, centerTitle: false,
        titleTextStyle: TextStyle(
            fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w600, color: cs.onSurface)),
    cardTheme: CardThemeData(
        color: cs.surfaceContainerLowest, elevation: 0, margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    dividerTheme: DividerThemeData(color: cs.outlineVariant, space: 1),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            shape: redondo, textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600))),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary, foregroundColor: cs.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
    inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: cs.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
    navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surfaceContainerLowest, indicatorColor: cs.primaryContainer,
        surfaceTintColor: Colors.transparent, elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: 'Inter', fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? cs.onPrimaryContainer : cs.onSurfaceVariant))),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contas',
      theme: tema(Brightness.light),
      darkTheme: tema(Brightness.dark),
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
        title: Text(const ['Início', 'Contas', 'Receitas', 'Resumo'][_aba]),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configurações',
            onPressed: () async {
              await Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const ConfigTela()));
              setState(() => _versao++);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: KeyedSubtree(
        key: ValueKey('$_aba-$_versao'),
        child: switch (_aba) {
          0 => InicioTela(verContas: () => setState(() => _aba = 1)),
          1 => const ContasTela(),
          2 => const ReceitasTela(),
          _ => const ResumoTela(),
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: NavigationBar(
              height: 68,
              selectedIndex: _aba,
              onDestinationSelected: (i) => setState(() => _aba = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
                NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Contas'),
                NavigationDestination(icon: Icon(Icons.savings_outlined), selectedIcon: Icon(Icons.savings), label: 'Receitas'),
                NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Resumo'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
