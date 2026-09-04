import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../services/app_state.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});
  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  List<Map<String, dynamic>> _archives = [];
  bool _loading = true;
  String? _shopId;

  @override
  void initState() {
    super.initState();
    _shopId = context.read<AppState>().shopId;
    _load();
  }

  Future<void> _load() async {
    if (_shopId == null) return;
    setState(() => _loading = true);
    try {
      final data = await FirebaseService.get(
          FirebaseService.shopArchivePath(_shopId!));
      if (data != null && data is Map) {
        final list = data.values
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList()
          ..sort((a, b) {
            final da = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(0);
            final db = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(0);
            return db.compareTo(da);
          });
        _archives = list;
      } else {
        _archives = [];
      }
    } catch (e) {
      _archives = [];
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final grandTotal = _archives.fold(0.0, (s, a) => s + (a['total_overall'] ?? 0));
    final grandTime = _archives.fold(0.0, (s, a) => s + (a['total_time'] ?? 0));
    final grandBuffet = _archives.fold(0.0, (s, a) => s + (a['total_buffet'] ?? 0));

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: const Text('الأرشيف الشهري',
            style: TextStyle(color: Color(0xFF38bdf8), fontWeight: FontWeight.bold)),
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.purple),
            tooltip: 'الأرشيف السنوي',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => YearlyArchiveScreen(shopId: _shopId!))),
          ),
          IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white54),
              onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38bdf8)))
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1c2128),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF38bdf8).withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _SumTile('🎮 اللعب', grandTime),
                      Container(width: 1, height: 40, color: Colors.white12),
                      _SumTile('🥤 البوفيه', grandBuffet),
                      Container(width: 1, height: 40, color: Colors.white12),
                      _SumTile('💰 الإجمالي', grandTotal, green: true),
                    ],
                  ),
                ),
                if (_archives.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _confirmYearlyArchive(context, grandTotal, grandTime, grandBuffet),
                        icon: const Icon(Icons.archive),
                        label: const Text('تصفير وحفظ في الأرشيف السنوي'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.purple.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: _archives.isEmpty
                      ? const Center(child: Text('لا يوجد أرشيف', style: TextStyle(color: Colors.white54)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _archives.length,
                          itemBuilder: (ctx, i) => _ArchiveTile(archive: _archives[i]),
                        ),
                ),
              ],
            ),
    );
  }

  void _confirmYearlyArchive(BuildContext ctx, double total, double time, double buffet) {
    if (_shopId == null) return;
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حفظ في الأرشيف السنوي؟',
            style: TextStyle(color: Color(0xFF38bdf8))),
        content: Text(
            'هيتحفظ إجمالي ${total.toStringAsFixed(1)} ج في الأرشيف السنوي وبعدين يتمسح الأرشيف الشامل',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final entry = {
                'archived_on': DateTime.now().toString(),
                'label': 'أرشيف ${DateTime.now().year}',
                'total_time': time,
                'total_buffet': buffet,
                'total_overall': total,
                'sessions_count': _archives.length,
                'sessions': _archives,
              };
             await FirebaseService.push(
    FirebaseService.shopYearlyArchivePath(_shopId!), entry);
            await FirebaseService.delete(
                FirebaseService.shopArchivePath(_shopId!));
            await FirebaseService.set(
                FirebaseService.shopArchivePath(_shopId!), {});
            await _load();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('✅ تم حفظ الأرشيف السنوي'),
                  backgroundColor: Colors.green,
                ));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.purple.shade700),
            child: const Text('حفظ وتصفير'),
          ),
        ],
      ),
    );
  }
}

// ─── Yearly Archive Screen ────────────────────────────────────────────────────

class YearlyArchiveScreen extends StatefulWidget {
  final String shopId;
  const YearlyArchiveScreen({super.key, required this.shopId});
  @override
  State<YearlyArchiveScreen> createState() => _YearlyArchiveScreenState();
}

