import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'models.dart';

class TagoService {
  final http.Client _client;
  TagoService([http.Client? client]) : _client = client ?? http.Client();

  /// Busca registros de uma variavel. Retorna do mais recente para o mais antigo.
  Future<List<Reading>> fetch(
    String variable, {
    int qty = 1,
    DateTime? start,
  }) async {
    final params = <String, String>{
      'variable': variable,
      'qty': '$qty',
      if (start != null) 'start_date': start.toUtc().toIso8601String(),
    };
    final uri = Uri.parse('${Config.baseUrl}/data').replace(
      queryParameters: params,
    );

    // Os dois cabecalhos levam o mesmo token: o contrato usa Device-Token e o
    // TagoIO tambem aceita Authorization; enviar ambos evita depender de um so.
    final resp = await _client.get(uri, headers: {
      'Device-Token': Config.token,
      'Authorization': Config.token,
      'Content-Type': 'application/json',
    }).timeout(const Duration(seconds: 15));

    if (resp.statusCode == 401) {
      throw Exception('Token invalido ou expirado (401).');
    }
    if (resp.statusCode != 200) {
      throw Exception('Erro da API: HTTP ${resp.statusCode}');
    }

    final body = jsonDecode(utf8.decode(resp.bodyBytes));
    if (body is! Map || body['status'] != true) {
      throw Exception('Resposta inesperada da API.');
    }

    final list = (body['result'] as List)
        .map((e) => Reading.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    list.sort((a, b) => b.time.compareTo(a.time));
    return list;
  }

  /// Ultimo valor de uma variavel (ou null se nao houver dados).
  Future<Reading?> latest(String variable) async {
    final r = await fetch(variable, qty: 1);
    return r.isEmpty ? null : r.first;
  }

  /// Alertas ativos (valor 1) das duas variaveis, do mais recente para o mais antigo.
  /// O alerta_temperatura tambem chega com 0 quando normaliza: isso nao e alerta.
  Future<List<Reading>> fetchAlertas({int qty = 30, DateTime? start}) async {
    final r = await Future.wait([
      fetch(Config.varAlertaTemp, qty: qty, start: start),
      fetch(Config.varAlertaHorario, qty: qty, start: start),
    ]);
    final todos = [...r[0], ...r[1]].where((a) => toBool(a.value)).toList()
      ..sort((a, b) => b.time.compareTo(a.time));
    return todos.length > qty ? todos.sublist(0, qty) : todos;
  }
}
