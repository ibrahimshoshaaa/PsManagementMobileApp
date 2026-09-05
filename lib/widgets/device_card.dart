import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/customer.dart';
import '../models/device.dart';
import '../services/app_state.dart';
import '../services/customer_service.dart';
import '../screens/customers_screen.dart';
import 'buffet_order_dialog.dart'; // ✅ إضافة الاستيراد

class DeviceCard extends StatelessWidget {
  final PSDevice device;
  final VoidCallback onTap;
  const DeviceCard(
      {super.key, required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final timePrice = device.calculateTimePrice(state.prices);
    final buffetPrice = device.getBuffetPrice(state.menu);
    final total = timePrice + buffetPrice;
    final isPs5 = device.deviceType == 'ps5';

    Color borderColor;
    if (device.isPaused) {
      borderColor = Colors.amber;
    } else if (device.isActive) {
      borderColor = const Color(0xFF38bdf8);
    } else {
      borderColor = Colors.white.withOpacity(0.1);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: const Color(0xFF1c2128),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: borderColor, width: device.isActive ? 1.5 : 1),
          boxShadow: device.isActive
              ? [
                  BoxShadow(
                      color: (device.isPaused
                              ? Colors.amber
                              : const Color(0xFF38bdf8))
                          .withOpacity(0.2),
                      blurRadius: 12,
                      spreadRadius: 1)
                ]
              : [],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ─── صف العنوان ───────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                    child: Text(device.displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis)),
                // PS4/PS5 badge
                if (device.isActive) ...[
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: device.mode == 'multi'
          ? Colors.orange.withOpacity(0.2)
          : const Color(0xFF4ade80).withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: device.mode == 'multi'
            ? Colors.orange
            : const Color(0xFF4ade80),
      ),
    ),
    child: Text(
      device.mode == 'multi' ? '👥 مالتي' : '👤 عادي',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: device.mode == 'multi'
            ? Colors.orange
            : const Color(0xFF4ade80),
      ),
    ),
  ),
  const SizedBox(width: 4),
],
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPs5
                        ? Colors.purple.withOpacity(0.2)
                        : const Color(0xFF38bdf8).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isPs5
                            ? Colors.purple.withOpacity(0.8)
                            : const Color(0xFF38bdf8).withOpacity(0.8),
                        width: 1.5),
                  ),
                  child: Text(
                    isPs5 ? 'PS5' : 'PS4',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isPs5
                            ? Colors.purple
                            : const Color(0xFF38bdf8)),
                  ),
                ),
              ],
            ),

            // ─── تايمر عداد ──────────────────────────────────────────
            _PulsingTimer(device: device),

            // ─── أسعار ───────────────────────────────────────────────
            Column(
              children: [
                Text(
                    'لعب: ${timePrice.toStringAsFixed(1)} | بوفيه: ${buffetPrice.toStringAsFixed(1)}',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.6))),
                const SizedBox(height: 2),
                Text('${total.toStringAsFixed(1)} ج.م',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4ade80))),
              ],
            ),

            // ─── أزرار ───────────────────────────────────────────────
           if (device.status == 'متاح' && device.orders.isEmpty)
  _StartButton(device: device)
else if (!device.isActive && device.orders.isNotEmpty)
  _MixedButtons(device: device)
else
  _ActiveButtons(device: device),
          ],
        ),
      ),
    );
  }
}

// ─── Pulsing Timer ────────────────────────────────────────────────────────────

class _PulsingTimer extends StatefulWidget {
  final PSDevice device;
  const _PulsingTimer({required this.device});
  @override
  State<_PulsingTimer> createState() => _PulsingTimerState();
}

class _PulsingTimerState extends State<_PulsingTimer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.device.isActive;
    final isPaused = widget.device.isPaused;
    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, child) => Transform.scale(
          scale: isActive && !isPaused ? _anim.value : 1.0,
          child: child),
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(
          widget.device.timerText,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: isPaused ? Colors.amber : Colors.white,
            shadows: isActive
                ? [
                    Shadow(
                        color: (isPaused
                                ? Colors.amber
                                : const Color(0xFF38bdf8))
                            .withOpacity(0.5),
                        blurRadius: 8)
                  ]
                : [],
          ),
        ),
      ),
    );
  }
}

// ─── Match Counter ────────────────────────────────────────────────────────────

