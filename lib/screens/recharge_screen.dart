import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';

class RechargeScreen extends StatelessWidget {
  const RechargeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isAdmin = state.isAdmin;
    final transactions = state.rechargeTransactions;

    // حساب الإجماليات
    final todaySales = transactions
        .where((t) => t['type'] == 'card' || t['type'] == 'free')
        .fold(0.0, (s, t) => s + ((t['value'] as num?) ?? 0));
    final todayTopUp = transactions
        .where((t) => t['type'] == 'top_up')
        .fold(0.0, (s, t) => s + ((t['value'] as num?) ?? 0));

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        automaticallyImplyLeading: false,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_android, color: Color(0xFF38bdf8), size: 20),
            SizedBox(width: 8),
            Text('شحن الرصيد',
                style: TextStyle(
                    color: Color(0xFF38bdf8), fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ── كارت الرصيد (أدمن فقط) ────────────────────────────────────
          if (isAdmin) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1c2128),
                    const Color(0xFF38bdf8).withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF38bdf8).withOpacity(0.4)),
              ),
              child: Column(children: [
                // الرصيد الإجمالي
                const Text('الرصيد الإجمالي',
                    style:
                        TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  '${state.rechargeBalance.toStringAsFixed(1)} ج',
                  style: const TextStyle(
                      color: Color(0xFF4ade80),
                      fontSize: 42,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _BalanceChip('⬆️ أضيف اليوم',
                        '${todayTopUp.toStringAsFixed(1)} ج',
                        Colors.green),
                    Container(
                        width: 1, height: 36, color: Colors.white12),
                    _BalanceChip('🃏 مبيعات اليوم',
                        '${todaySales.toStringAsFixed(1)} ج',
                        const Color(0xFF38bdf8)),
                    Container(
                        width: 1, height: 36, color: Colors.white12),
                    _BalanceChip(
                        '📊 الباقي',
                        '${(state.rechargeBalance - todaySales).toStringAsFixed(1)} ج',
                        Colors.orange),
                  ],
                ),
              ]),
            ),
            const SizedBox(height: 10),
            // زرار إضافة رصيد
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () => _showTopUpDialog(context, state),
                icon: const Icon(Icons.arrow_upward_rounded),
                label: const Text('⬆️ إضافة رصيد',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── أزرار العمليات ────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.sim_card,
                label: '🃏 بيع كارت',
                color: const Color(0xFF38bdf8),
                onTap: () => _showSellCardDialog(context, state),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionCard(
                icon: Icons.phone_android,
                label: '📱 شحن حر',
                color: Colors.orange,
                onTap: () => _showFreeChargeDialog(context, state),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionCard(
                icon: Icons.credit_card_off,
                label: '💳 مديونية',
                color: Colors.redAccent,
                onTap: () => _showAddDebtDialog(context, state),
              ),
            ),
          ]),

          const SizedBox(height: 16),

          // ── سجل اليوم ────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'سجل اليوم (${transactions.length} عملية)',
                style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
              if (isAdmin && transactions.isNotEmpty)
                GestureDetector(
                  onTap: () => _confirmClear(context, state),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: Colors.red.withOpacity(0.4)),
                    ),
                    child: const Text('تصفير',
                        style: TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (transactions.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1c2128),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: const Center(
                child: Column(children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 48, color: Colors.white12),
                  SizedBox(height: 10),
                  Text('لا يوجد عمليات اليوم',
                      style:
                          TextStyle(color: Colors.white38, fontSize: 14)),
                ]),
              ),
            )
          else
            ...transactions.reversed.map((t) => _TransactionTile(tx: t)),
        ],
      ),
    );
  }

  // ── إضافة رصيد (أدمن) ───────────────────────────────────────────────────
  void _showTopUpDialog(BuildContext context, AppState state) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.arrow_upward_rounded, color: Colors.green),
          SizedBox(width: 8),
          Text('إضافة رصيد',
              style: TextStyle(
                  color: Colors.green, fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            autofocus: true,
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            decoration: _inputDeco('المبلغ (ج)').copyWith(
              suffixText: 'ج',
              suffixStyle: const TextStyle(color: Colors.white54),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            decoration: _inputDeco('ملاحظة (اختياري)'),
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
              state.addRechargeBalance(
                  amount,
                  noteCtrl.text.trim().isEmpty
                      ? 'إضافة رصيد'
                      : noteCtrl.text.trim());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    '✅ تم إضافة ${amount.toStringAsFixed(1)} ج للرصيد'),
                backgroundColor: Colors.green,
              ));
            },
            style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  // ── بيع كارت ────────────────────────────────────────────────────────────
  void _showSellCardDialog(BuildContext context, AppState state) {
    if (state.rechargeCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ لا يوجد فئات كروت، أضفها من الإعدادات'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.sim_card, color: Color(0xFF38bdf8)),
          SizedBox(width: 8),
          Text('بيع كارت',
              style: TextStyle(
                  color: Color(0xFF38bdf8), fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: state.rechargeCards.map((card) {
            final name = card['name'] as String? ?? '';
            final value = (card['value'] as num?)?.toDouble() ?? 0;
            return GestureDetector(
              onTap: () {
                state.addRechargeTransaction(
                  type: 'card',
                  name: name,
                  value: value,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('✅ تم بيع $name (${value.toStringAsFixed(1)} ج)'),
                  backgroundColor: const Color(0xFF38bdf8),
                ));
              },
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF38bdf8).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF38bdf8).withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.sim_card,
                      color: Color(0xFF38bdf8), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  Text('${value.toStringAsFixed(1)} ج',
                      style: const TextStyle(
                          color: Color(0xFF4ade80),
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ]),
              ),
            );
          }).toList(),
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

  // ── شحن حر ──────────────────────────────────────────────────────────────
  void _showFreeChargeDialog(BuildContext context, AppState state) {
    final amountCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.phone_android, color: Colors.orange),
          SizedBox(width: 8),
          Text('شحن حر',
              style: TextStyle(
                  color: Colors.orange, fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl,
            decoration: _inputDeco('ملاحظة (اختياري)'),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            decoration: _inputDeco('المبلغ (ج)').copyWith(
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
              state.addRechargeTransaction(
                type: 'free',
                name: nameCtrl.text.trim().isEmpty
                    ? 'شحن حر'
                    : nameCtrl.text.trim(),
                value: amount,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    Text('✅ تم تسجيل شحن حر (${amount.toStringAsFixed(1)} ج)'),
                backgroundColor: Colors.orange,
              ));
            },
            style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black),
            child: const Text('تسجيل'),
          ),
        ],
      ),
    );
  }

  // ── إضافة مديونية ───────────────────────────────────────────────────────
  void _showAddDebtDialog(BuildContext context, AppState state) {
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
          Icon(Icons.credit_card_off, color: Colors.redAccent),
          SizedBox(width: 8),
          Text('إضافة مديونية شحن',
              style: TextStyle(
                  color: Colors.redAccent, fontWeight: FontWeight.bold)),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              decoration: _inputDeco('اسم العميل'),
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
              if (name.isEmpty || amount == null || amount <= 0) return;
              // إضافة للمديونيات العامة
              state.addDebt(name, amount, dateCtrl.text.trim(),
                  note: noteCtrl.text.trim().isEmpty
                      ? 'شحن رصيد'
                      : noteCtrl.text.trim());
              // تسجيل في سجل الشحن كـ debt
              state.addRechargeTransaction(
                type: 'debt',
                name: name,
                value: amount,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    '✅ تم إضافة مديونية لـ $name (${amount.toStringAsFixed(1)} ج)'),
                backgroundColor: Colors.redAccent,
              ));
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

  // ── تصفير السجل ─────────────────────────────────────────────────────────
  void _confirmClear(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تصفير سجل اليوم؟',
            style: TextStyle(color: Colors.red)),
        content: const Text('هيتم مسح كل عمليات الشحن اليومية',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              state.clearRechargeTransactions();
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

// ── Widgets مساعدة ───────────────────────────────────────────────────────────

class _BalanceChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _BalanceChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label,
          style: const TextStyle(color: Colors.white54, fontSize: 10)),
      const SizedBox(height: 4),
      Text(value,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 14)),
    ]);
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1c2128),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11),
          ),
        ]),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final type = tx['type'] as String? ?? '';
    final name = tx['name'] as String? ?? '';
    final value = (tx['value'] as num?)?.toDouble() ?? 0;
    final cashier = tx['cashier'] as String? ?? '';
    final dateStr = tx['date'] as String? ?? '';
    final timeStr =
        dateStr.length >= 16 ? dateStr.substring(11, 16) : '';

    Color color;
    IconData icon;
    String typeLabel;

    switch (type) {
      case 'top_up':
        color = Colors.green;
        icon = Icons.arrow_upward_rounded;
        typeLabel = '⬆️ إضافة رصيد';
        break;
      case 'card':
        color = const Color(0xFF38bdf8);
        icon = Icons.sim_card;
        typeLabel = '🃏 كارت';
        break;
      case 'free':
        color = Colors.orange;
        icon = Icons.phone_android;
        typeLabel = '📱 شحن حر';
        break;
      case 'debt':
        color = Colors.redAccent;
        icon = Icons.credit_card_off;
        typeLabel = '💳 مديونية';
        break;
      default:
        color = Colors.white54;
        icon = Icons.receipt;
        typeLabel = type;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(typeLabel,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
            if (name.isNotEmpty)
              Text(name,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13)),
            if (cashier.isNotEmpty)
              Text(cashier,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 10)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            type == 'top_up'
                ? '+${value.toStringAsFixed(1)} ج'
                : '-${value.toStringAsFixed(1)} ج',
            style: TextStyle(
                color: type == 'top_up' ? Colors.green : color,
                fontWeight: FontWeight.bold,
                fontSize: 15),
          ),
          Text(timeStr,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 10)),
        ]),
      ]),
    );
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
          borderSide:
              const BorderSide(color: Color(0xFF38bdf8), width: 2)),
    );
