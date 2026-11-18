import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monitor_iot/models.dart';
import 'package:monitor_iot/report.dart';
import 'package:monitor_iot/api_service.dart';

Reading r(String v, dynamic value, DateTime t) =>
    Reading(variable: v, value: value, time: t);

void main() {
  final now = DateTime(2025, 11, 10, 15, 30);

  test('media, movimentos, alertas e pico', () {
    final temps = [
      r('temperatura', 20, DateTime(2025, 11, 10, 10)),
      r('temperatura', 30, DateTime(2025, 11, 10, 11)),
    ];
    final moves = [
      r('movimento', true, DateTime(2025, 11, 10, 14, 5)),
      r('movimento', true, DateTime(2025, 11, 10, 14, 20)),
      r('movimento', false, DateTime(2025, 11, 10, 14, 25)),
      r('movimento', true, DateTime(2025, 11, 10, 9, 0)),
    ];
    final alerts = [r('alerta', 'x', DateTime(2025, 11, 10, 12))];

    final rep = buildReport(temps: temps, moves: moves, alerts: alerts, now: now);

    expect(rep.avgTemp, 25.0);
    expect(rep.movements, 3);
    expect(rep.alerts, 1);
    expect(rep.peak!.start.hour, 14);
    expect(rep.peak!.count, 2);
  });

  test('ignora dados fora da janela de 24 h', () {
    final moves = [r('movimento', true, DateTime(2025, 11, 8, 10))];
    final rep = buildReport(temps: [], moves: moves, alerts: [], now: now);
    expect(rep.movements, 0);
    expect(rep.peak, isNull);
    expect(rep.avgTemp, isNull);
  });

  test('contagem por borda', () {
    final moves = [
      r('movimento', 1, DateTime(2025, 11, 10, 14, 0)),
      r('movimento', 1, DateTime(2025, 11, 10, 14, 1)),
      r('movimento', 0, DateTime(2025, 11, 10, 14, 2)),
      r('movimento', 1, DateTime(2025, 11, 10, 14, 3)),
    ];
    final rep = buildReport(
        temps: [], moves: moves, alerts: [], now: now, countEdges: true);
    expect(rep.movements, 2);
  });

  test('fetchAlertas junta as duas variaveis e ignora valor 0', () async {
    final client = MockClient((req) async {
      final v = req.url.queryParameters['variable'];
      final itens = v == 'alerta_temperatura'
          ? [
              {'variable': v, 'value': 1, 'time': '2025-11-10T12:00:00.000Z'},
              {'variable': v, 'value': 0, 'time': '2025-11-10T13:00:00.000Z'},
            ]
          : [
              {'variable': v, 'value': 1, 'time': '2025-11-10T14:00:00.000Z'},
            ];
      return http.Response(jsonEncode({'status': true, 'result': itens}), 200);
    });
    final lista = await ApiService(client: client, token: () async => 'jwt-de-teste').fetchAlertas();
    expect(lista.length, 2);
    expect(lista.first.variable, 'alerta_fora_horario');
  });
}