class QuickTimeButtons extends StatelessWidget {
  final PSDevice device;
  const QuickTimeButtons({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final matchPrice = state.matchPriceFor(device);
    final type = device.deviceType;
    final mode = device.mode;
    final ratePerHour = state.prices['${type}_$mode'] ?? 25;
    final matchMinutes = ratePerHour > 0
        ? ((matchPrice / ratePerHour) * 60).round()
        : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: matchMinutes > 0
                  ? () {
                      final minAllowed =
                          -(device.elapsedSeconds - device.addedSeconds);
                      final newAdded =
                          device.addedSeconds - (matchMinutes * 60);
                      if (newAdded < minAllowed) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content:
                              Text('⚠️ مينفعش تنقص أكتر من الوقت الحالي'),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 1),
                        ));
                        return;
                      }
                      state.addTime(device, -matchMinutes);
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.4)),
                ),
                child: Column(children: [
                  const Text('−ماتش',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent)),
                  Text('$matchPrice ج',
                      style: const TextStyle(
                          fontSize: 9, color: Colors.white38)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () => _showMatchDialog(context, state, matchPrice, matchMinutes),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF38bdf8).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF38bdf8).withOpacity(0.4)),
                ),
                child: Column(children: [
                  const Icon(Icons.sports_soccer,
                      size: 14, color: Color(0xFF38bdf8)),
                  Text('$matchPrice ج/ماتش',
                      style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF38bdf8),
                          fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: matchMinutes > 0
                  ? () => state.addTime(device, matchMinutes)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4ade80).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF4ade80).withOpacity(0.4)),
                ),
                child: Column(children: [
                  const Text('+ماتش',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4ade80))),
                  Text('$matchPrice ج',
                      style: const TextStyle(
                          fontSize: 9, color: Colors.white38)),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMatchDialog(BuildContext context, AppState state,
      int matchPrice, int matchMinutes) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.sports_soccer, color: Color(0xFF38bdf8)),
          SizedBox(width: 8),
          Text('إضافة / خصم ماتشات',
              style: TextStyle(
                  color: Color(0xFF38bdf8), fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('سعر الماتش: $matchPrice ج  |  مدة الماتش: $matchMinutes د',
              style:
                  const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            autofocus: true,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'عدد الماتشات',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
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
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          OutlinedButton.icon(
            onPressed: () {
              final val = int.tryParse(ctrl.text.trim());
              if (val != null && val > 0) {
                state.addTime(device, -(val * matchMinutes));
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
                state.addTime(device, val * matchMinutes);
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

class _TimeBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _TimeBtn(
      {required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: onTap != null
              ? color.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: onTap != null
                  ? color.withOpacity(0.5)
                  : Colors.white10),
        ),
        child: Center(
            child: Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: onTap != null
                        ? color
                        : Colors.white12))),
      ),
    );
  }
}

// ─── Start Button ─────────────────────────────────────────────────────────────
// ✅ التعديل 1: بيفتح _StartModeDialog بدل ما يبدأ مباشرة

