import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config.dart';
import '../models.dart';
import '../tago_service.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final _svc = TagoService();
  Timer? _timer;
  bool _loading = false;
  String? _error;
  DateTime? _updated;

  Reading? _temp, _umid, _mov, _rele;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(
      const Duration(seconds: Config.refreshSeconds),
      (_) => _load(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return; // evita requisicoes sobrepostas
    _loading = true;
    try {
      final r = await Future.wait([
        _svc.latest(Config.varTemperatura),
        _svc.latest(Config.varUmidade),
        _svc.latest(Config.varMovimento),
        _svc.latest(Config.varRele),
      ]);
      if (!mounted) return;
      setState(() {
        _temp = r[0];
        _umid = r[1];
        _mov = r[2];
        _rele = r[3];
        _updated = DateTime.now();
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final temp = toDouble(_temp?.value);
    final umid = toDouble(_umid?.value);
    final movRecente = _mov != null &&
        DateTime.now().difference(_mov!.time) <
            const Duration(seconds: Config.movimentoRecenteSegundos);
    final rele = _rele == null ? null : toBool(_rele!.value);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Falha ao atualizar: $_error'),
            ),
          ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: [
            _Tile(
              icon: Icons.thermostat,
              label: 'Temperatura',
              value: temp == null ? '--' : '${temp.toStringAsFixed(1)} °C',
              color: Colors.orange,
            ),
            _Tile(
              icon: Icons.water_drop,
              label: 'Umidade',
              value: umid == null ? '--' : '${umid.toStringAsFixed(0)} %',
              color: Colors.blue,
            ),
            _Tile(
              icon: Icons.directions_run,
              label: 'Movimento',
              value: _mov == null
                  ? 'Nenhum registro'
                  : (movRecente
                      ? 'Detectado'
                      : 'Ultimo: ${DateFormat('HH:mm').format(_mov!.time)}'),
              color: movRecente ? Colors.red : Colors.grey,
            ),
            _Tile(
              icon: Icons.power,
              label: 'Rele',
              value: rele == null ? '--' : (rele ? 'Ligado' : 'Desligado'),
              color: rele == true ? Colors.green : Colors.grey,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _updated == null
                ? 'Carregando...'
                : 'Atualizado as ${DateFormat('HH:mm:ss').format(_updated!)} '
                    '(a cada ${Config.refreshSeconds} s)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _Tile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
