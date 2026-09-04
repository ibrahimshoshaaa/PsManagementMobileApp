// lib/services/shift_service.dart

class ShiftRecord {
  final String cashierName;
  final DateTime startTime;
  final DateTime? endTime;
  final List<Map<String, dynamic>> transactions;

  ShiftRecord({
    required this.cashierName,
    required this.startTime,
    this.endTime,
    required this.transactions,
  });

  bool get isOpen => endTime == null;

  Duration get duration =>
      (endTime ?? DateTime.now()).difference(startTime);

  // ── إجماليات ──────────────────────────────────────────────────────────────
  double get totalTime =>
      transactions.fold(0.0, (s, t) => s + ((t['time_cost'] as num?) ?? 0));

  double get totalBuffet =>
      transactions.fold(0.0, (s, t) => s + ((t['buffet_cost'] as num?) ?? 0));

  double get totalRevenue => totalTime + totalBuffet;

  int get sessionCount => transactions.length;

  // ── إجمالي الماتشات والجيمات ─────────────────────────────────────────────
  int get totalMatches =>
      transactions.where((t) => t['is_match'] == true).length;

  int get totalGames =>
      transactions.where((t) => t['is_game'] == true).length;

  // ── تفاصيل كل جهاز ───────────────────────────────────────────────────────
  /// deviceName → {sessions, revenue, time_cost, buffet_cost, device_type}
  Map<String, Map<String, dynamic>> get deviceBreakdown {
    final result = <String, Map<String, dynamic>>{};
    for (final t in transactions) {
      final name = t['name']?.toString() ?? 'غير محدد';
      final type = t['device_type']?.toString() ?? '';
      if (type == 'drink_table') continue;
      if (t['is_match'] == true || t['is_game'] == true) continue;
      result.putIfAbsent(name, () => {
        'sessions': 0,
        'revenue': 0.0,
        'time_cost': 0.0,
        'buffet_cost': 0.0,
        'device_type': type,
        'total_elapsed_seconds': 0,
      });
      result[name]!['sessions'] = (result[name]!['sessions'] as int) + 1;
      result[name]!['time_cost'] = (result[name]!['time_cost'] as double)
          + ((t['time_cost'] as num?) ?? 0).toDouble();
      result[name]!['buffet_cost'] = (result[name]!['buffet_cost'] as double)
          + ((t['buffet_cost'] as num?) ?? 0).toDouble();
      result[name]!['revenue'] = (result[name]!['revenue'] as double)
          + ((t['total'] as num?) ?? 0).toDouble();
      result[name]!['total_elapsed_seconds'] =
          (result[name]!['total_elapsed_seconds'] as int)
          + ((t['elapsed_seconds'] as num?) ?? 0).toInt();
    }
    return result;
  }

  // ── ملخص أصناف البوفيه ────────────────────────────────────────────────────
  Map<String, int> get itemsSold {
    final totals = <String, int>{};
    for (final t in transactions) {
      final orders = t['orders'] as Map?;
      if (orders != null) {
        orders.forEach((item, qty) {
          totals[item.toString()] =
              (totals[item.toString()] ?? 0) + ((qty as num?)?.toInt() ?? 0);
        });
      }
    }
    return totals;
  }

  // ── أكتر جهاز اشتغل ──────────────────────────────────────────────────────
  String? get topDevice {
    final counts = <String, int>{};
    for (final t in transactions) {
      final name = t['name'] as String?;
      if (name != null &&
          t['device_type'] != 'drink_table' &&
          t['is_match'] != true &&
          t['is_game'] != true) {
        counts[name] = (counts[name] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  // ── أكتر صنف اتباع ────────────────────────────────────────────────────────
  String? get topItem {
    final sold = itemsSold;
    if (sold.isEmpty) return null;
    return sold.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  Map<String, dynamic> toJson() => {
        'cashier_name': cashierName,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'transactions': transactions,
      };

  factory ShiftRecord.fromJson(Map<String, dynamic> j) => ShiftRecord(
        cashierName: j['cashier_name'] ?? '',
        startTime: DateTime.parse(j['start_time']),
        endTime:
            j['end_time'] != null ? DateTime.parse(j['end_time']) : null,
        transactions: List<Map<String, dynamic>>.from(
          (j['transactions'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e)),
        ),
      );
}
