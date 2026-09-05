import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../services/app_state.dart';
import '../services/customer_service.dart';
import '../screens/customers_screen.dart';

/// Dialog اختيار إعدادات تشغيل التربيزة
/// بلياردو: عادي / أمريكاني + وقت مفتوح / وقت محدد
/// بينج:    عادي فقط + وقت مفتوح / وقت محدد / تسجيل جيم مباشر
class TableStartDialog extends StatefulWidget {
  final int tableIndex;
  const TableStartDialog({super.key, required this.tableIndex});

  @override
  State<TableStartDialog> createState() => _TableStartDialogState();
}

class _TableStartDialogState extends State<TableStartDialog> {
  int _step = 0;

  // الخطوة 0 — نوع اللعب (بلياردو فقط: عادي / أمريكاني | بينج: عادي أو جيم)
  String _playMode = 'normal'; // normal | american | game
  bool _pingDirectGame = false; // بينج: تسجيل جيم مباشر بدون تايمر

  // الخطوة 1 — نوع الجلسة (وقت مفتوح / وقت محدد)
  String _timeMode = 'open'; // open | fixed
  int? _selectedSeconds;
  final _customCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  bool _customMinutes = true;
  String? _customerName; // اسم العميل لو موجود
  List<Customer> _customers = [];

