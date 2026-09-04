import 'dart:ui'; // مطلوب لـ FontFeature
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/device.dart';
import '../services/app_state.dart';
import '../widgets/device_card.dart';
import '../widgets/buffet_order_dialog.dart';
import 'qr_screen.dart';

class DeviceDetailScreen extends StatelessWidget {
  final PSDevice device;
  const DeviceDetailScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final timePrice = device.calculateTimePrice(state.prices);
    final buffetPrice = device.getBuffetPrice(state.menu);

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: device.deviceType == 'ps5'
                    ? Colors.purple.withOpacity(0.2)
                    : const Color(0xFF38bdf8).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: device.deviceType == 'ps5'
                        ? Colors.purple
                        : const Color(0xFF38bdf8)),
              ),
              child: Text(
                device.deviceType.toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    color: device.deviceType == 'ps5'
                        ? Colors.purple
                        : const Color(0xFF38bdf8),
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Text(device.displayName,
                style: const TextStyle(
                    color: Color(0xFF38bdf8), fontWeight: FontWeight.bold)),
          ],
        ),
        leading: const BackButton(color: Colors.white),
        // ✅ AppBar actions: فقط QR + pause/resume — باقي الخيارات انتقلت للبوكس
        actions: [
          if (device.isActive) ...[\n            IconButton(\n              icon: Icon(\n                device.whatsappNumber != null && device.whatsappNumber!.isNotEmpty\n                    ? Icons.phone\n                    : Icons.phone_outlined,\n                color: device.whatsappNumber != null && device.whatsappNumber!.isNotEmpty\n                    ? Colors.green\n                    : Colors.white38,\n                size: 24,\n              ),\n              tooltip: 'رقم الواتساب',\n              onPressed: () => _showWhatsappEditDialog(context, state, device),\n            ),
            IconButton(
              icon: const Icon(Icons.qr_code, color: Colors.white54, size: 24),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => QrScreen(device: device))),
              tooltip: 'QR Code',
            ),
            IconButton(
              icon: Icon(
                device.isPaused ? Icons.play_circle_fill : Icons.pause_circle_filled,
                color: device.isPaused ? Colors.amber : const Color(0xFF38bdf8),
                size: 30,
              ),
              onPressed: () => state.togglePause(device),
              tooltip: device.isPaused ? 'استكمال' : 'إيقاف مؤقت',
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ✅ بوكس الوقت المعدّل — أصغر + يحتوي على أزرار الخيارات
            _TimerCard(device: device, timePrice: timePrice, buffetPrice: buffetPrice),
            const SizedBox(height: 16),
            if (!device.isActive) ...[
              const SizedBox(height: 16),
              _StartButtons(device: device),
            ],
            if (device.isActive || device.orders.isNotEmpty) ...[
              const SizedBox(height: 16),
              _StopButton(device: device),
            ],
            const SizedBox(height: 16),
            _BuffetSection(device: device),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ✅ بوكس الوقت المعدّل — أصغر + أزرار الخيارات بداخله
// ══════════════════════════════════════════════════════════════════════════════

class _TimerCard extends StatelessWidget {
  final PSDevice device;
  final double timePrice;
  final double buffetPrice;
  const _TimerCard(
      {required this.device,
      required this.timePrice,
      required this.buffetPrice});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final isPaused = device.isPaused;
    final isActive = device.isActive;
    final accentColor = isPaused ? Colors.amber : const Color(0xFF38bdf8);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isPaused
                ? Colors.amber
                : isActive
                    ? const Color(0xFF38bdf8)
                    : Colors.white12,
            width: 1.5),
        boxShadow: isActive
            ? [
                BoxShadow(
                    color: accentColor.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: 2)
              ]
            : [],
      ),
      child: Column(
        children: [
          // ── صف الحالة ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isPaused
                      ? '⏸ موقوف • ${device.mode == "multi" ? "👥 مالتي" : "👤 عادي"}'
                      : isActive
                          ? '🎮 شغال • ${device.mode == "multi" ? "👥 مالتي" : "👤 عادي"}'
                          : '✅ متاح',
                  style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── التايمر (أصغر) ─────────────────────────────────────────
          Text(
            device.timerText,
            style: TextStyle(
              fontSize: 38, // ✅ أصغر من 52
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: isPaused ? Colors.amber : Colors.white,
              shadows: isActive
                  ? [
                      Shadow(
                          color: accentColor.withOpacity(0.5),
                          blurRadius: 10)
                    ]
                  : [],
            ),
          ),
          const SizedBox(height: 10),

          // ── صف الأسعار (أصغر) ─────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PriceTile('🎮 لعب', timePrice),
              Container(width: 1, height: 32, color: Colors.white12),
              _PriceTile('🥤 بوفيه', buffetPrice),
              Container(width: 1, height: 32, color: Colors.white12),
              _PriceTile('💰 الإجمالي', timePrice + buffetPrice,
                  highlight: true),
            ],
          ),

          // ── الفاصل + أزرار الخيارات (تظهر فقط لما الجهاز شغال) ───
          if (isActive) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 10),

            // ✅ أزرار الخيارات الأربعة
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 1. ضبط التايمر
                _ActionBtn(
                  icon: device.timerAlertMinutes != null
                      ? Icons.alarm_on
                      : Icons.alarm_add,
                  label: device.timerAlertMinutes != null
                      ? '${device.timerAlertMinutes}د'
                      : 'تايمر',
                  color: device.timerAlertMinutes != null
                      ? Colors.amber
                      : Colors.white54,
                  onTap: () => _showTimerDialog(context, state),
                ),

                _VertDivider(),

                // 2. سجل الجلسة
                _ActionBtn(
                  icon: Icons.list_alt,
                  label: 'السجل',
                  color: Colors.tealAccent,
                  onTap: device.sessionLog.isNotEmpty
                      ? () => _showSessionLog(context)
                      : null,
                  disabled: device.sessionLog.isEmpty,
                ),

                _VertDivider(),

                // 3. نقل الجلسة
                _ActionBtn(
                  icon: Icons.swap_horiz,
                  label: 'نقل',
                  color: Colors.orange,
                  onTap: () => _showTransferDialog(context, state),
                ),

                // 4. إلغاء (للأدمن فقط)
                if (state.isAdmin) ...[
                  _VertDivider(),
                  _ActionBtn(
                    icon: Icons.cancel_outlined,
                    label: 'إلغاء',
                    color: Colors.red,
                    onTap: () => _showCancelDialog(context, state),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 10),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 8),

            // ── زرار إضافة/خصم وقت ──────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAddTimeDialog(context, state),
                icon: const Icon(Icons.edit, size: 14, color: Colors.white54),
                label: const Text('إضافة / خصم وقت',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── الميثودات المنقولة من DeviceDetailScreen ──────────────────────────────

  void _showSessionLog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1c2128),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SessionLogSheet(device: device),
    );
  }

  void _showTransferDialog(BuildContext context, AppState state) {
    final availableDevices = state.devices
        .where((d) => d.id != device.id && !d.isActive)
        .toList();

    if (availableDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ مفيش أجهزة متاحة للنقل'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🔄 نقل الجلسة',
            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اختار الجهاز اللي هتنقل عليه:',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            ...availableDevices.map((d) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: d.deviceType == 'ps5'
                          ? Colors.purple.withOpacity(0.2)
                          : const Color(0xFF38bdf8).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: d.deviceType == 'ps5'
                              ? Colors.purple
                              : const Color(0xFF38bdf8)),
                    ),
                    child: Text(d.deviceType.toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            color: d.deviceType == 'ps5'
                                ? Colors.purple
                                : const Color(0xFF38bdf8),
                            fontWeight: FontWeight.bold)),
                  ),
                  title: Text(d.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('متاح',
                      style: TextStyle(color: Colors.green, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context);
                    state.transferSession(device, d);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          '✅ تم النقل من ${device.displayName} إلى ${d.displayName}'),
                      backgroundColor: Colors.green,
                    ));
                  },
                )),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('⚠️ إلغاء الجهاز',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(
            'هيتم إلغاء ${device.displayName} بدون تسجيل في السجلات. متأكد؟',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لأ', style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              state.cancelDevice(device);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('إلغاء الجهاز'),
          ),
        ],
      ),
    );
  }

  void _showTimerDialog(BuildContext context, AppState state) {
    final ctrl = TextEditingController(
        text: device.timerAlertMinutes?.toString() ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.alarm, color: Colors.amber),
          const SizedBox(width: 8),
          Text('تايمر ${device.displayName}',
              style: const TextStyle(
                  color: Colors.amber, fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            autofocus: true,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white),
            decoration: InputDecoration(
              hintText: 'عدد الدقايق',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              suffixText: 'دقيقة',
              suffixStyle: const TextStyle(color: Colors.white54),
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
                      const BorderSide(color: Colors.amber, width: 2)),
            ),
          ),
          const SizedBox(height: 8),
          const Text('هييجيك إشعار على الجهاز لما الوقت يخلص',
              style: TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center),
        ]),
        actions: [
          if (device.timerAlertMinutes != null)
            TextButton(
              onPressed: () {
                state.setDeviceTimer(device, null);
                Navigator.pop(context);
              },
              child:
                  const Text('مسح', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(ctrl.text.trim());
              if (val != null && val > 0) {
                state.setDeviceTimer(device, val);
                Navigator.pop(context);
              }
            },
            style: FilledButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showAddTimeDialog(BuildContext context, AppState state) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.edit, color: Color(0xFF38bdf8)),
          SizedBox(width: 8),
          Text('إضافة / خصم وقت',
              style: TextStyle(
                  color: Color(0xFF38bdf8), fontWeight: FontWeight.bold)),
        ]),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: true,
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'عدد الدقايق',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            suffixText: 'دقيقة',
            suffixStyle: const TextStyle(color: Colors.white54),
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
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          OutlinedButton.icon(
            onPressed: () {
              final val = int.tryParse(ctrl.text.trim());
              if (val != null && val > 0) {
                state.addTime(device, -val);
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.remove, color: Colors.red, size: 16),
            label: const Text('خصم', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red)),
          ),
          FilledButton.icon(
            onPressed: () {
              final val = int.tryParse(ctrl.text.trim());
              if (val != null && val > 0) {
                state.addTime(device, val);
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('إضافة'),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4ade80),
                foregroundColor: Colors.black),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ✅ زرار خيار صغير داخل بوكس الوقت
// ══════════════════════════════════════════════════════════════════════════════

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool disabled;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = disabled ? Colors.white24 : color;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: effectiveColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: effectiveColor.withOpacity(0.35)),
            ),
            child: Icon(icon, color: effectiveColor, size: 18),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: effectiveColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: Colors.white12);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// باقي الويدجتات بدون تغيير
