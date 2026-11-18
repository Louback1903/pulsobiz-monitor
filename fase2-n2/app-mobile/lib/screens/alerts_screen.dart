import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config.dart';
import '../models.dart';
import '../tago_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _svc = TagoService();
  late Future<List<Reading>> _future;

  @override
  void initState() {
    super.initState();
    _future = _svc.fetchAlertas(qty: 30);
  }

  Future<void> _refresh() async {
    final f = _svc.fetchAlertas(qty: 30);
    setState(() => _future = f);
    await f.catchError((_) => <Reading>[]);
  }

  String _mensagem(Reading r) => r.variable == Config.varAlertaTemp
      ? 'Temperatura alta no ambiente'
      : 'Movimento fora do expediente';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Reading>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      'Erro: ${snap.error.toString().replaceFirst('Exception: ', '')}',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                      onPressed: _refresh, child: const Text('Tentar de novo')),
                ],
              ),
            ),
          );
        }
        final alertas = snap.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: alertas.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Nenhum alerta recebido.')),
                ])
              : ListView.separated(
                  itemCount: alertas.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final a = alertas[i];
                    return ListTile(
                      leading: const Icon(Icons.warning_amber,
                          color: Colors.orange),
                      title: Text(_mensagem(a)),
                      subtitle:
                          Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(a.time)),
                    );
                  },
                ),
        );
      },
    );
  }
}
