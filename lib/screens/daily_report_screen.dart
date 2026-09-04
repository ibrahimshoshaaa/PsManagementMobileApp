import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final history = state.history;

    final totalTime   = history.fold(0.0, (s, h) => s + ((h['time_cost']   as num?)?.toDouble() ?? 0));
    final totalBuffet = history.fold(0.0, (s, h) => s + ((h['buffet_cost'] as num?)?.toDouble() ?? 0));
    final totalRevenue = totalTime + totalBuffet;
    final totalSessions = history.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تقرير اليوم المفصل',
              style: TextStyle(
                  color: Color(0xFF38bdf8),
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
            Text(
              '$totalSessions جلسة  •  ${totalRevenue.toStringAsFixed(1)} ج',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: const Color(0xFF38bdf8),
          labelColor: const Color(0xFF38bdf8),
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart, size: 15), text: 'الملخص'),
            Tab(icon: Icon(Icons.sports_esports, size: 15), text: 'الأجهزة'),
            Tab(icon: Icon(Icons.table_bar, size: 15), text: 'التربيزات'),
            Tab(icon: Icon(Icons.local_drink, size: 15), text: 'المشروبات'),
            Tab(icon: Icon(Icons.fastfood, size: 15), text: 'البوفيه'),
            Tab(icon: Icon(Icons.people, size: 15), text: 'الكاشير'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SummaryTab(history: history, state: state),
          _DevicesTab(history: history),
          _TablesTab(history: history),
          _DrinkTablesTab(history: history, menu: state.menu),
          _BuffetTab(
            history: history,
            menu: state.menu,
            inventory: state.inventory,
            menuBuyPrices: state.menuBuyPrices, // ← التعديل: إضافة menuBuyPrices
          ),
          _CashierTab(history: history),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — الملخص
// ══════════════════════════════════════════════════════════════════════════════

class _SummaryTab extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final AppState state;
  const _SummaryTab({required this.history, required this.state});

  @override
  Widget build(BuildContext context) {
    final totalTime    = history.fold(0.0, (s, h) => s + ((h['time_cost']   as num?)?.toDouble() ?? 0));
    final totalBuffet  = history.fold(0.0, (s, h) => s + ((h['buffet_cost'] as num?)?.toDouble() ?? 0));
    final totalRevenue = totalTime + totalBuffet;
    final totalSessions = history.length;
    final now      = DateTime.now();
    final todayStr = '${now.day}/${now.month}/${now.year}';
    final totalExpenses = state.expenses
      .where((e) => (e['date'] as String?)?.startsWith(todayStr) == true)
      .fold(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));
    final netProfit = totalRevenue - totalExpenses;
    final ps4Count     = history.where((h) => h['device_type'] == 'ps4').length;
    final ps5Count     = history.where((h) => h['device_type'] == 'ps5').length;
    final tableCount   = history.where((h) => h['device_type'] == 'table').length;
    final drinkCount   = history.where((h) => h['device_type'] == 'drink_table').length;
    final matchCount   = history.where((h) => h['is_match'] == true).length;
    final rechargeCount = history.where((h) => h['device_type'] == 'recharge').length;

    final Map<int, double> hourlyRevenue = {};
    for (final rec in history) {
      final dateStr = rec['date']?.toString() ?? '';
      if (dateStr.length >= 13) {
        final hour = int.tryParse(dateStr.substring(11, 13)) ?? 0;
        hourlyRevenue[hour] = (hourlyRevenue[hour] ?? 0) +
            ((rec['total'] as num?)?.toDouble() ?? 0);
      }
    }
    String peakHour = '—';
    if (hourlyRevenue.isNotEmpty) {
      final peak = hourlyRevenue.entries.reduce((a, b) => a.value > b.value ? a : b);
      peakHour = '${peak.key}:00 (${peak.value.toStringAsFixed(0)} ج)';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        _BigCard(totalRevenue: totalRevenue, totalTime: totalTime, totalBuffet: totalBuffet),
        const SizedBox(height: 10),
        _NetProfitCard(
          totalRevenue: totalRevenue,
          totalExpenses: totalExpenses,
          netProfit: netProfit,
        ),
        const SizedBox(height: 14),

        Row(children: [
          Expanded(child: _StatCard(
            icon: Icons.receipt_long,
            label: 'عدد الجلسات',
            value: '$totalSessions',
            color: const Color(0xFF38bdf8),
          )),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(
            icon: Icons.schedule,
            label: 'ذروة الإيراد',
            value: peakHour,
            color: Colors.amber,
            smallValue: true,
          )),
        ]),
        const SizedBox(height: 14),

        _SectionHeader('توزيع الجلسات'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (ps4Count > 0)    _TypeChip('PS4',       ps4Count,   Icons.sports_esports,   const Color(0xFF38bdf8)),
            if (ps5Count > 0)    _TypeChip('PS5',       ps5Count,   Icons.sports_esports,   const Color(0xFF818cf8)),
            if (matchCount > 0)  _TypeChip('ماتش',      matchCount, Icons.sports_soccer,    Colors.greenAccent),
            if (tableCount > 0)  _TypeChip('طاولة',     tableCount, Icons.table_restaurant, Colors.purpleAccent),
            if (drinkCount > 0)  _TypeChip('مشروبات',   drinkCount, Icons.local_cafe,       Colors.orange),
            if (rechargeCount > 0) _TypeChip('شحن', rechargeCount, Icons.phone_android, const Color(0xFF38bdf8)),
          ],
        ),
        const SizedBox(height: 14),

        if (history.isNotEmpty) ...[
          _SectionHeader('آخر الجلسات'),
          const SizedBox(height: 8),
          ...history.reversed.take(5).map((r) => _MiniSessionRow(record: r)),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — الأجهزة
// ══════════════════════════════════════════════════════════════════════════════

class _DevicesTab extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  const _DevicesTab({required this.history});

  @override
  Widget build(BuildContext context) {
    final Map<String, _DeviceStats> deviceMap = {};

    for (final rec in history) {
      final type = rec['device_type']?.toString() ?? '';
      if (type != 'ps4' && type != 'ps5') continue;
      final isMatch = rec['is_match'] == true;
      final name = rec['name']?.toString() ?? 'جهاز';

      deviceMap.putIfAbsent(name, () => _DeviceStats(name: name, deviceType: type));
      final ds = deviceMap[name]!;

      if (isMatch) {
        ds.matchCount++;
        ds.matchRevenue += ((rec['total'] as num?)?.toDouble() ?? 0);
      } else {
        ds.sessions++;
        ds.timeRevenue   += ((rec['time_cost']   as num?)?.toDouble() ?? 0);
        ds.buffetRevenue += ((rec['buffet_cost']  as num?)?.toDouble() ?? 0);
        ds.elapsedSeconds += ((rec['elapsed_seconds'] as num?)?.toInt() ?? 0);
        ds.records.add(rec);
      }
    }

    if (deviceMap.isEmpty) {
      return _EmptyState(icon: Icons.sports_esports, message: 'لا يوجد جلسات أجهزة اليوم');
    }

    final sorted = deviceMap.values.toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sorted.length,
      itemBuilder: (ctx, i) => _DeviceSection(stats: sorted[i], rank: i),
    );
  }
}

