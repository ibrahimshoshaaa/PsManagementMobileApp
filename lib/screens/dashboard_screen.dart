import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'shift_screen.dart';
import 'daily_report_screen.dart';
import 'audit_logs_screen.dart';
import 'inventory_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
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

    final activeDevices = state.devices.where((d) => d.isActive).toList();
    final busyDrinkTables = state.drinkTables.where((t) {
      final orders = Map<String, int>.from(t['orders'] ?? {});
      return orders.isNotEmpty;
    }).toList();

    final todayTime =
        state.history.fold(0.0, (s, h) => s + (h['time_cost'] ?? 0));
    final todayBuffet =
        state.history.fold(0.0, (s, h) => s + (h['buffet_cost'] ?? 0));
    final todayTotal = todayTime + todayBuffet;

    double liveRevenue = 0;
    for (final d in activeDevices) {
      liveRevenue += d.calculateTimePrice(state.prices);
      liveRevenue += d.getBuffetPrice(state.menu);
    }
    for (int i = 0; i < state.tables.length; i++) {
      if (state.tables[i]['start_time'] != null) {
        final elapsed = state.tableElapsed(i);
        final rate = (state.tables[i]['rate'] as num).toDouble();
        liveRevenue += (elapsed / 3600) * rate;
        final orders = Map<String, int>.from(state.tables[i]['orders'] ?? {});
        orders.forEach(
            (item, qty) => liveRevenue += qty * (state.menu[item] ?? 0));
      }
    }

    final unpaidDebts = state.debts.where((d) => d['paid'] != true).toList();
    final totalDebt =
        unpaidDebts.fold(0.0, (s, d) => s + ((d['amount'] as num?) ?? 0));
    final now = DateTime.now();
  final todayStr = '${now.day}/${now.month}/${now.year}';
  final todayExpenses = state.expenses
      .where((e) => (e['date'] as String?)?.startsWith(todayStr) == true)
      .fold(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));

    final activeTournaments =
        state.tournaments.where((t) => t['status'] == 'ongoing').toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dashboard_rounded, color: Color(0xFF38bdf8), size: 18),
            SizedBox(width: 6),
            Text('الداشبورد',
                style: TextStyle(
                    color: Color(0xFF38bdf8),
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ],
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        children: [
          // ── حالة الشيفت لايف (يظهر للأدمن فقط) ───────────────────────────────────
         if (state.isAdmin) ...[
  const ActiveShiftBanner(),
  const SizedBox(height: 8),
],

// ══ بطاقة الإيرادات (compact) ══════════════════════════════════════
_CompactRevenueCard(
  todayTotal: todayTotal,
  todayTime: todayTime,
  todayBuffet: todayBuffet,
  liveRevenue: liveRevenue,
),
const SizedBox(height: 8),

//----------------------------------------
// صف 1 — تقارير الشيفتات + تقرير اليوم
Row(
  children: [
    Expanded(
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ShiftHistoryScreen())),
        icon: const Icon(Icons.assignment_turned_in_outlined,
            color: Color(0xFFa78bfa), size: 16),
        label: Text(
          'الشيفتات (${state.shiftsHistory.length})',
          style: const TextStyle(color: Color(0xFFa78bfa), fontSize: 12),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFa78bfa)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const DailyReportScreen())),
        icon: const Icon(Icons.bar_chart_rounded,
            color: Color(0xFFf59e0b), size: 16),
        label: const Text(
          'تقرير اليوم',
          style: TextStyle(color: Color(0xFFf59e0b), fontSize: 12),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFf59e0b)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    ),
  ],
),
const SizedBox(height: 8),

