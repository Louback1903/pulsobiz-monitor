import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';
import '../brand.dart';
import '../config.dart';
import '../models.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final _svc = ApiService();
  Timer? _timer;
  bool _loading = false;
  String? _error;
  DateTime? _updated;
  Map<String, dynamic>? _d;

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
      final d = await _svc.dashboard();
      if (!mounted) return;
      setState(() {
        _d = d;
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

  // ---- leitura do painel ----
  Map<String, dynamic>? _latest(String v) {
    final l = _d?['latest'];
    if (l is Map && l[v] is Map) return Map<String, dynamic>.from(l[v] as Map);
    return null;
  }

  DateTime? _tempo(Map<String, dynamic>? m) =>
      m == null ? null : DateTime.tryParse('${m['t']}')?.toLocal();

  @override
  Widget build(BuildContext context) {
    final tempM = _latest(Config.varTemperatura);
    final temp = toDouble(tempM?['v']);
    final umid = toDouble(_latest(Config.varUmidade)?['v']);
    final movM = _latest(Config.varMovimento);
    final movT = _tempo(movM);
    final movRecente = movT != null &&
        DateTime.now().difference(movT) <
            const Duration(seconds: Config.movimentoRecenteSegundos);
    final releM = _latest(Config.varRele);
    final rele = releM == null ? null : toBool(releM['v']);

    final meta = _d?['meta'] is Map ? Map<String, dynamic>.from(_d!['meta'] as Map) : null;
    final lotacao = (meta?['lotacao'] as num?)?.toInt();
    final ideal = toDouble(meta?['ideal']);
    final estabilizada = meta?['estabilizada'] == true;

    final tTemp = _tempo(tempM);
    final agora = DateTime.tryParse('${_d?['now']}')?.toLocal() ?? DateTime.now();
    final online = tTemp != null &&
        agora.difference(tTemp) < const Duration(minutes: Config.offlineMinutos);
    final semDadosTxt = tTemp == null
        ? 'Sem dados ainda'
        : 'Sem dados há ${agora.difference(tTemp).inMinutes} min';

    final serie = <double>[];
    final s = _d?['series'];
    if (s is Map && s['temperatura'] is List) {
      for (final p in s['temperatura'] as List) {
        final v = toDouble(p is List && p.length > 1 ? p[1] : null);
        if (v != null) serie.add(v);
      }
    }

    String? alertaTemp;
    if (temp != null && temp > 32) {
      alertaTemp = 'Alerta: acima de 32 °C';
    } else if (temp != null && temp > 28) {
      alertaTemp = 'Acima de 28 °C';
    } else if (temp != null) {
      alertaTemp = 'Normal';
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              _Chip(
                texto: _d == null ? 'Carregando...' : (online ? 'Dispositivo online' : semDadosTxt),
                cor: _d == null ? Brand.mut : (online ? Brand.acc : Brand.bad),
              ),
              const Spacer(),
              Text(
                _updated == null
                    ? ''
                    : 'Atualizado às ${DateFormat('HH:mm:ss').format(_updated!)}',
                style: const TextStyle(color: Brand.mut, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: const Color(0xFF3A1A1A),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Falha ao atualizar: $_error'),
                ),
              ),
            ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [
              _Tile(
                icon: Icons.thermostat,
                label: 'Temperatura',
                value: temp == null ? '--' : '${temp.toStringAsFixed(1)} °C',
                sub: alertaTemp ?? ' ',
                color: (temp ?? 0) > 32 ? Brand.bad : Brand.warn,
              ),
              _Tile(
                icon: Icons.water_drop,
                label: 'Umidade',
                value: umid == null ? '--' : '${umid.toStringAsFixed(0)} %',
                sub: 'relativa do ar',
                color: Brand.cyan,
              ),
              _Tile(
                icon: Icons.groups,
                label: 'Lotação',
                value: lotacao == null
                    ? '--'
                    : '$lotacao ${lotacao == 1 ? 'pessoa' : 'pessoas'}',
                sub: 'na loja agora',
                color: Brand.acc,
              ),
              _Tile(
                icon: Icons.tune,
                label: 'Temp. ideal',
                value: ideal == null ? '--' : '${ideal.toStringAsFixed(1)} °C',
                sub: meta == null
                    ? ' '
                    : (estabilizada ? 'estabilizada' : 'ajustando a meta...'),
                color: estabilizada ? Brand.acc : Brand.warn,
              ),
              _Tile(
                icon: Icons.directions_run,
                label: 'Movimento',
                value: movT == null
                    ? 'Nenhum'
                    : (movRecente ? 'Detectado' : 'Nenhum agora'),
                sub: movT == null ? 'sem registros' : 'último às ${DateFormat('HH:mm').format(movT)}',
                color: movRecente ? Brand.warn : Brand.mut,
              ),
              _Tile(
                icon: Icons.mode_fan_off_outlined,
                label: 'Ventilador',
                value: rele == null ? '--' : (rele ? 'Ligado' : 'Desligado'),
                sub: 'liga acima de 28 °C',
                color: rele == true ? Brand.acc : Brand.mut,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TEMPERATURA (24 H)',
                      style: TextStyle(
                          color: Brand.mut,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .6)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 90,
                    child: serie.length < 2
                        ? const Center(
                            child: Text('Aguardando dados...',
                                style: TextStyle(color: Brand.mut)))
                        : CustomPaint(
                            painter: _SparkPainter(serie),
                            size: Size.infinite),
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

class _Chip extends StatelessWidget {
  final String texto;
  final Color cor;
  const _Chip({required this.texto, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withOpacity(.15),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, size: 9, color: cor),
        const SizedBox(width: 6),
        Text(texto, style: TextStyle(color: cor, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _Tile({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Brand.mut,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .6)),
              ),
            ]),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800, color: color)),
            ),
            const SizedBox(height: 4),
            Text(sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Brand.mut, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> values;
  _SparkPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    var mn = values.reduce((a, b) => a < b ? a : b);
    var mx = values.reduce((a, b) => a > b ? a : b);
    if (mx - mn < 2) {
      mx += 1;
      mn -= 1;
    }
    final range = mx - mn;
    final pts = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(size.width * i / (values.length - 1),
            size.height - ((values[i] - mn) / range) * (size.height - 12) - 6),
    ];
    final linha = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      linha.lineTo(p.dx, p.dy);
    }
    final area = Path.from(linha)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Brand.warn.withOpacity(.30), Brand.warn.withOpacity(0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      linha,
      Paint()
        ..color = Brand.warn
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.values != values;
}
