// lib/widgets/buffet_order_dialog.dart
//
// Dialog الطلب من البوفيه مع نظام الأقسام
// ══════════════════════════════════════════════════════════════════════════════
//
// الاستخدام:
//   showBuffetOrderDialog(
//     context: context,
//     title: 'بوفيه PS4 - 1',
//     getCurrentOrders: () => device.orders,        // أو table orders
//     onOrderChanged: (item, diff) => state.addOrder(device, item, diff),
//   );
//
// يعمل مع: الأجهزة، التربيزات، تربيزات المشروبات

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/buffet_category.dart';

// ─── Entry Point ─────────────────────────────────────────────────────────────

Future<void> showBuffetOrderDialog({
  required BuildContext context,
  required String title,
  required Map<String, int> Function() getCurrentOrders,
  required String? Function(String item, int diff) onOrderChanged,
  Color accentColor = Colors.orange,
}) async {
  await showDialog(
    context: context,
    builder: (_) => _BuffetOrderDialog(
      title: title,
      getCurrentOrders: getCurrentOrders,
      onOrderChanged: onOrderChanged,
      accentColor: accentColor,
    ),
  );
}

// ─── Main Dialog ─────────────────────────────────────────────────────────────

class _BuffetOrderDialog extends StatefulWidget {
  final String title;
  final Map<String, int> Function() getCurrentOrders;
  final String? Function(String, int) onOrderChanged;
  final Color accentColor;

  const _BuffetOrderDialog({
    required this.title,
    required this.getCurrentOrders,
    required this.onOrderChanged,
    required this.accentColor,
  });

  @override
  State<_BuffetOrderDialog> createState() => _BuffetOrderDialogState();
}

class _BuffetOrderDialogState extends State<_BuffetOrderDialog>
    with TickerProviderStateMixin {
  String? _selectedCategoryId; // null = شاشة الأقسام، قيمة = داخل قسم
  late Map<String, int> _tempOrders;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _tempOrders = Map<String, int>.from(widget.getCurrentOrders());
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  void _selectCategory(String catId) {
    setState(() => _selectedCategoryId = catId);
    _slideCtrl.forward(from: 0);
  }

  void _backToCategories() {
    setState(() => _selectedCategoryId = null);
  }

  void _increment(AppState state, String item) {
    final available = state.inventory[item];
    final current = _tempOrders[item] ?? 0;
    if (available != null && current >= available) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('⚠️ الكمية المتاحة من "$item" هي $available فقط!'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    setState(() => _tempOrders[item] = current + 1);
  }

  void _decrement(String item) {
    final current = _tempOrders[item] ?? 0;
    setState(() {
      if (current <= 1) _tempOrders.remove(item);
      else _tempOrders[item] = current - 1;
    });
  }

  void _confirm(AppState state) {
    final original = widget.getCurrentOrders();
    final errors = <String>[];

    for (final entry in state.menu.entries) {
      final item = entry.key;
      final newQty = _tempOrders[item] ?? 0;
      final oldQty = original[item] ?? 0;
      final diff = newQty - oldQty;
      if (diff == 0) continue;
      final err = widget.onOrderChanged(item, diff);
      if (err != null) errors.add(err);
    }

    Navigator.pop(context);
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('⚠️ ${errors.first}'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  double get _tempTotal {
    double t = 0;
    final state = context.read<AppState>();
    _tempOrders.forEach((item, qty) => t += qty * (state.menu[item] ?? 0));
    return t;
  }

  int get _tempItemCount => _tempOrders.values.fold(0, (s, v) => s + v);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final categories = state.buffetCategories;
    final menu = state.menu;

    // لو مفيش أقسام نعرض البوفيه كاملاً مباشرة
    if (categories.isEmpty) {
      return _FlatOrderDialog(
        title: widget.title,
        accentColor: widget.accentColor,
        tempOrders: _tempOrders,
        menu: menu,
        inventory: state.inventory,
        onIncrement: (item) => _increment(state, item),
        onDecrement: _decrement,
        onConfirm: () => _confirm(state),
        tempTotal: _tempTotal,
      );
    }

    return Dialog(
      backgroundColor: const Color(0xFF1c2128),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Header ─────────────────────────────────────────────────────
          _DialogHeader(
            title: widget.title,
            selectedCategoryId: _selectedCategoryId,
            categories: categories,
            tempItemCount: _tempItemCount,
            tempTotal: _tempTotal,
            accentColor: widget.accentColor,
            onBack: _backToCategories,
            onClose: () => Navigator.pop(context),
          ),

          const Divider(color: Colors.white12, height: 1),

          // ── Content (Categories Grid OR Items List) ────────────────────
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _selectedCategoryId == null
                  // شاشة الأقسام
                  ? _CategoriesGrid(
                      key: const ValueKey('cats'),
                      categories: categories,
                      menu: menu,
                      tempOrders: _tempOrders,
                      menuItemCategory: state.menuItemCategory,
                      onSelect: _selectCategory,
                    )
                  // شاشة أصناف القسم
                  : SlideTransition(
                      position: _slideAnim,
                      child: _ItemsInCategory(
                        key: ValueKey(_selectedCategoryId),
                        categoryId: _selectedCategoryId!,
                        categories: categories,
                        menu: menu,
                        inventory: state.inventory,
                        tempOrders: _tempOrders,
                        menuItemCategory: state.menuItemCategory,
                        onIncrement: (item) => _increment(state, item),
                        onDecrement: _decrement,
                        accentColor: widget.accentColor,
                      ),
                    ),
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // ── Footer ─────────────────────────────────────────────────────
          _DialogFooter(
            tempTotal: _tempTotal,
            tempItemCount: _tempItemCount,
            accentColor: widget.accentColor,
            onConfirm: () => _confirm(state),
          ),
        ]),
      ),
    );
  }
}

