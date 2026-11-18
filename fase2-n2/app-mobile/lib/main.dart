import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'brand.dart';
import 'screens/home_page.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.instance.carregar();
  runApp(const PulsoBizApp());
}

class PulsoBizApp extends StatelessWidget {
  const PulsoBizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PulsoBiz',
      debugShowCheckedModeBanner: false,
      theme: Brand.theme(),
      // Sem login = tela de entrada. Ao sair ou expirar a sessao, volta sozinho para ela.
      home: ValueListenableBuilder<bool>(
        valueListenable: AuthService.instance.logado,
        builder: (_, logado, __) =>
            logado ? const HomePage() : const LoginScreen(),
      ),
    );
  }
}
