import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'qr_screen.dart';
import '../widgets/table_start_dialog.dart';
import '../widgets/buffet_order_dialog.dart';
import '../services/notification_service.dart';

class TableDetailScreen extends StatefulWidget {
  final int tableIndex;
  const TableDetailScreen({super.key, required this.tableIndex});

  @override
  State<TableDetailScreen> createState() => _TableDetailScreenState();
}

class _TableDetailScreenState extends State<TableDetailScreen> {
  Timer? _timer;
  String _timerText = '00:00:00';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

 void _tick() {
  final state = context.read<AppState>();
  if (widget.tableIndex >= state.tables.length) return;
  final t = state.tables[widget.tableIndex];
  if (t['start_time'] == null) return;

  final elapsed = state.tableElapsed(widget.tableIndex);
  final isCountdown = t['is_countdown'] == true;
  final countdownTotal = (t['countdown_total_seconds'] as num?)?.toInt();

  int displaySeconds;
  if (isCountdown && countdownTotal != null) {
    final remaining = countdownTotal - elapsed;
    displaySeconds = remaining < 0 ? 0 : remaining;

    if (remaining <= 0 && t['countdown_alert_sent'] != true) {
      t['countdown_alert_sent'] = true;
      state.toggleTablePause(widget.tableIndex);
      NotificationService.showTimerAlert(
          t['name'] ?? 'تربيزة', countdownTotal ~/ 60);
    }
  } else {
    displaySeconds = elapsed;
  }

  final h = displaySeconds ~/ 3600;
  final m = (displaySeconds % 3600) ~/ 60;
  final s = displaySeconds % 60;
  setState(() {
    _timerText =
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  });
}

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (widget.tableIndex >= state.tables.length) {
      return const Scaffold(body: Center(child: Text('تربيزة مش موجودة')));
    }
    final t = state.tables[widget.tableIndex];
    final bool isActive = t['start_time'] != null;
    final bool isPaused = t['is_paused'] == true;
   final int rate = ((t['session_rate'] ?? t['rate']) as num).toInt();
    final int gamePrice = (t['game_price'] as num?)?.toInt() ?? 0;
    final String tableType = t['table_type'] ?? 'ping';
    final elapsed = state.tableElapsed(widget.tableIndex);
    final timeCost = (elapsed / 3600) * rate;
    final Map<String, int> orders = Map<String, int>.from(t['orders'] ?? {});
    double buffetCost = 0;
    orders.forEach((item, qty) { buffetCost += qty * (state.menu[item] ?? 0); });

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF34d399).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF34d399)),
            ),
            child: Text(
              tableType == 'billiard' ? '🎱 بلياردو' : '🏓 بينج',
              style: const TextStyle(fontSize: 11, color: Color(0xFF34d399), fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Text(t['name'] ?? '', style: const TextStyle(color: Color(0xFF34d399), fontWeight: FontWeight.bold)),
        ]),
        leading: const BackButton(color: Colors.white),
        actions: [
          // ✅ زرار QR - دايماً ظاهر
          IconButton(
            icon: const Icon(Icons.qr_code, color: Colors.white54, size: 26),
            tooltip: 'QR Code',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QrScreen(tableIndex: widget.tableIndex),
              ),
            ),
          ),
          if (isActive) ...[
            IconButton(
              icon: Icon(isPaused ? Icons.play_circle_fill : Icons.pause_circle_filled,
                  color: isPaused ? Colors.amber : const Color(0xFF38bdf8), size: 30),
              onPressed: () => state.toggleTablePause(widget.tableIndex),
            ),
            if (state.isAdmin)
              IconButton(
                icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 26),
                onPressed: () => _confirmCancel(context, state),
              ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Timer Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1c2128),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isPaused ? Colors.amber.withOpacity(0.4) : const Color(0xFF34d399).withOpacity(0.3),
              ),
            ),
            child: Column(children: [
              if (isPaused)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                  child: const Text('⏸ إيقاف مؤقت', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              const SizedBox(height: 8),
              Text(
                isActive ? _timerText : '00:00:00',
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  color: isPaused ? Colors.amber : const Color(0xFF34d399),
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _CostChip('⏱ الوقت', '${timeCost.toStringAsFixed(1)} ج', const Color(0xFF34d399)),
                _CostChip('🥤 البوفيه', '${buffetCost.toStringAsFixed(1)} ج', Colors.orange),
                _CostChip('💰 الإجمالي', '${(timeCost + buffetCost).toStringAsFixed(1)} ج', const Color(0xFF4ade80)),
              ]),
              const SizedBox(height: 4),
             Text(
  '${t['play_mode'] == 'multi' ? 'مالتي' : 'عادي'} | $rate ج/س',
  style: const TextStyle(color: Colors.white38, fontSize: 12),
),
            ]),
          ),

          const SizedBox(height: 16),

          // Start button if not active
        // بعد