class _DeviceStats {
  final String name;
  final String deviceType;
  int sessions = 0;
  int matchCount = 0;
  double timeRevenue = 0;
  double buffetRevenue = 0;
  double matchRevenue = 0;
  int elapsedSeconds = 0;
  List<Map<String, dynamic>> records = [];

  _DeviceStats({required this.name, required this.deviceType});

  double get totalRevenue => timeRevenue + buffetRevenue + matchRevenue;
}

class _DeviceSection extends StatelessWidget {
  final _DeviceStats stats;
  final int rank;
  const _DeviceSection({required this.stats, required this.rank});

  @override
  Widget build(BuildContext context) {
    final isPs5  = stats.deviceType == 'ps5';
    final color  = isPs5 ? Colors.purple : const Color(0xFF38bdf8);
    final h = stats.elapsedSeconds ~/ 3600;
    final m = (stats.elapsedSeconds % 3600) ~/ 60;

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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color),
          ),
          child: Text(isPs5 ? 'PS5' : 'PS4',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
        title: Row(children: [
          Expanded(
            child: Text(stats.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          if (rank < 3) Text(['🥇', '🥈', '🥉'][rank]),
        ]),
        subtitle: Text(
          '${stats.sessions} جلسة${stats.matchCount > 0 ? " + ${stats.matchCount} ماتش" : ""}  •  ${h}س ${m}د  •  ${stats.totalRevenue.toStringAsFixed(1)} ج',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(children: [
              Row(children: [
                Expanded(child: _MiniStatBox('🎮 لعب',   '${stats.timeRevenue.toStringAsFixed(1)} ج',   color)),
                const SizedBox(width: 8),
                Expanded(child: _MiniStatBox('🥤 بوفيه', '${stats.buffetRevenue.toStringAsFixed(1)} ج', Colors.orange)),
                if (stats.matchCount > 0) ...[
                  const SizedBox(width: 8),
                  Expanded(child: _MiniStatBox('⚽ ماتش',  '${stats.matchRevenue.toStringAsFixed(1)} ج',  Colors.greenAccent)),
                ],
              ]),
              const SizedBox(height: 12),
              const Divider(color: Colors.white12),
              ...stats.records.reversed.map((rec) => _SessionRow(record: rec)),
            ]),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — التربيزات
// ══════════════════════════════════════════════════════════════════════════════

class _TablesTab extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  const _TablesTab({required this.history});

  @override
  Widget build(BuildContext context) {
    final Map<String, _TableStats> tableMap = {};

    for (final rec in history) {
      final type = rec['device_type']?.toString() ?? '';
      if (type != 'table') continue;
      final isGame = rec['is_game'] == true;
      final name = rec['name']?.toString() ?? 'تربيزة';

      tableMap.putIfAbsent(name, () => _TableStats(name: name));
      final ts = tableMap[name]!;

      if (isGame) {
        ts.gameCount++;
        ts.gameRevenue += ((rec['total'] as num?)?.toDouble() ?? 0);
      } else {
        ts.sessions++;
        ts.timeRevenue    += ((rec['time_cost']     as num?)?.toDouble() ?? 0);
        ts.buffetRevenue  += ((rec['buffet_cost']    as num?)?.toDouble() ?? 0);
        ts.elapsedSeconds += ((rec['elapsed_seconds'] as num?)?.toInt() ?? 0);
        ts.records.add(rec);
      }
    }

    if (tableMap.isEmpty) {
      return _EmptyState(icon: Icons.table_bar, message: 'لا يوجد جلسات تربيزات اليوم');
    }

    final sorted = tableMap.values.toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sorted.length,
      itemBuilder: (ctx, i) => _TableSection(stats: sorted[i], rank: i),
    );
  }
}

class _TableStats {
  final String name;
  int sessions = 0;
  int gameCount = 0;
  double timeRevenue = 0;
  double buffetRevenue = 0;
  double gameRevenue = 0;
  int elapsedSeconds = 0;
  List<Map<String, dynamic>> records = [];

  _TableStats({required this.name});

  double get totalRevenue => timeRevenue + buffetRevenue + gameRevenue;
}

class _TableSection extends StatelessWidget {
  final _TableStats stats;
  final int rank;
  const _TableSection({required this.stats, required this.rank});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF34d399);
    final h = stats.elapsedSeconds ~/ 3600;
    final m = (stats.elapsedSeconds % 3600) ~/ 60;

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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.table_bar, color: color, size: 18),
        ),
        title: Row(children: [
          Expanded(
            child: Text(stats.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          if (rank < 3) Text(['🥇', '🥈', '🥉'][rank]),
        ]),
        subtitle: Text(
          '${stats.sessions} جلسة${stats.gameCount > 0 ? " + ${stats.gameCount} جيم" : ""}  •  ${h}س ${m}د  •  ${stats.totalRevenue.toStringAsFixed(1)} ج',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(children: [
              Row(children: [
                Expanded(child: _MiniStatBox('⏱ وقت',   '${stats.timeRevenue.toStringAsFixed(1)} ج',   color)),
                const SizedBox(width: 8),
                Expanded(child: _MiniStatBox('🥤 بوفيه', '${stats.buffetRevenue.toStringAsFixed(1)} ج', Colors.orange)),
                if (stats.gameCount > 0) ...[
                  const SizedBox(width: 8),
                  Expanded(child: _MiniStatBox('🎱 جيمات', '${stats.gameRevenue.toStringAsFixed(1)} ج', Colors.purple)),
                ],
              ]),
              const SizedBox(height: 12),
              const Divider(color: Colors.white12),
              ...stats.records.reversed.map((rec) => _SessionRow(record: rec, color: color)),
            ]),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 4 — تربيزات المشروبات
// ══════════════════════════════════════════════════════════════════════════════

class _DrinkTablesTab extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final Map<String, int> menu;
  const _DrinkTablesTab({required this.history, required this.menu});

  @override
  Widget build(BuildContext context) {
    final Map<String, _DrinkTableStats> dtMap = {};

    for (final rec in history) {
      final type = rec['device_type']?.toString() ?? '';
      if (type != 'drink_table') continue;
      final name = rec['name']?.toString() ?? 'تربيزة';

      dtMap.putIfAbsent(name, () => _DrinkTableStats(name: name));
      final ds = dtMap[name]!;
      ds.billCount++;
      ds.totalRevenue += ((rec['buffet_cost'] as num?)?.toDouble() ?? 0);
      ds.records.add(rec);

      final orders = rec['orders'] as Map?;
      orders?.forEach((item, qty) {
        ds.itemTotals[item.toString()] =
            (ds.itemTotals[item.toString()] ?? 0) + ((qty as num?)?.toInt() ?? 0);
      });
    }

    if (dtMap.isEmpty) {
      return _EmptyState(icon: Icons.local_drink, message: 'لا يوجد فواتير مشروبات اليوم');
    }

    final sorted = dtMap.values.toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sorted.length,
      itemBuilder: (ctx, i) => _DrinkTableSection(stats: sorted[i], menu: menu, rank: i),
    );
  }
}

class _DrinkTableStats {
  final String name;
  int billCount = 0;
  double totalRevenue = 0;
  Map<String, int> itemTotals = {};
  List<Map<String, dynamic>> records = [];

  _DrinkTableStats({required this.name});
}

class _DrinkTableSection extends StatelessWidget {
  final _DrinkTableStats stats;
  final Map<String, int> menu;
  final int rank;
  const _DrinkTableSection({required this.stats, required this.menu, required this.rank});

  @override
  Widget build(BuildContext context) {
    const color = Colors.orange;
    final topItems = (stats.itemTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3);

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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.local_drink, color: color, size: 18),
        ),
        title: Row(children: [
          Expanded(
            child: Text(stats.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          if (rank < 3) Text(['🥇', '🥈', '🥉'][rank]),
        ]),
        subtitle: Text(
          '${stats.billCount} فاتورة  •  ${stats.totalRevenue.toStringAsFixed(1)} ج',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        trailing: Text('${stats.totalRevenue.toStringAsFixed(1)} ج',
            style: const TextStyle(color: Color(0xFF4ade80), fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (topItems.isNotEmpty) ...[
                const Text('الأصناف الأكثر طلباً:',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: topItems.map((e) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Text('${e.key}  ×${e.value}',
                        style: const TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                  )).toList(),
                ),
                const SizedBox(height: 12),
              ],
              const Divider(color: Colors.white12),
              ...stats.records.reversed.map((rec) => _DrinkBillRow(record: rec, menu: menu)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _DrinkBillRow extends StatelessWidget {
  final Map<String, dynamic> record;
  final Map<String, int> menu;
  const _DrinkBillRow({required this.record, required this.menu});

  @override
  Widget build(BuildContext context) {
    final dateStr = record['date']?.toString() ?? '';
    final timeStr = dateStr.length > 16 ? dateStr.substring(11, 16) : '';
    final total   = ((record['buffet_cost'] as num?)?.toDouble() ?? 0);
    final orders  = record['orders'] as Map? ?? {};
    final cashier = record['cashier']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.receipt, color: Colors.orange, size: 14),
          const SizedBox(width: 6),
          Text(timeStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const Spacer(),
          if (cashier.isNotEmpty)
            Text(cashier, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(width: 8),
          Text('${total.toStringAsFixed(1)} ج',
              style: const TextStyle(color: Color(0xFF4ade80), fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
        if (orders.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: orders.entries.map((e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${e.key} ×${e.value}',
                  style: const TextStyle(color: Colors.orange, fontSize: 10)),
            )).toList(),
          ),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 5 — البوفيه (مع تعديل المكسب وهامش الربح)
// ══════════════════════════════════════════════════════════════════════════════

class _BuffetTab extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final Map<String, int> menu;
  final Map<String, int> inventory;
  final Map<String, int> menuBuyPrices; // ← التعديل: parameter جديد

  const _BuffetTab({
    required this.history,
    required this.menu,
    required this.inventory,
    required this.menuBuyPrices, // ← التعديل
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, int> allOrders = {};
    double totalBuffetRevenue = 0;

    for (final rec in history) {
      totalBuffetRevenue += ((rec['buffet_cost'] as num?)?.toDouble() ?? 0);
      final orders = rec['orders'] as Map?;
      orders?.forEach((k, v) {
        allOrders[k.toString()] = (allOrders[k.toString()] ?? 0) + ((v as num?)?.toInt() ?? 0);
      });
    }

    if (allOrders.isEmpty) {
      return _EmptyState(icon: Icons.fastfood, message: 'لا يوجد مبيعات بوفيه اليوم');
    }

    final sorted = allOrders.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalQty = sorted.fold(0, (s, e) => s + e.value);

    // ← التعديل: حساب إجمالي المكسب
    double totalProfit = 0;
    for (final entry in sorted) {
      final itemName = entry.key;
      final soldQty = entry.value;
      final sellPrice = menu[itemName] ?? 0;
      final buyPrice = menuBuyPrices[itemName] ?? 0;
      if (buyPrice > 0) totalProfit += (sellPrice - buyPrice) * soldQty;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        // ── بطاقة الإجمالي ─────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF1c2128), Colors.orange.withOpacity(0.08)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _BigStatChip(
                  icon: Icons.payments_outlined,
                  label: 'إجمالي الإيرادات',
                  value: '${totalBuffetRevenue.toStringAsFixed(1)} ج',
                  color: Colors.orange,
                ),
                Container(width: 1, height: 40, color: Colors.white12),
                _BigStatChip(
                  icon: Icons.shopping_bag,
                  label: 'إجمالي قطع مباعة',
                  value: '$totalQty قطعة',
                  color: const Color(0xFF38bdf8),
                ),
                Container(width: 1, height: 40, color: Colors.white12),
                _BigStatChip(
                  icon: Icons.category,
                  label: 'عدد الأصناف',
                  value: '${sorted.length} صنف',
                  color: Colors.white70,
                ),
              ],
            ),
            // ← التعديل: إجمالي المكسب في البطاقة
            if (totalProfit > 0) ...[
              const SizedBox(height: 12),
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.trending_up, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'إجمالي المكسب: ${totalProfit.toStringAsFixed(0)} ج',
                      style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 14),

        _SectionHeader('تفاصيل كل صنف'),
        const SizedBox(height: 10),

        ...sorted.asMap().entries.map((entry) {
          final i        = entry.key;
          final itemName = entry.value.key;
          final soldQty  = entry.value.value;
          final price    = menu[itemName] ?? 0;
          final revenue  = soldQty * price;
          final remaining = inventory[itemName];
          final ratio    = totalQty > 0 ? soldQty / totalQty : 0.0;

          // ← التعديل: حساب المكسب وهامش الربح لكل صنف
          final buyPrice = menuBuyPrices[itemName] ?? 0;
          final profit = buyPrice > 0 ? (price - buyPrice) * soldQty : null;
          final margin = (buyPrice > 0 && price > 0)
              ? ((price - buyPrice) / price * 100).round()
              : null;

          Color rankColor;
          if (i == 0) rankColor = Colors.amber;
          else if (i == 1) rankColor = Colors.grey;
          else if (i == 2) rankColor = const Color(0xFFcd7f32);
          else rankColor = Colors.white38;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1c2128),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: i == 0 ? Colors.amber.withOpacity(0.3) : Colors.white10,
                width: i == 0 ? 1.5 : 1,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── هيدر الصنف ──────────────────────────────────────────
              Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: rankColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: rankColor.withOpacity(0.5)),
                  ),
                  child: Center(child: Text(
                    i < 3 ? ['🥇', '🥈', '🥉'][i] : '${i + 1}',
                    style: i < 3
                        ? const TextStyle(fontSize: 14)
                        : TextStyle(fontSize: 11, color: rankColor, fontWeight: FontWeight.bold),
                  )),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(itemName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.4)),
                  ),
                  child: Text('$soldQty قطعة',
                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ]),
              const SizedBox(height: 8),

              // ── شريط التقدم ──────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 5,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    i == 0 ? Colors.amber : Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ← التعديل: صف الأسعار (إيراد + سعر البيع + سعر الشراء)
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _MiniInfo('💰 إيراد', '$revenue ج', const Color(0xFF4ade80)),
                _MiniInfo('💵 سعر البيع', '$price ج', Colors.white38),
                if (buyPrice > 0)
                  _MiniInfo('🛒 سعر الشراء', '$buyPrice ج', Colors.redAccent)
                else
                  const SizedBox.shrink(),
              ]),

              // ← التعديل: صندوق المكسب وهامش الربح
              if (profit != null) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Icon(Icons.trending_up, color: Colors.green, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'المكسب: $profit ج',
                          style: const TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ]),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$margin% هامش',
                          style: const TextStyle(
                              color: Colors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── المتبقي في المخزن ────────────────────────────────────
              if (remaining != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(
                    remaining <= 3 ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                    size: 13,
                    color: remaining <= 3 ? Colors.red : Colors.white38,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'متبقي في المخزن: $remaining قطعة',
                    style: TextStyle(
                        color: remaining <= 3 ? Colors.red : Colors.white38,
                        fontSize: 11),
                  ),
                ]),
              ],
            ]),
          );
        }),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 6 — الكاشير