// صف 2 — سجل الأحداث + تقرير البوفيه
Row(
  children: [
    Expanded(
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AuditLogsScreen())),
        icon: const Icon(Icons.history_edu,
            color: Color(0xFF38bdf8), size: 16),
        label: const Text(
          'سجل الأحداث',
          style: TextStyle(color: Color(0xFF38bdf8), fontSize: 12),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF38bdf8)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const InventoryScreen())),
        icon: const Icon(Icons.inventory_2,
            color: Colors.teal, size: 16),
        label: const Text(
          'تقرير البوفيه',
          style: TextStyle(color: Colors.teal, fontSize: 12),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.teal),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    ),
  ],
),
const SizedBox(height: 8),
          
          // ══ الأجهزة ════════════════════════════════════════════════════════
          if (state.devices.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.sports_esports,
              title: 'الأجهزة',
              color: const Color(0xFF38bdf8),
              trailing:
                  '${activeDevices.length}/${state.devices.length} شغال',
            ),
            const SizedBox(height: 6),
            _TinyDevicesGrid(devices: state.devices, prices: state.prices),
            const SizedBox(height: 8),
          ],

          // ══ التربيزات ═══════════════════════════════════════════════════════
          if (state.tables.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.table_bar,
              title: 'بنج / بلياردو',
              color: const Color(0xFF34d399),
              trailing:
                  '${state.tables.where((t) => t['start_time'] != null).length}/${state.tables.length} شغالة',
            ),
            const SizedBox(height: 6),
            _TinyTablesGrid(tables: state.tables, state: state),
            const SizedBox(height: 8),
          ],

          // ══ تربيزات المشروبات ════════════════════════════════════════════════
          if (state.drinkTables.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.local_drink,
              title: 'المشروبات',
              color: Colors.orange,
              trailing:
                  '${busyDrinkTables.length}/${state.drinkTables.length} فيها طلبات',
            ),
            const SizedBox(height: 6),
            _TinyDrinkGrid(drinkTables: state.drinkTables, menu: state.menu),
            const SizedBox(height: 8),
          ],

          // ══ مديونيات + بطولات (row) ══════════════════════════════════════════
          Row(children: [
    Expanded(
      child: _MiniInfoCard(
        icon: Icons.money_off,
        title: 'المديونيات',
        value: '${totalDebt.toStringAsFixed(0)} ج',
        sub: '${unpaidDebts.length} غير مسددة',
        color: Colors.redAccent,
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: _MiniInfoCard(
        icon: Icons.receipt_long,
        title: 'المصروفات',
        value: '${todayExpenses.toStringAsFixed(0)} ج',
        sub: '${state.expenses.where((e) => (e['date'] as String?)?.startsWith(todayStr) == true).length} مصروف اليوم',
        color: Colors.orange,
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: _MiniInfoCard(
        icon: Icons.emoji_events,
        title: 'البطولات',
        value: '${activeTournaments.length}',
        sub: 'جارية الآن',
        color: const Color(0xFFfbbf24),
      ),
    ),
  ]),

          // ══ تنبيهات المخزون ══════════════════════════════════════════════════
          if (state.inventory.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.inventory_2,
              title: 'تنبيهات المخزون',
              color: Colors.teal,
            ),
            const SizedBox(height: 6),
            _InventoryAlerts(inventory: state.inventory, menu: state.menu),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// بطاقة الإيرادات Compact
// ══════════════════════════════════════════════════════════════════════════════

class _CompactRevenueCard extends StatelessWidget {
  final double todayTotal, todayTime, todayBuffet, liveRevenue;
  const _CompactRevenueCard({
    required this.todayTotal,
    required this.todayTime,
    required this.todayBuffet,
    required this.liveRevenue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF38bdf8).withOpacity(0.2)),
      ),
      child: Row(children: [
        Expanded(child: _RevCol('💰 الإجمالي', todayTotal, const Color(0xFF4ade80),
            live: liveRevenue > 0 ? '+${liveRevenue.toStringAsFixed(0)}' : null)),
        Container(width: 1, height: 32, color: Colors.white12),
        Expanded(child: _RevCol('🎮 لعب', todayTime, const Color(0xFF38bdf8))),
        Container(width: 1, height: 32, color: Colors.white12),
        Expanded(child: _RevCol('🥤 بوفيه', todayBuffet, Colors.orange)),
      ]),
    );
  }
}

class _RevCol extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final String? live;
  const _RevCol(this.label, this.value, this.color, {this.live});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text('${value.toStringAsFixed(0)} ج',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      if (live != null)
        Text(live!, style: const TextStyle(color: Color(0xFF4ade80), fontSize: 8)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tiny Grids (أصغر من القديم)
// ══════════════════════════════════════════════════════════════════════════════

class _TinyDevicesGrid extends StatelessWidget {
  final List devices;
  final Map<String, int> prices;
  const _TinyDevicesGrid({required this.devices, required this.prices});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: devices.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,  // ✅ 4 في الصف بدل 3
        childAspectRatio: 1.1,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemBuilder: (ctx, i) {
        final d = devices[i];
        final isPs5 = d.deviceType == 'ps5';
        final color = d.isPaused
            ? Colors.amber
            : d.isActive
                ? (isPs5 ? Colors.purple : const Color(0xFF38bdf8))
                : Colors.white24;
        final statusLabel = d.isPaused ? 'وقف' : d.isActive ? 'شغال' : 'فاضي';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1c2128),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: color.withOpacity(d.isActive ? 0.7 : 0.2),
                width: d.isActive ? 1.5 : 1),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 6, height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(height: 3),
            Text(d.displayName,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(statusLabel,
                style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
          ]),
        );
      },
    );
  }
}

