import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_state.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../widgets/device_card.dart';
import 'device_detail_screen.dart';
import 'table_detail_screen.dart';
import 'drink_table_screen.dart';
import 'customer_orders_screen.dart';
import 'settings_screen.dart';
import 'debts_screen.dart';
import 'tournament_screen.dart';
import 'shift_screen.dart';
import '../widgets/table_start_dialog.dart';
import '../widgets/buffet_order_dialog.dart';
import '../widgets/device_transfer_start_dialog.dart';
import 'recharge_screen.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});
  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _tabCount = 1;
  int _pendingOrdersCount = 0;
  Timer? _ordersTimer;
  final Set<String> _notifiedOrderKeys = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildTabs();
      _startOrdersPolling();
    });
  }

  void _startOrdersPolling() {
    _pollOrders();
    _ordersTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _pollOrders());
  }

  Future<void> _pollOrders() async {
    final shopId = context.read<AppState>().shopId;
    if (shopId == null) return;
    try {
      final data =
          await FirebaseService.get('shops/$shopId/customer_orders');
      if (data == null || data is! Map) {
        if (mounted) setState(() => _pendingOrdersCount = 0);
        return;
      }

      int pendingCount = 0;
      for (final entry in (data as Map).entries) {
        final key = entry.key.toString();
        final v = entry.value;
        if (v is! Map) continue;
        final status = v['status']?.toString() ?? '';
        if (status != 'pending') continue;
        pendingCount++;
        if (!_notifiedOrderKeys.contains(key)) {
          _notifiedOrderKeys.add(key);
          final deviceName = v['device_name']?.toString() ?? 'جهاز';
          final orderText = v['order_text']?.toString() ?? '';
          await NotificationService.showCustomerOrderAlert(
              deviceName, orderText);
        }
      }
      _notifiedOrderKeys
          .removeWhere((key) => !(data as Map).containsKey(key));
      if (mounted) setState(() => _pendingOrdersCount = pendingCount);
    } catch (_) {}
  }

  void _rebuildTabs() {
    final state = context.read<AppState>();
    final hasDevices = state.devices.isNotEmpty;
    final hasTables = state.tables.isNotEmpty;
    final hasDrinkTables = state.drinkTables.isNotEmpty;
    final hasRecharge = state.rechargeEnabled;

    final newCount = (hasDevices ? 1 : 0) +
        (hasTables ? 1 : 0) +
        (hasDrinkTables ? 1 : 0) +
        (hasRecharge ? 1 : 0);

    final safeCount = newCount == 0 ? 1 : newCount;

    if (safeCount != _tabCount) {
      setState(() {
        _tabCount = safeCount;
        _tabController.dispose();
        _tabController = TabController(length: safeCount, vsync: this);
      });
    }
  }

  // ── إنهاء الشيفت ─────────────────────────────────────────────────────────
  void _confirmEndShift(BuildContext context) {
    final state = context.read<AppState>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.stop_circle_outlined, color: Colors.red),
          SizedBox(width: 8),
          Text('إنهاء الشيفت؟',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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

  @override
  void dispose() {
    _tabController.dispose();
    _ordersTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final hasDevices = state.devices.isNotEmpty;
    final hasTables = state.tables.isNotEmpty;
    final hasDrinkTables = state.drinkTables.isNotEmpty;
    final hasRecharge = state.rechargeEnabled;
    final hasAnything = hasDevices || hasTables || hasDrinkTables || hasRecharge;

    WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildTabs());

    final tabs = <Tab>[
      if (hasDevices)
        const Tab(
            icon: Icon(Icons.sports_esports, size: 18), text: 'الأجهزة'),
      if (hasTables)
        const Tab(
            icon: Icon(Icons.table_bar,
                size: 18, color: Color(0xFF34d399)),
            text: 'بنج / بلياردو'),
      if (hasDrinkTables)
        const Tab(
            icon: Icon(Icons.local_drink,
                size: 18, color: Colors.orange),
            text: 'تربيزات'),
      if (hasRecharge)
        const Tab(
            icon: Icon(Icons.phone_android, size: 18, color: Color(0xFF38bdf8)),
            text: 'شحن'),
    ];

    final tabViews = <Widget>[
      if (hasDevices)
        GridView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: state.devices.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.68,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (ctx, i) {
            final d = state.devices[i];
            return DeviceCard(
              device: d,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DeviceDetailScreen(device: d))),
            );
          },
        ),
      if (hasTables)
        GridView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: state.tables.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.95,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (ctx, i) => _TableCard(tableIndex: i),
        ),
      if (hasDrinkTables)
        Column(
          children: [
            _DrinkDaySummaryBar(state: state),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: state.drinkTables.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.82,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (ctx, i) => _DrinkTableCard(index: i),
              ),
            ),
          ],
        ),
      if (hasRecharge)
        const RechargeScreen(),
    ];

    final showTabs = tabs.length > 1;

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        elevation: 0,
        title: Text(
          '⚡ ${state.shopName}',
          style: const TextStyle(
              color: Color(0xFF38bdf8),
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
        centerTitle: true,
        actions: [
        Stack(
  clipBehavior: Clip.none,
  children: [
    PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white70),
      color: const Color(0xFF1c2128),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) async {
        switch (value) {
          case 'orders':
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => CustomerOrdersScreen(shopId: state.shopId ?? '')));
            _pollOrders();
            break;
          case 'debts':
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DebtsScreen()));
            break;
          case 'tournaments':
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TournamentScreen()));
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'orders',
          child: Row(children: [
            const Icon(Icons.notifications_active_outlined, color: Colors.orange, size: 20),
            const SizedBox(width: 10),
            const Text('طلبات العملاء'),
            if (_pendingOrdersCount > 0) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                child: Text('$_pendingOrdersCount',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ]),
        ),
        const PopupMenuItem(
          value: 'debts',
          child: Row(children: [
            Icon(Icons.money_off, color: Colors.redAccent, size: 20),
            SizedBox(width: 10),
            Text('المديونيات'),
          ]),
        ),
        const PopupMenuItem(
          value: 'tournaments',
          child: Row(children: [
            Icon(Icons.emoji_events, color: Color(0xFFfbbf24), size: 20),
            SizedBox(width: 10),
            Text('البطولات'),
          ]),
        ),
      ],
    ),
    if (_pendingOrdersCount > 0)
      Positioned(
        top: 6,
        left: 6,
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
            child: Text('$_pendingOrdersCount',
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
          ),
        ),
      ),
  ],
),
          
          // ── خروج ────────────────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
            onPressed: () => context.read<AppState>().logout(),
            tooltip: 'خروج',
          ),
        ],
        bottom: showTabs
            ? TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF38bdf8),
                labelColor: const Color(0xFF38bdf8),
                unselectedLabelColor: Colors.white38,
                labelStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold),
                tabs: tabs,
              )
            : null,
      ),
      body: !hasAnything
          ? const _EmptyWelcomeScreen()
          : (showTabs
              ? TabBarView(
                  controller: _tabController, children: tabViews)
              : tabViews.first),
      // ── Bottom Bar: زرار إنهاء الشيفت فقط ────────────────────────
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1c2128),
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: () => _confirmEndShift(context),
                icon: const Icon(Icons.stop_circle_outlined, size: 20),
                label: const Text(
                  'إنهاء الشيفت',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyWelcomeScreen extends StatelessWidget {
  const _EmptyWelcomeScreen();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1c2128),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF38bdf8).withOpacity(0.15),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.add_circle_outline,
                  size: 72, color: Color(0xFF38bdf8)),
            ),
            const SizedBox(height: 28),
            const Text(
              'أهلاً بك! 👋',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF38bdf8)),
            ),
            const SizedBox(height: 12),
            const Text(
              'التطبيق جاهز للاستخدام\nابدأ بإضافة محتوى من الإعدادات',
              style: TextStyle(
                  color: Colors.white54, fontSize: 15, height: 1.6),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TableCard extends StatelessWidget {
  final int tableIndex;
  const _TableCard({required this.tableIndex});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (tableIndex >= state.tables.length) return const SizedBox();
    final t = state.tables[tableIndex];
    final bool isActive = t['start_time'] != null;
    final bool isPaused = t['is_paused'] == true;
    final elapsed = state.tableElapsed(tableIndex);
    final isCountdown = t['is_countdown'] == true;
    final countdownTotal = (t['countdown_total_seconds'] as num?)?.toInt();
    int displaySeconds = elapsed;
    if (isCountdown && countdownTotal != null) {
      final remaining = countdownTotal - elapsed;
      displaySeconds = remaining < 0 ? 0 : remaining;
    }
    final h = displaySeconds ~/ 3600;
    final m = (displaySeconds % 3600) ~/ 60;
    final s = displaySeconds % 60;
    final timerText = isActive
        ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '--:--:--';
    final color = isActive
        ? (isPaused ? Colors.amber : const Color(0xFF34d399))
        : Colors.white24;

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  TableDetailScreen(tableIndex: tableIndex))),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1c2128),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: color.withOpacity(0.4),
              width: isActive ? 1.5 : 1),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(children: [
              Icon(Icons.table_bar, color: color, size: 26),
              const SizedBox(height: 4),
              Text(t['name'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(timerText,
                  style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [
                        FontFeature.tabularFigures()
                      ])),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                  isActive
                      ? (isPaused ? 'إيقاف مؤقت' : 'شغالة')
                      : '${t['rate']} ج/س',
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            if (!isActive)
              SizedBox(
                width: double.infinity,
                height: 34,
                child: FilledButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => TableStartDialog(tableIndex: tableIndex),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('تشغيل',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF34d399),
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              )
            else
              Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: OutlinedButton(
                      onPressed: () =>
                          state.toggleTablePause(tableIndex),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: BorderSide(
                            color: isPaused
                                ? Colors.amber
                                : Colors.white24),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10)),
                      ),
                      child: Icon(
                        isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        size: 18,
                        color: isPaused
                            ? Colors.amber
                            : Colors.white54,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 34,
                    child: FilledButton(
                      onPressed: () =>
                          _confirmStop(context, state),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4ade80),
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10)),
                      ),
                      child: const Text('حساب',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ]),
          ],
        ),
      ),
    );
  }

  void _confirmStop(BuildContext context, AppState state) {
    final t = state.tables[tableIndex];
    final elapsed = state.tableElapsed(tableIndex);
    final rate = ((t['session_rate'] ?? t['rate']) as num).toDouble();
    final timeCost = (elapsed / 3600) * rate;
    final Map<String, int> orders =
        Map<String, int>.from(t['orders'] ?? {});
    double buffetCost = 0;
    orders.forEach(
        (item, qty) => buffetCost += qty * (state.menu[item] ?? 0));
    final whatsappNumber = t['whatsapp_number'] as String?;
    final hasWhatsapp =
        whatsappNumber != null && whatsappNumber.isNotEmpty;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('حساب ${t['name']}',
            style: const TextStyle(color: Color(0xFF34d399))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _BillRow('⏱ وقت', '${timeCost.toStringAsFixed(1)} ج'),
          _BillRow(
              '🥤 بوفيه', '${buffetCost.toStringAsFixed(1)} ج'),
          const Divider(color: Colors.white12),
          _BillRow('💰 الإجمالي',
              '${(timeCost + buffetCost).toStringAsFixed(1)} ج',
              green: true),
          if (hasWhatsapp) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.phone, color: Colors.green, size: 14),
              const SizedBox(width: 4),
              Text(whatsappNumber,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12)),
            ]),
          ],
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              state.stopTable(tableIndex);
            },
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4ade80),
                foregroundColor: Colors.black),
            child: const Text('تأكيد'),
          ),
          if (hasWhatsapp)
            FilledButton.icon(
              icon: const Icon(Icons.send, size: 16),
              label: const Text('تأكيد وإرسال'),
              onPressed: () async {
                final tableName = t['name']?.toString() ?? 'تربيزة';
                final shopName = state.shopName;
                final menu = state.menu;
                Navigator.pop(context);
                state.stopTable(tableIndex);
                await cashierTableLaunchWhatsapp(
                  context: context,
                  phone: whatsappNumber,
                  shopName: shopName,
                  tableName: tableName,
                  elapsed: elapsed,
                  timeCost: timeCost,
                  buffetCost: buffetCost,
                  orders: orders,
                  menu: menu,
                );
              },
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white),
            ),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final bool green;
  const _BillRow(this.label, this.value, {this.green = false});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            Text(value,
                style: TextStyle(
                    color: green ? const Color(0xFF4ade80) : Colors.white,
                    fontWeight: FontWeight.bold)),
          ]),
    );
  }
}