// ══════════════════════════════════════════════════════════════════════════════

class _CashierTab extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  const _CashierTab({required this.history});

  @override
  Widget build(BuildContext context) {
    final Map<String, _CashierStats> cashierMap = {};

    for (final rec in history) {
      final cashier = rec['cashier']?.toString() ?? 'غير محدد';
      cashierMap.putIfAbsent(cashier, () => _CashierStats(name: cashier));
      final cs = cashierMap[cashier]!;
      cs.sessions++;
      cs.revenue += ((rec['total'] as num?)?.toDouble() ?? 0);
      cs.timeRevenue   += ((rec['time_cost']   as num?)?.toDouble() ?? 0);
      cs.buffetRevenue += ((rec['buffet_cost']  as num?)?.toDouble() ?? 0);
    }

    if (cashierMap.isEmpty) {
      return _EmptyState(icon: Icons.people, message: 'لا يوجد بيانات كاشير');
    }

    final sorted = cashierMap.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    final totalRevenue = sorted.fold(0.0, (s, c) => s + c.revenue);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1c2128),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('الإجمالي الكلي',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            Text('${totalRevenue.toStringAsFixed(1)} ج',
                style: const TextStyle(color: Color(0xFF4ade80),
                    fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
        ),
        const SizedBox(height: 14),

        ...sorted.asMap().entries.map((entry) {
          final i     = entry.key;
          final stats = entry.value;
          final pct   = totalRevenue > 0 ? stats.revenue / totalRevenue : 0.0;

          Color rankColor;
          if (i == 0) rankColor = Colors.amber;
          else if (i == 1) rankColor = Colors.grey;
          else if (i == 2) rankColor = const Color(0xFFcd7f32);
          else rankColor = Colors.white38;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1c2128),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: i == 0 ? Colors.amber.withOpacity(0.4) : Colors.white10,
                width: i == 0 ? 1.5 : 1,
              ),
            ),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: rankColor.withOpacity(0.15),
                    border: Border.all(color: rankColor.withOpacity(0.5)),
                  ),
                  child: Center(child: Text(
                    stats.name.isNotEmpty ? stats.name[0].toUpperCase() : 'K',
                    style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, fontSize: 18),
                  )),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(stats.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('${stats.sessions} جلسة',
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${stats.revenue.toStringAsFixed(1)} ج',
                      style: const TextStyle(
                          color: Color(0xFF4ade80), fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('${(pct * 100).toStringAsFixed(0)}٪ من الإجمالي',
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ]),
              ]),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4ade80)),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _MiniStatBox('🎮 لعب',   '${stats.timeRevenue.toStringAsFixed(1)} ج',   const Color(0xFF38bdf8))),
                const SizedBox(width: 8),
                Expanded(child: _MiniStatBox('🥤 بوفيه', '${stats.buffetRevenue.toStringAsFixed(1)} ج', Colors.orange)),
              ]),
            ]),
          );
        }),
      ]),
    );
  }
}

