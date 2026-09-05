import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/customer.dart';
import '../services/customer_service.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  /// بيفتح قائمة اختيار عميل (بحث بالاسم أو الرقم) ويرجع العميل المختار.
  /// تستخدمه أي دايلوج بداية تشغيل (تربيزة/جهاز) عن طريق زرار 📋.
  static Future<Customer?> pickCustomer(BuildContext context) async {
    final customers = await CustomerService.fetchAll();
    if (!context.mounted) return null;
    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد عملاء محفوظين'),
          backgroundColor: Colors.orange,
        ),
      );
      return null;
    }
    return showModalBottomSheet<Customer>(
      context: context,
      backgroundColor: const Color(0xFF1c2128),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CustomerPickerSheet(customers: customers),
    );
  }

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Customer> _customers = [];
  List<Customer> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await CustomerService.fetchAll();
    setState(() {
      _customers = list;
      _filtered = list;
      _loading = false;
    });
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _customers
          : _customers
              .where((c) =>
                  c.name.toLowerCase().contains(q) || c.phone.contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1c2128),
        title: const Text('العملاء',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Color(0xFF34d399)),
            tooltip: 'إضافة عميل',
            onPressed: () => _showAddDialog(),
          ),
        ],
      ),
      body: Column(children: [
        // ── خانة البحث ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو الرقم...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF1c2128),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        // ── القائمة ────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF34d399)))
              : _filtered.isEmpty
                  ? const Center(
                      child: Text('لا يوجد عملاء',
                          style: TextStyle(color: Colors.white38)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: const Color(0xFF34d399),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) =>
                            _CustomerTile(customer: _filtered[i], onRefresh: _load),
                      ),
                    ),
        ),
      ]),
    );
  }

  void _showAddDialog({String prefillPhone = ''}) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: prefillPhone);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('عميل جديد',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _Field(ctrl: nameCtrl, hint: 'الاسم (اختياري)', icon: Icons.person),
          const SizedBox(height: 12),
          _Field(
            ctrl: phoneCtrl,
            hint: '01xxxxxxxxx',
            icon: Icons.phone,
            phone: true,
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () async {
              final phone = phoneCtrl.text.trim();
              if (phone.isEmpty) return;
              Navigator.pop(context);
              await CustomerService.add(phone, name: nameCtrl.text.trim());
              _load();
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF34d399)),
            child: const Text('حفظ', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}

// ── Tile ────────────────────────────────────────────────────────────────────

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  final VoidCallback onRefresh;
  const _CustomerTile({required this.customer, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final initial = customer.name.isNotEmpty
        ? customer.name[0].toUpperCase()
        : '?';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF34d399).withOpacity(0.2),
          child: Text(initial,
              style: const TextStyle(
                  color: Color(0xFF34d399), fontWeight: FontWeight.bold)),
        ),
        title: Text(
          customer.name.isNotEmpty ? customer.name : 'بدون اسم',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(customer.phone,
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 2),
            Row(children: [
              _Chip('${customer.visits} زيارة', Icons.repeat, Colors.blue),
              const SizedBox(width: 8),
              _Chip('${customer.totalSpent.toStringAsFixed(0)} ج',
                  Icons.monetization_on, const Color(0xFF34d399)),
            ]),
          ],
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          // واتساب
          IconButton(
            icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 22),
            onPressed: () => _openWhatsapp(customer.phone),
          ),
          // المزيد
          PopupMenuButton<String>(
            color: const Color(0xFF1c2128),
            icon: const Icon(Icons.more_vert, color: Colors.white38),
            onSelected: (v) async {
              if (v == 'edit') _showEditDialog(context);
              if (v == 'delete') {
                await CustomerService.delete(customer.id);
                onRefresh();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit, color: Colors.white54, size: 18),
                  SizedBox(width: 8),
                  Text('تعديل', style: TextStyle(color: Colors.white)),
                ]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Text('حذف', style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
          ),
        ]),
        onTap: () => _showDetails(context),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1c2128),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 32,
            backgroundColor: const Color(0xFF34d399).withOpacity(0.2),
            child: Text(
              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Color(0xFF34d399),
                  fontSize: 28,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            customer.name.isNotEmpty ? customer.name : 'بدون اسم',
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(customer.phone,
              style: const TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _StatBox('الزيارات', '${customer.visits}', Icons.repeat),
            _StatBox('الإجمالي',
                '${customer.totalSpent.toStringAsFixed(0)} ج',
                Icons.monetization_on),
            _StatBox(
              'آخر زيارة',
              customer.lastVisit.isNotEmpty
                  ? customer.lastVisit.substring(0, 10)
                  : '—',
              Icons.calendar_today,
            ),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.chat),
              label: const Text('واتساب'),
              onPressed: () => _openWhatsapp(customer.phone),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366)),
            ),
          ),
        ]),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: customer.name);
    final phoneCtrl = TextEditingController(text: customer.phone);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تعديل العميل',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _Field(ctrl: nameCtrl, hint: 'الاسم', icon: Icons.person),
          const SizedBox(height: 12),
          _Field(ctrl: phoneCtrl, hint: '01xxxxxxxxx', icon: Icons.phone, phone: true),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () async {
              customer.name = nameCtrl.text.trim();
              customer.phone = phoneCtrl.text.trim();
              await CustomerService.update(customer);
              if (context.mounted) Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF34d399)),
            child: const Text('حفظ', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsapp(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final intl = clean.startsWith('0') ? '2$clean' : clean;
    final uri = Uri.parse('https://wa.me/$intl');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final bool phone;
  const _Field(
      {required this.ctrl,
      required this.hint,
      required this.icon,
      this.phone = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0b0e14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: phone ? TextInputType.phone : TextInputType.text,
        textDirection: phone ? TextDirection.ltr : TextDirection.rtl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24),
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _Chip(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: color, size: 13),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(color: color, fontSize: 11)),
    ]);
  }
}

// ── Picker Sheet ────────────────────────────────────────────────────────────

class _CustomerPickerSheet extends StatefulWidget {
  final List<Customer> customers;
  const _CustomerPickerSheet({required this.customers});

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<Customer> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.customers;
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.customers
          : widget.customers
              .where((c) =>
                  c.name.toLowerCase().contains(q) || c.phone.contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollCtrl) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Text('اختار عميل',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            autofocus: false,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو الرقم...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF0b0e14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text('لا يوجد نتائج',
                        style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    controller: scrollCtrl,
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final c = _filtered[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              const Color(0xFF34d399).withOpacity(0.15),
                          child: Text(
                            c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: Color(0xFF34d399),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(c.name.isNotEmpty ? c.name : 'بدون اسم',
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text(c.phone,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _StatBox(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, color: const Color(0xFF34d399), size: 20),
      const SizedBox(height: 4),
      Text(value,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      Text(label,
          style: const TextStyle(color: Colors.white38, fontSize: 11)),
    ]);
  }
}