// ══════════════════════════════════════════════════════════════════════════════

class _PriceTile extends StatelessWidget {
  final String label;
  final double value;
  final bool highlight;
  const _PriceTile(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white54)),
        const SizedBox(height: 4),
        Text('${value.toStringAsFixed(1)} ج',
            style: TextStyle(
                fontSize: highlight ? 15 : 13,
                fontWeight:
                    highlight ? FontWeight.bold : FontWeight.normal,
                color:
                    highlight ? const Color(0xFF4ade80) : Colors.white)),
      ],
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final PSDevice device;
  const _ModeSelector({required this.device});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final type = device.deviceType;
    return Row(
      children: [
        _ModeBtn(
            label: 'عادي',
            icon: Icons.person,
            selected: device.mode == 'normal',
            price: state.prices['${type}_normal'] ?? 25,
            onTap: () {
              device.mode = 'normal';
              state.notifyListeners();
            }),
        const SizedBox(width: 12),
        _ModeBtn(
            label: 'مالتي',
            icon: Icons.people,
            selected: device.mode == 'multi',
            price: state.prices['${type}_multi'] ?? 35,
            onTap: () {
              device.mode = 'multi';
              state.notifyListeners();
            }),
      ],
    );
  }
}

class _ModeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final int price;
  final VoidCallback onTap;
  const _ModeBtn(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.price,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF38bdf8).withOpacity(0.15)
                : const Color(0xFF1c2128),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected
                    ? const Color(0xFF38bdf8)
                    : Colors.white12,
                width: selected ? 2 : 1),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected
                      ? const Color(0xFF38bdf8)
                      : Colors.white54),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: selected
                          ? const Color(0xFF38bdf8)
                          : Colors.white)),
              Text('$price ج/س',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white54)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartButtons extends StatelessWidget {
  final PSDevice device;
  const _StartButtons({required this.device});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final matchEnabled = state.matchEnabled;
    final matchPrice = state.matchPriceFor(device);

    return Column(children: [
      if (matchEnabled) ...[
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => _showMatchModeDialog(context, state),
            icon: const Icon(Icons.sports_soccer,
                color: Color(0xFF4ade80)),
            label: Text('+ ماتش  ($matchPrice ج)',
                style: const TextStyle(
                    color: Color(0xFF4ade80),
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(
                  color: Color(0xFF4ade80), width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
      SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: () => _showStartModeDialog(context, state),
          icon: const Icon(Icons.play_arrow),
          label: const Text('بدء اللعب', style: TextStyle(fontSize: 18)),
          style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16))),
        ),
      ),
    ]);
  }

    void _showMatchModeDialog(BuildContext context, AppState state) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1c2128),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [
        Icon(Icons.sports_soccer, color: Color(0xFF4ade80)),
        SizedBox(width: 8),
        Text('نوع الماتش', style: TextStyle(color: Color(0xFF4ade80), fontWeight: FontWeight.bold)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _MatchModeBtn(
          label: 'فردي (Normal)',
          icon: Icons.person,
          color: const Color(0xFF38bdf8),
          onTap: () {
            Navigator.pop(context);
            device.mode = 'normal';
            _recordMatch(context, state);
          },
        ),
        const SizedBox(height: 10),
        _MatchModeBtn(
          label: 'مالتي (Multi)',
          icon: Icons.people,
          color: Colors.orange,
          onTap: () {
            Navigator.pop(context);
            device.mode = 'multi';
            _recordMatch(context, state);
          },
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
        ),
      ],
    ),
  );
}

  void _recordMatch(BuildContext context, AppState state) {
  final matchPrice = state.matchPriceFor(device);
  state.addMatchRecord(device);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text('✅ تم تسجيل ماتش (${device.mode == 'multi' ? 'مالتي' : 'فردي'}) — $matchPrice ج'),
    backgroundColor: Colors.green,
    duration: const Duration(seconds: 2),
  ));
}

  void _showStartModeDialog(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (_) => _StartModeDialog(device: device),
    );
  }
}

