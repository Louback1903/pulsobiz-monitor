import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'config.dart';
import 'models.dart';

typedef TokenProvider = Future<String?> Function();

/// Acesso aos dados da loja do cliente logado (sempre com o login dele).
class ApiService {
  final http.Client _client;
  final TokenProvider _token;

  ApiService({http.Client? client, TokenProvider? token})
      : _client = client ?? http.Client(),
        _token = token ?? (() => AuthService.instance.tokenAcesso());

  Future<http.Response> _get(Uri uri) async {
    final tk = await _token();
    if (tk == null) throw SessaoExpirada();
    final resp = await _client.get(uri, headers: {
      'Authorization': 'Bearer $tk',
      'apikey': Config.publicKey,
    }).timeout(const Duration(seconds: 15));
    if (resp.statusCode == 401) {
      await AuthService.instance.sair();
      throw SessaoExpirada();
    }
    if (resp.statusCode != 200) {
      throw Exception('Erro da API: HTTP ${resp.statusCode}');
    }
    return resp;
  }

  Map<String, dynamic> _corpo(http.Response resp) {
    final body = jsonDecode(utf8.decode(resp.bodyBytes));
    if (body is! Map || body['status'] != true) {
      throw Exception('Resposta inesperada da API.');
    }
    return Map<String, dynamic>.from(body);
  }

  /// Painel pronto da loja (valores atuais, lotacao, temperatura ideal, series).
  Future<Map<String, dynamic>> dashboard() async {
    final uri = Uri.parse(Config.apiUrl).replace(queryParameters: {'view': 'dashboard'});
    final d = _corpo(await _get(uri));
    final loja = d['loja'];
    if (loja is Map && loja['nome'] != null) {
      AuthService.instance.lojaNome.value = '${loja['nome']}';
    }
    return d;
  }

  /// Busca registros de uma variavel. Retorna do mais recente para o mais antigo.
  Future<List<Reading>> fetch(
    String variable, {
    int qty = 1,
    DateTime? start,
  }) async {
    final uri = Uri.parse(Config.apiUrl).replace(queryParameters: {
      'variable': variable,
      'qty': '$qty',
      if (start != null) 'start_date': start.toUtc().toIso8601String(),
    });
    final body = _corpo(await _get(uri));
    final list = (body['result'] as List)
        .map((e) => Reading.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    list.sort((a, b) => b.time.compareTo(a.time));
    return list;
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
