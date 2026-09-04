// ════════════════════════════════════════════════════════════════════════════
// lib/screens/cashiers_screen.dart
// شاشة إدارة الكاشيرين — أضفها كـ import في settings_screen.dart
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';

class CashiersScreen extends StatelessWidget {
  const CashiersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cashiers = state.cashiers;

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people, color: Color(0xFF38bdf8), size: 20),
            SizedBox(width: 8),
            Text(
              'إدارة الكاشيرين',
              style: TextStyle(
                  color: Color(0xFF38bdf8), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle,
                color: Color(0xFF38bdf8), size: 28),
            tooltip: 'إضافة كاشير',
            onPressed: () => _showAddDialog(context, state),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── بانر توضيحي ─────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1c2128),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF38bdf8).withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline,
                  color: Color(0xFF38bdf8), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'كل كاشير ليه اسم وباسورد خاص بيه',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${cashiers.length} كاشير متاح',
                        style: const TextStyle(
                            color: Color(0xFF4ade80),
                            fontSize: 12),
                      ),
                    ]),
              ),
            ]),
          ),

          // ─── قائمة الكاشيرين ──────────────────────────────────────────
          Expanded(
            child: cashiers.isEmpty
                ? const Center(
                    child: Text('لا يوجد كاشيرين',
                        style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: cashiers.length,
                    itemBuilder: (ctx, i) =>
                        _CashierTile(index: i, cashier: cashiers[i]),
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, AppState state) {
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1c2128),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.person_add, color: Color(0xFF4ade80)),
            SizedBox(width: 8),
            Text('إضافة كاشير جديد',
                style: TextStyle(
                    color: Color(0xFF4ade80),
                    fontWeight: FontWeight.bold)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _inputField('اسم الكاشير', nameCtrl, Icons.person),
            const SizedBox(height: 12),
            _inputField('كلمة السر', passCtrl, Icons.lock,
                obscure: true),
            const SizedBox(height: 12),
            _inputField('تأكيد كلمة السر', confirmCtrl,
                Icons.lock_outline,
                obscure: true),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء',
                    style: TextStyle(color: Colors.white54))),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final pass = passCtrl.text;
                final confirm = confirmCtrl.text;

                if (name.isEmpty) {
                  setS(() => error = '⚠️ اكتب اسم الكاشير');
                  return;
                }
                if (pass.length < 4) {
                  setS(() => error = '⚠️ الباسورد قصير جداً (4 أحرف على الأقل)');
                  return;
                }
                if (pass != confirm) {
                  setS(() => error = '⚠️ كلمتا السر مش متطابقتين');
                  return;
                }
                // تحقق من تكرار الاسم
                final exists = state.cashiers
                    .any((c) => c['name'] == name);
                if (exists) {
                  setS(() => error = '⚠️ الاسم ده موجود بالفعل');
                  return;
                }

                state.addCashier(name, pass);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ تم إضافة الكاشير "$name"'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4ade80),
                  foregroundColor: Colors.black),
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Cashier Tile ─────────────────────────────────────────────────────────────

class _CashierTile extends StatelessWidget {
  final int index;
  final Map<String, dynamic> cashier;
  const _CashierTile({required this.index, required this.cashier});

  @override
  Widget build(BuildContext context) {
    final name = cashier['name'] as String? ?? 'كاشير ${index + 1}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(children: [
        // أيقونة الكاشير
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF38bdf8).withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(
                color: const Color(0xFF38bdf8).withOpacity(0.4)),
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'K',
              style: const TextStyle(
                  color: Color(0xFF38bdf8),
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // الاسم والرقم
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                Text(
                  'كاشير رقم ${index + 1}',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12),
                ),
              ]),
        ),

        // أزرار التعديل والحذف
        Row(mainAxisSize: MainAxisSize.min, children: [
          // تغيير الاسم
          IconButton(
            icon: const Icon(Icons.edit,
                color: Color(0xFF38bdf8), size: 20),
            tooltip: 'تعديل الاسم',
            onPressed: () =>
                _showEditNameDialog(context, index, name),
          ),
          // تغيير الباسورد
          IconButton(
            icon: const Icon(Icons.lock_reset,
                color: Colors.amber, size: 20),
            tooltip: 'تغيير الباسورد',
            onPressed: () =>
                _showChangePasswordDialog(context, index, name),
          ),
          // حذف
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Colors.red, size: 20),
            tooltip: 'حذف',
            onPressed: () =>
                _confirmDelete(context, index, name),
          ),
        ]),
      ]),
    );
  }

  void _showEditNameDialog(
      BuildContext context, int index, String currentName) {
    final state = context.read<AppState>();
    final ctrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.edit, color: Color(0xFF38bdf8)),
          SizedBox(width: 8),
          Text('تعديل اسم الكاشير',
              style: TextStyle(
                  color: Color(0xFF38bdf8),
                  fontWeight: FontWeight.bold)),
        ]),
        content:
            _inputField('الاسم الجديد', ctrl, Icons.person),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              state.updateCashierName(index, name);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF38bdf8),
                foregroundColor: Colors.black),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(
      BuildContext context, int index, String cashierName) {
    final state = context.read<AppState>();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1c2128),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            const Icon(Icons.lock_reset, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تغيير باسورد "$cashierName"',
                style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _inputField(
                'الباسورد الجديد', newCtrl, Icons.lock,
                obscure: true),
            const SizedBox(height: 12),
            _inputField('تأكيد الباسورد', confirmCtrl,
                Icons.lock_outline,
                obscure: true),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!,
                  style:
                      const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء',
                    style: TextStyle(color: Colors.white54))),
            FilledButton(
              onPressed: () {
                if (newCtrl.text.length < 4) {
                  setS(() =>
                      error = '⚠️ الباسورد قصير (4 أحرف على الأقل)');
                  return;
                }
                if (newCtrl.text != confirmCtrl.text) {
                  setS(
                      () => error = '⚠️ كلمتا السر مش متطابقتين');
                  return;
                }
                state.updateCashierPassword(index, newCtrl.text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('✅ تم تغيير باسورد "$cashierName"'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, int index, String name) {
    final state = context.read<AppState>();
    if (state.cashiers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ لازم يفضل كاشير واحد على الأقل!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف كاشير؟',
            style: TextStyle(color: Colors.red)),
        content: Text(
          'هيتم حذف "$name" من قائمة الكاشيرين',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              state.removeCashier(index);
              Navigator.pop(context);
            },
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

// ─── Helper ───────────────────────────────────────────────────────────────────

Widget _inputField(
    String label, TextEditingController ctrl, IconData icon,
    {bool obscure = false}) {
  return TextField(
    controller: ctrl,
    obscureText: obscure,
    style: const TextStyle(color: Colors.white),
    autofocus: false,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon:
          Icon(icon, color: const Color(0xFF38bdf8), size: 20),
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
          borderSide: const BorderSide(
              color: Color(0xFF38bdf8), width: 2)),
    ),
  );
}
