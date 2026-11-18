import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../config.dart';
import '../report.dart';
import '../api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _svc = ApiService();
  late Future<Report> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Report> _load() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(hours: Config.janelaHoras + 1));
    final r = await Future.wait([
      _svc.fetch(Config.varTemperatura, qty: 10000, start: start),
      _svc.fetch(Config.varMovimento, qty: 10000, start: start),
      _svc.fetchAlertas(qty: 1000, start: start),
    ]);
    return buildReport(
      temps: r[0],
      moves: r[1],
      alerts: r[2],
      now: now,
      hours: Config.janelaHoras,
      countEdges: Config.movimentoContaBorda,
    );
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    await f.catchError((_) => Report(
          avgTemp: null,
          minTemp: null,
          maxTemp: null,
          movements: 0,
          alerts: 0,
          buckets: const [],
          tempSeries: const [],
        ));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Report>(
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
        final rep = snap.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Resumo das últimas ${Config.janelaHoras} h',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Stat('Temp. media',
                      rep.avgTemp == null ? '--' : '${rep.avgTemp!.toStringAsFixed(1)} °C'),
                  _Stat('Movimentos', '${rep.movements}'),
                  _Stat('Alertas', '${rep.alerts}'),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('Horário de pico'),
                  subtitle: Text(rep.peakText),
                ),
              ),
              const SizedBox(height: 16),
              Text('Movimentos por hora',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _BarChart(rep.buckets, peak: rep.peak),
              const SizedBox(height: 24),
              Text(
                'Temperatura'
                '${rep.minTemp == null ? '' : ' (min ${rep.minTemp!.toStringAsFixed(1)} / max ${rep.maxTemp!.toStringAsFixed(1)} °C)'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: rep.tempSeries.length < 2
                    ? const Center(child: Text('Dados insuficientes'))
                    : CustomPaint(
                        painter: _LinePainter(
                            rep.tempSeries, Theme.of(context).colorScheme.primary),
                        size: Size.infinite,
                      ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Share.share(rep.toShareText()),
                icon: const Icon(Icons.share),
                label: const Text('Compartilhar resumo'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            children: [
              FittedBox(
                child: Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<HourBucket> buckets;
  final HourBucket? peak;
  const _BarChart(this.buckets, {this.peak});

  @override
  Widget build(BuildContext context) {
    final maxCount =
        buckets.fold<int>(0, (m, b) => b.count > m ? b.count : m);
    final primary = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < buckets.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (buckets[i].count > 0)
                      Text('${buckets[i].count}',
                          style: const TextStyle(fontSize: 8)),
                    Container(
                      height: maxCount == 0
                          ? 2
                          : 2 + 100 * buckets[i].count / maxCount,
                      color: identical(buckets[i], peak)
                          ? Colors.deepOrange
                          : primary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      i % 4 == 0 ? buckets[i].label.replaceAll('h', '') : '',
                      style: const TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  _LinePainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final mn = values.reduce((a, b) => a < b ? a : b);
    final mx = values.reduce((a, b) => a > b ? a : b);
    final range = (mx - mn) == 0 ? 1.0 : (mx - mn);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - ((values[i] - mn) / range) * (size.height - 8) - 4;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.values != values;
}
