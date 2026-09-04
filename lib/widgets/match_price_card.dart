// ═══════════════════════════════════════════════════════════════════════════
// PATCH for settings_screen.dart → _DeviceSettingsScreen
//
// Replace the "⚽ الماتش" section (the _SectionHeader + 2 cards) with
// the widget below.
// ═══════════════════════════════════════════════════════════════════════════

// ─── Match Prices Section ─────────────────────────────────────────────────────
// استبدل القسم القديم بالكود ده في _DeviceSettingsScreen.build()

/*
  // ─── الماتش ────────────────────────────────────────────────
  _SectionHeader('⚽ الماتش'),
  const SizedBox(height: 8),
  // PS4 match card
  _MatchPriceCard(deviceType: 'ps4'),
  const SizedBox(height: 8),
  // PS5 match card
  _MatchPriceCard(deviceType: 'ps5'),
  const SizedBox(height: 8),
  // toggle
  Container( ... Switch matchEnabled ... ),
*/

// ── كارت سعر الماتش ──────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';

class MatchPriceCard extends StatelessWidget {
  final String deviceType; // 'ps4' or 'ps5'
  const MatchPriceCard({super.key, required this.deviceType});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isPs5  = deviceType == 'ps5';
    final color  = isPs5 ? Colors.purple : const Color(0xFF38bdf8);
    final label  = isPs5 ? 'PS5' : 'PS4';

    final normalPrice = state.prices['match_${deviceType}_normal'] ?? (isPs5 ? 15 : 10);
    final multiPrice  = state.prices['match_${deviceType}_multi']  ?? (isPs5 ? 20 : 15);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ─────────────────────────────────────────────────────────
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color),
            ),
            child: Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.sports_soccer,
              color: Color(0xFF4ade80), size: 18),
          const SizedBox(width: 4),
          const Text('أسعار الماتش',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
        const SizedBox(height: 12),
        // ── Two buttons ───────────────────────────────────────────────────
        Row(children: [
          // فردي
          Expanded(
            child: _PriceBtn(
              label: '👤 فردي',
              price: normalPrice,
              color: color,
              onTap: () => _showEditDialog(
                  context, state, '${label} فردي', 'match_${deviceType}_normal', normalPrice, color),
            ),
          ),
          const SizedBox(width: 10),
          // مالتي
          Expanded(
            child: _PriceBtn(
              label: '👥 مالتي',
              price: multiPrice,
              color: color,
              onTap: () => _showEditDialog(
                  context, state, '${label} مالتي', 'match_${deviceType}_multi', multiPrice, color),
            ),
          ),
        ]),
      ]),
    );
  }

  void _showEditDialog(BuildContext context, AppState state,
      String title, String priceKey, int current, Color color) {
    final ctrl = TextEditingController(text: '$current');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.sports_soccer, color: color),
          const SizedBox(width: 8),
          Text('سعر ماتش $title',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: true,
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'السعر',
            hintStyle: const TextStyle(color: Colors.white38),
            suffixText: 'ج/ماتش',
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
                borderSide: BorderSide(color: color, width: 2)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim());
              if (v != null && v > 0) {
                final newPrices = Map<String, int>.from(state.prices);
                newPrices[priceKey] = v;
                state.updatePrices(newPrices);
                Navigator.pop(context);
              }
            },
            style: FilledButton.styleFrom(
                backgroundColor: color, foregroundColor: Colors.black),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class _PriceBtn extends StatelessWidget {
  final String label;
  final int price;
  final Color color;
  final VoidCallback onTap;
  const _PriceBtn({
    required this.label,
    required this.price,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('$price ج',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 2),
          Text('اضغط للتعديل',
              style:
                  TextStyle(color: color.withOpacity(0.5), fontSize: 10)),
        ]),
      ),
    );
  }
}
