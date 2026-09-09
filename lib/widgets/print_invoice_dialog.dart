import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../services/printer_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PrintInvoiceDialog — ديالوج الطباعة الشامل
// ═══════════════════════════════════════════════════════════════════════════════

class PrintInvoiceDialog extends StatefulWidget {
  final Map<String, dynamic> record;
  final String shopName;

  const PrintInvoiceDialog({
    super.key,
    required this.record,
    required this.shopName,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> record,
    required String shopName,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PrintInvoiceDialog(record: record, shopName: shopName),
    );
  }

  @override
  State<PrintInvoiceDialog> createState() => _PrintInvoiceDialogState();
}

class _PrintInvoiceDialogState extends State<PrintInvoiceDialog> {
  _Phase _phase = _Phase.preview;
  bool _printing = false;
  String? _savedAddress;
  String? _savedName;
  List<BluetoothDevice> _devices = [];
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final addr = await PrinterService.getSavedAddress();
    if (addr != null && mounted) {
      setState(() {
        _savedAddress = addr;
        _savedName = addr;
      });
    }
  }

  Future<void> _scan() async {
    setState(() { _scanning = true; _devices = []; });
    final found = await PrinterService.scanDevices();
    if (mounted) setState(() { _devices = found; _scanning = false; });
  }

  Future<void> _print(String address, String name) async {
    setState(() { _printing = true; });
    final result = await PrinterService.printReceipt(
      record: widget.record,
      shopName: widget.shopName,
      printerAddress: address,
    );
    if (!mounted) return;
    setState(() { _printing = false; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.message),
      backgroundColor: result.color,
      duration: const Duration(seconds: 3),
    ));
    if (result == PrintResult.success) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1c2128),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _phase == _Phase.preview ? _buildPreview() : _buildPrinterPicker(),
      ),
    );
  }

  // ── معاينة الفاتورة ────────────────────────────────────────────────────────
  Widget _buildPreview() {
    final r = widget.record;
    final deviceType = r['device_type']?.toString() ?? '';
    final timeCost = (r['time_cost'] as num?)?.toDouble() ?? 0;
    final buffetCost = (r['buffet_cost'] as num?)?.toDouble() ?? 0;
    final total = (r['total'] as num?)?.toDouble() ?? 0;
    final orders = (r['orders'] as Map?)
            ?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ??
        {};
    final duration = r['duration']?.toString();
    final startT = r['start_time_display']?.toString();
    final endT = r['end_time_display']?.toString();
    final hourlyRate = (r['hourly_rate'] as num?)?.toDouble();
    final now = DateTime.now();
    final isDrink = deviceType == 'drink_table';

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(children: [
            const Icon(Icons.receipt_long, color: Color(0xFF38bdf8)),
            const SizedBox(width: 8),
            const Text('معاينة الفاتورة',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
          const SizedBox(height: 8),

          // بطاقة الفاتورة
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF38bdf8).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // اسم المحل
                Text(widget.shopName,
                    style: const TextStyle(
                        color: Color(0xFF38bdf8),
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                const SizedBox(height: 4),
                Text(
                  '${now.year}-${_d(now.month)}-${_d(now.day)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const Divider(color: Colors.white24, height: 16),

                // اسم الجهاز
                Text(r['name']?.toString() ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),

                const SizedBox(height: 8),

                // ── تفاصيل وقت اللعب ──────────────────────────────────────
                if (!isDrink && (startT != null || endT != null)) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1c2128),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF38bdf8).withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        // وقت البدء والانتهاء في صف واحد
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _timeBox('بدء', startT ?? '--:--',
                                const Color(0xFF4ade80)),
                            const Icon(Icons.arrow_back,
                                color: Colors.white38, size: 16),
                            _timeBox('انتهاء', endT ?? '--:--',
                                Colors.orange),
                          ],
                        ),
                        if (duration != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.timer_outlined,
                                  color: Colors.white54, size: 14),
                              const SizedBox(width: 4),
                              Text('المدة: $duration',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ],
                        if (hourlyRate != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.monetization_on_outlined,
                                  color: Colors.white38, size: 13),
                              const SizedBox(width: 4),
                              Text(
                                'سعر الساعة: ${hourlyRate.toStringAsFixed(0)} ج/س',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                const Divider(color: Colors.white24, height: 8),

                // تكلفة اللعب
                if (!isDrink && timeCost > 0)
                  _previewRow('💻 تكلفة اللعب', '${timeCost.toStringAsFixed(1)} ج'),

                // البوفيه
                if (orders.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('🧃 البوفيه',
                        style: TextStyle(color: Colors.white60, fontSize: 12)),
                  ),
                  ...orders.entries.map((e) => Padding(
                        padding: const EdgeInsets.only(right: 12, bottom: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${e.key} ×${e.value}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      )),
                  _previewRow('  مجموع البوفيه',
                      '${buffetCost.toStringAsFixed(1)} ج'),
                ],

                const Divider(color: Colors.white24, height: 12),

                // الإجمالي
                _previewRow('💰 الإجمالي', '${total.toStringAsFixed(1)} ج',
                    highlight: true),

                if (r['cashier'] != null) ...[
                  const SizedBox(height: 8),
                  Text('كاشير: ${r['cashier']}',
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
                const SizedBox(height: 8),
                const Text('شكراً لزيارتكم ❤',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // أزرار
          if (_savedAddress != null) ...[
            FilledButton.icon(
              icon: _printing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.print, size: 18),
              label: Text(_printing
                  ? 'جاري الطباعة...'
                  : 'طباعة على ${_savedName ?? 'الطابعة'}'),
              onPressed:
                  _printing ? null : () => _print(_savedAddress!, _savedName ?? ''),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF38bdf8),
                  foregroundColor: Colors.black),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            icon: const Icon(Icons.bluetooth_searching,
                size: 18, color: Color(0xFF38bdf8)),
            label: const Text('اختر طابعة',
                style: TextStyle(color: Color(0xFF38bdf8))),
            onPressed: () {
              setState(() { _phase = _Phase.picker; });
              _scan();
            },
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF38bdf8))),
          ),
        ],
      ),
    );
  }

  Widget _timeBox(String label, String time, Color color) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 2),
        Text(time,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 20)),
      ],
    );
  }

  Widget _previewRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: highlight ? Colors.white : Colors.white70,
                  fontWeight:
                      highlight ? FontWeight.bold : FontWeight.normal,
                  fontSize: highlight ? 15 : 13)),
          Text(value,
              style: TextStyle(
                  color: highlight ? const Color(0xFF4ade80) : Colors.white,
                  fontWeight:
                      highlight ? FontWeight.bold : FontWeight.normal,
                  fontSize: highlight ? 15 : 13)),
        ],
      ),
    );
  }

  // ── اختيار الطابعة ─────────────────────────────────────────────────────────
  Widget _buildPrinterPicker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back,
                color: Colors.white70, size: 20),
            onPressed: () => setState(() { _phase = _Phase.preview; }),
          ),
          const Text('اختر طابعة Bluetooth',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const Spacer(),
          if (_scanning)
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF38bdf8)))
          else
            IconButton(
              icon: const Icon(Icons.refresh,
                  color: Color(0xFF38bdf8), size: 20),
              onPressed: _scan,
            ),
        ]),
        const SizedBox(height: 4),
        const Text('الأجهزة المقترنة (Paired):',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 8),

        if (_devices.isEmpty && !_scanning)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'مفيش طابعات مقترنة.\nاقترن بالطابعة من إعدادات Bluetooth في الهاتف الأول.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _devices.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: Colors.white12, height: 1),
              itemBuilder: (_, i) {
                final d = _devices[i];
                final isSaved = d.address == _savedAddress;
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.print,
                      color: isSaved
                          ? const Color(0xFF4ade80)
                          : Colors.white54,
                      size: 20),
                  title: Text(d.name ?? d.address,
                      style: TextStyle(
                          color: isSaved
                              ? const Color(0xFF4ade80)
                              : Colors.white,
                          fontWeight: isSaved
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14)),
                  subtitle: Text(d.address,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                  trailing: isSaved
                      ? const Icon(Icons.check_circle,
                          color: Color(0xFF4ade80), size: 16)
                      : null,
                  onTap: () async {
                    await PrinterService.saveAddress(d.address);
                    if (!mounted) return;
                    setState(() {
                      _savedAddress = d.address;
                      _savedName = d.name ?? d.address;
                      _phase = _Phase.preview;
                    });
                    _print(d.address, d.name ?? d.address);
                  },
                );
              },
            ),
          ),

        const SizedBox(height: 8),
        if (_savedAddress != null)
          TextButton.icon(
            icon: const Icon(Icons.delete_outline,
                size: 16, color: Colors.red),
            label: const Text('إزالة الطابعة المحفوظة',
                style: TextStyle(color: Colors.red, fontSize: 12)),
            onPressed: () async {
              await PrinterService.clearSavedAddress();
              if (!mounted) return;
              setState(() {
                _savedAddress = null;
                _savedName = null;
              });
            },
          ),
      ],
    );
  }

  String _d(int v) => v.toString().padLeft(2, '0');
}

enum _Phase { preview, picker }
