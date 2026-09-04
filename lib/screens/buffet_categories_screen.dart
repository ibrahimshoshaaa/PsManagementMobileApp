// lib/screens/buffet_categories_screen.dart
//
// شاشة إدارة أقسام البوفيه — للأدمن فقط
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/buffet_category.dart';

class BuffetCategoriesScreen extends StatelessWidget {
  const BuffetCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final categories = state.buffetCategories;

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.category, color: Colors.orange, size: 20),
          SizedBox(width: 8),
          Text('أقسام البوفيه',
              style: TextStyle(
                  color: Colors.orange, fontWeight: FontWeight.bold)),
        ]),
        leading: const BackButton(color: Colors.white),
        actions: [
          // زرار استعادة الأقسام الافتراضية
          IconButton(
            icon: const Icon(Icons.restore, color: Colors.white38),
            tooltip: 'استعادة الأقسام الافتراضية',
            onPressed: () => _confirmRestoreDefaults(context, state),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.orange, size: 28),
            tooltip: 'إضافة قسم',
            onPressed: () => _showAddDialog(context, state),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── بانر توضيحي ─────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1c2128),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Colors.orange, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('كل صنف في البوفيه ينتمي لقسم',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                    '${categories.length} قسم | ${state.menu.length} صنف',
                    style: const TextStyle(color: Color(0xFF4ade80), fontSize: 12),
                  ),
                ]),
              ),
            ]),
          ),

          // ── قائمة الأقسام ──────────────────────────────────────────────
          Expanded(
            child: categories.isEmpty
                ? _EmptyCategories(onAdd: () => _showAddDialog(context, state))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: categories.length,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex--;
                      state.reorderCategory(oldIndex, newIndex);
                    },
                    itemBuilder: (ctx, i) {
                      final cat = categories[i];
                      // حساب عدد الأصناف في هذا القسم
                      final itemCount = state.menu.keys
                          .where((k) => state.menuItemCategory(k) == cat.id)
                          .length;
                      return _CategoryTile(
                        key: ValueKey(cat.id),
                        category: cat,
                        itemCount: itemCount,
                        onEdit: () => _showEditDialog(context, state, cat),
                        onDelete: () => _confirmDelete(context, state, cat),
                      );
                    },
                  ),
          ),

          // ── ملاحظة إعادة الترتيب ─────────────────────────────────────
          if (categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.drag_indicator, color: Colors.white24, size: 14),
                const SizedBox(width: 4),
                const Text('اسحب لإعادة الترتيب',
                    style: TextStyle(color: Colors.white24, fontSize: 11)),
              ]),
            ),
        ],
      ),
    );
  }

  // ─── إضافة قسم ──────────────────────────────────────────────────────────
  void _showAddDialog(BuildContext context, AppState state) {
    final nameCtrl = TextEditingController();
    String selectedEmoji = '🍽';
    final emojiOptions = ['🔥', '❄️', '🍟', '🥤', '🍕', '🍔', '🍫', '🍰', '🧃', '☕', '🌮', '🍝', '🍗', '🥗', '🍽'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1c2128),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.add_circle, color: Colors.orange),
            SizedBox(width: 8),
            Text('إضافة قسم جديد',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            // اسم القسم
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'اسم القسم (مثال: سخن، بارد، سناكس)',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF0b0e14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.orange, width: 2)),
              ),
            ),
            const SizedBox(height: 16),
            // اختيار الإيموجي
            Align(
              alignment: Alignment.centerRight,
              child: Text('اختار أيقونة:',
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: emojiOptions.map((e) => GestureDetector(
                onTap: () => setS(() => selectedEmoji = e),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: selectedEmoji == e
                        ? Colors.orange.withOpacity(0.2)
                        : const Color(0xFF0b0e14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selectedEmoji == e ? Colors.orange : Colors.white12,
                      width: selectedEmoji == e ? 2 : 1,
                    ),
                  ),
                  child: Center(child: Text(e, style: const TextStyle(fontSize: 20))),
                ),
              )).toList(),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                state.addCategory(name, selectedEmoji);
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange, foregroundColor: Colors.black),
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── تعديل قسم ──────────────────────────────────────────────────────────
  void _showEditDialog(BuildContext context, AppState state, BuffetCategory cat) {
    final nameCtrl = TextEditingController(text: cat.name);
    String selectedEmoji = cat.emoji;
    final emojiOptions = ['🔥', '❄️', '🍟', '🥤', '🍕', '🍔', '🍫', '🍰', '🧃', '☕', '🌮', '🍝', '🍗', '🥗', '🍽'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1c2128),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.edit, color: Color(0xFF38bdf8)),
            SizedBox(width: 8),
            Text('تعديل القسم',
                style: TextStyle(color: Color(0xFF38bdf8), fontWeight: FontWeight.bold)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'اسم القسم',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF0b0e14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF38bdf8), width: 2)),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Text('اختار أيقونة:',
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: emojiOptions.map((e) => GestureDetector(
                onTap: () => setS(() => selectedEmoji = e),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: selectedEmoji == e
                        ? const Color(0xFF38bdf8).withOpacity(0.2)
                        : const Color(0xFF0b0e14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selectedEmoji == e ? const Color(0xFF38bdf8) : Colors.white12,
                      width: selectedEmoji == e ? 2 : 1,
                    ),
                  ),
                  child: Center(child: Text(e, style: const TextStyle(fontSize: 20))),
                ),
              )).toList(),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                state.updateCategory(cat.id, name, selectedEmoji);
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF38bdf8), foregroundColor: Colors.black),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── حذف قسم ────────────────────────────────────────────────────────────
  void _confirmDelete(BuildContext context, AppState state, BuffetCategory cat) {
    final itemsInCat = state.menu.keys
        .where((k) => state.menuItemCategory(k) == cat.id)
        .length;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف القسم؟', style: TextStyle(color: Colors.red)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('هيتم حذف قسم "${cat.emoji} ${cat.name}"',
              style: const TextStyle(color: Colors.white70)),
          if (itemsInCat > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$itemsInCat صنف في هذا القسم هينتقلوا لـ "أخرى"',
                    style: const TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              ]),
            ),
          ],
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              state.deleteCategory(cat.id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  // ─── استعادة الأقسام الافتراضية ─────────────────────────────────────────
  void _confirmRestoreDefaults(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.restore, color: Colors.white70),
          SizedBox(width: 8),
          Text('استعادة الافتراضي؟', style: TextStyle(color: Colors.white)),
        ]),
        content: const Text(
            'هيتم استبدال الأقسام الحالية بالأقسام الافتراضية (سخن، بارد، سناكس، مشروبات، أخرى)',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              state.restoreDefaultCategories();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.white24),
            child: const Text('استعادة'),
          ),
        ],
      ),
    );
  }
}

