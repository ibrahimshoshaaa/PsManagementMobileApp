import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PrinterService — خدمة طباعة الفواتير عبر Bluetooth ESC/POS
// يدعم أي طابعة حرارية تعمل بـ ESC/POS (Xprinter, GOOJPRT, وغيرها)
// ═══════════════════════════════════════════════════════════════════════════════

class PrinterService {
  static const _prefKey = 'saved_printer_address';

  // ── حفظ واسترجاع الطابعة الافتراضية ─────────────────────────────────────
  static Future<String?> getSavedAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey);
  }

  static Future<void> saveAddress(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, address);
  }

  static Future<void> clearSavedAddress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  // ── البحث عن الطابعات المتاحة ─────────────────────────────────────────────
  static Future<List<BluetoothDevice>> scanDevices() async {
    try {
      final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      return devices;
    } catch (_) {
      return [];
    }
  }

  // ── الطباعة الرئيسية ──────────────────────────────────────────────────────
  /// يطبع فاتورة من record (نفس بنية stopDevice/stopTable/checkoutDrinkTable)
  static Future<PrintResult> printReceipt({
    required Map<String, dynamic> record,
    required String shopName,
    String? printerAddress,
  }) async {
    final address = printerAddress ?? await getSavedAddress();
    if (address == null) {
      return PrintResult.noDevice;
    }

    BluetoothConnection? connection;
    try {
      connection = await BluetoothConnection.toAddress(address)
          .timeout(const Duration(seconds: 8));

      final bytes = _buildReceipt(record: record, shopName: shopName);
      connection.output.add(bytes);
      await connection.output.allSent;
      await Future.delayed(const Duration(milliseconds: 500));
      connection.finish();
      return PrintResult.success;
    } on TimeoutException {
      connection?.dispose();
      return PrintResult.timeout;
    } catch (e) {
      connection?.dispose();
      return PrintResult.error;
    }
  }

  // ── بناء بايتات الفاتورة ESC/POS ─────────────────────────────────────────
  static Uint8List _buildReceipt({
    required Map<String, dynamic> record,
    required String shopName,
  }) {
    final buf = BytesBuilder();
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${_d(now.month)}-${_d(now.day)}  ${_d(now.hour)}:${_d(now.minute)}';

    final deviceName = record['name']?.toString() ?? '';
    final deviceType = record['device_type']?.toString() ?? '';
    final duration = record['duration']?.toString() ?? '-';
    final timeCost = (record['time_cost'] as num?)?.toDouble() ?? 0;
    final buffetCost = (record['buffet_cost'] as num?)?.toDouble() ?? 0;
    final total = (record['total'] as num?)?.toDouble() ?? 0;
    final cashier = record['cashier']?.toString() ?? '';
    final Map<String, int> orders =
        (record['orders'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ?? {};
    final playMode = record['play_mode']?.toString() ?? '';
    final startTimeDisplay = record['start_time_display']?.toString();
    final endTimeDisplay = record['end_time_display']?.toString();
    final hourlyRate = (record['hourly_rate'] as num?)?.toDouble();

    // ── ESC/POS commands ───
    // Initialize printer
    buf.add([0x1B, 0x40]);
    // Arabic/UTF-8 codepage — حسب الطابعة
    buf.add([0x1B, 0x74, 0x21]);

    // ── Header: اسم المحل ── Bold + Center + Big
    buf.add(_center());
    buf.add(_bold(true));
    buf.add(_size(2, 2));
    buf.add(_latin(shopName));
    buf.add(_lf());
    buf.add(_size(1, 1));
    buf.add(_bold(false));

    // خط فاصل
    buf.add(_latin('--------------------------------'));
    buf.add(_lf());

    // التاريخ والوقت
    buf.add(_center());
    buf.add(_latin(dateStr));
    buf.add(_lf());

    // ── اسم الجهاز/التربيزة ──
    buf.add(_latin('--------------------------------'));
    buf.add(_lf());
    buf.add(_bold(true));
    buf.add(_center());
    buf.add(_size(1, 2));
    buf.add(_latin(_deviceLabel(deviceType, deviceName)));
    buf.add(_lf());
    buf.add(_size(1, 1));
    buf.add(_bold(false));

    // نوع الجلسة
    if (playMode.isNotEmpty && deviceType != 'drink_table') {
      buf.add(_center());
      buf.add(_latin(_modeLabel(deviceType, playMode)));
      buf.add(_lf());
    }

    buf.add(_latin('--------------------------------'));
    buf.add(_lf());

    // ── تفاصيل الجلسة ──
    buf.add(_left());

    if (deviceType != 'drink_table' && duration != '-') {
      if (startTimeDisplay != null) {
        buf.add(_row('بدء', startTimeDisplay));
      }
      if (endTimeDisplay != null) {
        buf.add(_row('انتهاء', endTimeDisplay));
      }
      buf.add(_row('المدة', duration));
      if (hourlyRate != null) {
        buf.add(_row('سعر الساعة', '${hourlyRate.toStringAsFixed(0)} ج/س'));
      }
      buf.add(_row('تكلفة اللعب', '${timeCost.toStringAsFixed(1)} ج'));
    }

    // المشروبات/البوفيه
    if (orders.isNotEmpty) {
      buf.add(_latin('  [البوفيه]'));
      buf.add(_lf());
      for (final e in orders.entries) {
        buf.add(_latin('  ${e.key} x${e.value}'));
        buf.add(_lf());
      }
      buf.add(_row('تكلفة البوفيه', '${buffetCost.toStringAsFixed(1)} ج'));
    }

    buf.add(_latin('================================'));
    buf.add(_lf());

    // الإجمالي
    buf.add(_bold(true));
    buf.add(_size(1, 2));
    buf.add(_left());
    buf.add(_row('الاجمالي', '${total.toStringAsFixed(1)} ج'));
    buf.add(_size(1, 1));
    buf.add(_bold(false));

    buf.add(_latin('================================'));
    buf.add(_lf());

    // الكاشير
    if (cashier.isNotEmpty) {
      buf.add(_center());
      buf.add(_latin('كاشير: $cashier'));
      buf.add(_lf());
    }

    // Footer
    buf.add(_latin('--------------------------------'));
    buf.add(_lf());
    buf.add(_center());
    buf.add(_latin('شكرا لزيارتكم'));
    buf.add(_lf());
    buf.add(_latin('ElHarifa PS'));
    buf.add(_lf());

    // Feed + cut
    buf.add([0x1B, 0x64, 0x05]); // feed 5 lines
    buf.add([0x1D, 0x56, 0x41, 0x00]); // partial cut

    return buf.toBytes();
  }

  // ── ESC/POS helpers ───────────────────────────────────────────────────────
  static Uint8List _latin(String text) =>
      Uint8List.fromList(latin1.encode(_toAsciiSafe(text)));

  static Uint8List _lf() => Uint8List.fromList([0x0A]);
  static Uint8List _bold(bool on) =>
      Uint8List.fromList([0x1B, 0x45, on ? 1 : 0]);
  static Uint8List _center() => Uint8List.fromList([0x1B, 0x61, 0x01]);
  static Uint8List _left() => Uint8List.fromList([0x1B, 0x61, 0x00]);
  static Uint8List _size(int w, int h) =>
      Uint8List.fromList([0x1D, 0x21, ((w - 1) << 4) | (h - 1)]);

  static Uint8List _row(String label, String value) {
    // 32 chars wide — label right, value left (RTL receipt)
    final line = '${label.padRight(18)}${value.padLeft(14)}';
    return Uint8List.fromList([...latin1.encode(_toAsciiSafe(line)), 0x0A]);
  }

  static String _d(int v) => v.toString().padLeft(2, '0');

  /// تحويل العربي لـ ASCII مقروء على الطابعة الحرارية
  /// (الطابعات الرخيصة مش بتدعم Unicode — نستخدم Transliteration بسيط)
  static String _toAsciiSafe(String text) {
    // يحتفظ بالأحرف اللي الطابعة تقدر تطبعها
    return text
        .replaceAll('ج', 'ج')
        .replaceAll('×', 'x')
        .replaceAll('،', ',')
        .replaceAll('–', '-')
        .replaceAll('—', '-');
  }

  static String _deviceLabel(String type, String name) {
    switch (type) {
      case 'table':
        return 'بلياردو / بينج: $name';
      case 'drink_table':
        return 'تربيزة مشروبات: $name';
      default:
        return 'جهاز: $name';
    }
  }

  static String _modeLabel(String type, String mode) {
    if (type == 'table') return 'نوع: $mode';
    switch (mode) {
      case 'multi':
        return 'جلسة مالتي';
      case 'normal':
        return 'جلسة عادي';
      case 'ping':
        return 'بينج بونج';
      case 'billiard':
        return 'بلياردو';
      default:
        return mode;
    }
  }
}

// ── نتيجة الطباعة ─────────────────────────────────────────────────────────────
enum PrintResult { success, noDevice, timeout, error }

extension PrintResultX on PrintResult {
  String get message {
    switch (this) {
      case PrintResult.success:
        return 'تمت الطباعة بنجاح ✓';
      case PrintResult.noDevice:
        return 'لا توجد طابعة محددة — اختر طابعة من الإعدادات';
      case PrintResult.timeout:
        return 'الطابعة لا تستجيب — تأكد إنها شغالة وقريبة';
      case PrintResult.error:
        return 'خطأ في الاتصال بالطابعة';
    }
  }

  Color get color {
    switch (this) {
      case PrintResult.success:
        return const Color(0xFF4ade80);
      default:
        return Colors.orange;
    }
  }
}