// ─── Dialog Header ────────────────────────────────────────────────────────────

class _DialogHeader extends StatelessWidget {
  final String title;
  final String? selectedCategoryId;
  final List<BuffetCategory> categories;
  final int tempItemCount;
  final double tempTotal;
  final Color accentColor;
  final VoidCallback onBack;
  final VoidCallback onClose;

  const _DialogHeader({
    required this.title,
    required this.selectedCategoryId,
    required this.categories,
    required this.tempItemCount,
    required this.tempTotal,
    required this.accentColor,
    required this.onBack,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cat = selectedCategoryId != null
        ? categories.firstWhere((c) => c.id == selectedCategoryId,
            orElse: () => BuffetCategory(id: '', name: ''))
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
      child: Row(children: [
        // زرار رجوع (لو داخل قسم)
        if (selectedCategoryId != null)
          GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70, size: 16),
            ),
          )
        else
          const Icon(Icons.fastfood, color: Colors.orange, size: 22),
        const SizedBox(width: 10),

        // العنوان
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              cat != null ? '${cat.emoji} ${cat.name}' : 'بوفيه',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            Text(
              title,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ]),
        ),

        // Badge الطلبات
        if (tempItemCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withOpacity(0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.shopping_bag_outlined, color: Colors.orange, size: 13),
              const SizedBox(width: 4),
              Text(
                '$tempItemCount | ${tempTotal.toStringAsFixed(1)} ج',
                style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ]),
          ),

        const SizedBox(width: 8),
        GestureDetector(
          onTap: onClose,
          child: const Icon(Icons.close, color: Colors.white38, size: 22),
        ),
      ]),
    );
  }
}

// ─── Categories Grid ──────────────────────────────────────────────────────────

class _CategoriesGrid extends StatelessWidget {
  final List<BuffetCategory> categories;
  final Map<String, int> menu;
  final Map<String, int> tempOrders;
  final String? Function(String) menuItemCategory;
  final void Function(String) onSelect;

  const _CategoriesGrid({
    super.key,
    required this.categories,
    required this.menu,
    required this.tempOrders,
    required this.menuItemCategory,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: categories.length,
      itemBuilder: (ctx, i) {
        final cat = categories[i];
        // أصناف هذا القسم
        final catItems = menu.keys
            .where((k) => menuItemCategory(k) == cat.id)
            .toList();
        // الكمية المطلوبة من هذا القسم
        int catQty = 0;
        for (final item in catItems) {
          catQty += tempOrders[item] ?? 0;
        }

        return _CategoryCard(
          category: cat,
          itemCount: catItems.length,
          orderedQty: catQty,
          onTap: () => onSelect(cat.id),
        );
      },
    );
  }
}