class _StartButton extends StatelessWidget {
  final PSDevice device;
  const _StartButton({required this.device});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: () => _showStartModeDialog(context),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('بدء اللعب', style: TextStyle(fontSize: 13)),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 40,
          height: 38,
          child: OutlinedButton(
            onPressed: () => _showOrderDialog(context),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: BorderSide(color: Colors.orange.withOpacity(0.6)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Icon(Icons.fastfood, color: Colors.orange, size: 18),
          ),
        ),
      ],
    );
  }

  void _showStartModeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _StartModeDialog(device: device),
    );
  }

  void _showOrderDialog(BuildContext context) {
    final state = context.read<AppState>();
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

class _MixedButtons extends StatelessWidget {
  final PSDevice device;
  const _MixedButtons({required this.device});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Row(
      children: [
        // زر بدء اللعب
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => _StartModeDialog(device: device),
            ),
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text('بدء', style: TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 4),
        // زر طلب
        SizedBox(
          width: 34,
          height: 34,
          child: OutlinedButton(
            onPressed: () => showBuffetOrderDialog(
              context: context,
              title: device.displayName,
              getCurrentOrders: () => Map<String, int>.from(device.orders),
              onOrderChanged: (item, diff) =>
                  state.addOrder(device, item, diff),
              accentColor: device.deviceType == 'ps5'
                  ? Colors.purple
                  : const Color(0xFF38bdf8),
            ),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: BorderSide(color: Colors.orange.withOpacity(0.6)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Icon(Icons.fastfood, color: Colors.orange, size: 16),
          ),
        ),
        const SizedBox(width: 4),
        // زر انهاء
        SizedBox(
          width: 34,
          height: 34,
          child: FilledButton(
            onPressed: () => _showStopDialog(context, state),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Icon(Icons.receipt, size: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _showStopDialog(BuildContext context, AppState state) {
    final buffetPrice = device.getBuffetPrice(state.menu);
    final whatsappNumber = device.whatsappNumber;
    final hasWhatsapp =
        whatsappNumber != null && whatsappNumber.isNotEmpty;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('إنهاء ${device.displayName}',
            style: const TextStyle(color: Color(0xFF38bdf8))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (device.orders.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerRight,
              child: Text('🥤 تفاصيل البوفيه',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
            ...device.orders.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('  • ${e.key} ×${e.value}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      Text('${e.value * (state.menu[e.key] ?? 0)} ج',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                )),
          ],
          const Divider(color: Colors.white24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('💰 الإجمالي',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text('${buffetPrice.toStringAsFixed(1)} ج',
                style: const TextStyle(
                    color: Color(0xFF4ade80),
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
          ]),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              state.stopDevice(device);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('تأكيد الإنهاء'),
          ),
          if (hasWhatsapp)
            FilledButton.icon(
              icon: const Icon(Icons.send, size: 16),
              label: const Text('تأكيد وإرسال'),
              onPressed: () async {
                final name = device.displayName;
                final orders = Map<String, int>.from(device.orders);
                final menu = state.menu;
                final shopName = state.shopName;
                state.stopDevice(device);
                Navigator.pop(context);
                await deviceCardLaunchWhatsapp(
                  context: context,
                  phone: whatsappNumber!,
                  shopName: shopName,
                  deviceName: name,
                  elapsed: 0,
                  timeCost: 0,
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
  }
}

// ─── Active Buttons ────────────────────────────────────────────────────────────

class _ActiveButtons extends StatelessWidget {
  final PSDevice device;
  const _ActiveButtons({required this.device});

  // ✅ تم إضافة ميثود الطلب من البوفيه
  void _showOrderDialog(BuildContext context) {
    final state = context.read<AppState>();
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

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Row(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: IconButton(
            key: ValueKey(device.isPaused),
            icon: Icon(
                device.isPaused
                    ? Icons.play_circle_fill
                    : Icons.pause_circle_filled,
                color: device.isPaused
                    ? Colors.amber
                    : const Color(0xFF38bdf8),
                size: 30),
            onPressed: () => state.togglePause(device),
          ),
        ),
        // ✅ زرار البوفيه السريع
        IconButton(
          icon: const Icon(Icons.fastfood, color: Colors.orange, size: 26),
          onPressed: () => _showOrderDialog(context),
        ),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _showStopDialog(context, state),
            icon: const Icon(Icons.receipt, size: 16),
            label: const Text('إنهاء',
                style: TextStyle(fontSize: 13)),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  void _showStopDialog(BuildContext context, AppState state) {
    final timePrice = device.calculateTimePrice(state.prices);
    final buffetPrice = device.getBuffetPrice(state.menu);
    final whatsappNumber = device.whatsappNumber;
    final hasWhatsapp =
        whatsappNumber != null && whatsappNumber.isNotEmpty;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('إنهاء ${device.displayName}',
            style: const TextStyle(color: Color(0xFF38bdf8))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _InfoRow(
                '🎮 اللعب', '${timePrice.toStringAsFixed(1)} ج'),
            if (device.orders.isNotEmpty) ...[
              const Divider(color: Colors.white12),
              const Align(
                alignment: Alignment.centerRight,
                child: Text('🥤 تفاصيل البوفيه',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 12)),
              ),
              ...device.orders.entries.map((e) => _InfoRow(
                    '  • ${e.key} ×${e.value}',
                    '${e.value * (state.menu[e.key] ?? 0)} ج',
                    small: true,
                  )),
            ],
            _InfoRow('🥤 البوفيه (إجمالي)',
                '${buffetPrice.toStringAsFixed(1)} ج'),
            const Divider(color: Colors.white24),
            _InfoRow(
                '💰 الإجمالي',
                '${(timePrice + buffetPrice).toStringAsFixed(1)} ج',
                highlight: true),
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
            },
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700),
            child: const Text('تأكيد الإنهاء'),
          ),
          if (hasWhatsapp)
            FilledButton.icon(
              icon: const Icon(Icons.send, size: 16),
              label: const Text('تأكيد وإرسال'),
              onPressed: () async {
                final name = device.displayName;
                final elapsed = device.elapsedSeconds;
                final orders = Map<String, int>.from(device.orders);
                final menu = state.menu;
                final shopName = state.shopName;
                state.stopDevice(device);
                Navigator.pop(context);
                await deviceCardLaunchWhatsapp(
                  context: context,
                  phone: whatsappNumber!,
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
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final bool small;
  const _InfoRow(this.label, this.value,
      {this.highlight = false, this.small = false});

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
                  color:
                      small ? Colors.white54 : Colors.white)),
          Text(value,
              style: TextStyle(
                  fontSize: highlight ? 18 : (small ? 12 : 14),
                  fontWeight: highlight
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: highlight
                      ? const Color(0xFF4ade80)
                      : (small
                          ? Colors.white54
                          : Colors.white))),
        ],
      ),
    );
  }
}

// ─── _StartModeDialog ─────────────────────────────────────────────────────────
// نفس الـ dialog الموجود في device_detail_screen.dart

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
  String? _customerName; // اسم العميل لو موجود
  List<Customer> _customers = [];

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
          child: Text(
            isPs5 ? 'PS5' : 'PS4',
            style: TextStyle(
                color: accentColor, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.device.displayName,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
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
          child: _step == 0 ? _buildStep0(accentColor, state) : _buildStep1(),
        ),
      ),
      actions: _buildActions(state, accentColor),
    );
  }

  Widget _buildStep0(Color accentColor, AppState state) {
    final type = widget.device.deviceType;
    final normalRate = state.prices['${type}_normal'] ?? (type == 'ps5' ? 40 : 25);
    final multiRate  = state.prices['${type}_multi']  ?? (type == 'ps5' ? 50 : 35);

    return Column(
      key: const ValueKey('step0'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        const Text('اختار نوع اللعب',
            style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
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
        const Text('رقم الواتساب (اختياري)',
            style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
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
            onPressed: () => _pickCustomer(context),
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
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _pickCustomer(BuildContext context) async {
    final picked = await CustomersScreen.pickCustomer(context);
    if (picked != null && mounted) {
      setState(() {
        _whatsappCtrl.text = picked.phone;
        _customerName = picked.name;
      });
    }
  }

  Widget _buildStep1() {
    return Column(
      key: const ValueKey('step1'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        const Text('اختار نوع الجلسة',
            style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
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
              style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.orange.withOpacity(0.2) : const Color(0xFF0b0e14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.orange : Colors.white12,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(p['label'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.orange : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _customCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: const Color(0xFF1c2128),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white12)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white12)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.orange, width: 2)),
                    ),
                    onChanged: (_) {
                      final val = int.tryParse(_customCtrl.text.trim());
                      if (val != null && val > 0) {
                        setState(() {
                          _selectedSeconds = _customMinutes ? val * 60 : val * 3600;
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
                      final val = int.tryParse(_customCtrl.text.trim());
                      if (val != null && val > 0) {
                        _selectedSeconds = _customMinutes ? val * 60 : val * 3600;
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withOpacity(0.5)),
                    ),
                    child: Text(_customMinutes ? 'د' : 'س',
                        style: const TextStyle(
                            color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ]),
            ]),
          ),
          if (_selectedSeconds != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.timer, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Text(
                  'الوقت المختار: ${_formatSeconds(_selectedSeconds!)}',
                  style: const TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14),
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
          icon: const Icon(Icons.arrow_back, size: 16, color: Colors.white54),
          label: const Text('رجوع', style: TextStyle(color: Colors.white54)),
        )
      else
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
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
                    countdownSeconds: _timeMode == 'fixed' ? _selectedSeconds : null,
                    whatsappNumber: _whatsappCtrl.text.trim().isEmpty
                        ? null
                        : _whatsappCtrl.text.trim(),
                  );
                }
              }
            : null,
        icon: Icon(_step == 0 ? Icons.arrow_forward : Icons.play_arrow, size: 18),
        label: Text(
          _step == 0 ? 'التالي' : 'ابدأ',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _step == 0
              ? accentColor
              : (_timeMode == 'open'
                  ? Colors.green.shade700
                  : (_canProceed ? Colors.orange : Colors.white24)),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : const Color(0xFF0b0e14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.white12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? color : Colors.white38, size: 26),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: selected ? color : Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const SizedBox(height: 2),
          Text(sub,
              style: TextStyle(
                  color: selected ? color.withOpacity(0.7) : Colors.white24,
                  fontSize: 10)),
        ]),
      ),
    );
  }
}

// ─── WhatsApp Invoice (نفس منطق device_detail_screen._launchWhatsapp) ────────
// عشان ديالوج الإنهاء اللي جوه كارت الجهاز (في صفحة كل الأجهزة) يبقى فيه
// نفس خيار "تأكيد وإرسال" الموجود في شاشة تفاصيل الجهاز.
Future<void> deviceCardLaunchWhatsapp({
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
      const SnackBar(content: Text('تعذر فتح واتساب'), backgroundColor: Colors.red),
    );
  }
}
