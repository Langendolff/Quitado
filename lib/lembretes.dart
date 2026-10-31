import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'logica.dart';
import 'models.dart';

/// Notificações agendadas só no Android; no Linux tudo é no-op
/// (o aviso desktop aparece ao abrir o app, ver main.dart).
class Lembretes {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool get suportado => Platform.isAndroid;

  static Future<void> iniciar() async {
    if (!suportado) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
        settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    unawaited(_plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission() ?? Future.value());
  }

  static Future<void> agendar(Conta c, int dias) async {
    if (!suportado || c.id == null || c.pagoEm != null) return;
    final v = c.vencimento;
    var quando = DateTime(v.year, v.month, v.day - dias, 9);
    if (quando.isBefore(DateTime.now())) {
      if (v.isBefore(hoje())) return;
      quando = DateTime.now().add(const Duration(minutes: 1)); // dentro da janela de aviso
    }
    // ponytail: instante local convertido para UTC; dispensa descobrir o fuso do aparelho
    await _plugin.zonedSchedule(
      id: c.id!,
      title: dias == 0 ? 'Conta vence hoje' : 'Conta vence em $dias dia(s)',
      body: '${c.descricao} — ${reais(c.valor)}',
      scheduledDate: tz.TZDateTime.from(quando, tz.UTC),
      notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('vencimentos', 'Vencimentos')),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancelar(int id) async {
    if (suportado) await _plugin.cancel(id: id);
  }

  static Future<void> reagendarTodos(List<Conta> contas, int dias) async {
    if (!suportado) return;
    await _plugin.cancelAll();
    for (final c in contas) {
      await agendar(c, dias);
    }
  }
}
