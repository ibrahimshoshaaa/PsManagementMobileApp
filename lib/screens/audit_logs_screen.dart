// lib/screens/audit_logs_screen.dart
//
// شاشة سجل الأحداث — للأدمن فقط
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../services/app_state.dart';
import '../services/audit_log_service.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _searchQuery = '';
  String _selectedFilter = 'الكل'; // فلتر حسب النوع
  final _searchCtrl = TextEditingController();

  // الفلاتر المتاحة
  static const _filters = [
    'الكل',
    'الأجهزة',
    'التربيزات',
    'البوفيه',
    'المديونيات',
    'الشيفتات',
    'الإعدادات',
    'البطولات',
    'دخول/خروج',
   'المصروفات',
  ];

  // ربط اسم الفلتر بالـ action names
  static const _filterMap = {
    'الأجهزة': ['deviceStart', 'deviceStop', 'deviceCancel', 'devicePause',
      'deviceResume', 'deviceAddTime', 'deviceTransfer', 'deviceTimerSet',
      'deviceModeChange', 'matchRecorded'],
    'المصروفات': ['expenseAdded', 'expenseDeleted', 'expenseUpdated'],
    'التربيزات': ['tableStart', 'tableStop', 'tableCancel', 'tablePause',
      'tableResume', 'tableGameRecord', 'tableOrderAdded', 'tableOrderRemoved',
      'drinkTableOrderAdded', 'drinkTableOrderRemoved', 'drinkTableCheckout',
      'drinkTableTransfer'],
    'البوفيه': ['buffetItemAdded', 'buffetItemRemoved'],
    'المديونيات': ['debtAdded', 'debtPaid', 'debtPartialPaid',
      'debtAmountAdded', 'debtDeleted'],
    'الشيفتات': ['shiftStarted', 'shiftEnded', 'dayArchived',
      'yearlyArchiveSaved'],
    'الإعدادات': ['pricesUpdated', 'menuItemAdded', 'menuItemUpdated',
      'menuItemDeleted', 'deviceAdded', 'deviceRemoved', 'deviceRenamed',
      'tableAdded', 'tableRemoved', 'drinkTableAdded', 'drinkTableRemoved',
      'passwordChanged', 'cashierAdded', 'cashierRemoved', 'shopNameChanged',
      'matchToggled', 'inventoryUpdated'],
    'البطولات': ['tournamentCreated', 'tournamentDeleted',
      'tournamentPlayerAdded', 'tournamentPlayerRemoved',
      'tournamentMatchResult', 'tournamentEnded'],
    'دخول/خروج': ['login', 'logout'],
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final shopId = context.read<AppState>().shopId;
    if (shopId == null) return;
    setState(() => _loading = true);

    try {
      final data = await FirebaseService.get('shops/$shopId/activity_logs');
      if (data != null && data is Map) {
        final list = data.entries.map((e) {
          final v = Map<String, dynamic>.from(e.value as Map);
          v['_key'] = e.key;
          return v;
        }).toList();

        // ترتيب من الأحدث للأقدم
        list.sort((a, b) {
          final ta = (a['timestamp_ms'] as num?)?.toInt() ?? 0;
          final tb = (b['timestamp_ms'] as num?)?.toInt() ?? 0;
          return tb.compareTo(ta);
        });

        _logs = list;
      } else {
        _logs = [];
      }
    } catch (_) {
      _logs = [];
    }

    _applyFilter();
    setState(() => _loading = false);
  }

  void _applyFilter() {
    var result = List<Map<String, dynamic>>.from(_logs);

    // فلتر النوع
    if (_selectedFilter != 'الكل') {
      final allowed = _filterMap[_selectedFilter] ?? [];
      result = result
          .where((l) => allowed.contains(l['action']?.toString()))
          .toList();
    }

    // فلتر البحث
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((l) {
        final details = l['action_details']?.toString().toLowerCase() ?? '';
        final cashier = l['cashier_name']?.toString().toLowerCase() ?? '';
        return details.contains(q) || cashier.contains(q);
      }).toList();
    }

    _filtered = result;
  }

  Future<void> _confirmClearAll() async {
    final shopId = context.read<AppState>().shopId;
    if (shopId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('مسح كل السجلات؟',
            style: TextStyle(color: Colors.red)),
        content: const Text(
          'هيتم حذف كل سجلات الأحداث نهائياً ولا هيرجعوا',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('مسح'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseService.delete('shops/$shopId/activity_logs');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: Row(children: [
          const Icon(Icons.history_edu, color: Color(0xFF38bdf8), size: 20),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'سجل الأحداث',
              style: TextStyle(
                  color: Color(0xFF38bdf8),
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
            if (!_loading)
              Text(
                '${_filtered.length} من ${_logs.length} حدث',
                style:
                    const TextStyle(color: Colors.white38, fontSize: 11),
              ),
          ]),
        ]),
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: _load,
          ),
          if (_logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              tooltip: 'مسح الكل',
              onPressed: _confirmClearAll,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── شريط البحث ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'بحث في السجل...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon:
                            const Icon(Icons.close, color: Colors.white38),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _searchQuery = '';
                            _applyFilter();
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1c2128),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() {
                _searchQuery = v;
                _applyFilter();
              }),
            ),
          ),

          // ── فلاتر النوع ───────────────────────────────────────────────
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _filters.length,
              itemBuilder: (ctx, i) {
                final f = _filters[i];
                final selected = _selectedFilter == f;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedFilter = f;
                    _applyFilter();
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF38bdf8).withOpacity(0.2)
                          : const Color(0xFF1c2128),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF38bdf8)
                            : Colors.white12,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      f,
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFF38bdf8)
                            : Colors.white54,
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // ── القائمة ───────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF38bdf8)))
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.history_toggle_off,
                                size: 64, color: Colors.white12),
                            const SizedBox(height: 12),
                            Text(
                              _logs.isEmpty
                                  ? 'لا يوجد سجلات بعد'
                                  : 'لا يوجد نتائج',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) =>
                            _LogTile(log: _filtered[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Log Tile ─────────────────────────────────────────────────────────────────

class _LogTile extends StatelessWidget {
  final Map<String, dynamic> log;
  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final action = log['action']?.toString() ?? '';
    final details = log['action_details']?.toString() ?? '';
    final cashier = log['cashier_name']?.toString() ?? '';
    final role = log['role']?.toString() ?? 'cashier';
    final tsMs = (log['timestamp_ms'] as num?)?.toInt();
    final tsStr = log['timestamp']?.toString() ?? '';

    final color = _colorForAction(action);
    final icon = _iconForAction(action);

    // تنسيق الوقت
   String timeLabel = '';
if (tsMs != null) {
  final dt = DateTime.fromMillisecondsSinceEpoch(tsMs);
  timeLabel =
      '${dt.day}/${dt.month}/${dt.year}\n${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
} else if (tsStr.length >= 16) {
  timeLabel = tsStr.substring(0, 10).replaceAll('-', '/') +
      '\n' + tsStr.substring(11, 16);
}
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // أيقونة الحدث
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),

        // التفاصيل
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(
              details,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Row(children: [
              // الكاشير
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: (role == 'admin'
                          ? Colors.amber
                          : const Color(0xFF38bdf8))
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  cashier,
                  style: TextStyle(
                    color: role == 'admin'
                        ? Colors.amber
                        : const Color(0xFF38bdf8),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]),
          ]),
        ),

        // الوقت
        Text(
  timeLabel,
  textAlign: TextAlign.end,
  style: const TextStyle(color: Colors.white38, fontSize: 10),
),
      ]),
    );
  }

  Color _colorForAction(String action) {
    if (action.startsWith('device') || action == 'matchRecorded') {
      return const Color(0xFF38bdf8);
    }
    if (action.startsWith('expense')) return Colors.redAccent;
    if (action.startsWith('table') || action.startsWith('drinkTable')) {
      return const Color(0xFF34d399);
    }
    if (action.startsWith('buffet')) return Colors.orange;
    if (action.startsWith('debt')) return Colors.redAccent;
    if (action.startsWith('shift') ||
        action.startsWith('day') ||
        action.startsWith('yearly')) return Colors.purple;
    if (action.startsWith('tournament')) return const Color(0xFFfbbf24);
    if (action == 'login' || action == 'logout') return Colors.teal;
    return Colors.white38; // إعدادات وغيرها
  }

  IconData _iconForAction(String action) {
    if (action == 'deviceStart') return Icons.play_arrow_rounded;
    if (action == 'deviceStop') return Icons.stop_circle_outlined;
    if (action == 'deviceCancel') return Icons.cancel_outlined;
    if (action == 'devicePause') return Icons.pause_circle_outlined;
    if (action == 'deviceResume') return Icons.play_circle_fill;
    if (action == 'deviceAddTime') return Icons.edit;
    if (action == 'deviceTransfer') return Icons.swap_horiz;
    if (action == 'matchRecorded') return Icons.sports_soccer;
    if (action.startsWith('buffet')) return Icons.fastfood;
    if (action.startsWith('table')) return Icons.table_bar;
    if (action.startsWith('drinkTable')) return Icons.local_drink;
    if (action.startsWith('debt')) return Icons.money_off;
    if (action == 'shiftStarted') return Icons.play_circle_outline;
    if (action == 'shiftEnded') return Icons.stop_circle;
    if (action.startsWith('day') || action.startsWith('yearly')) {
      return Icons.archive_outlined;
    }
    if (action == 'expenseAdded')   return Icons.add_circle_outline;
  if (action == 'expenseDeleted') return Icons.delete_outline;
  if (action == 'expenseUpdated') return Icons.edit;
    if (action.startsWith('tournament')) return Icons.emoji_events;
    if (action == 'login') return Icons.login;
    if (action == 'logout') return Icons.logout;
    if (action.contains('Added') || action.contains('Created')) {
      return Icons.add_circle_outline;
    }
    if (action.contains('Removed') || action.contains('Deleted')) {
      return Icons.delete_outline;
    }
    if (action.contains('Updated') || action.contains('Changed')) {
      return Icons.settings;
    }
    return Icons.history;
  }
}