class _YearlyArchiveScreenState extends State<YearlyArchiveScreen> {
  List<Map<String, dynamic>> _archives = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await FirebaseService.get(
          FirebaseService.shopYearlyArchivePath(widget.shopId));
      if (data != null && data is Map) {
        final list = data.values
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList()
          ..sort((a, b) {
            final da = DateTime.tryParse(a['archived_on']?.toString() ?? '') ?? DateTime(0);
            final db = DateTime.tryParse(b['archived_on']?.toString() ?? '') ?? DateTime(0);
            return db.compareTo(da);
          });
        _archives = list;
      } else {
        _archives = [];
      }
    } catch (e) {
      _archives = [];
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final grandTotal = _archives.fold(0.0, (s, a) => s + (a['total_overall'] ?? 0));
    final grandTime = _archives.fold(0.0, (s, a) => s + (a['total_time'] ?? 0));
    final grandBuffet = _archives.fold(0.0, (s, a) => s + (a['total_buffet'] ?? 0));

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
     appBar: AppBar(
  backgroundColor: const Color(0xFF0b0e14),
  title: const Text('الأرشيف السنوي',
      style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
  leading: const BackButton(color: Colors.white),
  actions: [
    // زر الحذف الجديد
    IconButton(
      icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
      tooltip: 'مسح الأرشيف السنوي',
      onPressed: () => _confirmDeleteAll(context),
    ),
    IconButton(icon: const Icon(Icons.refresh, color: Colors.white54), onPressed: _load),
  ],
),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.purple))
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1c2128),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.purple.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _SumTile('🎮 اللعب', grandTime),
                      Container(width: 1, height: 40, color: Colors.white12),
                      _SumTile('🥤 البوفيه', grandBuffet),
                      Container(width: 1, height: 40, color: Colors.white12),
                      _SumTile('💰 الإجمالي', grandTotal, green: true),
                    ],
                  ),
                ),
                Expanded(
                  child: _archives.isEmpty
                      ? const Center(child: Text('لا يوجد أرشيف سنوي', style: TextStyle(color: Colors.white54)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _archives.length,
                          itemBuilder: (ctx, i) {
                            final a = _archives[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1c2128),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                title: Text(a['label'] ?? 'أرشيف',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                    '${a['sessions_count'] ?? 0} وردية | ${a['archived_on']?.toString().substring(0, 10) ?? ''}',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                trailing: Text('${(a['total_overall'] ?? 0).toStringAsFixed(1)} ج',
                                    style: const TextStyle(color: Color(0xFF4ade80), fontWeight: FontWeight.bold)),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                    child: Column(children: [
                                      _Row('🎮 اللعب', '${(a['total_time'] ?? 0).toStringAsFixed(1)} ج'),
                                      _Row('🥤 البوفيه', '${(a['total_buffet'] ?? 0).toStringAsFixed(1)} ج'),
                                      _Row('عدد الورديات', '${a['sessions_count'] ?? 0}'),
                                    ]),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
  void _confirmDeleteAll(BuildContext ctx) {
  showDialog(
    context: ctx,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1c2128),
      title: const Text('حذف الأرشيف السنوي؟', style: TextStyle(color: Colors.redAccent)),
      content: const Text('هل أنت متأكد من مسح جميع بيانات الأرشيف السنوي نهائياً؟',
          style: TextStyle(color: Colors.white70)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () async {
            Navigator.pop(ctx);
            try {
              // مسح البيانات من Firebase
              await FirebaseService.delete(FirebaseService.shopYearlyArchivePath(widget.shopId));
              // إعادة إنشاء المسار كـ map فارغ لضمان عدم وجود أخطاء في القراءة مستقبلاً
              await FirebaseService.set(FirebaseService.shopYearlyArchivePath(widget.shopId), {});
              
              await _load(); // تحديث الشاشة
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('🗑️ تم مسح الأرشيف السنوي')));
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('خطأ في الحذف'), backgroundColor: Colors.red));
              }
            }
          },
          child: const Text('مسح نهائي'),
        ),
      ],
    ),
  );
}
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _ArchiveTile extends StatelessWidget {
  final Map<String, dynamic> archive;
  const _ArchiveTile({required this.archive});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text('وردية: ${archive['date']?.toString().substring(0, 10) ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        trailing: Text('${(archive['total_overall'] ?? 0).toStringAsFixed(1)} ج',
            style: const TextStyle(color: Color(0xFF4ade80), fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: [
              _Row('🎮 اللعب', '${(archive['total_time'] ?? 0).toStringAsFixed(1)} ج'),
              _Row('🥤 البوفيه', '${(archive['total_buffet'] ?? 0).toStringAsFixed(1)} ج'),
            ]),
          ),
        ],
      ),
    );
  }
}

class _SumTile extends StatelessWidget {
  final String label;
  final double value;
  final bool green;
  const _SumTile(this.label, this.value, {this.green = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        const SizedBox(height: 4),
        Text('${value.toStringAsFixed(1)} ج',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: green ? const Color(0xFF4ade80) : Colors.white)),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
