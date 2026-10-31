import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../lembretes.dart';
import '../main.dart';
import '../models.dart';

class ConfigTela extends StatefulWidget {
  const ConfigTela({super.key});
  @override
  State<ConfigTela> createState() => _ConfigTelaState();
}

class _ConfigTelaState extends State<ConfigTela> {
  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _mudarDias(int d) async {
    await prefs.setInt('dias_aviso', d);
    await Lembretes.reagendarTodos(await db.contasEmAberto(), d);
    setState(() {});
  }

  Future<void> _exportar() async {
    final json = jsonEncode(await db.exportar(diasAviso));
    final nome = 'contas-backup-${iso(hoje())}.json';
    if (Platform.isAndroid) {
      final f = File('${(await getTemporaryDirectory()).path}/$nome');
      await f.writeAsString(json);
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path)]));
    } else {
      final local = await getSaveLocation(suggestedName: nome);
      if (local == null) return;
      await File(local.path).writeAsString(json);
      if (mounted) _msg('Backup salvo');
    }
  }

  Future<void> _importar() async {
    // Android: sem filtro, gerenciadores de arquivo nem sempre reconhecem .json
    final f = await openFile(
        acceptedTypeGroups:
            Platform.isAndroid ? const [] : const [XTypeGroup(label: 'JSON', extensions: ['json'])]);
    if (f == null) return;
    final Map<String, Object?> dados;
    try {
      dados = jsonDecode(await f.readAsString()) as Map<String, Object?>;
    } catch (_) {
      if (mounted) _msg('Arquivo inválido');
      return;
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Importar backup?'),
              content: const Text('Todos os dados atuais serão substituídos.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Substituir')),
              ],
            ));
    if (ok != true) return;
    try {
      final dias = (await db.importar(dados)).clamp(0, 10); // limite do seletor
      await prefs.setInt('dias_aviso', dias);
      await Lembretes.reagendarTodos(await db.contasEmAberto(), dias);
      setState(() {});
      if (mounted) _msg('Backup importado');
    } on FormatException catch (e) {
      if (mounted) _msg(e.message);
    } catch (_) {
      // erro do sqflite (ids duplicados, NOT NULL): transação desfeita
      if (mounted) _msg('Arquivo de backup inválido');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(children: [
        ListTile(
          title: const Text('Avisar antes do vencimento'),
          subtitle: Lembretes.suportado ? null : const Text('No computador o aviso aparece ao abrir o app'),
          trailing: DropdownButton<int>(
            value: diasAviso,
            items: [
              for (var d = 0; d <= 10; d++)
                DropdownMenuItem(value: d, child: Text(d == 0 ? 'No dia' : '$d dia(s)')),
            ],
            onChanged: (d) => _mudarDias(d!),
          ),
        ),
        const Divider(),
        ListTile(leading: const Icon(Icons.upload), title: const Text('Exportar backup'), onTap: _exportar),
        ListTile(leading: const Icon(Icons.download), title: const Text('Importar backup'), onTap: _importar),
      ]),
    );
  }
}