// ─── Category Card ────────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final BuffetCategory category;
  final int itemCount;
  final int orderedQty;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.itemCount,
    required this.orderedQty,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasOrder = orderedQty > 0;
    final isEmpty = itemCount == 0;

    return GestureDetector(
      onTap: isEmpty ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasOrder
              ? Colors.orange.withOpacity(0.12)
              : const Color(0xFF0b0e14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasOrder
                ? Colors.orange.withOpacity(0.6)
                : isEmpty
                    ? Colors.white.withOpacity(0.05)
                    : Colors.white.withOpacity(0.1),
            width: hasOrder ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(
                category.emoji,
                style: TextStyle(
                  fontSize: 28,
                  color: isEmpty ? null : null,
                ),
              ),
              const Spacer(),
              // Badge الطلبات
              if (hasOrder)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$orderedQty',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 6),
            Text(
              category.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isEmpty ? Colors.white24 : Colors.white,
              ),
            ),
            Text(
              isEmpty ? 'فاضي' : '$itemCount صنف',
              style: TextStyle(
                fontSize: 11,
                color: isEmpty ? Colors.white12 : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Items In Category ────────────────────────────────────────────────────────

class _ItemsInCategory extends StatelessWidget {
  final String categoryId;
  final List<BuffetCategory> categories;
  final Map<String, int> menu;
  final Map<String, int> inventory;
  final Map<String, int> tempOrders;
  final String? Function(String) menuItemCategory;
  final void Function(String) onIncrement;
  final void Function(String) onDecrement;
  final Color accentColor;

  const _ItemsInCategory({
    super.key,
    required this.categoryId,
    required this.categories,
    required this.menu,
    required this.inventory,
    required this.tempOrders,
    required this.menuItemCategory,
    required this.onIncrement,
    required this.onDecrement,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final items = menu.keys
        .where((k) => menuItemCategory(k) == categoryId)
        .toList();

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.white12),
            SizedBox(height: 12),
            Text('لا يوجد أصناف في هذا القسم',
                style: TextStyle(color: Colors.white38, fontSize: 14)),
          ]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        final price = menu[item] ?? 0;
        final qty = tempOrders[item] ?? 0;
        final stock = inventory[item];
        final outOfStock = stock != null && stock <= 0;
        final lowStock = stock != null && stock > 0 && stock <= 3;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: qty > 0
                ? Colors.orange.withOpacity(0.08)
                : const Color(0xFF0b0e14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: qty > 0
                  ? Colors.orange.withOpacity(0.4)
                  : outOfStock
                      ? Colors.red.withOpacity(0.2)
                      : Colors.white.withOpacity(0.07),
            ),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: outOfStock ? Colors.white38 : Colors.white,
                    )),
                const SizedBox(height: 2),
                Row(children: [
                  Text('$price ج',
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  if (stock != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: outOfStock
                            ? Colors.red.withOpacity(0.15)
                            : lowStock
                                ? Colors.orange.withOpacity(0.15)
                                : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        outOfStock ? 'نفد!' : 'متاح: $stock',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: outOfStock
                              ? Colors.red
                              : lowStock
                                  ? Colors.orange
                                  : Colors.white38,
                        ),
                      ),
                    ),
                  ],
                ]),
              ]),
            ),

            // أزرار الكمية
            Row(mainAxisSize: MainAxisSize.min, children: [
              // زر ناقص
              GestureDetector(
                onTap: qty > 0 ? () => onDecrement(item) : null,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: qty > 0 ? Colors.red.withOpacity(0.12) : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: qty > 0 ? Colors.red.withOpacity(0.4) : Colors.white12,
                    ),
                  ),
                  child: Icon(Icons.remove, size: 18,
                      color: qty > 0 ? Colors.red : Colors.white24),
                ),
              ),

              // الكمية
              SizedBox(
                width: 40,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Text(
                    '$qty',
                    key: ValueKey(qty),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: qty > 0 ? Colors.orange : Colors.white38,
                    ),
                  ),
                ),
              ),

              // زر زائد
              GestureDetector(
                onTap: outOfStock ? null : () => onIncrement(item),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: outOfStock
                        ? Colors.white.withOpacity(0.04)
                        : const Color(0xFF4ade80).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: outOfStock
                          ? Colors.white12
                          : const Color(0xFF4ade80).withOpacity(0.4),
                    ),
                  ),
                  child: Icon(Icons.add, size: 18,
                      color: outOfStock ? Colors.white24 : const Color(0xFF4ade80)),
                ),
              ),
            ]),
          ]),
        );
      },
    );
  }
}