if (!isActive)
  SizedBox(
    width: double.infinity,
    height: 54,
    child: FilledButton.icon(
      onPressed: () => showDialog(
        context: context,
        builder: (_) => TableStartDialog(tableIndex: widget.tableIndex),
      ),
      icon: const Icon(Icons.play_arrow_rounded, size: 28),
      label: const Text('بدء التربيزة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF34d399),
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  ),

          // زرار الجيم - دايماً ظاهر لو سعر الجيم محدد
          if (gamePrice > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _confirmGame(context, state, gamePrice),
                icon: Icon(
                  tableType == 'billiard' ? Icons.sports_golf : Icons.sports_tennis,
                  color: Colors.purple,
                ),
                label: Text(
                  'تسجيل جيم ($gamePrice ج)',
                  style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.purple, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],

          // Buffet section if active
          if (isActive) ...[
            const SizedBox(height: 16),
            _BuffetSection(tableIndex: widget.tableIndex, orders: orders),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: () => _confirmStop(context, state, timeCost, buffetCost),
                icon: const Icon(Icons.stop_circle_outlined, size: 24),
                label: const Text('إيقاف وحساب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4ade80),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  void _confirmGame(BuildContext context, AppState state, int gamePrice) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تسجيل جيم؟', style: TextStyle(color: Colors.purple)),
        content: Text('هيتسجل جيم بـ $gamePrice ج', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              state.addTableGameRecord(widget.tableIndex);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ تم تسجيل الجيم ($gamePrice ج)'),
                  backgroundColor: Colors.purple,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  void _confirmStop(BuildContext context, AppState state, double timeCost, double buffetCost) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('إيقاف التربيزة؟', style: TextStyle(color: Color(0xFF34d399))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _InfoRow('⏱ وقت', '${timeCost.toStringAsFixed(1)} ج'),
          _InfoRow('🥤 بوفيه', '${buffetCost.toStringAsFixed(1)} ج'),
          const Divider(color: Colors.white12),
          _InfoRow('💰 الإجمالي', '${(timeCost + buffetCost).toStringAsFixed(1)} ج', green: true),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              state.stopTable(widget.tableIndex);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4ade80), foregroundColor: Colors.black),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('إلغاء التربيزة؟', style: TextStyle(color: Colors.red)),
        content: const Text('هيتم إلغاء الجلسة بدون حساب', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              state.cancelTable(widget.tableIndex);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('إلغاء الجلسة'),
          ),
        ],
      ),
    );
  }
}

class _BuffetSection extends StatelessWidget {
  final int tableIndex;
  final Map<String, int> orders;
  const _BuffetSection({required this.tableIndex, required this.orders});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final hasOrders = orders.isNotEmpty;
    double buffetTotal = 0;
    orders.forEach((item, qty) => buffetTotal += qty * (state.menu[item] ?? 0));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasOrders
              ? Colors.orange.withOpacity(0.4)
              : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Row(children: [
                Icon(Icons.fastfood, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Text('البوفيه',
                    style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ]),
              const Spacer(),
              if (hasOrders)
                Text(
                  '${buffetTotal.toStringAsFixed(1)} ج',
                  style: const TextStyle(
                      color: Color(0xFF4ade80),
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
            ],
          ),

          // ── الطلبات الحالية كـ chips ────────────────────────────────
          if (hasOrders) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: orders.entries.map((e) {
                final price = state.menu[e.key] ?? 0;
                return GestureDetector(
                  onTap: () => state.addTableOrder(tableIndex, e.key, -1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: Colors.orange.withOpacity(0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                        '${e.key}  ×${e.value}',
                        style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${e.value * price} ج',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.remove_circle_outline,
                          color: Colors.redAccent, size: 15),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            const Text(
              'اضغط على الصنف لإزالة واحدة',
              style: TextStyle(color: Colors.white24, fontSize: 10),
            ),
          ],

          const SizedBox(height: 12),

          // ── زرار إضافة طلب ───────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: state.menu.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text('لا يوجد منتجات في البوفيه',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 13)),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: () =>
                        _showAddOrderDialog(context, state),
                    icon: const Icon(Icons.add_shopping_cart,
                        color: Colors.orange, size: 18),
                    label: Text(
                      hasOrders ? 'إضافة المزيد' : 'إضافة طلب',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddOrderDialog(BuildContext context, AppState state) {
    showBuffetOrderDialog(
      context: context,
      title: state.tables[tableIndex]['name']?.toString() ?? 'تربيزة',
      getCurrentOrders: () => Map<String, int>.from(
          state.tables[tableIndex]['orders'] ?? {}),
      onOrderChanged: (item, diff) =>
          state.addTableOrder(tableIndex, item, diff),
      accentColor: const Color(0xFF34d399),
    );
  }
}

class _CostChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _CostChip(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool green;
  const _InfoRow(this.label, this.value, {this.green = false});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        Text(value, style: TextStyle(color: green ? const Color(0xFF4ade80) : Colors.white, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