class _TinyTablesGrid extends StatelessWidget {
  final List<Map<String, dynamic>> tables;
  final AppState state;
  const _TinyTablesGrid({required this.tables, required this.state});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tables.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // ✅ 4 في الصف
        childAspectRatio: 1.1,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemBuilder: (ctx, i) {
        final t = tables[i];
        final isActive = t['start_time'] != null;
        final isPaused = t['is_paused'] == true;
        final tableType = t['table_type'] ?? 'ping';
        final color = isPaused
            ? Colors.amber
            : isActive
                ? const Color(0xFF34d399)
                : Colors.white24;
        final emoji = tableType == 'billiard' ? '🎱' : '🏓';
        final statusLabel = isPaused ? 'وقف' : isActive ? 'شغالة' : 'فاضية';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1c2128),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: color.withOpacity(isActive ? 0.7 : 0.2),
                width: isActive ? 1.5 : 1),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(emoji, style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 2),
            Text(t['name'] ?? '',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(statusLabel,
                style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
          ]),
        );
      },
    );
  }
}

class _TinyDrinkGrid extends StatelessWidget {
  final List<Map<String, dynamic>> drinkTables;
  final Map<String, int> menu;
  const _TinyDrinkGrid({required this.drinkTables, required this.menu});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: drinkTables.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // ✅ 4 في الصف
        childAspectRatio: 1.1,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemBuilder: (ctx, i) {
        final t = drinkTables[i];
        final orders = Map<String, int>.from(t['orders'] ?? {});
        final hasBusy = orders.isNotEmpty;
        final color = hasBusy ? Colors.orange : Colors.white24;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1c2128),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: color.withOpacity(hasBusy ? 0.7 : 0.2),
                width: hasBusy ? 1.5 : 1),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.local_drink, color: color, size: 11),
            const SizedBox(height: 2),
            Text(t['name'] ?? '',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(hasBusy ? 'طلبات' : 'فاضية',
                style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
          ]),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Mini Info Card (أصغر)
// ══════════════════════════════════════════════════════════════════════════════

class _MiniInfoCard extends StatelessWidget {
  final IconData icon;
  final String title, value, sub;
  final Color color;
  const _MiniInfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          Text(value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 9)),
        ])),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Inventory Alerts
// ══════════════════════════════════════════════════════════════════════════════

class _InventoryAlerts extends StatelessWidget {
  final Map<String, int> inventory;
  final Map<String, int> menu;
  const _InventoryAlerts({required this.inventory, required this.menu});

  @override
  Widget build(BuildContext context) {
    final lowStock = inventory.entries
        .where((e) => e.value <= 3 && menu.containsKey(e.key))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    if (lowStock.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1c2128),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: const Row(children: [
          Icon(Icons.check_circle_outline, color: Color(0xFF4ade80), size: 14),
          SizedBox(width: 6),
          Text('المخزون كويس ✅',
              style: TextStyle(color: Color(0xFF4ade80), fontSize: 12)),
        ]),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: lowStock.map((e) {
        final color = e.value == 0 ? Colors.red : Colors.orange;
        final label = e.value == 0 ? 'نفد!' : '${e.value} قطعة';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1c2128),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.warning_amber_rounded, color: color, size: 12),
            const SizedBox(width: 4),
            Text(e.key,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(5)),
              child: Text(label,
                  style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ]),
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Section Header
// ══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final String? trailing;
  const _SectionHeader(
      {required this.icon,
      required this.title,
      required this.color,
      this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: color, size: 13),
      const SizedBox(width: 5),
      Text(title,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 11)),
      const Spacer(),
      if (trailing != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Text(trailing!,
              style: TextStyle(color: color, fontSize: 9)),
        ),
    ]);
  }
}