class _BuffetSection extends StatelessWidget {
  final PSDevice device;
  const _BuffetSection({required this.device});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final hasOrders = device.orders.isNotEmpty;
    final buffetTotal = device.getBuffetPrice(state.menu);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasOrders ? Colors.orange.withOpacity(0.4) : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🥤 البوفيه',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              if (hasOrders)
                Text(
                  '${buffetTotal.toStringAsFixed(1)} ج',
                  style: const TextStyle(
                      color: Color(0xFF4ade80),
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
            ],
          ),
          if (hasOrders) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: device.orders.entries.map((e) {
                final price = state.menu[e.key] ?? 0;
                return GestureDetector(
                  onTap: () => state.addOrder(device, e.key, -1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withOpacity(0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                        '${e.key}  ×${e.value}',
                        style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${e.value * price} ج',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.remove_circle_outline,
                          color: Colors.redAccent, size: 15),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            const Text(
              'اضغط على الصنف لإزالة واحدة',
              style: TextStyle(color: Colors.white24, fontSize: 10),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: state.menu.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text('لا يوجد منتجات في البوفيه',
                          style: TextStyle(color: Colors.white38, fontSize: 13)),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: () => _showAddOrderDialog(context, state),
                    icon: const Icon(Icons.add_shopping_cart,
                        color: Colors.orange, size: 18),
                    label: Text(
                      hasOrders ? 'إضافة المزيد' : 'إضافة طلب',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showWhatsappEditDialog(BuildContext context, AppState state, PSDevice device) {
    final ctrl = TextEditingController(text: device.whatsappNumber ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.phone, color: Colors.green, size: 20),
          SizedBox(width: 8),
          Text('رقم الواتساب', style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0b0e14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: const InputDecoration(
              hintText: '01xxxxxxxxx',
              hintStyle: TextStyle(color: Colors.white24),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.phone, color: Colors.green, size: 20),
            ),
          ),
        ),
        actions: [
          if (device.whatsappNumber != null && device.whatsappNumber!.isNotEmpty)
            TextButton(
              onPressed: () {
                device.whatsappNumber = null;
                state.notifyListeners();
                Navigator.pop(context);
              },
              child: const Text('حذف الرقم', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () {
              device.whatsappNumber = ctrl.text.trim().isEmpty ? null : ctrl.text.trim();
              state.notifyListeners();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showAddOrderDialog(BuildContext context, AppState state) {
    showBuffetOrderDialog(
      context: context,
      title: device.displayName,
      getCurrentOrders: () => Map<String, int>.from(device.orders),
      onOrderChanged: (item, diff) => state.addOrder(device, item, diff),
      accentColor: device.deviceType == 'ps5'
          ? Colors.purple
          : const Color(0xFF38bdf8),
    );
  }
}

class _StopButton extends StatelessWidget {
  final PSDevice device;
  const _StopButton({required this.device});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final timePrice = device.calculateTimePrice(state.prices);
    final buffetPrice = device.getBuffetPrice(state.menu);

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF1c2128),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text('إنهاء ${device.displayName}',
                  style:
                      const TextStyle(color: Color(0xFF38bdf8))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (device.isActive)
                    _Row('🎮 اللعب', '${timePrice.toStringAsFixed(1)} ج'),
                  if (device.orders.isNotEmpty) ...[
                    const Divider(color: Colors.white12),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text('🥤 تفاصيل البوفيه',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ),
                    ...device.orders.entries.map((e) => _Row(
                          '  • ${e.key} ×${e.value}',
                          '${e.value * (state.menu[e.key] ?? 0)} ج',
                          small: true,
                        )),
                  ],
                  _Row('🥤 البوفيه (إجمالي)',
                      '${buffetPrice.toStringAsFixed(1)} ج'),
                  const Divider(color: Colors.white24),
                  _Row('💰 الإجمالي',
                      '${(timePrice + buffetPrice).toStringAsFixed(1)} ج',
                      bold: true),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء',
                        style: TextStyle(color: Colors.white54))),
                FilledButton(
                  onPressed: () {
                    state.stopDevice(device);
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700),
                  child: const Text('تأكيد'),
                ),
                if (device.whatsappNumber != null &&
                    device.whatsappNumber!.isNotEmpty)
                  FilledButton.icon(
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('تأكيد وإرسال'),
                    onPressed: () async {
                      final phone = device.whatsappNumber!;
                      final name = device.displayName;
                      final elapsed = device.elapsedSeconds;
                      final orders = Map<String, int>.from(device.orders);
                      final menu = state.menu;
                      final shopName = state.shopName;
                      state.stopDevice(device);
                      Navigator.pop(context);
                      Navigator.pop(context);
                      await _launchWhatsapp(
                        context: context,
                        phone: phone,
                        shopName: shopName,
                        deviceName: name,
                        elapsed: elapsed,
                        timeCost: timePrice,
                        buffetCost: buffetPrice,
                        orders: orders,
                        menu: menu,
                      );
                    },
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white),
                  ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.receipt_long),
        label:
            const Text('إنهاء وحساب', style: TextStyle(fontSize: 18)),
        style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16))),
      ),
    );
  }
}