class _CashierStats {
  final String name;
  int sessions = 0;
  double revenue = 0;
  double timeRevenue = 0;
  double buffetRevenue = 0;
  _CashierStats({required this.name});
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared Widgets
// ══════════════════════════════════════════════════════════════════════════════

class _BigCard extends StatelessWidget {
  final double totalRevenue, totalTime, totalBuffet;
  const _BigCard({required this.totalRevenue, required this.totalTime, required this.totalBuffet});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1e3a4f), Color(0xFF0f2030)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF38bdf8).withOpacity(0.3)),
      ),
      child: Column(children: [
        const Text('إجمالي إيرادات اليوم',
            style: TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 8),
        Text(
          '${totalRevenue.toStringAsFixed(1)} ج',
          style: const TextStyle(color: Color(0xFF4ade80), fontSize: 42, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _RevItem('🎮 اللعب', totalTime, const Color(0xFF38bdf8)),
          Container(width: 1, height: 30, color: Colors.white12),
          _RevItem('🥤 البوفيه', totalBuffet, Colors.orange),
        ]),
      ]),
    );
  }
}

class _RevItem extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _RevItem(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
    const SizedBox(height: 4),
    Text('${value.toStringAsFixed(1)} ج',
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
  ]);
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  final bool smallValue;
  const _StatCard({required this.icon, required this.label, required this.value,
    required this.color, this.smallValue = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Expanded(child: Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold,
            fontSize: smallValue ? 13 : 22)),
      ]),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  const _TypeChip(this.label, this.count, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ]),
    );
  }
}