// ─── Dialog Footer ────────────────────────────────────────────────────────────

class _DialogFooter extends StatelessWidget {
  final double tempTotal;
  final int tempItemCount;
  final Color accentColor;
  final VoidCallback onConfirm;

  const _DialogFooter({
    required this.tempTotal,
    required this.tempItemCount,
    required this.accentColor,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(children: [
        // إجمالي
        if (tempItemCount > 0) ...[
          const Icon(Icons.shopping_bag_outlined, color: Colors.orange, size: 18),
          const SizedBox(width: 6),
          Text(
            '${tempTotal.toStringAsFixed(1)} ج',
            style: const TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ] else
          const Text('لم يتم اختيار أي صنف',
              style: TextStyle(color: Colors.white38, fontSize: 12)),

        const Spacer(),

        // زرار إلغاء
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
        ),
        const SizedBox(width: 6),

        // زرار تأكيد
        FilledButton.icon(
          onPressed: onConfirm,
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: Text(
            tempItemCount > 0
                ? 'تأكيد ($tempItemCount صنف)'
                : 'تأكيد',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
    );
  }
}

// ─── Flat Dialog (fallback بدون أقسام) ───────────────────────────────────────

class _FlatOrderDialog extends StatelessWidget {
  final String title;
  final Color accentColor;
  final Map<String, int> tempOrders;
  final Map<String, int> menu;
  final Map<String, int> inventory;
  final void Function(String) onIncrement;
  final void Function(String) onDecrement;
  final VoidCallback onConfirm;
  final double tempTotal;

  const _FlatOrderDialog({
    required this.title,
    required this.accentColor,
    required this.tempOrders,
    required this.menu,
    required this.inventory,
    required this.onIncrement,
    required this.onDecrement,
    required this.onConfirm,
    required this.tempTotal,
  });

  @override
  Widget build(BuildContext context) {
    if (menu.isEmpty) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.fastfood, color: Colors.orange),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        ]),
        content: const Text('البوفيه فاضي، أضف منتجات من الإعدادات.',
            style: TextStyle(color: Colors.white54)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('تمام', style: TextStyle(color: Colors.black)),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF1c2128),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.zero,
      title: Row(children: [
        const Icon(Icons.fastfood, color: Colors.orange),
        const SizedBox(width: 8),
        Expanded(child: Text(title,
            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 15))),
        if (tempTotal > 0)
          Text('${tempTotal.toStringAsFixed(1)} ج',
              style: const TextStyle(color: Color(0xFF4ade80), fontWeight: FontWeight.bold, fontSize: 14)),
      ]),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: menu.entries.map((e) {
            final item = e.key;
            final price = e.value;
            final qty = tempOrders[item] ?? 0;
            final stock = inventory[item];
            final outOfStock = stock != null && stock <= 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: qty > 0 ? Colors.orange.withOpacity(0.08) : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: qty > 0 ? Colors.orange.withOpacity(0.4) : Colors.white12),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                      color: outOfStock ? Colors.white38 : Colors.white)),
                  Text('$price ج', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ])),
                GestureDetector(
                  onTap: qty > 0 ? () => onDecrement(item) : null,
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: qty > 0 ? Colors.red.withOpacity(0.12) : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: qty > 0 ? Colors.red.withOpacity(0.4) : Colors.white12),
                    ),
                    child: Icon(Icons.remove, size: 16, color: qty > 0 ? Colors.red : Colors.white24),
                  ),
                ),
                SizedBox(width: 32,
                  child: Text('$qty', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                          color: qty > 0 ? Colors.orange : Colors.white38))),
                GestureDetector(
                  onTap: outOfStock ? null : () => onIncrement(item),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: outOfStock ? Colors.white.withOpacity(0.04) : const Color(0xFF4ade80).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: outOfStock ? Colors.white12 : const Color(0xFF4ade80).withOpacity(0.4)),
                    ),
                    child: Icon(Icons.add, size: 16, color: outOfStock ? Colors.white24 : const Color(0xFF4ade80)),
                  ),
                ),
              ]),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
        FilledButton(
          onPressed: onConfirm,
          style: FilledButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.black),
          child: const Text('تأكيد', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
