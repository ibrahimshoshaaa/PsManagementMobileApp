// lib/widgets/device_transfer_start_dialog.dart

import 'package:flutter/material.dart';

class DeviceTransferStartDialog extends StatefulWidget {
  final bool isPs5;
  final String targetDeviceName;
  final Function(String mode, int? seconds) onConfirm;

  const DeviceTransferStartDialog({
    super.key,
    required this.isPs5,
    required this.targetDeviceName,
    required this.onConfirm,
  });

  @override
  State<DeviceTransferStartDialog> createState() => _DeviceTransferStartDialogState();
}

class _DeviceTransferStartDialogState extends State<DeviceTransferStartDialog> {
  String _playMode = 'single'; // single | multi
  String _timeMode = 'open';   // open | fixed
  int? _selectedSeconds;
  final _customCtrl = TextEditingController();

  static const List<Map<String, dynamic>> _presets = [
    {'label': '30 د', 'seconds': 1800},
    {'label': '1 س', 'seconds': 3600},
    {'label': '1.5 س', 'seconds': 5400},
    {'label': '2 س', 'seconds': 7200},
  ];

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.isPs5 ? Colors.purple : const Color(0xFF38bdf8);

    return AlertDialog(
      backgroundColor: const Color(0xFF1c2128),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.play_circle_fill, color: accentColor),
          const SizedBox(width: 8),
          Text(
            'تشغيل ونقل إلى ${widget.targetDeviceName}',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── القسم الأول: نوع اللعب ───
            const Text('نوع اللعب:', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildOptionTile(
                    icon: Icons.person,
                    label: 'عادي (Single)',
                    selected: _playMode == 'single',
                    color: accentColor,
                    onTap: () => setState(() => _playMode = 'single'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildOptionTile(
                    icon: Icons.people,
                    label: 'مالتي (Multi)',
                    selected: _playMode == 'multi',
                    color: accentColor,
                    onTap: () => setState(() => _playMode = 'multi'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ─── القسم الثاني: نظام الوقت ───
            const Text('نظام الوقت:', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildOptionTile(
                    icon: Icons.all_inclusive,
                    label: 'وقت مفتوح',
                    selected: _timeMode == 'open',
                    color: accentColor,
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
                    color: accentColor,
                    onTap: () => setState(() => _timeMode = 'fixed'),
                  ),
                ),
              ],
            ),

            // ─── خيارات الوقت المحدّد (تظهر فقط لو اختار وقت محدد) ───
            if (_timeMode == 'fixed') ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _presets.map((p) {
                  final isSel = _selectedSeconds == p['seconds'];
                  return ChoiceChip(
                    label: Text(p['label'], style: TextStyle(color: isSel ? Colors.black : Colors.white)),
                    selected: isSel,
                    selectedColor: accentColor,
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
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0b0e14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onChanged: (val) {
                  final mins = int.tryParse(val);
                  setState(() {
                    if (mins != null && mins > 0) {
                      _selectedSeconds = mins * 60;
                    } else {
                      _selectedSeconds = null;
                    }
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
            // التحقق إذا اختار وقت محدد ولم يحدد القيمة
            if (_timeMode == 'fixed' && _selectedSeconds == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('الرجاء تحديد الوقت أولاً')),
              );
              return;
            }
            Navigator.pop(context);
            // إرسال المود والوقت بالثواني للدالة المسؤولة
            widget.onConfirm(_playMode, _selectedSeconds);
          },
          style: FilledButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.black),
          child: const Text('بدء وتشغيل وبدء النقل', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : const Color(0xFF0b0e14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : Colors.white12, width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : Colors.white38, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: selected ? color : Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