// ─── Category Tile ────────────────────────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  final BuffetCategory category;
  final int itemCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryTile({
    super.key,
    required this.category,
    required this.itemCount,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(children: [
        // Drag handle
        const Icon(Icons.drag_indicator, color: Colors.white24, size: 20),
        const SizedBox(width: 10),

        // Emoji + اسم
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Center(child: Text(category.emoji, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),

        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(category.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(
              '$itemCount ${itemCount == 1 ? "صنف" : "أصناف"}',
              style: TextStyle(
                color: itemCount > 0 ? const Color(0xFF4ade80) : Colors.white38,
                fontSize: 12,
              ),
            ),
          ]),
        ),

        // أزرار
        IconButton(
          icon: const Icon(Icons.edit, color: Color(0xFF38bdf8), size: 20),
          onPressed: onEdit,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
          onPressed: onDelete,
        ),
      ]),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyCategories extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyCategories({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.category_outlined, size: 64, color: Colors.white12),
        const SizedBox(height: 16),
        const Text('لا يوجد أقسام',
            style: TextStyle(color: Colors.white54, fontSize: 18)),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('إضافة أول قسم'),
          style: FilledButton.styleFrom(
              backgroundColor: Colors.orange, foregroundColor: Colors.black),
        ),
      ]),
    );
  }
}
