import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'archive_screen.dart';
import 'daily_report_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AppState>().fetchHistoryOnDemand();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.isLoadingHistory && state.history.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF0b0e14),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF38bdf8))),
      );
    }
    final history = state.history.reversed.toList();
    final totalTime =
        state.history.fold(0.0, (s, h) => s + (h['time_cost'] ?? 0));
    final totalBuffet =
        state.history.fold(0.0, (s, h) => s + (h['buffet_cost'] ?? 0));

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: const Text('سجلات اليوم',
            style: TextStyle(
                color: Color(0xFF38bdf8), fontWeight: FontWeight.bold)),
        leading: const BackButton(color: Colors.white),
        actions: [
          // زرار تحديث السجل
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF38bdf8)),
            tooltip: 'تحديث السجل',
            onPressed: () => context.read<AppState>().fetchHistoryOnDemand(limit: 300),
          ),
          // زرار التقرير المفصل
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Color(0xFFf59e0b)),
            tooltip: 'تقرير اليوم المفصل',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DailyReportScreen()),
            ),
          ),
          // زرار الأرشيف الشامل
          IconButton(
            icon: const Icon(Icons.history_edu, color: Colors.white54),
            tooltip: 'الأرشيف الشامل',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ArchiveScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── ملخص الإجماليات ─────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1c2128),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryItem('🎮 اللعب', totalTime, const Color(0xFF38bdf8)),
                Container(width: 1, height: 30, color: Colors.white12),
                _SummaryItem('🥤 البوفيه', totalBuffet, Colors.orange),
                Container(width: 1, height: 30, color: Colors.white12),
                _SummaryItem('💰 الإجمالي', totalTime + totalBuffet,
                    const Color(0xFF4ade80)),
              ],
            ),
          ),

          // ── قائمة السجلات ────────────────────────────────────────────────
          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 64, color: Colors.white12),
                        const SizedBox(height: 16),
                        const Text('لا توجد سجلات لليوم بعد',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: history.length,
                    itemBuilder: (ctx, i) =>
                        _HistoryItem(record: history[i]),
                  ),
          ),

          // ── زرار الأرشفة في الأسفل ────────────────────────────────────────
          if (history.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: BoxDecoration(
                color: const Color(0xFF0b0e14),
                border: Border(
                  top: BorderSide(
                      color: Colors.white.withOpacity(0.07), width: 1),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: () => _confirmArchive(context, state),
                  icon: const Icon(Icons.archive_outlined, size: 22),
                  label: const Text(
                    'حفظ في الأرشيف ومسح السجل',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4ade80),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmArchive(BuildContext context, AppState state) {
    final history = state.history;
    final totalTime =
        history.fold(0.0, (s, h) => s + (h['time_cost'] ?? 0));
    final totalBuffet =
        history.fold(0.0, (s, h) => s + (h['buffet_cost'] ?? 0));
    final total = totalTime + totalBuffet;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.archive_outlined, color: Color(0xFF4ade80)),
          SizedBox(width: 8),
          Text('حفظ في الأرشيف؟',
              style: TextStyle(
                  color: Color(0xFF4ade80), fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ملخص ما سيتم أرشفته
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF4ade80).withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF4ade80).withOpacity(0.25)),
              ),
              child: Column(children: [
                _ArchiveRow('📋 عدد الجلسات', '${history.length} جلسة'),
                const SizedBox(height: 6),
                _ArchiveRow('🎮 إيراد اللعب',
                    '${totalTime.toStringAsFixed(1)} ج'),
                const SizedBox(height: 6),
                _ArchiveRow('🥤 إيراد البوفيه',
                    '${totalBuffet.toStringAsFixed(1)} ج'),
                const Divider(color: Colors.white12, height: 16),
                _ArchiveRow('💰 الإجمالي',
                    '${total.toStringAsFixed(1)} ج',
                    highlight: true),
              ]),
            ),
            const SizedBox(height: 14),
            // تحذير واضح
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'هيتم حفظ السجلات في الأرشيف الشامل\nوبعدين مسح سجل اليوم الحالي',
                    style: TextStyle(color: Colors.orange, fontSize: 12, height: 1.5),
                  ),
                ),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء',
                style: TextStyle(color: Colors.white54, fontSize: 15)),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await state.archiveAndClear();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Row(children: [
                    Icon(ok ? Icons.check_circle : Icons.error,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(ok
                        ? '✅ تم الحفظ في الأرشيف بنجاح'
                        : '❌ فشلت الأرشفة، حاول تاني'),
                  ]),
                  backgroundColor: ok ? Colors.green : Colors.red,
                  duration: const Duration(seconds: 3),
                ));
              }
            },
            icon: const Icon(Icons.archive_outlined, size: 18),
            label: const Text('حفظ ومسح السجل',
                style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4ade80),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widget داخل الـ dialog ────────────────────────────────────────────

