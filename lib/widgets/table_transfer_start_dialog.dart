// lib/widgets/table_transfer_start_dialog.dart

import 'package:flutter/material.dart';

class TableTransferStartDialog extends StatefulWidget {
  final String tableType;   // 'ping' | 'billiard'
  final String tableName;
  final int ratePerHour;
  final int? gamePrice;     // سعر اللعبة (بلياردو أمريكاني)

  /// onConfirm(playMode, countdownSeconds, customRate)
  final Function(String playMode, int? countdownSeconds, int? customRate) onConfirm;

  const TableTransferStartDialog({
    super.key,
    required this.tableType,
    required this.tableName,
    required this.ratePerHour,
    this.gamePrice,
    required this.onConfirm,
  });

  @override
  State<TableTransferStartDialog> createState() => _TableTransferStartDialogState();
}

class _TableTransferStartDialogState extends State<TableTransferStartDialog> {
  String _playMode = 'normal'; // normal | american (بلياردو فقط)
  String _timeMode = 'open';   // open | fixed
  int? _selectedSeconds;
  final _customCtrl = TextEditingController();

  bool get _isPing => widget.tableType == 'ping';

  static const _accentColor = Color(0xFF34d399);

  static const List<Map<String, dynamic>> _presets = [
    {'label': '30 د', 'seconds': 1800},
    {'label': '1 س',  'seconds': 3600},
    {'label': '1.5 س','seconds': 5400},
    {'label': '2 س',  'seconds': 7200},
  ];

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1c2128),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            _isPing ? Icons.sports_tennis : Icons.circle_outlined,
            color: _accentColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'تشغيل ونقل إلى ${widget.tableName}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── نوع اللعب (بلياردو فقط — عادي / أمريكاني) ───
            if (!_isPing) ...[
              const Text('نوع اللعب:',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _buildOptionTile(
                    icon: Icons.sports_baseball,
                    label: 'عادي',
                    selected: _playMode == 'normal',
                    onTap: () => setState(() => _playMode = 'normal'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildOptionTile(
                    icon: Icons.flag,
                    label: 'أمريكاني',
                    selected: _playMode == 'american',
                    onTap: () => setState(() => _playMode = 'american'),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
            ],

            // ─── السعر المتوقع ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _accentColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('💰 السعر',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  Text(
                    _isPing
                        ? '${widget.ratePerHour} ج/س'
                        : _playMode == 'american' && widget.gamePrice != null
                            ? '${widget.gamePrice} ج/لعبة + ${widget.ratePerHour} ج/س'
                            : '${widget.ratePerHour} ج/س',
                    style: const TextStyle(
                        color: Color(0xFF4ade80),
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── نظام الوقت ───
            const Text('نظام الوقت:',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: _buildOptionTile(
                  icon: Icons.all_inclusive,
                  label: 'وقت مفتوح',
                  selected: _timeMode == 'open',
                  onTap: () => setState(() {
                    _timeMode = 'open';
                    _selectedSeconds = null;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildOptionTile(
                  icon: Icons.timer,
                  label: 'وقت محدد',
                  selected: _timeMode == 'fixed',
                  onTap: () => setState(() => _timeMode = 'fixed'),
                ),
              ),
            ]),

            // ─── خيارات الوقت المحدد ───
            if (_timeMode == 'fixed') ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _presets.map((p) {
                  final isSel = _selectedSeconds == p['seconds'];
                  return ChoiceChip(
                    label: Text(p['label'],
                        style: TextStyle(
                            color: isSel ? Colors.black : Colors.white)),
                    selected: isSel,
                    selectedColor: _accentColor,
                    backgroundColor: const Color(0xFF0b0e14),
                    onSelected: (val) {
                      setState(() {
                        _selectedSeconds = val ? p['seconds'] : null;
                        _customCtrl.clear();
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _customCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'أو اكتب عدد الدقائق يدوياً...',
                  hintStyle:
                      const TextStyle(color: Colors.white38, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0b0e14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                ),
                onChanged: (val) {
                  final mins = int.tryParse(val);
                  setState(() {
                    _selectedSeconds =
                        (mins != null && mins > 0) ? mins * 60 : null;
                  });
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
        ),
        FilledButton(
          onPressed: () {
            if (_timeMode == 'fixed' && _selectedSeconds == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('الرجاء تحديد الوقت أولاً')),
              );
              return;
            }
            Navigator.pop(context);
            final customRate = (!_isPing &&
                    _playMode == 'american' &&
                    widget.gamePrice != null)
                ? widget.gamePrice
                : null;
            widget.onConfirm(_playMode, _selectedSeconds, customRate);
          },
          style: FilledButton.styleFrom(
              backgroundColor: _accentColor, foregroundColor: Colors.black),
          child: const Text('بدء وتشغيل وبدء النقل',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? _accentColor.withOpacity(0.12)
              : const Color(0xFF0b0e14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? _accentColor : Colors.white12,
              width: selected ? 2 : 1),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? _accentColor : Colors.white38, size: 22),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: selected ? _accentColor : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}