class _DrinkDaySummaryBar extends StatelessWidget {
  final AppState state;
  const _DrinkDaySummaryBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final todayDrink = state.history
        .where((h) => h['device_type']?.toString() == 'drink_table')
        .toList();

    final double totalRevenue = todayDrink.fold(
        0.0, (s, h) => s + ((h['buffet_cost'] as num?) ?? 0));

    final Map<String, int> itemTotals = {};
    for (final h in todayDrink) {
      final orders = h['orders'] as Map?;
      orders?.forEach((item, qty) {
        itemTotals[item.toString()] =
            (itemTotals[item.toString()] ?? 0) + ((qty as num?)?.toInt() ?? 0);
      });
    }
    final top3 = (itemTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('مبيعات اليوم',
                style: TextStyle(
                    color: Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(
              '${totalRevenue.toStringAsFixed(0)} ج',
              style: const TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text('${todayDrink.length} فاتورة',
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ]),
          if (top3.isNotEmpty) ...[
            const SizedBox(width: 12),
            Container(width: 1, height: 40, color: Colors.white12),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: top3.map((e) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Text('${e.key} ×${e.value}',
                      style: const TextStyle(
                          color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                )).toList(),
              ),
            ),
          ] else
            const Expanded(
              child: Text('  مفيش مبيعات لسه',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _DrinkTableCard extends StatelessWidget {
  final int index;
  const _DrinkTableCard({required this.index});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (index >= state.drinkTables.length) return const SizedBox();
    final t = state.drinkTables[index];
    final Map<String, int> orders =
        Map<String, int>.from(t['orders'] ?? {});
    final int totalItems =
        orders.values.fold(0, (s, q) => s + q);
    double total = 0;
    orders.forEach((item, qty) {
      total += qty * (state.menu[item] ?? 0);
    });

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => DrinkTableScreen(tableIndex: index))),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1c2128),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: totalItems > 0
                ? Colors.orange.withOpacity(0.5)
                : Colors.white12,
            width: totalItems > 0 ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(children: [
              Icon(Icons.local_drink,
                  color: totalItems > 0 ? Colors.orange : Colors.white38,
                  size: 26),
              const SizedBox(height: 6),
              Text(t['name'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              if (totalItems > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$totalItems صنف',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                )
              else
                Text('فاضية',
                    style: TextStyle(
                        color: Colors.white38.withOpacity(0.5),
                        fontSize: 12)),
            ]),
            Column(children: [
              Text(
                '${total.toStringAsFixed(1)} ج',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: total > 0
                      ? const Color(0xFF4ade80)
                      : Colors.white24,
                ),
              ),
              const SizedBox(height: 6),
              if (totalItems > 0) ...[
                Row(children: [
                  Expanded(
                    child: SizedBox(
                      height: 30,
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddOrderDialog(context, state),
                        icon: const Icon(Icons.add, size: 13, color: Colors.orange),
                        label: const Text('إضافة',
                            style: TextStyle(
                                color: Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          side: BorderSide(color: Colors.orange.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: SizedBox(
                      height: 30,
                      child: OutlinedButton.icon(
                        onPressed: () => _showTransferDialogDirect(context, state),
                        icon: const Icon(Icons.swap_horiz, size: 13, color: Colors.white54),
                        label: const Text('نقل',
                            style: TextStyle(color: Colors.white54, fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  height: 30,
                  child: FilledButton.icon(
                    onPressed: () => _confirmCheckout(context, state, total),
                    icon: const Icon(Icons.receipt_long, size: 13),
                    label: const Text('حساب',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: FilledButton.icon(
                    onPressed: () => _showAddOrderDialog(context, state),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('إضافة طلب',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange.withOpacity(0.7),
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  void _showTransferDialogDirect(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.swap_horiz, color: Colors.white70),
          SizedBox(width: 8),
          Text('نقل الطلبات لـ',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.devices.isNotEmpty) ...[
                  const Text('🎮 الأجهزة',
                      style: TextStyle(
                          color: Color(0xFF38bdf8),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const SizedBox(height: 6),
                  ...state.devices.map((d) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.sports_esports,
                        color: d.isActive ? const Color(0xFF38bdf8) : const Color(0xFF4ade80)),
                    title: Text(d.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(d.isActive ? 'شغال' : 'متاح',
                        style: TextStyle(
                            color: d.isActive ? const Color(0xFF38bdf8) : const Color(0xFF4ade80),
                            fontSize: 12)),
                    onTap: () {
                      Navigator.pop(context);
                      if (d.isActive) {
                        state.transferDrinkTableToDevice(index, d);
                      } else {
                        state.transferDrinkTableOrdersOnly(index, d);
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => DeviceTransferStartDialog(
                            isPs5: d.deviceType == 'ps5',
                            targetDeviceName: d.displayName,
                            onConfirm: (mode, seconds) {
                              state.startDevice(d, mode, countdownSeconds: seconds);
                              Navigator.push(context,
                                  MaterialPageRoute(
                                      builder: (_) => DeviceDetailScreen(device: d)));
                            },
                          ),
                        );
                      }
                    },
                  )),
                ],
                if (state.tables.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('🎱 تربيزات بنج / بلياردو',
                      style: TextStyle(
                          color: Color(0xFF34d399),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const SizedBox(height: 6),
                  ...List.generate(state.tables.length, (i) {
                    final t = state.tables[i];
                    final isActive = t['start_time'] != null;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.table_bar,
                          color: isActive ? const Color(0xFF34d399) : Colors.white54),
                      title: Text(t['name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(isActive ? 'شغالة' : 'فاضية',
                          style: TextStyle(
                              color: isActive ? const Color(0xFF34d399) : Colors.white54,
                              fontSize: 12)),
                      onTap: () async {
                        Navigator.pop(context);
                        if (isActive) {
                          state.transferDrinkTableToTable(index, i);
                        } else {
                          await state.transferDrinkTableOrdersToTable(index, i);
                          if (context.mounted) {
                            showDialog(context: context,
                              builder: (_) => TableStartDialog(tableIndex: i));
                          }
                        }
                      },
                    );
                  }),
                ],
                if (state.devices.isEmpty && state.tables.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('مفيش أجهزة أو تربيزات متاحة',
                        style: TextStyle(color: Colors.white38)),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
        ],
      ),
    );
  }

  void _showAddOrderDialog(BuildContext context, AppState state) {
    if (state.menu.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ البوفيه فاضي، أضف منتجات من الإعدادات'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    showBuffetOrderDialog(
      context: context,
      title: state.drinkTables[index]['name']?.toString() ?? 'تربيزة',
      getCurrentOrders: () => Map<String, int>.from(
          state.drinkTables[index]['orders'] ?? {}),
      onOrderChanged: (item, diff) =>
          state.addDrinkTableOrder(index, item, diff),
      accentColor: Colors.orange,
    );
  }

  void _confirmCheckout(
      BuildContext context, AppState state, double total) {
    final t = state.drinkTables[index];
    final Map<String, int> orders =
        Map<String, int>.from(t['orders'] ?? {});
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('حساب ${t['name']}',
            style: const TextStyle(
                color: Colors.orange, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...orders.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${e.key} ×${e.value}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                      Text(
                          '${e.value * (state.menu[e.key] ?? 0)} ج',
                          style:
                              const TextStyle(color: Colors.white)),
                    ],
                  ),
                )),
            const Divider(color: Colors.white12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('💰 الإجمالي',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${total.toStringAsFixed(1)} ج',
                    style: const TextStyle(
                        color: Color(0xFF4ade80),
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              state.checkoutDrinkTable(index);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }
}

// ─── WhatsApp Invoice (نفس منطق table_detail_screen._sendWhatsappInvoice) ────
// عشان ديالوج إنهاء التربيزة في شاشة الكاشير يبقى فيه نفس خيار
// "تأكيد وإرسال" الموجود في شاشة تفاصيل التربيزة.
Future<void> cashierTableLaunchWhatsapp({
  required BuildContext context,
  required String phone,
  required String shopName,
  required String tableName,
  required int elapsed,
  required double timeCost,
  required double buffetCost,
  required Map<String, int> orders,
  required Map<String, int> menu,
}) async {
  final h = elapsed ~/ 3600;
  final m = (elapsed % 3600) ~/ 60;
  final durationStr = h > 0 ? '${h}س ${m}د' : '${m}د';

  final buf = StringBuffer();
  buf.writeln('🎮 *$shopName*');
  buf.writeln('─────────────────');
  buf.writeln('📍 *$tableName*');
  buf.writeln('');
  buf.writeln('⏱ *مدة اللعب:* $durationStr');
  buf.writeln('💵 *حساب الوقت:* ${timeCost.toStringAsFixed(1)} ج');

  if (orders.isNotEmpty) {
    buf.writeln('');
    buf.writeln('🥤 *الأصناف والمشروبات:*');
    orders.forEach((item, qty) {
      final price = (menu[item] ?? 0) * qty;
      buf.writeln('  • $item × $qty = ${price.toStringAsFixed(1)} ج');
    });
    buf.writeln('💵 *إجمالي المشروبات:* ${buffetCost.toStringAsFixed(1)} ج');
  }

  buf.writeln('');
  buf.writeln('─────────────────');
  buf.writeln('💰 *المطلوب: ${(timeCost + buffetCost).toStringAsFixed(1)} ج*');
  buf.writeln('');
  buf.writeln('🌟 نورتونا، يارب تعود تاني! 🌟');

  final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
  final intlPhone = cleanPhone.startsWith('0') ? '2$cleanPhone' : cleanPhone;
  final encoded = Uri.encodeComponent(buf.toString());
  final uri = Uri.parse('https://wa.me/$intlPhone?text=$encoded');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر فتح واتساب'), backgroundColor: Colors.red),
    );
  }
}
