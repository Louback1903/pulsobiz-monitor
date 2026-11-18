import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../brand.dart';
import 'account_screen.dart';
import 'alerts_screen.dart';
import 'history_screen.dart';
import 'live_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // Troca de tela recria o widget: o timer da tela "Painel" para sozinho.
    final pages = <Widget>[
      const LiveScreen(),
      const HistoryScreen(),
      const AlertsScreen(),
      const AccountScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset('assets/brand/simbolo.png', width: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text.rich(
                    TextSpan(children: [
                      TextSpan(text: 'Pulso'),
                      TextSpan(text: 'Biz', style: TextStyle(color: Brand.acc)),
                    ]),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  ValueListenableBuilder<String>(
                    valueListenable: AuthService.instance.lojaNome,
                    builder: (_, nome, __) => Text(
                      nome.isEmpty ? 'Monitor do seu comércio' : nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Brand.mut),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.speed_outlined),
              selectedIcon: Icon(Icons.speed),
              label: 'Painel'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Relatório'),
          NavigationDestination(
              icon: Icon(Icons.notifications_none),
              selectedIcon: Icon(Icons.notifications),
              label: 'Alertas'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Conta'),
        ],
      ),
    );
  }
}
