// lib/screens/shift_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/shift_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// شاشة بداية الشيفت
// ══════════════════════════════════════════════════════════════════════════════

class ShiftStartScreen extends StatelessWidget {
  final String cashierName;
  final VoidCallback onShiftStarted;

  const ShiftStartScreen({
    super.key,
    required this.cashierName,
    required this.onShiftStarted,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dateStr = '${now.day}/${now.month}/${now.year}';

    final initial =
        cashierName.isNotEmpty ? cashierName[0].toUpperCase() : 'K';

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF38bdf8).withOpacity(0.15),
                  border: Border.all(
                      color: const Color(0xFF38bdf8).withOpacity(0.5),
                      width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38bdf8).withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(initial,
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF38bdf8),
                      )),
                ),
              ),
              const SizedBox(height: 20),
              Text('أهلاً، $cashierName 👋',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  )),
              const SizedBox(height: 6),
              Text('$dateStr  •  $timeStr',
                  style: const TextStyle(color: Colors.white38, fontSize: 14)),
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1c2128),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF38bdf8).withOpacity(0.2)),
                ),
                child: const Column(children: [
                  Icon(Icons.access_time_filled,
                      color: Color(0xFF38bdf8), size: 32),
                  SizedBox(height: 12),
                  Text('جاهز تبدأ شيفتك؟',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 6),
                  Text(
                    'كل العمليات اللي هتعملها هتتسجل\nتحت اسمك في تقرير الشيفت',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white54, fontSize: 13, height: 1.5),
                  ),
                ]),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: () {
                    context.read<AppState>().startShift(cashierName);
                    onShiftStarted();
                  },
                  icon: const Icon(Icons.play_circle_fill, size: 24),
                  label: const Text('بداية الشيفت',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF38bdf8),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.read<AppState>().logout(),
                child: const Text('مش أنا، رجوع',
                    style: TextStyle(color: Colors.white38)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// زرار إنهاء الشيفت
// ══════════════════════════════════════════════════════════════════════════════

class EndShiftButton extends StatelessWidget {
  const EndShiftButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.withOpacity(0.4)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.stop_circle_outlined, color: Colors.red, size: 16),
          SizedBox(width: 4),
          Text('إنهاء الشيفت',
              style: TextStyle(
                  color: Colors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ]),
      ),
      onPressed: () => _confirmEndShift(context),
      tooltip: 'إنهاء الشيفت',
    );
  }

  void _confirmEndShift(BuildContext context) {
    final state = context.read<AppState>();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.stop_circle_outlined, color: Colors.red),
          SizedBox(width: 8),
          Text('إنهاء الشيفت؟',
              style: TextStyle(
                  color: Colors.red, fontWeight: FontWeight.bold)),
        ]),
        content: const Text('هيتم حفظ تقرير الشيفت وتسجيل الخروج',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final shift = await state.endShift();
              if (context.mounted && shift != null) {
                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => ShiftReportDialog(shift: shift),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('إنهاء وعرض التقرير'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ديالوج تقرير إنهاء الشيفت
// ══════════════════════════════════════════════════════════════════════════════

class ShiftReportDialog extends StatefulWidget {
  final ShiftRecord shift;
  const ShiftReportDialog({super.key, required this.shift});

  @override
  State<ShiftReportDialog> createState() => _ShiftReportDialogState();
}

class _ShiftReportDialogState extends State<ShiftReportDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shift = widget.shift;
    final dur = shift.duration;

    final durStr =
        '${dur.inHours}س ${dur.inMinutes.remainder(60)}د';

    final startStr =
        '${shift.startTime.hour.toString().padLeft(2, '0')}:${shift.startTime.minute.toString().padLeft(2, '0')}';

    final endStr = shift.endTime != null
        ? '${shift.endTime!.hour.toString().padLeft(2, '0')}:${shift.endTime!.minute.toString().padLeft(2, '0')}'
        : '--:--';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0b0e14),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: const Color(0xFF38bdf8).withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(children: [
                Row(children: [
                  _CashierAvatar(name: shift.cashierName, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تقرير شيفت ${shift.cashierName}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(
                            '$startStr → $endStr  •  $durStr',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                          ),
                        ]),
                  ),
                  const Icon(Icons.receipt_long,
                      color: Color(0xFF38bdf8), size: 22),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ade80).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF4ade80).withOpacity(0.3)),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _QuickStat('💰 الإجمالي',
                            '${shift.totalRevenue.toStringAsFixed(1)} ج',
                            const Color(0xFF4ade80)),
                        Container(width: 1, height: 32, color: Colors.white12),
                        _QuickStat('🎮 لعب',
                            '${shift.totalTime.toStringAsFixed(1)} ج',
                            const Color(0xFF38bdf8)),
                        Container(width: 1, height: 32, color: Colors.white12),
                        _QuickStat('🥤 بوفيه',
                            '${shift.totalBuffet.toStringAsFixed(1)} ج',
                            Colors.orange),
                        Container(width: 1, height: 32, color: Colors.white12),
                        _QuickStat('📋 جلسات',
                            '${shift.sessionCount}', Colors.white70),
                      ]),
                ),
                const SizedBox(height: 8),
                TabBar(
                  controller: _tabs,
                  indicatorColor: const Color(0xFF38bdf8),
                  labelColor: const Color(0xFF38bdf8),
                  unselectedLabelColor: Colors.white38,
                  labelStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(icon: Icon(Icons.sports_esports, size: 16), text: 'الأجهزة'),
                    Tab(icon: Icon(Icons.fastfood, size: 16), text: 'البوفيه'),
                    Tab(icon: Icon(Icons.list, size: 16), text: 'كل الجلسات'),
                  ],
                ),
              ]),
            ),
            Flexible(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _DeviceBreakdownTab(shift: shift),
                  _BuffetBreakdownTab(shift: shift),
                  _AllSessionsTab(shift: shift),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.read<AppState>().logout();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('تسجيل الخروج',
                      style: TextStyle(fontSize: 15)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF38bdf8),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── TAB 1: تفاصيل الأجهزة ─────────────────────────────────────────────────────

class _DeviceBreakdownTab extends StatelessWidget {
  final ShiftRecord shift;
  const _DeviceBreakdownTab({required this.shift});

  @override
  Widget build(BuildContext context) {
    final breakdown = shift.deviceBreakdown;

    final sorted = breakdown.entries.toList()
      ..sort((a, b) =>
          (b.value['revenue'] as double)
              .compareTo(a.value['revenue'] as double));

    final matches = shift.totalMatches;
    final games = shift.totalGames;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      children: [
        if (matches > 0 || games > 0)
          Row(children: [
            if (matches > 0)
              Expanded(
                child: _MiniInfoTile(
                  icon: Icons.sports_soccer,
                  label: 'ماتشات سريعة',
                  value: '$matches',
                  color: const Color(0xFF4ade80),
                ),
              ),
            if (matches > 0 && games > 0) const SizedBox(width: 8),
            if (games > 0)
              Expanded(
                child: _MiniInfoTile(
                  icon: Icons.sports_golf,
                  label: 'جيمات بنج/بلياردو',
                  value: '$games',
                  color: Colors.purple,
                ),
              ),
          ]),
        if (matches > 0 || games > 0) const SizedBox(height: 10),
        if (sorted.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text('لا يوجد جلسات أجهزة في هذا الشيفت',
                  style: TextStyle(color: Colors.white38)),
            ),
          )
        else
          ...sorted.asMap().entries.map((entry) {
            final i = entry.key;
            final name = entry.value.key;
            final data = entry.value.value;
            final type = data['device_type']?.toString() ?? '';

            // جيب كل جلسات الجهاز ده بالترتيب الزمني
            final deviceSessions = shift.transactions.where((t) {
              return t['name']?.toString() == name &&
                  t['device_type']?.toString() == type &&
                  t['is_match'] != true &&
                  t['is_game'] != true;
            }).toList();

            return _DeviceSection(
              stats: data,
              deviceName: name,
              rank: i,
              sessions: deviceSessions,
            );
          }),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// كارت الجهاز مع تفاصيل كل جلسة
// ══════════════════════════════════════════════════════════════════════════════

class _DeviceSection extends StatelessWidget {
  final Map<String, dynamic> stats;
  final String deviceName;
  final int rank;
  final List<Map<String, dynamic>> sessions;

  const _DeviceSection({
    required this.stats,
    required this.deviceName,
    required this.rank,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    final type = stats['device_type']?.toString() ?? '';
    final isPs5 = type == 'ps5';
    final color = isPs5 ? Colors.purple : const Color(0xFF38bdf8);

    final timeCost = stats['time_cost'] as double;
    final buffetCost = stats['buffet_cost'] as double;
    final revenue = stats['revenue'] as double;
    final sessionCount = stats['sessions'] as int;

    final elapsedSec = stats['total_elapsed_seconds'] as int;
    final h = elapsedSec ~/ 3600;
    final m = (elapsedSec % 3600) ~/ 60;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: color),
          ),
          child: Text(isPs5 ? 'PS5' : 'PS4',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 10)),
        ),
        title: Row(children: [
          Expanded(
            child: Text(deviceName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          if (rank < 3) Text(['🥇', '🥈', '🥉'][rank]),
        ]),
        subtitle: Text(
          '$sessionCount جلسة  •  ${h}س ${m}د  •  ${revenue.toStringAsFixed(1)} ج',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── إجماليات الجهاز ─────────────────────────────────
                Row(children: [
                  Expanded(child: _MiniStatBox('🎮 لعب', '${timeCost.toStringAsFixed(1)} ج', color)),
                  const SizedBox(width: 8),
                  Expanded(child: _MiniStatBox('🥤 بوفيه', '${buffetCost.toStringAsFixed(1)} ج', Colors.orange)),
                  const SizedBox(width: 8),
                  Expanded(child: _MiniStatBox('⏱ وقت', '${h}س ${m}د', Colors.white54)),
                ]),
                const SizedBox(height: 14),

                // ── تفاصيل كل جلسة ──────────────────────────────────
                if (sessions.isNotEmpty) ...[
                  Row(children: [
                    Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'تفاصيل كل جلسة (${sessions.length})',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  ...sessions.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final s = entry.value;
                    return _SessionDetailCard(
                      session: s,
                      index: idx + 1,
                      color: color,
                    );
                  }),
                ] else
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'لا يوجد تفاصيل جلسات',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// كارت تفاصيل الجلسة الواحدة ← الجديد
// ══════════════════════════════════════════════════════════════════════════════

class _SessionDetailCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final int index;
  final Color color;

  const _SessionDetailCard({
    required this.session,
    required this.index,
    required this.color,
  });

  String _extractTime(String? dateStr) {
    if (dateStr == null || dateStr.length < 16) return '--:--';
    return dateStr.substring(11, 16);
  }

  String _calcStartTime(Map<String, dynamic> s) {
    // بنحسب وقت البداية من وقت الانتهاء - المدة
    final dateStr = s['date']?.toString() ?? '';
    final endTime = DateTime.tryParse(dateStr);
    if (endTime == null) return '--:--';
    final elapsed = (s['elapsed_seconds'] as num?)?.toInt() ?? 0;
    final startTime = endTime.subtract(Duration(seconds: elapsed));
    return '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = session['date']?.toString() ?? '';
    final endTimeStr = _extractTime(dateStr);
    final startTimeStr = _calcStartTime(session);
    final duration = session['duration']?.toString() ?? '--';
    final timeCost = (session['time_cost'] as num?)?.toDouble() ?? 0;
    final buffetCost = (session['buffet_cost'] as num?)?.toDouble() ?? 0;
    final total = (session['total'] as num?)?.toDouble() ?? 0;
    final playMode = session['play_mode']?.toString() ?? 'normal';
    final cashier = session['cashier']?.toString() ?? '--';
    final orders = session['orders'] as Map? ?? {};
    final wasCountdown = session['was_countdown'] == true;
    final elapsedSeconds = (session['elapsed_seconds'] as num?)?.toInt() ?? 0;

    final modeLabel = playMode == 'multi' ? 'مالتي' : 'عادي';
    final modeColor = playMode == 'multi' ? Colors.orange : color;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0b0e14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          // ── هيدر الجلسة ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              // رقم الجلسة
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Center(
                  child: Text('$index',
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                ),
              ),
              const SizedBox(width: 10),

              // وقت البداية ← النهاية
              Expanded(
                child: Row(children: [
                  Icon(Icons.play_arrow_rounded, color: Colors.green, size: 14),
                  const SizedBox(width: 3),
                  Text(startTimeStr,
                      style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFeatures: [FontFeature.tabularFigures()])),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward, color: Colors.white24, size: 12),
                  const SizedBox(width: 6),
                  Icon(Icons.stop_circle_outlined, color: Colors.red.shade300, size: 14),
                  const SizedBox(width: 3),
                  Text(endTimeStr,
                      style: TextStyle(
                          color: Colors.red.shade300,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                ]),
              ),

              // المدة
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(duration,
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
          ),

          // ── تفاصيل الجلسة ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              children: [
                // صف المعلومات الأساسية
                Row(children: [
                  // الكاشير
                  _InfoChip(
                    icon: Icons.person_outline,
                    label: cashier,
                    color: const Color(0xFF38bdf8),
                  ),
                  const SizedBox(width: 6),
                  // وضع اللعب
                  _InfoChip(
                    icon: playMode == 'multi' ? Icons.people : Icons.person,
                    label: modeLabel,
                    color: modeColor,
                  ),
                  const SizedBox(width: 6),
                  // نوع الجلسة
                  if (wasCountdown)
                    _InfoChip(
                      icon: Icons.timer,
                      label: 'وقت محدد',
                      color: Colors.orange,
                    ),
                ]),
                const SizedBox(height: 10),

                // صف الأسعار
                Row(children: [
                  Expanded(
                    child: _PriceBox(
                      label: '🎮 لعب',
                      value: '${timeCost.toStringAsFixed(1)} ج',
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _PriceBox(
                      label: '🥤 بوفيه',
                      value: '${buffetCost.toStringAsFixed(1)} ج',
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _PriceBox(
                      label: '💰 إجمالي',
                      value: '${total.toStringAsFixed(1)} ج',
                      color: const Color(0xFF4ade80),
                      highlight: true,
                    ),
                  ),
                ]),

                // البوفيه تفاصيل
                if (orders.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('تفاصيل البوفيه:',
                            style: TextStyle(
                                color: Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: orders.entries.map((e) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${e.key} ×${e.value}',
                              style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          )).toList(),
                        ),
                      ],
                    ),
                  ),
                ],

                // سجل الجلسة (session_log)
                if (session['session_log'] != null &&
                    (session['session_log'] as List).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _SessionLogMini(log: session['session_log'] as List),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── سجل الجلسة مصغّر ─────────────────────────────────────────────────────────

class _SessionLogMini extends StatefulWidget {
  final List log;
  const _SessionLogMini({required this.log});

  @override
  State<_SessionLogMini> createState() => _SessionLogMiniState();
}

class _SessionLogMiniState extends State<_SessionLogMini> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(children: [
                const Icon(Icons.history, color: Colors.tealAccent, size: 14),
                const SizedBox(width: 6),
                Text(
                  'سجل الجلسة (${widget.log.length} حدث)',
                  style: const TextStyle(
                      color: Colors.tealAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.white38,
                  size: 16,
                ),
              ]),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Column(
                children: widget.log.map((ev) {
                  final type = ev['type'] as String? ?? '';
                  final time = ev['time'] as String? ?? '';
                  final note = ev['note'] as String? ?? '';
                  final role = ev['role'] as String? ?? '';

                  Color c;
                  IconData icon;
                  switch (type) {
                    case 'start':
                      c = Colors.green;
                      icon = Icons.play_arrow_rounded;
                      break;
                    case 'pause':
                      c = Colors.amber;
                      icon = Icons.pause_rounded;
                      break;
                    case 'resume':
                      c = const Color(0xFF38bdf8);
                      icon = Icons.play_circle_fill;
                      break;
                    case 'add_time':
                      final mins = ev['minutes'] as int? ?? 0;
                      c = mins > 0 ? const Color(0xFF4ade80) : Colors.redAccent;
                      icon = mins > 0 ? Icons.add_circle : Icons.remove_circle;
                      break;
                    case 'stop':
                      c = Colors.red;
                      icon = Icons.stop_circle_outlined;
                      break;
                    default:
                      c = Colors.white38;
                      icon = Icons.info_outline;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(children: [
                      Icon(icon, color: c, size: 13),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$note${role.isNotEmpty ? " ($role)" : ""}',
                          style: TextStyle(color: c.withOpacity(0.9), fontSize: 11),
                        ),
                      ),
                      Text(time,
                          style: const TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                              fontFeatures: [FontFeature.tabularFigures()])),
                    ]),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ── TAB 2: البوفيه ─────────────────────────────────────────────────────────────

class _BuffetBreakdownTab extends StatelessWidget {
  final ShiftRecord shift;
  const _BuffetBreakdownTab({required this.shift});

  @override
  Widget build(BuildContext context) {
    final items = shift.itemsSold;

    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Text('لا يوجد مبيعات بوفيه في هذا الشيفت',
              style: TextStyle(color: Colors.white38)),
        ),
      );
    }

    final sorted = items.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalQty = sorted.fold(0, (s, e) => s + e.value);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.shopping_bag, color: Colors.orange, size: 16),
            const SizedBox(width: 8),
            Text('إجمالي قطع مباعة: $totalQty',
                style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ]),
        ),
        ...sorted.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value.key;
          final qty = entry.value.value;

          final ratio = totalQty > 0 ? qty / totalQty : 0.0;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1c2128),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                if (i < 3)
                  Text(['🥇', '🥈', '🥉'][i])
                else
                  Text('  ${i + 1}.',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Text(
                  '${(ratio * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$qty قطعة',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: ratio.toDouble(),
                  minHeight: 4,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    i == 0 ? Colors.amber : Colors.orange,
                  ),
                ),
              ),
            ]),
          );
        }),
      ],
    );
  }
}