Future<void> _launchWhatsapp({
  required BuildContext context,
  required String phone,
  required String shopName,
  required String deviceName,
  required int elapsed,
  required double timeCost,
  required double buffetCost,
  required Map<String, int> orders,
  required Map<String, int> menu,
}) async {
  final h = elapsed ~/ 3600;
  final m = (elapsed % 3600) ~/ 60;
  final durationStr = h > 0 ? '${h}س ${m}د' : '${m}د';

  final buf = StringBuffer();
  buf.writeln('🎮 *$shopName*');
  buf.writeln('─────────────────');
  buf.writeln('📍 *$deviceName*');
  buf.writeln('');
  buf.writeln('⏱ *مدة اللعب:* $durationStr');
  buf.writeln('💵 *حساب الوقت:* ${timeCost.toStringAsFixed(1)} ج');

  if (orders.isNotEmpty) {
    buf.writeln('');
    buf.writeln('🥤 *الأصناف والمشروبات:*');
    orders.forEach((item, qty) {
      final price = (menu[item] ?? 0) * qty;
      buf.writeln('  • $item × $qty = ${price.toStringAsFixed(1)} ج');
    });
    buf.writeln('💵 *إجمالي المشروبات:* ${buffetCost.toStringAsFixed(1)} ج');
  }

  buf.writeln('');
  buf.writeln('─────────────────');
  buf.writeln('💰 *المطلوب: ${(timeCost + buffetCost).toStringAsFixed(1)} ج*');
  buf.writeln('');
  buf.writeln('🌟 نورتونا، يارب تعود تاني! 🌟');

  final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
  final intlPhone = cleanPhone.startsWith('0') ? '2$cleanPhone' : cleanPhone;
  final encoded = Uri.encodeComponent(buf.toString());
  final uri = Uri.parse('https://wa.me/$intlPhone?text=$encoded');

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('تعذر فتح واتساب'),
          backgroundColor: Colors.red),
    );
  }
}
  final String label;
  final String value;
  final bool bold;
  final bool small;
  const _Row(this.label, this.value, {this.bold = false, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: small ? 12 : 14,
                  color: small ? Colors.white54 : Colors.white)),
          Text(value,
              style: TextStyle(
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal,
                  fontSize: bold ? 18 : (small ? 12 : 14),
                  color: bold
                      ? const Color(0xFF4ade80)
                      : (small ? Colors.white54 : Colors.white))),
        ],
      ),
    );
  }
}

