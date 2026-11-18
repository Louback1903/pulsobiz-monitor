import 'package:flutter/material.dart';
import 'config.dart';
import 'screens/alerts_screen.dart';
import 'screens/history_screen.dart';
import 'screens/live_screen.dart';
import 'screens/web_screen.dart';

void main() => runApp(const MonitorApp());

class MonitorApp extends StatelessWidget {
  const MonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monitor IoT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (Config.token.isEmpty) {
      return const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Token nao configurado.\n\n'
              'Compile com:\nflutter run --dart-define-from-file=env.json',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final temWeb = Config.dashboardUrl.isNotEmpty;
    final pages = <Widget>[
      const LiveScreen(),
      const HistoryScreen(),
      const AlertsScreen(),
      if (temWeb) const WebScreen(),
    ];
    final titles = ['Ao vivo', 'Relatorio', 'Alertas', if (temWeb) 'Dashboard'];

    // Troca de tela recria o widget: o timer da tela "Ao vivo" para sozinho.
    return Scaffold(
      appBar: AppBar(title: Text(titles[_index])),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.speed), label: 'Ao vivo'),
          const NavigationDestination(
              icon: Icon(Icons.bar_chart), label: 'Relatorio'),
          const NavigationDestination(
              icon: Icon(Icons.warning_amber), label: 'Alertas'),
          if (temWeb)
            const NavigationDestination(
                icon: Icon(Icons.public), label: 'Dashboard'),
        ],
      ),
    );
  }
}
