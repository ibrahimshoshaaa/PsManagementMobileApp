import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';

class DebtsScreen extends StatelessWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isAdmin = state.isAdmin;
    final debts = state.debts;

    final unpaid = debts.where((d) => d['paid'] != true).toList();
    final paid = debts.where((d) => d['paid'] == true).toList();
    final totalUnpaid =
        unpaid.fold(0.0, (s, d) => s + ((d['amount'] as num?) ?? 0));

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: const Text('المديونيات',
            style: TextStyle(
                color: Colors.redAccent, fontWeight: FontWeight.bold)),
        leading: const BackButton(color: Colors.white),
        actions: [
          // ✅ أدمن وكاشير كلهم يقدروا يضيفوا مديونية
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.redAccent, size: 28),
            tooltip: 'إضافة مديونية',
            onPressed: () => _showAddDialog(context, state),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── ملخص ─────────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1c2128),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SumTile('📋 الكل', '${debts.length}', Colors.white),
                Container(width: 1, height: 40, color: Colors.white12),
                _SumTile('⏳ غير مسدد', '${unpaid.length}', Colors.redAccent),
                Container(width: 1, height: 40, color: Colors.white12),
                _SumTile('💰 إجمالي',
                    '${totalUnpaid.toStringAsFixed(1)} ج', Colors.redAccent),
              ],
            ),
          ),

          // ── القائمة ───────────────────────────────────────────────────────
          Expanded(
            child: debts.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.money_off, size: 64, color: Colors.white12),
                        SizedBox(height: 16),
                        Text('لا يوجد مديونيات',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      // ── غير مسددة ─────────────────────────────────────
                      if (unpaid.isNotEmpty) ...[
                        _Header('⏳ غير مسددة (${unpaid.length})'),
                        ...unpaid.map((d) {
                          final index = debts.indexOf(d);
                          return _DebtTile(
                            debt: d,
                            isAdmin: isAdmin,
                            // ✅ الكاشير يقدر يستلم بس — مش يمسح أو يضيف
                            onPaid: () => _confirmFullPay(context, state, index, d),
                            onDelete: isAdmin
                                ? () => _confirmDelete(context, state, index)
                                : null,
                            onPartialPay: () =>
                                _showPartialPayDialog(context, state, index),
                            // ✅ إضافة مبلغ لمديونية موجودة
                            onAddAmount: () => _showAddAmountDialog(context, state, index),

                          );
                        }),
                        const SizedBox(height: 12),
                      ],

                      // ── مسددة (أرشيف) ─────────────────────────────────
                      if (paid.isNotEmpty) ...[
                        _Header('✅ مسددة — أرشيف (${paid.length})'),
                        ...paid.map((d) {
                          final index = debts.indexOf(d);
                          return _DebtTile(
                            debt: d,
                            isAdmin: isAdmin,
                            isPaid: true,
                            onPaid: () {},
                            // ✅ الكاشير مش يشوف زرار حذف المسددة
                            onDelete: isAdmin
                                ? () => _confirmDelete(context, state, index)
                                : null,
                            onPartialPay: () {},
                            onAddAmount: null,
                          );
                        }),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ─── إضافة مديونية جديدة ──────────────────────────────────────────────────
  void _showAddDialog(BuildContext context, AppState state) {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final dateCtrl = TextEditingController(
        text:
            '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.add_circle, color: Colors.redAccent),
          SizedBox(width: 8),
          Text('إضافة مديونية',
              style: TextStyle(
                  color: Colors.redAccent, fontWeight: FontWeight.bold)),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              decoration: _inputDeco('اسم الشخص'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDeco('المبلغ (ج)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: _inputDeco('ملاحظة (اختياري)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dateCtrl,
              decoration: _inputDeco('التاريخ'),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final amount = double.tryParse(amountCtrl.text);
              final date = dateCtrl.text.trim();
              if (name.isEmpty || amount == null || amount <= 0) return;
              state.addDebt(name, amount, date,
                  note: noteCtrl.text.trim().isEmpty
                      ? null
                      : noteCtrl.text.trim());
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  // ─── إضافة مبلغ لمديونية موجودة (أدمن فقط) ──────────────────────────────
  void _showAddAmountDialog(
      BuildContext context, AppState state, int index) {
    final debt = state.debts[index];
    final current = (debt['amount'] as num?)?.toDouble() ?? 0;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.add_box, color: Colors.orange),
          SizedBox(width: 8),
          Text('إضافة مبلغ للمديونية',
              style: TextStyle(
                  color: Colors.orange, fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          // المبلغ الحالي
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المديونية الحالية:',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
                Text('${current.toStringAsFixed(1)} ج',
                    style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            decoration: _inputDeco('المبلغ المضاف (ج)').copyWith(
              suffixText: 'ج',
              suffixStyle: const TextStyle(color: Colors.white54),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            decoration: _inputDeco('سبب الإضافة (اختياري)'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(amountCtrl.text.trim());
              if (amount == null || amount <= 0) return;
              state.addToDebt(index, amount,
                  note: noteCtrl.text.trim().isEmpty
                      ? null
                      : noteCtrl.text.trim());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    '✅ تم إضافة ${amount.toStringAsFixed(1)} ج | الإجمالي: ${(current + amount).toStringAsFixed(1)} ج'),
                backgroundColor: Colors.orange,
              ));
            },
            style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  // ─── تأكيد تسديد كامل ────────────────────────────────────────────────────
  void _confirmFullPay(
      BuildContext context, AppState state, int index, Map<String, dynamic> d) {
    final amount = (d['amount'] as num?)?.toDouble() ?? 0;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.check_circle_outline, color: Colors.green),
          SizedBox(width: 8),
          Text('تسديد كامل؟',
              style:
                  TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        ]),
        content: Text(
            'هيتسجل استلام ${amount.toStringAsFixed(1)} ج كاملة من ${d['name']}',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              state.markDebtPaid(index);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('✅ تم تسجيل التسديد الكامل'),
                backgroundColor: Colors.green,
              ));
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('تأكيد التسديد'),
          ),
        ],
      ),
    );
  }

  // ─── دفع جزئي ────────────────────────────────────────────────────────────
  void _showPartialPayDialog(
      BuildContext context, AppState state, int index) {
    final debt = state.debts[index];
    final remaining = (debt['amount'] as num?)?.toDouble() ?? 0;
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.payments_outlined, color: Colors.orange),
          SizedBox(width: 8),
          Text('استلام جزئي',
              style: TextStyle(
                  color: Colors.orange, fontWeight: FontWeight.bold)),
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
                const Text('المتبقي:',
                    style:
                        TextStyle(color: Colors.white54, fontSize: 13)),
                Text('${remaining.toStringAsFixed(1)} ج',
                    style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            decoration: _inputDeco('المبلغ المستلم (ج)').copyWith(
              suffixText: 'ج',
              suffixStyle: const TextStyle(color: Colors.white54),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(amountCtrl.text.trim());
              if (amount == null || amount <= 0) return;
              if (amount > remaining) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('⚠️ المبلغ أكبر من المتبقي!'),
                  backgroundColor: Colors.red,
                ));
                return;
              }
              state.partialPayDebt(index, amount);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    '✅ تم استلام ${amount.toStringAsFixed(1)} ج | متبقي: ${(remaining - amount).toStringAsFixed(1)} ج'),
                backgroundColor: Colors.orange,
              ));
            },
            style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black),
            child: const Text('تسجيل الاستلام'),
          ),
        ],
      ),
    );
  }

  // ─── حذف (أدمن فقط) ───────────────────────────────────────────────────────
  void _confirmDelete(BuildContext context, AppState state, int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف مديونية؟',
            style: TextStyle(color: Colors.red)),
        content: const Text('هيتم حذف المديونية دي نهائياً',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              state.deleteDebt(index);
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

// ─── Debt Tile ────────────────────────────────────────────────────────────────

class _DebtTile extends StatelessWidget {
  final Map<String, dynamic> debt;
  final bool isAdmin;
  final bool isPaid;
  final VoidCallback onPaid;
  final VoidCallback? onDelete;
  final VoidCallback onPartialPay;
  final VoidCallback? onAddAmount; // أدمن فقط

  const _DebtTile({
    required this.debt,
    required this.isAdmin,
    required this.onPaid,
    required this.onDelete,
    required this.onPartialPay,
    this.onAddAmount,
    this.isPaid = false,
  });

  @override
  Widget build(BuildContext context) {
    final amount = (debt['amount'] as num?)?.toDouble() ?? 0;
    final note = debt['note'] as String?;
    final history = debt['payment_history'] as List?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPaid
              ? Colors.white12
              : Colors.redAccent.withOpacity(0.4),
          width: isPaid ? 1 : 1.5,
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isPaid
                ? Colors.green.withOpacity(0.12)
                : Colors.redAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isPaid ? Icons.check_circle_outline : Icons.person_outline,
            color: isPaid ? Colors.green : Colors.redAccent,
            size: 22,
          ),
        ),
        title: Text(
          debt['name'] ?? '',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            decoration: isPaid ? TextDecoration.lineThrough : null,
            color: isPaid ? Colors.white38 : Colors.white,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(
                '${amount.toStringAsFixed(1)} ج',
                style: TextStyle(
                  color: isPaid ? Colors.white38 : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                debt['date'] ?? '',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ]),
            if (note != null && note.isNotEmpty)
              Text(note,
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 11)),
            if (debt['created_by'] != null)
              Text(
                'أضافها: ${debt['created_by']}',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            if (debt['last_partial_pay'] != null)
              Text(
                'آخر استلام: ${debt['last_partial_pay'].toString().substring(0, 10)}',
                style: const TextStyle(color: Colors.orange, fontSize: 10),
              ),
          ],
        ),
        trailing: isPaid
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  // أدمن فقط يشوف زرار الحذف
                  if (isAdmin && onDelete != null)
                    GestureDetector(
                      onTap: onDelete,
                      child: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 16),
                    ),
                ],
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── سجل المدفوعات ──────────────────────────────────────
                if (history != null && history.isNotEmpty) ...[
                  const Text('📋 سجل الحركات:',
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...history.map((h) {
                    final isAdd = h['type'] == 'add';
                    final color = isAdd ? Colors.orange : const Color(0xFF4ade80);
                    final icon = isAdd ? Icons.add_circle_outline : Icons.remove_circle_outline;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        Icon(icon, color: color, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isAdd
                                ? 'إضافة ${(h['amount'] as num).toStringAsFixed(1)} ج${h['note'] != null ? ' — ${h['note']}' : ''}  |  ${h['by'] ?? ''}'
                                : 'استلام ${(h['amount'] as num).toStringAsFixed(1)} ج  |  ${h['by'] ?? ''}',
                            style: TextStyle(color: color, fontSize: 12),
                          ),
                        ),
                        Text(
                          h['date']?.toString().substring(0, 10) ?? '',
                          style: const TextStyle(
                              color: Colors.white24, fontSize: 10),
                        ),
                      ]),
                    );
                  }),
                  const Divider(color: Colors.white12),
                ],

                // ── أزرار التحكم ───────────────────────────────────────
                if (!isPaid) ...[
                  Row(children: [
                    // ✅ أدمن فقط: إضافة مبلغ
                    if (onAddAmount != null) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onAddAmount,
                          icon: const Icon(Icons.add, size: 14,
                              color: Colors.orange),
                          label: const Text('إضافة مبلغ',
                              style: TextStyle(
                                  color: Colors.orange, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.orange),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // ✅ كاشير وأدمن: استلام جزئي
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onPartialPay,
                        icon: const Icon(Icons.payments_outlined,
                            size: 14, color: Colors.orange),
                        label: const Text('استلام جزئي',
                            style: TextStyle(
                                color: Colors.orange, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.orange),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    // ✅ كاشير وأدمن: تسديد كامل
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onPaid,
                        icon: const Icon(Icons.check_circle_outline, size: 14),
                        label: const Text('تسديد كامل',
                            style: TextStyle(fontSize: 12)),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    // ✅ أدمن فقط: حذف
                    if (isAdmin && onDelete != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        tooltip: 'حذف المديونية',
                      ),
                    ],
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.bold)),
    );
  }
}

class _SumTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SumTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label,
          style: const TextStyle(fontSize: 11, color: Colors.white54)),
      const SizedBox(height: 4),
      Text(value,
          style: TextStyle(
              fontWeight: FontWeight.bold, color: color, fontSize: 13)),
    ]);
  }
}

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
          borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
    );