// ── TAB 3: كل الجلسات ─────────────────────────────────────────────────────────

class _AllSessionsTab extends StatelessWidget {
  final ShiftRecord shift;
  const _AllSessionsTab({required this.shift});

  @override
  Widget build(BuildContext context) {
    final txns = shift.transactions.reversed.toList();

    if (txns.isEmpty) {
      return const Center(
        child: Text('لا يوجد جلسات مسجلة',
            style: TextStyle(color: Colors.white38)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: txns.length,
      itemBuilder: (ctx, i) => _TransactionRow(transaction: txns[i]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// شاشة تقارير الشيفتات للأدمن
// ══════════════════════════════════════════════════════════════════════════════

// بعد
class ShiftHistoryScreen extends StatefulWidget {
  const ShiftHistoryScreen({super.key});
  @override
  State<ShiftHistoryScreen> createState() => _ShiftHistoryScreenState();
}

class _ShiftHistoryScreenState extends State<ShiftHistoryScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AppState>().fetchShiftsHistoryOnDemand();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.isLoadingShifts && state.shiftsHistory.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF0b0e14),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF38bdf8))),
      );
    }
    final shifts = state.shiftsHistory.reversed.toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تقارير الشيفتات',
                style: TextStyle(
                    color: Color(0xFF38bdf8), fontWeight: FontWeight.bold)),
            if (shifts.isNotEmpty)
              Text('${shifts.length} شيفت مسجل',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
          ],
        ),
        leading: const BackButton(color: Colors.white),
        actions: [
          if (shifts.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.bar_chart_rounded,
                  color: Color(0xFFfbbf24)),
              tooltip: 'ملخص إجمالي',
              onPressed: () => _showGrandSummary(context, shifts),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              tooltip: 'مسح كل التقارير',
              onPressed: () => _confirmClearAll(context, state),
            ),
          ],
        ],
      ),
      body: shifts.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off,
                      size: 64, color: Colors.white12),
                  SizedBox(height: 16),
                  Text('لا يوجد شيفتات مسجلة',
                      style:
                          TextStyle(color: Colors.white54, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: shifts.length,
              itemBuilder: (ctx, i) {
                final realIndex = state.shiftsHistory.length - 1 - i;
                return _ShiftCard(
                  shift: shifts[i],
                  onDelete: () =>
                      _confirmDeleteShift(context, state, realIndex, shifts[i]),
                );
              },
            ),
    );
  }

  void _showGrandSummary(BuildContext context, List<ShiftRecord> shifts) {
    final totalRev = shifts.fold(0.0, (s, sh) => s + sh.totalRevenue);
    final totalTime = shifts.fold(0.0, (s, sh) => s + sh.totalTime);
    final totalBuffet = shifts.fold(0.0, (s, sh) => s + sh.totalBuffet);
    final totalSessions = shifts.fold(0, (s, sh) => s + sh.sessionCount);

    final cashierRevMap = <String, double>{};
    for (final sh in shifts) {
      cashierRevMap[sh.cashierName] =
          (cashierRevMap[sh.cashierName] ?? 0) + sh.totalRevenue;
    }
    final topCashier = cashierRevMap.isNotEmpty
        ? cashierRevMap.entries
            .reduce((a, b) => a.value > b.value ? a : b)
        : null;

    final itemMap = <String, int>{};
    for (final sh in shifts) {
      sh.itemsSold.forEach((k, v) {
        itemMap[k] = (itemMap[k] ?? 0) + v;
      });
    }
    final topItem = itemMap.isNotEmpty
        ? itemMap.entries.reduce((a, b) => a.value > b.value ? a : b)
        : null;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.bar_chart_rounded, color: Color(0xFFfbbf24)),
          SizedBox(width: 8),
          Text('ملخص إجمالي',
              style: TextStyle(
                  color: Color(0xFFfbbf24),
                  fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _SummaryRow('💰 إجمالي الإيرادات',
              '${totalRev.toStringAsFixed(1)} ج',
              const Color(0xFF4ade80)),
          _SummaryRow('🎮 إيرادات اللعب',
              '${totalTime.toStringAsFixed(1)} ج',
              const Color(0xFF38bdf8)),
          _SummaryRow('🥤 إيرادات البوفيه',
              '${totalBuffet.toStringAsFixed(1)} ج', Colors.orange),
          _SummaryRow('📋 إجمالي الجلسات', '$totalSessions', Colors.white70),
          _SummaryRow('🔄 عدد الشيفتات', '${shifts.length}', Colors.white70),
          const Divider(color: Colors.white12),
          if (topCashier != null)
            _SummaryRow('🏆 أعلى كاشير إيراداً',
                '${topCashier.key} (${topCashier.value.toStringAsFixed(0)} ج)',
                const Color(0xFFfbbf24)),
          if (topItem != null)
            _SummaryRow('🥤 أكتر صنف مباع',
                '${topItem.key} (${topItem.value} قطعة)', Colors.orange),
        ]),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFfbbf24),
                foregroundColor: Colors.black),
            child: const Text('تمام'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteShift(
      BuildContext context, AppState state, int index, ShiftRecord shift) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.delete_outline, color: Colors.red),
          SizedBox(width: 8),
          Text('حذف تقرير الشيفت؟',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('الكاشير: ${shift.cashierName}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                'تاريخ: ${shift.startTime.day}/${shift.startTime.month}/${shift.startTime.year}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                'إجمالي: ${shift.totalRevenue.toStringAsFixed(1)} ج | ${shift.sessionCount} جلسة',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          const Text('هيتم حذف التقرير ده نهائياً ولا هيرجع.',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              state.deleteShift(index);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('✅ تم حذف التقرير'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ));
            },
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('حذف التقرير'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('مسح كل التقارير؟',
            style: TextStyle(color: Colors.red)),
        content: const Text('هيتم حذف كل تقارير الشيفتات نهائياً',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              state.clearShiftsHistory();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('مسح الكل'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ShiftCard — الكارت في شاشة تاريخ الشيفتات
// ══════════════════════════════════════════════════════════════════════════════

class _ShiftCard extends StatelessWidget {
  final ShiftRecord shift;
  final VoidCallback onDelete;
  const _ShiftCard({required this.shift, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final dur = shift.duration;
    final durStr = '${dur.inHours}س ${dur.inMinutes.remainder(60)}د';

    final startStr =
        '${shift.startTime.hour.toString().padLeft(2, '0')}:${shift.startTime.minute.toString().padLeft(2, '0')}';

    final endStr = shift.endTime != null
        ? '${shift.endTime!.hour.toString().padLeft(2, '0')}:${shift.endTime!.minute.toString().padLeft(2, '0')}'
        : 'جاري';

    final dateStr =
        '${shift.startTime.day}/${shift.startTime.month}/${shift.startTime.year}';

    final deviceBreakdown = shift.deviceBreakdown;
    final itemsSorted = shift.itemsSold.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalBuffetPieces = itemsSorted.fold<int>(0, (s, e) => s + e.value);

    final totalHours = dur.inMinutes / 60.0;
    final playPercentage =
        shift.totalRevenue > 0 ? (shift.totalTime / shift.totalRevenue) * 100 : 0.0;
    final buffetPercentage =
        shift.totalRevenue > 0 ? (shift.totalBuffet / shift.totalRevenue) * 100 : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: shift.isOpen
                ? Colors.green.withOpacity(0.4)
                : Colors.white10),
      ),
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: _CashierAvatar(name: shift.cashierName, size: 40),
        title: Row(children: [
          Text(shift.cashierName,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          if (shift.isOpen) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('جاري',
                  style: TextStyle(color: Colors.green, fontSize: 10)),
            ),
          ],
        ]),
        subtitle: Text(
          '$dateStr  •  $startStr → $endStr  •  $durStr',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${shift.totalRevenue.toStringAsFixed(1)} ج',
                style: const TextStyle(
                    color: Color(0xFF4ade80),
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            Text('${shift.sessionCount} جلسة',
                style:
                    const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── إجماليات سريعة ──────────────────────────────────
                Row(children: [
                  Expanded(child: _MiniStat(
                      icon: Icons.sports_esports,
                      label: 'لعب',
                      value: '${shift.totalTime.toStringAsFixed(1)} ج')),
                  const SizedBox(width: 8),
                  Expanded(child: _MiniStat(
                      icon: Icons.fastfood,
                      label: 'بوفيه',
                      value: '${shift.totalBuffet.toStringAsFixed(1)} ج')),
                  const SizedBox(width: 8),
                  Expanded(child: _MiniStat(
                      icon: Icons.receipt,
                      label: 'جلسات',
                      value: '${shift.sessionCount}')),
                ]),

                if (shift.totalMatches > 0 || shift.totalGames > 0) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    if (shift.totalMatches > 0)
                      _TagChip(
                          '⚽ ${shift.totalMatches} ماتش سريع',
                          const Color(0xFF4ade80)),
                    if (shift.totalGames > 0) ...[
                      const SizedBox(width: 6),
                      _TagChip(
                          '🎱 ${shift.totalGames} جيم طاولة', Colors.purple),
                    ],
                  ]),
                ],
                const SizedBox(height: 14),

                // ── تحليلات ─────────────────────────────────────────
                _SectionTitle('📊 تحليلات الشيفت', const Color(0xFFfbbf24)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFfbbf24).withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFfbbf24).withOpacity(0.15)),
                  ),
                  child: Column(children: [
                    _AnalyticsRow('🎮 نسبة اللعب من الإيراد:',
                        '${playPercentage.toStringAsFixed(1)}%'),
                    _AnalyticsRow('🥤 نسبة البوفيه من الإيراد:',
                        '${buffetPercentage.toStringAsFixed(1)}%'),
                  ]),
                ),
                const SizedBox(height: 14),

                // ── تفاصيل كل الأجهزة مع جلساتها ────────────────────
                if (deviceBreakdown.isNotEmpty) ...[
                  _SectionTitle(
                      '🎮 تفاصيل الأجهزة مع كل جلسة',
                      const Color(0xFF38bdf8)),
                  const SizedBox(height: 8),
                  ...(() {
                    final sortedDevices = deviceBreakdown.entries.toList()
                      ..sort((a, b) =>
                          (b.value['revenue'] as double)
                              .compareTo(a.value['revenue'] as double));

                    return sortedDevices.asMap().entries.map((entry) {
                      final i = entry.key;
                      final deviceName = entry.value.key;
                      final data = entry.value.value;
                      final isPs5 =
                          data['device_type']?.toString() == 'ps5';
                      final col = isPs5
                          ? Colors.purple
                          : const Color(0xFF38bdf8);

                      final devRevenue = data['revenue'] as double;
                      final devTime = data['time_cost'] as double;
                      final devBuffet = data['buffet_cost'] as double;
                      final devSessions = data['sessions'] as int;

                      final elapsedSec =
                          data['total_elapsed_seconds'] as int;
                      final h = elapsedSec ~/ 3600;
                      final m = (elapsedSec % 3600) ~/ 60;

                      final devContribution = shift.totalRevenue > 0
                          ? (devRevenue / shift.totalRevenue) * 100
                          : 0.0;

                      // جيب جلسات الجهاز ده بالترتيب الزمني
                      final deviceSessions = shift.transactions
                          .where((t) =>
                              t['name']?.toString() == deviceName &&
                              t['device_type']?.toString() ==
                                  data['device_type']?.toString() &&
                              t['is_match'] != true &&
                              t['is_game'] != true)
                          .toList();

                      return _DeviceCardExpanded(
                        index: i,
                        deviceName: deviceName,
                        isPs5: isPs5,
                        color: col,
                        devRevenue: devRevenue,
                        devTime: devTime,
                        devBuffet: devBuffet,
                        devSessions: devSessions,
                        h: h,
                        m: m,
                        contribution: devContribution,
                        sessions: deviceSessions,
                      );
                    }).toList();
                  })(),
                  const SizedBox(height: 14),
                ],

                // ── أصناف البوفيه ────────────────────────────────────
                if (itemsSorted.isNotEmpty) ...[
                  _SectionTitle('🥤 أصناف البوفيه المباعة', Colors.orange),
                  const SizedBox(height: 6),
                  ...itemsSorted.asMap().entries.map((entry) {
                    final i = entry.key;
                    final e = entry.value;
                    final itemRatio = totalBuffetPieces > 0
                        ? (e.value / totalBuffetPieces) * 100
                        : 0.0;
                    return _RankRow(
                      rank: i + 1,
                      name: '${e.key}  (${itemRatio.toStringAsFixed(1)}%)',
                      value: '${e.value} قطعة',
                      color: Colors.orange,
                    );
                  }),
                  const SizedBox(height: 14),
                ],

                // ── خط زمني ─────────────────────────────────────────
                _SectionTitle('📋 الخط الزمني الكامل', const Color(0xFF4ade80)),
                const Divider(color: Colors.white12, height: 12),
                ...shift.transactions.reversed
                    .map((t) => _TransactionRow(transaction: t)),

                // ── حذف ─────────────────────────────────────────────
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 16),
                    label: const Text('حذف هذا التقرير',
                        style: TextStyle(color: Colors.red, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// كارت الجهاز الموسّع مع جلساته ← الجديد في ShiftCard
// ══════════════════════════════════════════════════════════════════════════════

class _DeviceCardExpanded extends StatefulWidget {
  final int index;
  final String deviceName;
  final bool isPs5;
  final Color color;
  final double devRevenue, devTime, devBuffet;
  final int devSessions, h, m;
  final double contribution;
  final List<Map<String, dynamic>> sessions;

  const _DeviceCardExpanded({
    required this.index,
    required this.deviceName,
    required this.isPs5,
    required this.color,
    required this.devRevenue,
    required this.devTime,
    required this.devBuffet,
    required this.devSessions,
    required this.h,
    required this.m,
    required this.contribution,
    required this.sessions,
  });

  @override
  State<_DeviceCardExpanded> createState() => _DeviceCardExpandedState();
}

class _DeviceCardExpandedState extends State<_DeviceCardExpanded> {
  bool _showSessions = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // ── هيدر الجهاز ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(children: [
                  Text('${widget.index + 1}. ',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: widget.color),
                    ),
                    child: Text(
                      widget.isPs5 ? 'PS5' : 'PS4',
                      style: TextStyle(
                          color: widget.color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.deviceName,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${widget.contribution.toStringAsFixed(1)}% من الشيفت',
                      style: TextStyle(
                          color: widget.color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${widget.devSessions} جلسة',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                    Text('${widget.h}س ${widget.m}د',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                    Text('لعب: ${widget.devTime.toStringAsFixed(0)}ج',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                    Text('بوفيه: ${widget.devBuffet.toStringAsFixed(0)}ج',
                        style: const TextStyle(
                            color: Colors.orange, fontSize: 11)),
                    Text(
                        'صافي: ${widget.devRevenue.toStringAsFixed(0)}ج',
                        style: const TextStyle(
                            color: Color(0xFF4ade80),
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),

          // ── زرار عرض الجلسات ──────────────────────────────────────
          if (widget.sessions.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _showSessions = !_showSessions),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.08),
                  borderRadius: BorderRadius.vertical(
                    bottom: _showSessions
                        ? Radius.zero
                        : const Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _showSessions
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: widget.color,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _showSessions
                          ? 'إخفاء تفاصيل الجلسات'
                          : 'عرض تفاصيل ${widget.sessions.length} جلسة',
                      style: TextStyle(
                        color: widget.color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── تفاصيل الجلسات ──────────────────────────────────────────
          if (_showSessions && widget.sessions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                children: widget.sessions.asMap().entries.map((entry) {
                  return _SessionDetailCard(
                    session: entry.value,
                    index: entry.key + 1,
                    color: widget.color,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ActiveShiftBanner
// ══════════════════════════════════════════════════════════════════════════════

class ActiveShiftBanner extends StatelessWidget {
  const ActiveShiftBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final open = state.openShifts;

    if (open.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(12),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1c2128),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: const Row(children: [
          Icon(Icons.radio_button_unchecked,
              color: Colors.white38, size: 14),
          SizedBox(width: 10),
          Text('مفيش كاشير شغال دلوقتي',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ]),
      );
    }

    return Column(
      children: open.entries.map((entry) {
        final shift = entry.value;
        final dur = DateTime.now().difference(shift.startTime);
        final durStr =
            '${dur.inHours}س ${dur.inMinutes.remainder(60)}د';
        final startStr =
            '${shift.startTime.hour.toString().padLeft(2, '0')}'
            ':${shift.startTime.minute.toString().padLeft(2, '0')}';

        return Container(
          margin:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1c2128),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.green.withOpacity(0.4), width: 1.5),
          ),
          child: Row(children: [
            Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: Color(0xFF4ade80), shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(shift.cashierName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text('بدأ الساعة $startStr  •  $durStr',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4ade80).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF4ade80).withOpacity(0.4)),
              ),
              child: Text('${shift.sessionCount} جلسة',
                  style: const TextStyle(
                      color: Color(0xFF4ade80),
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared Widgets
// ══════════════════════════════════════════════════════════════════════════════

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _PriceBox extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool highlight;
  const _PriceBox(
      {required this.label,
      required this.value,
      required this.color,
      this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(highlight ? 0.1 : 0.06),
        borderRadius: BorderRadius.circular(8),
        border: highlight ? Border.all(color: color.withOpacity(0.3)) : null,
      ),
      child: Column(children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 9)),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: highlight ? 13 : 12,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _CashierAvatar extends StatelessWidget {
  final String name;
  final double size;
  const _CashierAvatar({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'K';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF38bdf8).withOpacity(0.12),
        border:
            Border.all(color: const Color(0xFF38bdf8).withOpacity(0.4)),
      ),
      child: Center(
        child: Text(initial,
            style: TextStyle(
                color: const Color(0xFF38bdf8),
                fontWeight: FontWeight.bold,
                fontSize: size * 0.4)),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _QuickStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(value,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
    ]);
  }
}

class _MiniInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniInfoTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Expanded(
            child: Text(label,
                style: TextStyle(color: color, fontSize: 10))),
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(children: [
        Icon(icon, color: Colors.white38, size: 14),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 9)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.white)),
      ]),
    );
  }
}

class _MiniStatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStatBox(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TagChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionTitle(this.title, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(title,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      ]),
    );
  }
}

class _AnalyticsRow extends StatelessWidget {
  final String title;
  final String value;
  const _AnalyticsRow(this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(value,
              style: const TextStyle(
                  color: Color(0xFFfbbf24),
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final int rank;
  final String name;
  final String value;
  final Color color;

  const _RankRow(
      {required this.rank,
      required this.name,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    const medals = ['🥇', '🥈', '🥉', '4️⃣', '5️⃣'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        Text(rank <= 5 ? medals[rank - 1] : '$rank',
            style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final Map<String, dynamic> transaction;
  const _TransactionRow({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final name = transaction['name'] as String? ?? '';
    final total =
        ((transaction['total'] as num?) ?? 0).toStringAsFixed(1);
    final dateStr = transaction['date']?.toString() ?? '';
    final timeStr =
        dateStr.length >= 16 ? dateStr.substring(11, 16) : '';
    final isMatch = transaction['is_match'] == true;
    final isGame = transaction['is_game'] == true;
    final isDrink = transaction['device_type'] == 'drink_table';
    final cashier = transaction['cashier']?.toString() ?? '';

    IconData icon;
    Color color;

    if (isDrink) {
      icon = Icons.local_drink;
      color = Colors.orange;
    } else if (isMatch) {
      icon = Icons.sports_soccer;
      color = const Color(0xFF4ade80);
    } else if (isGame) {
      icon = Icons.sports_golf;
      color = Colors.purple;
    } else {
      icon = Icons.sports_esports;
      color = const Color(0xFF38bdf8);
    }

    return IntrinsicHeight(
      child: Row(children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.5), width: 1),
              ),
              child: Icon(icon, color: color, size: 11),
            ),
            Expanded(
              child: Container(
                width: 1.5,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500)),
                ),
                if (cashier.isNotEmpty) ...[
                  Text(cashier,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10)),
                  const SizedBox(width: 8),
                ],
                Text(timeStr,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontFeatures: [FontFeature.tabularFigures()])),
                const SizedBox(width: 12),
                Text('$total ج',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
