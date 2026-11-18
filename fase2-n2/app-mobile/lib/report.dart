import 'config.dart';
import 'models.dart';

class HourBucket {
  final DateTime start;
  final int count;
  HourBucket(this.start, this.count);

  String get label => '${start.hour.toString().padLeft(2, '0')}h';
}

class Report {
  final double? avgTemp;
  final double? minTemp;
  final double? maxTemp;
  final int movements;
  final int alerts;
  final List<HourBucket> buckets;
  final List<double> tempSeries; // em ordem cronologica

  Report({
    required this.avgTemp,
    required this.minTemp,
    required this.maxTemp,
    required this.movements,
    required this.alerts,
    required this.buckets,
    required this.tempSeries,
  });

  /// Hora com mais movimentos (null se nao houve nenhum).
  HourBucket? get peak {
    HourBucket? best;
    for (final b in buckets) {
      if (b.count > 0 && (best == null || b.count > best.count)) best = b;
    }
    return best;
  }

  String get peakText {
    final p = peak;
    if (p == null) return 'sem movimentos';
    final end = (p.start.hour + 1) % 24;
    return '${p.label} as ${end.toString().padLeft(2, '0')}h '
        '(${p.count} mov.)';
  }

  String toShareText() {
    final t = avgTemp == null ? '--' : avgTemp!.toStringAsFixed(1);
    return 'Resumo das ultimas ${Config.janelaHoras} h\n'
        'Temperatura media: $t C\n'
        'Movimentos: $movements\n'
        'Alertas: $alerts\n'
        'Horario de pico: $peakText';
  }
}

Report buildReport({
  required List<Reading> temps,
  required List<Reading> moves,
  required List<Reading> alerts,
  required DateTime now,
  int hours = 24,
  bool countEdges = false,
}) {
  // Janela alinhada ao inicio da hora: 24 blocos de 1 hora, o ultimo e a hora atual.
  final windowStart = DateTime(now.year, now.month, now.day, now.hour)
      .subtract(Duration(hours: hours - 1));

  bool inWindow(Reading r) => !r.time.isBefore(windowStart);

  // Temperatura
  final tempReadings = temps.where(inWindow).toList()
    ..sort((a, b) => a.time.compareTo(b.time));
  final tempValues = tempReadings
      .map((r) => toDouble(r.value))
      .whereType<double>()
      .toList();
  double? avg, mn, mx;
  if (tempValues.isNotEmpty) {
    avg = tempValues.reduce((a, b) => a + b) / tempValues.length;
    mn = tempValues.reduce((a, b) => a < b ? a : b);
    mx = tempValues.reduce((a, b) => a > b ? a : b);
  }

  // Movimentos
  final moveReadings = moves.where(inWindow).toList()
    ..sort((a, b) => a.time.compareTo(b.time));
  final events = <DateTime>[];
  bool? prev;
  for (final r in moveReadings) {
    final cur = toBool(r.value);
    final conta = countEdges ? (cur && prev != true) : cur;
    if (conta) events.add(r.time);
    prev = cur;
  }

  final counts = List<int>.filled(hours, 0);
  for (final t in events) {
    final idx = t.difference(windowStart).inHours;
    if (idx >= 0 && idx < hours) counts[idx]++;
  }
  final buckets = List.generate(
    hours,
    (i) => HourBucket(windowStart.add(Duration(hours: i)), counts[i]),
  );

  return Report(
    avgTemp: avg,
    minTemp: mn,
    maxTemp: mx,
    movements: events.length,
    alerts: alerts.where(inWindow).length,
    buckets: buckets,
    tempSeries: tempValues,
  );
}
