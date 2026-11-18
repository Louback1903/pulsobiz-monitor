import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../brand.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _ver = false;
  bool _carregando = false;
  String? _erro;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_email.text.trim().isEmpty || _senha.text.isEmpty) {
      setState(() => _erro = 'Informe o e-mail e a senha.');
      return;
    }
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      await AuthService.instance.entrar(_email.text, _senha.text);
      // Sucesso: o ValueListenableBuilder do main troca para o painel.
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.9),
            radius: 1.3,
            colors: [Color(0xFF14301F), Brand.bg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/brand/simbolo.png', width: 104),
                    const SizedBox(height: 14),
                    const Text.rich(
                      TextSpan(children: [
                        TextSpan(text: 'Pulso'),
                        TextSpan(text: 'Biz', style: TextStyle(color: Brand.acc)),
                      ]),
                      style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .3),
                    ),
                    const SizedBox(height: 2),
                    const Text('Monitor do seu comércio',
                        style: TextStyle(color: Brand.mut, fontSize: 15)),
                    const SizedBox(height: 26),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.username],
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'E-mail',
                                  prefixIcon: Icon(Icons.mail_outline),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _senha,
                                obscureText: !_ver,
                                autofillHints: const [AutofillHints.password],
                                onSubmitted: (_) => _entrar(),
                                decoration: InputDecoration(
                                  labelText: 'Senha',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(_ver
                                        ? Icons.visibility_off
                                        : Icons.visibility),
                                    onPressed: () => setState(() => _ver = !_ver),
                                  ),
                                ),
                              ),
                              if (_erro != null) ...[
                                const SizedBox(height: 12),
                                Text(_erro!,
                                    style: const TextStyle(color: Color(0xFFFF8A80))),
                              ],
                              const SizedBox(height: 18),
                              FilledButton(
                                onPressed: _carregando ? null : _entrar,
                                child: _carregando
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Brand.accDark))
                                    : const Text('Entrar'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Acesso fornecido pela PulsoBiz.\nNão tem login? Fale com a sua equipe PulsoBiz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Brand.mut, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