class _ArchiveRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _ArchiveRow(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text(value,
            style: TextStyle(
                color: highlight
                    ? const Color(0xFF4ade80)
                    : Colors.white,
                fontWeight: highlight
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: highlight ? 15 : 13)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Summary Item
// ═══════════════════════════════════════════════════════════════════════════════

class _SummaryItem extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _SummaryItem(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style:
                const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Text('${value.toStringAsFixed(1)} ج',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// History Item
// ═══════════════════════════════════════════════════════════════════════════════

class _HistoryItem extends StatelessWidget {
  final Map<String, dynamic> record;
  const _HistoryItem({required this.record});

  @override
  Widget build(BuildContext context) {
    final isTable = record['device_type'] == 'table';
    final isDrink = record['device_type'] == 'drink_table';
    final isMatch = record['is_match'] == true;
    final isGame = record['is_game'] == true;

    Color typeColor = const Color(0xFF38bdf8);
    IconData icon = Icons.sports_esports;

    if (isTable) {
      typeColor = Colors.purpleAccent;
      icon = Icons.table_restaurant;
    } else if (isDrink) {
      typeColor = Colors.orange;
      icon = Icons.local_cafe;
    } else if (isMatch) {
      typeColor = Colors.green;
      icon = Icons.sports_soccer;
    }

    final dateStr = record['date'] as String? ?? '';
    final timeStr = dateStr.length > 16
    ? '${dateStr.substring(0, 10).replaceAll('-', '/')}  ${dateStr.substring(11, 16)}'
    : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: typeColor, size: 20),
        ),
        title: Text(record['name'] ?? 'جهاز',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14)),
       subtitle: Text(
  isMatch || isGame
      ? 'جيم سريع  •  $timeStr'
      : '${record['duration'] ?? ''} • $timeStr • ${record['play_mode'] == 'multi' ? '👥 مالتي' : '👤 عادي'}',
  style: const TextStyle(color: Colors.white38, fontSize: 11),
),
        trailing: Text(
            '${(record['total'] ?? 0).toStringAsFixed(1)} ج',
            style: const TextStyle(
                color: Color(0xFF4ade80),
                fontWeight: FontWeight.bold,
                fontSize: 15)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                _DetailRow(
                    isTable ? '🎱 التربيزة' : '🎮 اللعب',
                    '${(record['time_cost'] ?? 0).toStringAsFixed(1)} ج'),
                _DetailRow('🥤 البوفيه',
                    '${(record['buffet_cost'] ?? 0).toStringAsFixed(1)} ج'),

                if ((record['orders'] as Map?)?.isNotEmpty ==
                    true) ...[
                  const Divider(color: Colors.white12),
                  ...(record['orders'] as Map).entries.map((e) =>
                      _DetailRow('  • ${e.key}', 'x${e.value}')),
                ],

                if (record['session_log'] != null &&
                    (record['session_log'] as List)
                        .isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('📋 سجل الجلسة',
                        style: TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  ...(record['session_log'] as List)
                      .map((ev) => _LogEntryRow(event: ev)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

class _LogEntryRow extends StatelessWidget {
  final Map<String, dynamic> event;
  const _LogEntryRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final type = event['type'] as String;
    final time = event['time'] as String? ?? '';
    final note = event['note'] as String? ?? '';
    final role = event['role'] as String? ?? '';

    Color c;
    switch (type) {
      case 'start':
        c = Colors.green;
        break;
      case 'pause':
        c = Colors.amber;
        break;
      case 'resume':
        c = const Color(0xFF38bdf8);
        break;
      case 'add_time':
        final m = event['minutes'] as int? ?? 0;
        c = m > 0 ? const Color(0xFF4ade80) : Colors.redAccent;
        break;
      case 'stop':
        c = Colors.red;
        break;
      default:
        c = Colors.white38;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
                color: c.withOpacity(0.8),
                shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$note${role.isNotEmpty ? " ($role)" : ""}',
              style: TextStyle(
                  color: c.withOpacity(0.9), fontSize: 11),
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              color: Colors.white24,
              fontSize: 11,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
