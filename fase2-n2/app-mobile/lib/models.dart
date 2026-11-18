bool toBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    return ['true', '1', 'on', 'ligado', 'ligada', 'sim', 'detectado']
        .contains(s);
  }
  return false;
}

double? toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.'));
  return null;
}

class Reading {
  final String variable;
  final dynamic value;
  final DateTime time;
  final String? unit;
  final Map<String, dynamic> metadata;

  Reading({
    required this.variable,
    required this.value,
    required this.time,
    this.unit,
    this.metadata = const {},
  });

  factory Reading.fromJson(Map<String, dynamic> j) => Reading(
        variable: j['variable']?.toString() ?? '',
        value: j['value'],
        time: DateTime.parse(j['time'] as String).toLocal(),
        unit: j['unit']?.toString(),
        metadata: j['metadata'] is Map
            ? Map<String, dynamic>.from(j['metadata'] as Map)
            : const {},
      );
}
