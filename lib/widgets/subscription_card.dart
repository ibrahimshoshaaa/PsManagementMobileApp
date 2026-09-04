import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';

/// ويدجت بطاقة الاشتراك — ضيفها في شاشة الإعدادات
class SubscriptionCard extends StatelessWidget {
  const SubscriptionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state  = context.watch<AppState>();
    final expiry = state.subscriptionExpiry;
    final active = state.subscriptionActive;

    if (expiry == null) return const SizedBox.shrink();

    final now      = DateTime.now();
    final daysLeft = expiry.difference(now).inDays;
    final isExpired = now.isAfter(expiry);

    // ── تحديد اللون حسب الحالة ──────────────────────────────────────
    Color accent;
    IconData icon;
    String statusText;

    if (isExpired || !active) {
      accent     = Colors.red;
      icon       = Icons.cancel_outlined;
      statusText = 'منتهي';
    } else if (daysLeft <= 7) {
      accent     = Colors.orange;
      icon       = Icons.warning_amber_rounded;
      statusText = 'ينتهي قريباً';
    } else {
      accent     = Colors.green;
      icon       = Icons.check_circle_outline;
      statusText = 'نشط';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.workspace_premium, color: accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'الاشتراك',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: accent, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── تاريخ الانتهاء ───────────────────────────────────────
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'تاريخ الانتهاء',
            value:
                '${expiry.day}/${expiry.month}/${expiry.year}',
            color: Colors.white70,
          ),
          const SizedBox(height: 8),

          // ── الباقي ───────────────────────────────────────────────
          if (!isExpired && active)
            _InfoRow(
              icon: Icons.hourglass_bottom_rounded,
              label: 'المتبقي',
              value: daysLeft == 0
                  ? 'آخر يوم!'
                  : '$daysLeft يوم',
              color: accent,
            ),

          if (isExpired || !active) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'انتهى اشتراكك — تواصل مع المطور للتجديد',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],

          // ── تحذير قرب الانتهاء ───────────────────────────────────
          if (!isExpired && active && daysLeft <= 7) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'اشتراكك ينتهي قريباً — تواصل مع المطور للتجديد',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],

          // ── معرف المحل ───────────────────────────────────────────
          if (state.shopId != null) ...[
            const SizedBox(height: 12),
            Divider(color: Colors.white.withOpacity(0.06)),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.store_outlined,
              label: 'كود المحل',
              value: state.shopId!,
              color: Colors.white38,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.white38),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