  static const List<Map<String, dynamic>> _presets = [
    {'label': '30 د', 'seconds': 1800},
    {'label': '1 س', 'seconds': 3600},
    {'label': '1.5 س', 'seconds': 5400},
    {'label': '2 س', 'seconds': 7200},
    {'label': '3 س', 'seconds': 10800},
  ];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _whatsappCtrl.addListener(_lookupCustomer);
  }

  Future<void> _loadCustomers() async {
    final list = await CustomerService.fetchAll();
    if (mounted) setState(() => _customers = list);
  }

  void _lookupCustomer() {
    final phone = _whatsappCtrl.text.trim();
    if (phone.length >= 8) {
      final match = _customers.where((c) => c.phone == phone).firstOrNull;
      if (mounted) setState(() => _customerName = match?.name);
    } else {
      if (mounted) setState(() => _customerName = null);
    }
  }

  Future<void> _pickCustomer() async {
    final picked = await CustomersScreen.pickCustomer(context);
    if (picked != null && mounted) {
      setState(() {
        _whatsappCtrl.text = picked.phone;
        _customerName = picked.name;
      });
    }
  }

  @override
  void dispose() {
    _whatsappCtrl.removeListener(_lookupCustomer);
    _customCtrl.dispose();
    _whatsappCtrl.dispose();
    super.dispose();
  }

  bool get _canProceed {
    if (_step == 0) return true;
    if (_timeMode == 'open') return true;
    return _selectedSeconds != null && _selectedSeconds! > 0;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final t = state.tables[widget.tableIndex];
    final tableType = t['table_type'] ?? 'ping';
    final isBilliard = tableType == 'billiard';
    final color = isBilliard ? Colors.purple : const Color(0xFF34d399);
    final emoji = isBilliard ? '🎱' : '🏓';
    final typeLabel = isBilliard ? 'بلياردو' : 'بينج';

    // أسعار من AppState
    final normalRate = isBilliard
        ? (state.prices['billiard_normal'] ?? (t['rate'] as num).toInt())
        : (state.prices['ping_normal'] ?? (t['rate'] as num).toInt());
    final americanRate = isBilliard
        ? (state.prices['billiard_american'] ?? (t['rate'] as num).toInt())
        : null;
    final gamePrice = (t['game_price'] as num?)?.toInt() ?? 0;

    return AlertDialog(
      backgroundColor: const Color(0xFF1c2128),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color),
          ),
          child: Text(
            '$emoji $typeLabel',
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            t['name']?.toString() ?? 'تربيزة',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        // مؤشر الخطوات — لو مش جيم مباشر
        if (!_pingDirectGame)
          Row(children: [
            _StepDot(active: _step == 0, done: _step > 0, color: color),
            const SizedBox(width: 4),
            _StepDot(active: _step == 1, done: false, color: color),
          ]),
      ]),
      content: SingleChildScrollView(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _step == 0
              ? _buildStep0(
                  color, isBilliard, normalRate, americanRate, gamePrice)
              : _buildStep1(color),
        ),
      ),
      actions: _buildActions(
          context, state, color, isBilliard, normalRate, americanRate,
          gamePrice),
    );
  }

  // ─── الخطوة 0: اختيار نوع اللعب ───────────────────────────────────────────

  Widget _buildStep0(Color color, bool isBilliard, int normalRate,
      int? americanRate, int gamePrice) {
    if (isBilliard) {
      // بلياردو: عادي | أمريكاني
      return Column(
        key: const ValueKey('step0_billiard'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          const Text('اختار نوع اللعب',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: _ModeChip(
                icon: Icons.person,
                label: 'عادي',
                sub: '$normalRate ج/س',
                selected: _playMode == 'normal',
                color: color,
                onTap: () => setState(() => _playMode = 'normal'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ModeChip(
                icon: Icons.sports_bar,
                label: 'أمريكاني',
                sub: '${americanRate ?? normalRate} ج/س',
                selected: _playMode == 'american',
                color: color,
                onTap: () => setState(() => _playMode = 'american'),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          _buildWhatsappField(),
          const SizedBox(height: 20),
        ],
      );
    } else {
      // بينج: عادي بالوقت | تسجيل جيم مباشر
      return Column(
        key: const ValueKey('step0_ping'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          const Text('اختار نوع الجلسة',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          // جلسة بالوقت
          _ModeChip(
            icon: Icons.timer,
            label: 'جلسة بالوقت',
            sub: '$normalRate ج/س',
            selected: !_pingDirectGame,
            color: color,
            onTap: () => setState(() {
              _pingDirectGame = false;
              _playMode = 'normal';
            }),
          ),
          if (gamePrice > 0) ...[
            const SizedBox(height: 12),
            // تسجيل جيم مباشر
            _ModeChip(
              icon: Icons.sports_tennis,
              label: 'تسجيل جيم',
              sub: '$gamePrice ج/جيم',
              selected: _pingDirectGame,
              color: Colors.amber,
              onTap: () => setState(() {
                _pingDirectGame = true;
                _playMode = 'game';
              }),
            ),
          ],
          const SizedBox(height: 20),
          _buildWhatsappField(),
          const SizedBox(height: 20),
        ],
      );
    }
  }

  Widget _buildWhatsappField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('رقم الواتساب (اختياري)',
            style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0b0e14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _customerName != null ? Colors.green : Colors.white12,
                ),
              ),
              child: TextField(
                controller: _whatsappCtrl,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: '01xxxxxxxxx',
                  hintStyle: TextStyle(color: Colors.white24),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.phone, color: Colors.green, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // زرار اختيار من قائمة العملاء
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF0b0e14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white12)),
            ),
            icon: const Icon(Icons.contacts, color: Colors.white54, size: 22),
            onPressed: _pickCustomer,
          ),
        ]),
        if (_customerName != null && _customerName!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.person_pin, color: Colors.green, size: 14),
            const SizedBox(width: 4),
            Text(_customerName!,
                style: const TextStyle(color: Colors.green, fontSize: 12)),
          ]),
        ],
      ],
    );
  }

  Widget _buildStep1(Color color) {
    return Column(
      key: const ValueKey('step1'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        const Text('اختار نوع الجلسة',
            style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _ModeChip(
              icon: Icons.all_inclusive,
              label: 'مفتوح',
              sub: 'عداد تصاعدي',
              selected: _timeMode == 'open',
              color: const Color(0xFF4ade80),
              onTap: () => setState(() {
                _timeMode = 'open';
                _selectedSeconds = null;
              }),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ModeChip(
              icon: Icons.timer,
              label: 'وقت محدد',
              sub: 'عداد تنازلي',
              selected: _timeMode == 'fixed',
              color: Colors.orange,
              onTap: () => setState(() => _timeMode = 'fixed'),
            ),
          ),
        ]),
        if (_timeMode == 'fixed') ...[
          const SizedBox(height: 16),
          const Text('اختار المدة',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((p) {
              final isSelected = _selectedSeconds == p['seconds'];
              return GestureDetector(
                onTap: () => setState(() => _selectedSeconds = p['seconds']),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.orange.withOpacity(0.2)
                        : const Color(0xFF0b0e14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.orange : Colors.white12,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(p['label'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.orange : Colors.white70,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 14,
                      )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0b0e14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('أو أدخل وقت مخصص',
                  style:
                      TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _customCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: const Color(0xFF1c2128),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
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
                              color: Colors.orange, width: 2)),
                    ),
                    onChanged: (_) {
                      final val = int.tryParse(_customCtrl.text.trim());
                      if (val != null && val > 0) {
                        setState(() {
                          _selectedSeconds =
                              _customMinutes ? val * 60 : val * 3600;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _customMinutes = !_customMinutes;
                      final val =
                          int.tryParse(_customCtrl.text.trim());
                      if (val != null && val > 0) {
                        _selectedSeconds =
                            _customMinutes ? val * 60 : val * 3600;
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.orange.withOpacity(0.5)),
                    ),
                    child: Text(_customMinutes ? 'د' : 'س',
                        style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                ),
              ]),
            ]),
          ),
          if (_selectedSeconds != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.orange.withOpacity(0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.timer, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Text(
                  'الوقت المختار: ${_formatSeconds(_selectedSeconds!)}',
                  style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ]),
            ),
          ],
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  // ─── الأزرار ───────────────────────────────────────────────────────────────

  List<Widget> _buildActions(
      BuildContext context,
      AppState state,
      Color color,
      bool isBilliard,
      int normalRate,
      int? americanRate,
      int gamePrice) {
    // بينج + اختار تسجيل جيم مباشر → زرار واحد فقط
    if (!isBilliard && _pingDirectGame) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text('إلغاء', style: TextStyle(color: Colors.white54)),
        ),
        FilledButton.icon(
          onPressed: gamePrice > 0
              ? () {
                  Navigator.pop(context);
                  state.addTableGameRecord(widget.tableIndex);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('✅ تم تسجيل الجيم ($gamePrice ج)'),
                    backgroundColor: Colors.amber,
                    duration: const Duration(seconds: 2),
                  ));
                }
              : null,
          icon: const Icon(Icons.sports_tennis, size: 18),
          label: Text(
            'تسجيل جيم ($gamePrice ج)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ];
    }

    return [
      if (_step == 1)
        TextButton.icon(
          onPressed: () => setState(() => _step = 0),
          icon: const Icon(Icons.arrow_back, size: 16, color: Colors.white54),
          label:
              const Text('رجوع', style: TextStyle(color: Colors.white54)),
        )
      else
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text('إلغاء', style: TextStyle(color: Colors.white54)),
        ),
      FilledButton.icon(
        onPressed: _canProceed
            ? () {
                if (_step == 0) {
                  setState(() => _step = 1);
                } else {
                  Navigator.pop(context);

                  // احسب السعر الصح حسب نوع اللعب
                  int rateToUse = normalRate;
                  if (_playMode == 'american' && americanRate != null) {
                    rateToUse = americanRate;
                  }

                  state.startTable(
                    widget.tableIndex,
                    playMode: _playMode,
                    countdownSeconds:
                        _timeMode == 'fixed' ? _selectedSeconds : null,
                    customRate: rateToUse,
                    whatsappNumber: _whatsappCtrl.text.trim().isEmpty
                        ? null
                        : _whatsappCtrl.text.trim(),
                  );
                }
              }
            : null,
        icon: Icon(
            _step == 0 ? Icons.arrow_forward : Icons.play_arrow,
            size: 18),
        label: Text(
          _step == 0 ? 'التالي' : 'ابدأ',
          style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _step == 0
              ? color
              : (_timeMode == 'open'
                  ? Colors.green.shade700
                  : (_canProceed ? Colors.orange : Colors.white24)),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ];
  }

  String _formatSeconds(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h > 0 && m > 0) return '$h ساعة و$m دقيقة';
    if (h > 0) return '$h ساعة';
    return '$m دقيقة';
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _StepDot extends StatelessWidget {
  final bool active, done;
  final Color color;
  const _StepDot(
      {required this.active, required this.done, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: active ? 20 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active
            ? color
            : (done ? color.withOpacity(0.5) : Colors.white12),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ModeChip({
    required this.icon,
    required this.label,
    required this.sub,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.12)
              : const Color(0xFF0b0e14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? color : Colors.white12,
              width: selected ? 2 : 1),
        ),
        child: Row(children: [
          Icon(icon,
              color: selected ? color : Colors.white38, size: 24),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    color: selected ? color : Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            Text(sub,
                style: TextStyle(
                    color: selected
                        ? color.withOpacity(0.7)
                        : Colors.white24,
                    fontSize: 11)),
          ]),
        ]),
      ),
    );
  }
}
