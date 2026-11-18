import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class SessaoExpirada implements Exception {
  @override
  String toString() => 'Sua sessao expirou. Entre novamente.';
}

class _Sessao {
  final String access;
  final String refresh;
  final DateTime expira;
  final String email;
  _Sessao(this.access, this.refresh, this.expira, this.email);

  Map<String, dynamic> toJson() => {
        'access': access,
        'refresh': refresh,
        'expira': expira.toIso8601String(),
        'email': email,
      };

  static _Sessao? fromJson(Map<String, dynamic> j) {
    try {
      return _Sessao(j['access'] as String, j['refresh'] as String,
          DateTime.parse(j['expira'] as String), j['email'] as String);
    } catch (_) {
      return null;
    }
  }
}

/// Login do cliente (e-mail e senha fornecidos pela PulsoBiz), com renovacao automatica da sessao.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _chave = 'pulsobiz.sessao';
  http.Client client = http.Client();
  _Sessao? _s;

  /// true = ha cliente logado. A tela principal escuta isso.
  final ValueNotifier<bool> logado = ValueNotifier(false);

  /// Nome da loja (preenchido quando o painel carrega).
  final ValueNotifier<String> lojaNome = ValueNotifier('');

  String get email => _s?.email ?? '';

  Future<void> carregar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final txt = prefs.getString(_chave);
      if (txt != null) {
        _s = _Sessao.fromJson(jsonDecode(txt) as Map<String, dynamic>);
      }
    } catch (_) {
      _s = null;
    }
    logado.value = _s != null;
  }

  Future<void> _guardar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_s == null) {
        await prefs.remove(_chave);
      } else {
        await prefs.setString(_chave, jsonEncode(_s!.toJson()));
      }
    } catch (_) {/* sem armazenamento: a sessao vale so ate fechar o app */}
  }

  Map<String, String> get _cabecalhoAuth =>
      {'apikey': Config.publicKey, 'Content-Type': 'application/json'};

  Future<_Sessao> _pedirToken(Map<String, String> corpo, String tipo,
      {String emailFallback = ''}) async {
    final r = await client
        .post(Uri.parse('${Config.authUrl}/token?grant_type=$tipo'),
            headers: _cabecalhoAuth, body: jsonEncode(corpo))
        .timeout(const Duration(seconds: 15));
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode != 200 || d is! Map || d['access_token'] == null) {
      final msg = '${d is Map ? (d['error_description'] ?? d['msg'] ?? '') : ''}';
      throw Exception(RegExp('invalid|credentials', caseSensitive: false)
              .hasMatch(msg)
          ? 'E-mail ou senha incorretos.'
          : 'Nao foi possivel entrar. $msg'.trim());
    }
    final emailResp = (d['user'] is Map ? d['user']['email'] : null) as String?;
    return _Sessao(
      d['access_token'] as String,
      d['refresh_token'] as String,
      DateTime.now().add(Duration(seconds: (d['expires_in'] as num).toInt() - 60)),
      emailResp ?? emailFallback,
    );
  }

  Future<void> entrar(String email, String senha) async {
    try {
      _s = await _pedirToken(
          {'email': email.trim(), 'password': senha}, 'password');
    } on Exception catch (e) {
      if (e.toString().contains('incorretos')) rethrow;
      if (e.toString().startsWith('Exception: Nao foi')) rethrow;
      throw Exception('Sem conexao. Verifique a internet.');
    }
    await _guardar();
    logado.value = true;
  }

  /// Token de acesso valido (renova se estiver perto de vencer). null = precisa entrar de novo.
  Future<String?> tokenAcesso() async {
    final s = _s;
    if (s == null) return null;
    if (DateTime.now().isBefore(s.expira)) return s.access;
    try {
      _s = await _pedirToken({'refresh_token': s.refresh}, 'refresh_token',
          emailFallback: s.email);
      await _guardar();
      return _s!.access;
    } catch (_) {
      await sair();
      return null;
    }
  }

  Future<void> sair() async {
    _s = null;
    lojaNome.value = '';
    await _guardar();
    logado.value = false;
  }

  Future<void> trocarSenha(String novaSenha) async {
    final tk = await tokenAcesso();
    if (tk == null) throw SessaoExpirada();
    final r = await client
        .put(Uri.parse('${Config.authUrl}/user'),
            headers: {..._cabecalhoAuth, 'Authorization': 'Bearer $tk'},
            body: jsonEncode({'password': novaSenha}))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) {
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      throw Exception(
          '${d is Map ? (d['msg'] ?? d['error_description'] ?? 'Erro ao trocar a senha.') : 'Erro ao trocar a senha.'}');
    }
  }
}
