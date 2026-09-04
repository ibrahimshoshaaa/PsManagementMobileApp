import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/device.dart';
import 'qr_screen.dart';
import '../widgets/buffet_order_dialog.dart';
import 'device_detail_screen.dart';
import '../widgets/device_transfer_start_dialog.dart';
import '../widgets/table_transfer_start_dialog.dart';

class DrinkTableScreen extends StatelessWidget {
  final int tableIndex;
  const DrinkTableScreen({super.key, required this.tableIndex});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (tableIndex >= state.drinkTables.length) {
      return const Scaffold(
          body: Center(child: Text('تربيزة مش موجودة')));
    }
    final t = state.drinkTables[tableIndex];
    final Map<String, int> orders =
        Map<String, int>.from(t['orders'] ?? {});
    double total = 0;
    orders.forEach(
        (item, qty) => total += qty * (state.menu[item] ?? 0));

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: const Text('مشروبات',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Text(t['name'] ?? '',
              style: const TextStyle(
                  color: Colors.orange, fontWeight: FontWeight.bold)),
        ]),
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code, color: Colors.white54, size: 26),
            tooltip: 'QR Code',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QrScreen(drinkTableIndex: tableIndex),
              ),
            ),
          ),
          if (orders.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.swap_horiz, color: Colors.white70),
              tooltip: 'نقل الطلبات',
              onPressed: () => _showTransferDialog(context, state),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── إجمالي ───────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1c2128),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('💰 الإجمالي',
                    style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                Text('${total.toStringAsFixed(1)} ج',
                    style: const TextStyle(
                        color: Color(0xFF4ade80),
                        fontWeight: FontWeight.bold,
                        fontSize: 22)),
              ],
            ),
          ),

          // ── الطلبات الحالية كـ chips ──────────────────────────────────
          if (orders.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1c2128),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.receipt_long, color: Colors.orange, size: 16),
                      SizedBox(width: 6),
                      Text('الطلبات الحالية',
                          style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ]),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: orders.entries.map((e) {
                        final price = state.menu[e.key] ?? 0;
                        return GestureDetector(
                          onTap: () => state.addDrinkTableOrder(
                              tableIndex, e.key, -1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.orange.withOpacity(0.4)),
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
                    const SizedBox(height: 6),
                    const Text(
                      'اضغط على الصنف لإزالة واحدة',
                      style: TextStyle(color: Colors.white24, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // ── زرار إضافة طلب ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: state.menu.isEmpty
                  ? const Center(
                      child: Text('البوفيه فاضي، أضف منتجات من الإعدادات',
                          style: TextStyle(color: Colors.white38)))
                  : OutlinedButton.icon(
                      onPressed: () => _showAddOrderDialog(context, state, orders),
                      icon: const Icon(Icons.add_shopping_cart,
                          color: Colors.orange, size: 18),
                      label: Text(
                        orders.isNotEmpty ? 'إضافة المزيد' : 'إضافة طلب',
                        style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
            ),
          ),

          const Spacer(),

          // ── أزرار الحساب والنقل ───────────────────────────────────────
          if (orders.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showTransferDialog(context, state),
                      icon: const Icon(Icons.swap_horiz,
                          color: Colors.white70),
                      label: const Text('نقل',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 15)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () =>
                          _confirmCheckout(context, state, total, orders),
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('حساب وتصفير',
                          style: TextStyle(fontSize: 15)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  void _showAddOrderDialog(BuildContext context, AppState state,
      Map<String, int> currentOrders) {
    showBuffetOrderDialog(
      context: context,
      title: state.drinkTables[tableIndex]['name']?.toString() ?? 'تربيزة',
      getCurrentOrders: () => Map<String, int>.from(
          state.drinkTables[tableIndex]['orders'] ?? {}),
      onOrderChanged: (item, diff) =>
          state.addDrinkTableOrder(tableIndex, item, diff),
      accentColor: Colors.orange,
    );
  }

  void _showTransferDialog(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.swap_horiz, color: Colors.white70),
          SizedBox(width: 8),
          Text('نقل الطلبات لـ',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
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
                  ...state.devices.map((d) => _TransferTile(
                        label: d.displayName,
                        sub: d.isActive ? 'شغال - ${d.timerText}' : 'متاح',
                        color: d.isActive
                            ? const Color(0xFF38bdf8)
                            : const Color(0xFF4ade80),
                        icon: Icons.sports_esports,
                       onTap: () {
  if (d.isActive) {
    // الجهاز شغال → نقل مباشر كالعادة
    Navigator.pop(context);
    Navigator.pop(context);
    state.transferDrinkTableToDevice(tableIndex, d);
  } else {
    // الجهاز مش شغال → اعرض دايلوج الإعدادات الأول
    Navigator.pop(context); // أغلق دايلوج النقل
    Navigator.pop(context); // أغلق شاشة التربيزة
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeviceTransferStartDialog(
        isPs5: d.deviceType == 'ps5',
        targetDeviceName: d.displayName,
        onConfirm: (mode, seconds) {
          // 1) شغّل الجهاز بالإعدادات اللي اختارها
          state.startDevice(d, mode, countdownSeconds: seconds);
          // 2) انقل الطلبات للجهاز
          state.transferDrinkTableOrdersOnly(tableIndex, d);
          // 3) روح لشاشة تفاصيل الجهاز
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => DeviceDetailScreen(device: d),
          ));
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
                    return _TransferTile(
                      label: t['name'] ?? '',
                      sub: isActive ? 'شغالة' : 'فاضية',
                      color: isActive
                          ? const Color(0xFF34d399)
                          : Colors.white54,
                      icon: Icons.table_bar,
                    onTap: () {
  if (isActive) {
    // التربيزة شغالة → نقل مباشر كالعادة
    Navigator.pop(context);
    Navigator.pop(context);
    state.transferDrinkTableToTable(tableIndex, i);
  } else {
    // التربيزة مش شغالة → دايلوج البدء الأول
    Navigator.pop(context); // أغلق دايلوج النقل
    Navigator.pop(context); // أغلق شاشة التربيزة
    final tableData = state.tables[i];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => TableTransferStartDialog(
        tableType: tableData['table_type']?.toString() ?? 'ping',
        tableName: tableData['name']?.toString() ?? '',
        ratePerHour: (tableData['rate'] as num?)?.toInt() ?? 0,
        gamePrice: (tableData['game_price'] as num?)?.toInt(),
        onConfirm: (playMode, countdownSeconds, customRate) async {
          // 1) انقل الطلبات للتربيزة
          await state.transferDrinkTableOrdersToTable(tableIndex, i);
          // 2) شغّل التربيزة بالإعدادات اللي اختارها
          state.startTable(i,
            playMode: playMode,
            countdownSeconds: countdownSeconds,
            customRate: customRate,
          );
        },
      ),
    );
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

  void _confirmCheckout(BuildContext context, AppState state,
      double total, Map<String, int> orders) {
    final t = state.drinkTables[tableIndex];
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${e.key} ×${e.value}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                        Text(
                            '${e.value * (state.menu[e.key] ?? 0)} ج',
                            style: const TextStyle(color: Colors.white)),
                      ]),
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
              state.checkoutDrinkTable(tableIndex);
              Navigator.pop(context);
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

// ─── Transfer Tile ────────────────────────────────────────────────────────────

class _TransferTile extends StatelessWidget {
  final String label;
  final String sub;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _TransferTile({
    required this.label,
    required this.sub,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(sub,
                      style: TextStyle(color: color, fontSize: 12)),
                ]),
          ),
          Icon(Icons.arrow_forward_ios, color: color, size: 14),
        ]),
      ),
    );
  }
}
