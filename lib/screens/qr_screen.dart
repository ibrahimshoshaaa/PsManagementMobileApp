import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/device.dart';
import '../services/app_state.dart';

/// شاشة عرض QR code - بتدعم الأجهزة وتربيزات البنج/البلياردو وتربيزات المشروبات
class QrScreen extends StatelessWidget {
  final PSDevice? device;
  final int? tableIndex;      // تربيزة بنج/بلياردو
  final int? drinkTableIndex; // تربيزة مشروبات

  const QrScreen({
    super.key,
    this.device,
    this.tableIndex,
    this.drinkTableIndex,
  }) : assert(
          device != null || tableIndex != null || drinkTableIndex != null,
          'لازم تحدد device أو tableIndex أو drinkTableIndex',
        );

  // ── روابط URL ────────────────────────────────────────────────────────────

 static String buildDeviceUrl(String shopId, int deviceId) {
  final encodedId = base64Url.encode(utf8.encode(shopId)).replaceAll('=', '');
  return 'https://ps-harifa.web.app/?s=$encodedId&d=$deviceId';
}

static String buildTableUrl(String shopId, int tableIndex) {
  final encodedId = base64Url.encode(utf8.encode(shopId)).replaceAll('=', '');
  return 'https://ps-harifa.web.app/?s=$encodedId&t=$tableIndex';
}

static String buildDrinkTableUrl(String shopId, int drinkTableIndex) {
  final encodedId = base64Url.encode(utf8.encode(shopId)).replaceAll('=', '');
  return 'https://ps-harifa.web.app/?s=$encodedId&dt=$drinkTableIndex';
}
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final shopId = state.shopId ?? '';

    // ── تحديد البيانات حسب النوع ─────────────────────────────────────────
    late String name;
    late String url;
    late Color color;
    late String typeLabel;
    late IconData icon;

    if (device != null) {
      // ── جهاز PS ────────────────────────────────────────────────────────
      final isPs5 = device!.deviceType == 'ps5';
      name      = device!.displayName;
      url       = buildDeviceUrl(shopId, device!.id);
      color     = isPs5 ? Colors.purple : const Color(0xFF38bdf8);
      typeLabel = isPs5 ? 'PS5' : 'PS4';
      icon      = Icons.sports_esports;

    } else if (tableIndex != null) {
      // ── تربيزة بنج/بلياردو ─────────────────────────────────────────────
      final t         = state.tables[tableIndex!];
      final tableType = t['table_type'] ?? 'ping';
      name      = t['name'] ?? 'تربيزة';
      url       = buildTableUrl(shopId, tableIndex!);
      color     = tableType == 'billiard' ? Colors.purple : const Color(0xFF34d399);
      typeLabel = tableType == 'billiard' ? '🎱 بلياردو' : '🏓 بينج';
      icon      = Icons.table_bar;

    } else {
      // ── تربيزة مشروبات ─────────────────────────────────────────────────
      final t = state.drinkTables[drinkTableIndex!];
      name      = t['name'] ?? 'تربيزة مشروبات';
      url       = buildDrinkTableUrl(shopId, drinkTableIndex!);
      color     = Colors.orange;
      typeLabel = '🍹 مشروبات';
      icon      = Icons.local_drink;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: Text(
          'QR - $name',
          style: const TextStyle(
              color: Color(0xFF38bdf8), fontWeight: FontWeight.bold),
        ),
        leading: const BackButton(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Badge ────────────────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '$typeLabel  •  $name',
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── QR Code ───────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: color.withOpacity(0.35),
                        blurRadius: 30,
                        spreadRadius: 5),
                  ],
                ),
                child: QrImageView(
                  data: url,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                  errorStateBuilder: (ctx, err) => const SizedBox(
                    width: 220,
                    height: 220,
                    child: Center(child: Text('خطأ في QR')),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Label ─────────────────────────────────────────────────────
              Text(
                '📱 العميل يمسح الكود للطلب',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _subtitle(),
                style: const TextStyle(
                    color: Colors.white54, fontSize: 13, height: 1.6),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    if (device != null) {
      return 'سيتمكن العميل من رؤية الوقت والحساب\nوإرسال طلبات المشروبات مباشرة';
    } else if (tableIndex != null) {
      return 'سيتمكن العميل من متابعة الوقت والحساب\nوإرسال طلبات المشروبات للتربيزة';
    } else {
      return 'سيتمكن العميل من عرض المنيو\nوإرسال طلباته مباشرة لتربيزة المشروبات';
    }
  }
}