class _MiniSessionRow extends StatelessWidget {
  final Map<String, dynamic> record;
  const _MiniSessionRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final dateStr = record['date']?.toString() ?? '';
    final timeStr = dateStr.length > 16 ? dateStr.substring(11, 16) : '';
    final total   = (record['total'] as num?)?.toDouble() ?? 0;
    final cashier = record['cashier']?.toString() ?? '—';
    final type    = record['device_type']?.toString() ?? '';

    Color color = const Color(0xFF38bdf8);
    if (type == 'table')       color = const Color(0xFF34d399);
    if (type == 'drink_table') color = Colors.orange;
    if (record['is_match'] == true) color = Colors.greenAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(children: [
        Container(width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(record['name']?.toString() ?? '—',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
        Text(cashier, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(width: 10),
        Text(timeStr, style: const TextStyle(color: Colors.white24, fontSize: 11,
            fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(width: 12),
        Text('${total.toStringAsFixed(1)} ج',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final Map<String, dynamic> record;
  final Color color;
  const _SessionRow({required this.record, this.color = const Color(0xFF38bdf8)});

  @override
  Widget build(BuildContext context) {
    final dateStr = record['date']?.toString() ?? '';
    final timeStr = dateStr.length > 16 ? dateStr.substring(11, 16) : '';
    final total    = (record['total'] as num?)?.toDouble() ?? 0;
    final duration = record['duration']?.toString() ?? '';
    final cashier  = record['cashier']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        const Icon(Icons.play_circle_outline, size: 14, color: Colors.white24),
        const SizedBox(width: 6),
        Text(timeStr, style: const TextStyle(color: Colors.white38, fontSize: 11,
            fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(width: 8),
        Expanded(child: Text(duration,
            style: const TextStyle(color: Colors.white54, fontSize: 11))),
        if (cashier.isNotEmpty) ...[
          Text(cashier, style: const TextStyle(color: Colors.white24, fontSize: 10)),
          const SizedBox(width: 8),
        ],
        Text('${total.toStringAsFixed(1)} ج',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
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
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }
}

class _BigStatChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _BigStatChip({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
    ]);
  }
}

class _MiniInfo extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniInfo(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text(label, style: const TextStyle(color: Colors.white24, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    ]);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(title,
          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 64, color: Colors.white12),
        const SizedBox(height: 16),
        Text(message, style: const TextStyle(color: Colors.white38, fontSize: 16)),
      ]),
    );
  }
}

class _NetProfitCard extends StatelessWidget {
  final double totalRevenue, totalExpenses, netProfit;
  const _NetProfitCard({
    required this.totalRevenue,
    required this.totalExpenses,
    required this.netProfit,
  });
 
  @override
  Widget build(BuildContext context) {
    final isPos = netProfit >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPos
              ? const Color(0xFF4ade80).withOpacity(0.3)
              : Colors.redAccent.withOpacity(0.3),
        ),
      ),
      child: Column(children: [
        // صف الإيرادات والمصروفات
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ProfitChip(
              label: '💰 الإيرادات',
              value: '${totalRevenue.toStringAsFixed(1)} ج',
              color: const Color(0xFF4ade80),
            ),
            const Text('−',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            _ProfitChip(
              label: '💸 المصروفات',
              value: '${totalExpenses.toStringAsFixed(1)} ج',
              color: Colors.redAccent,
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Divider(color: Colors.white12, height: 1),
        const SizedBox(height: 10),
        // صافي الربح
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            isPos ? Icons.trending_up : Icons.trending_down,
            color: isPos ? const Color(0xFF4ade80) : Colors.redAccent,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'صافي الربح: ',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          Text(
            '${netProfit.toStringAsFixed(1)} ج',
            style: TextStyle(
              color:
                  isPos ? const Color(0xFF4ade80) : Colors.redAccent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ]),
      ]),
    );
  }
}
 
class _ProfitChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _ProfitChip(
      {required this.label, required this.value, required this.color});
 
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label,
            style:
                const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
      ]);
}
