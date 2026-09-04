import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0b0e14),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0b0e14),
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2, color: Colors.teal, size: 20),
              SizedBox(width: 8),
              Text('المخزن',
                  style: TextStyle(
                      color: Colors.teal, fontWeight: FontWeight.bold)),
            ],
          ),
          leading: const BackButton(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Colors.teal,
            labelColor: Colors.teal,
            unselectedLabelColor: Colors.white38,
            labelStyle:
                TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            tabs: [
              Tab(icon: Icon(Icons.warehouse, size: 18), text: 'المخزون'),
              Tab(icon: Icon(Icons.bar_chart, size: 18), text: 'ملخص اليوم'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _StockTab(),
            _DailySummaryTab(),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1 — المخزون
// ═══════════════════════════════════════════════════════════════════════════════

class _StockTab extends StatelessWidget {
  const _StockTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final inventory = state.inventory; // Map<String, int>  item → qty
    final menu = state.menu;

    // أصناف موجودة في المنيو
    final menuItems = menu.keys.toList();

    // إجمالي قيمة المخزون
    double totalValue = 0;
    inventory.forEach((item, qty) {
      totalValue += qty * (menu[item] ?? 0);
    });

    return Column(
      children: [
        // ─── بار الإجمالي ───────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1c2128),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.teal.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatChip(
                icon: Icons.category,
                label: 'أصناف',
                value: '${inventory.length}',
                color: Colors.teal,
              ),
              Container(width: 1, height: 36, color: Colors.white12),
              _StatChip(
                icon: Icons.inventory,
                label: 'إجمالي قطع',
                value: '${inventory.values.fold(0, (s, v) => s + v)}',
                color: const Color(0xFF38bdf8),
              ),
              Container(width: 1, height: 36, color: Colors.white12),
              _StatChip(
                icon: Icons.attach_money,
                label: 'قيمة المخزون',
                value: '${totalValue.toStringAsFixed(0)} ج',
                color: const Color(0xFF4ade80),
              ),
            ],
          ),
        ),

        // ─── قائمة الأصناف ──────────────────────────────────────────────
        Expanded(
          child: menuItems.isEmpty
              ? const _EmptyMenuHint()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: menuItems.length,
                  itemBuilder: (ctx, i) {
                    final item = menuItems[i];
                    final qty = inventory[item] ?? 0;
                    final price = menu[item] ?? 0;
                    return _StockItemTile(
                      item: item,
                      qty: qty,
                      price: price,
                      onAdd: () => _showAddStockDialog(context, state, item, qty),
                      onReset: () => _confirmReset(context, state, item),
                    );
                  },
                ),
        ),

        // ─── زرار إضافة دفعة كاملة ──────────────────────────────────────
        if (menuItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _showBulkAddDialog(context, state),
                icon: const Icon(Icons.add_shopping_cart, color: Colors.teal),
                label: const Text('إضافة دفعة لكل الأصناف',
                    style: TextStyle(color: Colors.teal, fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.teal),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showAddStockDialog(
      BuildContext context, AppState state, String item, int current) {
    final ctrl = TextEditingController();
    final price = state.menu[item] ?? 0;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.add_box, color: Colors.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Text('إضافة مخزون - $item',
                style: const TextStyle(
                    color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الكمية الحالية:',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
                Text('$current قطعة',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            autofocus: true,
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'الكمية المضافة',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 16),
              suffixText: 'قطعة',
              suffixStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF0b0e14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.teal, width: 2)),
            ),
          ),
          const SizedBox(height: 8),
          Text('سعر الوحدة: $price ج',
              style:
                  const TextStyle(color: Colors.white38, fontSize: 12)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(ctrl.text.trim());
              if (val != null && val > 0) {
                state.addInventory(item, val);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('✅ تم إضافة $val قطعة لـ $item'),
                  backgroundColor: Colors.teal,
                  duration: const Duration(seconds: 2),
                ));
              }
            },
            style: FilledButton.styleFrom(
                backgroundColor: Colors.teal, foregroundColor: Colors.black),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, AppState state, String item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تصفير المخزون؟',
            style: TextStyle(color: Colors.red)),
        content: Text('هيتم تصفير كمية "$item" في المخزون',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              state.resetInventoryItem(item);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('تصفير'),
          ),
        ],
      ),
    );
  }

  void _showBulkAddDialog(BuildContext context, AppState state) {
    final menu = state.menu;
    final controllers = <String, TextEditingController>{};
    for (final item in menu.keys) {
      controllers[item] = TextEditingController();
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.add_shopping_cart, color: Colors.teal),
          SizedBox(width: 8),
          Text('إضافة دفعة',
              style: TextStyle(
                  color: Colors.teal, fontWeight: FontWeight.bold)),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: menu.keys.map((item) {
                final current = state.inventory[item] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            Text('متاح: $current',
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11)),
                          ]),
                    ),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: controllers[item],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        decoration: InputDecoration(
                          hintText: '+0',
                          hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.25),
                              fontSize: 14),
                          filled: true,
                          fillColor: const Color(0xFF0b0e14),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Colors.white12)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Colors.white12)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Colors.teal, width: 2)),
                        ),
                      ),
                    ),
                  ]),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              bool added = false;
              controllers.forEach((item, ctrl) {
                final val = int.tryParse(ctrl.text.trim());
                if (val != null && val > 0) {
                  state.addInventory(item, val);
                  added = true;
                }
              });
              Navigator.pop(context);
              if (added) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('✅ تم تحديث المخزون'),
                  backgroundColor: Colors.teal,
                  duration: Duration(seconds: 2),
                ));
              }
            },
            style: FilledButton.styleFrom(
                backgroundColor: Colors.teal, foregroundColor: Colors.black),
            child: const Text('حفظ الكل'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2 — ملخص اليوم
// ═══════════════════════════════════════════════════════════════════════════════

class _DailySummaryTab extends StatelessWidget {
  const _DailySummaryTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final summary = state.dailyInventorySummary; // Map<String, int>  item → totalSold
    final menu = state.menu;

    if (summary.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.white12),
            SizedBox(height: 16),
            Text('لا يوجد مبيعات اليوم',
                style: TextStyle(color: Colors.white38, fontSize: 16)),
            SizedBox(height: 6),
            Text('هيتحدث تلقائياً لما يتباع حاجة من البوفيه',
                style: TextStyle(color: Colors.white24, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    // احسب الإجماليات
    double totalRevenue = 0;
    int totalQty = 0;
    summary.forEach((item, qty) {
      totalRevenue += qty * (menu[item] ?? 0);
      totalQty += qty;
    });

    // رتّب من الأعلى مبيعاً للأقل
    final sorted = summary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        // ─── بار الإجماليات ─────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.teal.withOpacity(0.15),
                Colors.green.withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.teal.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.today, color: Colors.teal, size: 18),
                const SizedBox(width: 6),
                Text(
                  'ملخص ${_todayLabel()}',
                  style: const TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ]),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatChip(
                    icon: Icons.shopping_bag,
                    label: 'إجمالي قطع',
                    value: '$totalQty',
                    color: const Color(0xFF38bdf8),
                  ),
                  Container(width: 1, height: 36, color: Colors.white12),
                  _StatChip(
                    icon: Icons.payments_outlined,
                    label: 'إيرادات البوفيه',
                    value: '${totalRevenue.toStringAsFixed(0)} ج',
                    color: const Color(0xFF4ade80),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ─── قائمة المبيعات ─────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: sorted.length,
            itemBuilder: (ctx, i) {
              final entry = sorted[i];
              final item = entry.key;
              final soldQty = entry.value;
              final price = menu[item] ?? 0;
              final revenue = soldQty * price;
              final remaining = state.inventory[item] ?? 0;

              // نسبة الشريط (نسبة هذا الصنف من إجمالي المبيعات)
              final ratio = totalQty > 0 ? soldQty / totalQty : 0.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1c2128),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      // رقم الترتيب
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: i == 0
                              ? Colors.amber.withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: i == 0
                                ? Colors.amber
                                : Colors.white12,
                          ),
                        ),
                        child: Center(
                          child: Text('${i + 1}',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: i == 0
                                      ? Colors.amber
                                      : Colors.white38)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(item,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                      ),
                      // الكمية المباعة
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.teal.withOpacity(0.4)),
                        ),
                        child: Text('$soldQty قطعة',
                            style: const TextStyle(
                                color: Colors.teal,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ),
                    ]),
                    const SizedBox(height: 8),

                    // شريط التقدم
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio.toDouble(),
                        minHeight: 5,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          i == 0 ? Colors.amber : Colors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _MiniInfo('💰 إيراد', '${revenue} ج',
                            const Color(0xFF4ade80)),
                        _MiniInfo('📦 متبقي', '$remaining قطعة',
                            remaining <= 3
                                ? Colors.red
                                : Colors.white54),
                        _MiniInfo('💵 سعر الوحدة', '$price ج',
                            Colors.white38),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // ─── زرار تصفير ملخص اليوم ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () => _confirmResetDaily(context, state),
              icon: const Icon(Icons.refresh, color: Colors.white38),
              label: const Text('تصفير ملخص اليوم',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year}';
  }

  void _confirmResetDaily(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تصفير ملخص اليوم؟',
            style: TextStyle(color: Colors.red)),
        content: const Text(
            'هيتم تصفير ملخص المبيعات اليومي فقط، المخزون هيفضل زي ما هو',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              state.resetDailySummary();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('تصفير'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared Widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _StockItemTile extends StatelessWidget {
  final String item;
  final int qty;
  final int price;
  final VoidCallback onAdd;
  final VoidCallback onReset;

  const _StockItemTile({
    required this.item,
    required this.qty,
    required this.price,
    required this.onAdd,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    // تحديد اللون حسب الكمية
    Color stockColor;
    String stockLabel;
    IconData stockIcon;

    if (qty == 0) {
      stockColor = Colors.red;
      stockLabel = 'نفد!';
      stockIcon = Icons.warning_amber_rounded;
    } else if (qty <= 3) {
      stockColor = Colors.orange;
      stockLabel = 'قليل';
      stockIcon = Icons.warning_outlined;
    } else {
      stockColor = const Color(0xFF4ade80);
      stockLabel = 'متاح';
      stockIcon = Icons.check_circle_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: qty == 0
                ? Colors.red.withOpacity(0.4)
                : Colors.white10,
            width: qty == 0 ? 1.5 : 1),
      ),
      child: Row(children: [
        // أيقونة الحالة
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: stockColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(stockIcon, color: stockColor, size: 22),
        ),
        const SizedBox(width: 12),
        // معلومات الصنف
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 2),
              Row(children: [
                Text('$price ج/وحدة',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: stockColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(stockLabel,
                      style: TextStyle(
                          color: stockColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ]),
            ],
          ),
        ),
        // الكمية
        Column(children: [
          Text('$qty',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: stockColor)),
          const Text('قطعة',
              style: TextStyle(color: Colors.white38, fontSize: 10)),
        ]),
        const SizedBox(width: 8),
        // أزرار
        Column(children: [
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.teal.withOpacity(0.4)),
              ),
              child: const Icon(Icons.add, color: Colors.teal, size: 18),
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onReset,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.red.withOpacity(0.25)),
              ),
              child:
                  const Icon(Icons.refresh, color: Colors.red, size: 18),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 4),
      Text(label,
          style: const TextStyle(color: Colors.white38, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value,
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14)),
    ]);
  }
}

class _MiniInfo extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniInfo(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text(label,
          style: const TextStyle(color: Colors.white24, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value,
          style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold)),
    ]);
  }
}

class _EmptyMenuHint extends StatelessWidget {
  const _EmptyMenuHint();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fastfood, size: 64, color: Colors.white12),
          SizedBox(height: 16),
          Text('البوفيه فاضي!',
              style: TextStyle(color: Colors.white38, fontSize: 16)),
          SizedBox(height: 6),
          Text('أضف منتجات في إعدادات البوفيه الأول',
              style: TextStyle(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }
}
