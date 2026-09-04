// lib/screens/expenses_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String _selectedCategory = 'الكل';

  static const List<String> _categories = [
    'الكل',
    'إيجار',
    'كهرباء',
    'رواتب',
    'صيانة',
    'أخرى',
  ];

  static const Map<String, IconData> _categoryIcons = {
    'إيجار':  Icons.home_outlined,
    'كهرباء': Icons.bolt_outlined,
    'رواتب':  Icons.people_outline,
    'صيانة':  Icons.build_outlined,
    'أخرى':   Icons.receipt_long_outlined,
  };

  static const Map<String, Color> _categoryColors = {
    'إيجار':  Color(0xFF818cf8),
    'كهرباء': Color(0xFFfbbf24),
    'رواتب':  Color(0xFF34d399),
    'صيانة':  Color(0xFF38bdf8),
    'أخرى':   Colors.white54,
  };

  @override
  Widget build(BuildContext context) {
    final state  = context.watch<AppState>();
    final isAdmin = state.isAdmin;

    // فلتر الفئة
    final filtered = _selectedCategory == 'الكل'
        ? state.expenses
        : state.expenses
            .where((e) => e['category'] == _selectedCategory)
            .toList();

    // إجماليات
    final now       = DateTime.now();
    final todayStr  = '${now.day}/${now.month}/${now.year}';
    final todayExp  = state.expenses
        .where((e) => (e['date'] as String?)?.startsWith(todayStr) == true)
        .fold(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));

    final monthExp  = state.expenses
        .where((e) {
          final d = e['date'] as String? ?? '';
          return d.endsWith('/${now.month}/${now.year}') ||
              d.contains('/${now.month}/${now.year}');
        })
        .fold(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));

    final todayRev  = state.history
        .fold(0.0, (s, h) => s + ((h['total'] as num?)?.toDouble() ?? 0));
    final netProfit = todayRev - todayExp;

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, color: Colors.redAccent, size: 20),
            SizedBox(width: 8),
            Text('المصروفات',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle,
                color: Colors.redAccent, size: 28),
            tooltip: 'إضافة مصروف',
            onPressed: () => _showAddDialog(context, state),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── بطاقة الإجماليات ──────────────────────────────────────────
          _SummaryCard(
            todayExp:  todayExp,
            monthExp:  monthExp,
            netProfit: netProfit,
          ),

          // ── فلاتر الفئة ──────────────────────────────────────────────
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              itemBuilder: (ctx, i) {
                final cat      = _categories[i];
                final selected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.redAccent.withOpacity(0.2)
                          : const Color(0xFF1c2128),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? Colors.redAccent
                            : Colors.white12,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(cat,
                        style: TextStyle(
                          color:
                              selected ? Colors.redAccent : Colors.white54,
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        )),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // ── القائمة ──────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 64, color: Colors.white12),
                        SizedBox(height: 16),
                        Text('لا يوجد مصروفات',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 16)),
                        SizedBox(height: 6),
                        Text('اضغط + لإضافة مصروف جديد',
                            style: TextStyle(
                                color: Colors.white24, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      // ترتيب من الأحدث للأقدم
                      final sorted = List<Map<String, dynamic>>.from(filtered)
                        ..sort((a, b) {
                          final ta =
                              (a['created_at'] as String?) ?? '';
                          final tb =
                              (b['created_at'] as String?) ?? '';
                          return tb.compareTo(ta);
                        });
                      return _ExpenseTile(
                        expense: sorted[i],
                        isAdmin: isAdmin,
                        categoryIcons: _categoryIcons,
                        categoryColors: _categoryColors,
                        onDelete: isAdmin
                            ? () => _confirmDelete(
                                context, state, sorted[i]['id'] as String)
                            : null,
                        onEdit: isAdmin
                            ? () => _showEditDialog(
                                context, state, sorted[i])
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Add Dialog ──────────────────────────────────────────────────────────
  void _showAddDialog(BuildContext context, AppState state) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String selectedCat = 'أخرى';

    final availableCats = state.expenseCategories.isNotEmpty
        ? state.expenseCategories
        : ['إيجار', 'كهرباء', 'رواتب', 'صيانة', 'أخرى'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1c2128),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.add_circle, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('إضافة مصروف',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold)),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // العنوان
              TextField(
                controller: titleCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('عنوان المصروف'),
              ),
              const SizedBox(height: 12),
              // المبلغ
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
                decoration: _inputDeco('المبلغ (ج)').copyWith(
                  suffixText: 'ج',
                  suffixStyle: const TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 14),
              // الفئة
              Align(
                alignment: Alignment.centerRight,
                child: Text('الفئة:',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 13)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableCats.map((cat) {
                  final sel = selectedCat == cat;
                  return GestureDetector(
                    onTap: () => setS(() => selectedCat = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel
                            ? Colors.redAccent.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel
                              ? Colors.redAccent
                              : Colors.white24,
                          width: sel ? 2 : 1,
                        ),
                      ),
                      child: Text(cat,
                          style: TextStyle(
                            color: sel
                                ? Colors.redAccent
                                : Colors.white54,
                            fontSize: 12,
                            fontWeight: sel
                                ? FontWeight.bold
                                : FontWeight.normal,
                          )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              // ملاحظة
              TextField(
                controller: noteCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('ملاحظة (اختياري)'),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء',
                    style: TextStyle(color: Colors.white54))),
            FilledButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                final amount = double.tryParse(amountCtrl.text.trim());
                if (title.isEmpty || amount == null || amount <= 0) return;
                state.addExpense(
                  title,
                  amount,
                  selectedCat,
                  note: noteCtrl.text.trim().isEmpty
                      ? null
                      : noteCtrl.text.trim(),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content:
                      Text('✅ تم تسجيل مصروف "$title" (${amount.toStringAsFixed(1)} ج)'),
                  backgroundColor: Colors.redAccent,
                  duration: const Duration(seconds: 2),
                ));
              },
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white),
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Edit Dialog ─────────────────────────────────────────────────────────
  void _showEditDialog(
      BuildContext context, AppState state, Map<String, dynamic> expense) {
    final titleCtrl =
        TextEditingController(text: expense['title'] as String? ?? '');
    final amountCtrl = TextEditingController(
        text: '${(expense['amount'] as num?)?.toDouble() ?? 0}');
    final noteCtrl =
        TextEditingController(text: expense['note'] as String? ?? '');
    String selectedCat =
        expense['category'] as String? ?? 'أخرى';

    final availableCats = state.expenseCategories.isNotEmpty
        ? state.expenseCategories
        : ['إيجار', 'كهرباء', 'رواتب', 'صيانة', 'أخرى'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1c2128),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.edit, color: Color(0xFF38bdf8)),
            SizedBox(width: 8),
            Text('تعديل مصروف',
                style: TextStyle(
                    color: Color(0xFF38bdf8),
                    fontWeight: FontWeight.bold)),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: titleCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('عنوان المصروف'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
                decoration: _inputDeco('المبلغ (ج)').copyWith(
                  suffixText: 'ج',
                  suffixStyle: const TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: Text('الفئة:',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 13)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableCats.map((cat) {
                  final sel = selectedCat == cat;
                  return GestureDetector(
                    onTap: () => setS(() => selectedCat = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel
                            ? const Color(0xFF38bdf8).withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel
                              ? const Color(0xFF38bdf8)
                              : Colors.white24,
                          width: sel ? 2 : 1,
                        ),
                      ),
                      child: Text(cat,
                          style: TextStyle(
                            color: sel
                                ? const Color(0xFF38bdf8)
                                : Colors.white54,
                            fontSize: 12,
                            fontWeight: sel
                                ? FontWeight.bold
                                : FontWeight.normal,
                          )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('ملاحظة (اختياري)'),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء',
                    style: TextStyle(color: Colors.white54))),
            FilledButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                final amount =
                    double.tryParse(amountCtrl.text.trim());
                if (title.isEmpty || amount == null || amount <= 0) return;
                state.updateExpense(
                  expense['id'] as String,
                  title,
                  amount,
                  selectedCat,
                  note: noteCtrl.text.trim().isEmpty
                      ? null
                      : noteCtrl.text.trim(),
                );
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF38bdf8),
                  foregroundColor: Colors.black),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Confirm Delete ───────────────────────────────────────────────────────
  void _confirmDelete(
      BuildContext context, AppState state, String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف المصروف؟',
            style: TextStyle(color: Colors.red)),
        content: const Text('هيتم حذف هذا المصروف نهائياً',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              state.deleteExpense(id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

// ─── Summary Card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double todayExp, monthExp, netProfit;
  const _SummaryCard({
    required this.todayExp,
    required this.monthExp,
    required this.netProfit,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = netProfit >= 0;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatChip(
              icon: Icons.today,
              label: 'مصروفات اليوم',
              value: '${todayExp.toStringAsFixed(1)} ج',
              color: Colors.redAccent,
            ),
            Container(width: 1, height: 36, color: Colors.white12),
            _StatChip(
              icon: Icons.calendar_month,
              label: 'مصروفات الشهر',
              value: '${monthExp.toStringAsFixed(1)} ج',
              color: Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(color: Colors.white12, height: 1),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPositive
                  ? Icons.trending_up
                  : Icons.trending_down,
              color: isPositive
                  ? const Color(0xFF4ade80)
                  : Colors.redAccent,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'صافي الربح اليوم: ',
              style: const TextStyle(
                  color: Colors.white54, fontSize: 13),
            ),
            Text(
              '${netProfit.toStringAsFixed(1)} ج',
              style: TextStyle(
                color: isPositive
                    ? const Color(0xFF4ade80)
                    : Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
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
      Icon(icon, color: color, size: 16),
      const SizedBox(height: 4),
      Text(label,
          style: const TextStyle(
              color: Colors.white38, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value,
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14)),
    ]);
  }
}

// ─── Expense Tile ─────────────────────────────────────────────────────────────

class _ExpenseTile extends StatelessWidget {
  final Map<String, dynamic> expense;
  final bool isAdmin;
  final Map<String, IconData> categoryIcons;
  final Map<String, Color> categoryColors;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const _ExpenseTile({
    required this.expense,
    required this.isAdmin,
    required this.categoryIcons,
    required this.categoryColors,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final title    = expense['title'] as String? ?? '';
    final amount   = (expense['amount'] as num?)?.toDouble() ?? 0;
    final category = expense['category'] as String? ?? 'أخرى';
    final date     = expense['date'] as String? ?? '';
    final note     = expense['note'] as String?;
    final addedBy  = expense['added_by'] as String? ?? '';

    final color = categoryColors[category] ?? Colors.white38;
    final icon  = categoryIcons[category] ?? Icons.receipt_long_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.redAccent.withOpacity(0.2)),
      ),
      child: Row(children: [
        // أيقونة الفئة
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),

        // المعلومات
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                  Text('${amount.toStringAsFixed(1)} ج',
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(category,
                        style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Text(date,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                  if (addedBy.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text('· $addedBy',
                        style: const TextStyle(
                            color: Colors.white24, fontSize: 10)),
                  ],
                ]),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(note,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                ],
              ]),
        ),

        // أزرار الأدمن
        if (isAdmin) ...[
          const SizedBox(width: 6),
          Column(children: [
            GestureDetector(
              onTap: onEdit,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF38bdf8).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF38bdf8).withOpacity(0.3)),
                ),
                child: const Icon(Icons.edit,
                    color: Color(0xFF38bdf8), size: 15),
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.red.withOpacity(0.25)),
                ),
                child: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 15),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

// ─── Helper ───────────────────────────────────────────────────────────────────

InputDecoration _inputDeco(String label) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
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
          borderSide:
              const BorderSide(color: Colors.redAccent, width: 2)),
    );