// ─── Session Log Sheet ────────────────────────────────────────────────────────

class _SessionLogSheet extends StatelessWidget {
  final PSDevice device;
  const _SessionLogSheet({required this.device});

  @override
  Widget build(BuildContext context) {
    final log = device.sessionLog.reversed.toList();
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.list_alt, color: Colors.tealAccent, size: 20),
            const SizedBox(width: 8),
            Text(
              'سجل جلسة ${device.displayName}',
              style: const TextStyle(
                  color: Colors.tealAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            '${log.length} حدث مسجّل',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const Divider(color: Colors.white12, height: 20),
          Expanded(
            child: log.isEmpty
                ? const Center(
                    child: Text('لا يوجد أحداث بعد',
                        style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    itemCount: log.length,
                    itemBuilder: (ctx, i) {
                      return _LogEventTile(event: log[i]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LogEventTile extends StatelessWidget {
  final Map<String, dynamic> event;
  const _LogEventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final type = event['type'] as String;
    final time = event['time'] as String? ?? '';
    final note = event['note'] as String? ?? '';
    final role = event['role'] as String? ?? '';

    IconData icon;
    Color color;
    switch (type) {
      case 'start':
        icon = Icons.play_arrow_rounded;
        color = Colors.green;
        break;
      case 'pause':
        icon = Icons.pause_rounded;
        color = Colors.amber;
        break;
      case 'resume':
        icon = Icons.play_circle_fill;
        color = const Color(0xFF38bdf8);
        break;
      case 'add_time':
        final minutes = event['minutes'] as int? ?? 0;
        icon = minutes > 0 ? Icons.add_circle : Icons.remove_circle;
        color = minutes > 0 ? const Color(0xFF4ade80) : Colors.redAccent;
        break;
      case 'stop':
        icon = Icons.stop_circle_outlined;
        color = Colors.red;
        break;
      default:
        icon = Icons.info_outline;
        color = Colors.white54;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                if (role.isNotEmpty)
                  Text(role,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
              ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(time,
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ),
      ]),
    );
  }
}

// ─── _StartModeDialog ─────────────────────────────────────────────────────────

class _StartModeDialog extends StatefulWidget {
  final PSDevice device;
  const _StartModeDialog({required this.device});

  @override
  State<_StartModeDialog> createState() => _StartModeDialogState();
}

class _StartModeDialogState extends State<_StartModeDialog> {
  int _step = 0;
  String _playMode = 'normal';
  String _timeMode = 'open';
  int? _selectedSeconds;
  final _customCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  bool _customMinutes = true;

  static const List<Map<String, dynamic>> _presets = [
    {'label': '30 د',  'seconds': 1800},
    {'label': '1 س',   'seconds': 3600},
    {'label': '1.5 س', 'seconds': 5400},
    {'label': '2 س',   'seconds': 7200},
    {'label': '3 س',   'seconds': 10800},
  ];

  @override
  void dispose() {
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
    final isPs5 = widget.device.deviceType == 'ps5';
    final accentColor = isPs5 ? Colors.purple : const Color(0xFF38bdf8);

    return AlertDialog(
      backgroundColor: const Color(0xFF1c2128),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accentColor),
          ),
          child: Text(isPs5 ? 'PS5' : 'PS4',
              style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(widget.device.displayName,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ),
        Row(children: [
          _StepDot(active: _step == 0, done: _step > 0, color: accentColor),
          const SizedBox(width: 4),
          _StepDot(active: _step == 1, done: false, color: accentColor),
        ]),
      ]),
      content: SingleChildScrollView(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _step == 0
              ? _buildStep0(accentColor, state)
              : _buildStep1(),
        ),
      ),
      actions: _buildActions(state, accentColor),
    );
  }

  Widget _buildStep0(Color accentColor, AppState state) {
    final type = widget.device.deviceType;
    final normalRate =
        state.prices['${type}_normal'] ?? (type == 'ps5' ? 40 : 25);
    final multiRate =
        state.prices['${type}_multi'] ?? (type == 'ps5' ? 50 : 35);

    return Column(
      key: const ValueKey('step0'),
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
              label: 'فردي',
              sub: '$normalRate ج/س',
              selected: _playMode == 'normal',
              color: accentColor,
              onTap: () => setState(() => _playMode = 'normal'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ModeChip(
              icon: Icons.people,
              label: 'مالتي',
              sub: '$multiRate ج/س',
              selected: _playMode == 'multi',
              color: accentColor,
              onTap: () => setState(() => _playMode = 'multi'),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        // ── خانة رقم الواتساب (اختياري) ──────────────────────────────
        const Text('رقم الواتساب (اختياري)',
            style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0b0e14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
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
        const SizedBox(height: 20),
      ],
    );
  }
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
              label: 'لعب مفتوح',
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
                onTap: () =>
                    setState(() => _selectedSeconds = p['seconds']),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
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
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                border:
                    Border.all(color: Colors.orange.withOpacity(0.4)),
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

  List<Widget> _buildActions(AppState state, Color accentColor) {
    return [
      if (_step == 1)
        TextButton.icon(
          onPressed: () => setState(() => _step = 0),
          icon: const Icon(Icons.arrow_back,
              size: 16, color: Colors.white54),
          label: const Text('رجوع',
              style: TextStyle(color: Colors.white54)),
        )
      else
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء',
              style: TextStyle(color: Colors.white54)),
        ),
      FilledButton.icon(
        onPressed: _canProceed
            ? () {
                if (_step == 0) {
                  setState(() => _step = 1);
                } else {
                  Navigator.pop(context);
                  widget.device.mode = _playMode;
                  state.startDevice(
                    widget.device,
                    _playMode,
                    countdownSeconds:
                        _timeMode == 'fixed' ? _selectedSeconds : null,
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
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _step == 0
              ? accentColor
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

class _StepDot extends StatelessWidget {
  final bool active;
  final bool done;
  final Color color;
  const _StepDot({required this.active, required this.done, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: active ? 20 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active
            ? color
            : done
                ? color.withOpacity(0.5)
                : Colors.white12,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _MatchModeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _MatchModeBtn({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
      ),
    );
  }
}


class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
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
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.12)
              : const Color(0xFF0b0e14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.white12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(children: [
          Icon(icon,
              color: selected ? color : Colors.white38, size: 26),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: selected ? color : Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const SizedBox(height: 2),
          Text(sub,
              style: TextStyle(
                  color: selected
                      ? color.withOpacity(0.7)
                      : Colors.white24,
                  fontSize: 10)),
        ]),
      ),
    );
  }
}
