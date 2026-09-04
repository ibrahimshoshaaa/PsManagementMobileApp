import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../services/app_state.dart';
import '../models/device.dart';

/// شاشة الطلبات الواردة من العملاء عبر QR
class CustomerOrdersScreen extends StatefulWidget {
  final String shopId;
  const CustomerOrdersScreen({super.key, required this.shopId});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  List<_CustomerOrder> _orders = [];
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // تحديث كل 15 ثانية تلقائياً
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await FirebaseService.get(
          'shops/${widget.shopId}/customer_orders');
      if (data == null || data is! Map) {
        setState(() { _orders = []; _loading = false; });
        return;
      }

      final list = data.entries.map((e) {
        final v = Map<String, dynamic>.from(e.value as Map);
        return _CustomerOrder(
          key: e.key.toString(),
          deviceId:   (v['device_id'] as num?)?.toInt() ?? 0,
          deviceName: v['device_name']?.toString() ?? 'جهاز',
          deviceType: v['device_type']?.toString() ?? 'device',
          orderText:  v['order_text']?.toString() ?? '',
          orderItems: v['order_items'] != null
              ? Map<String, int>.from(
                  (v['order_items'] as Map).map(
                    (k, val) => MapEntry(k.toString(), (val as num).toInt()),
                  ))
              : {},
          timestamp:  (v['timestamp'] as num?)?.toInt() ?? 0,
          status:     v['status']?.toString() ?? 'pending',
        );
      }).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() { _orders = list; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  /// ✅ FIX: يضيف الأوردر على الجهاز/التربيزة الصح ثم يحدد الأوردر كـ done
  Future<void> _markDone(String key) async {
    // دور على الأوردر
    final order = _orders.firstWhere((o) => o.key == key,
        orElse: () => _orders.first);

    // لو فيه order_items، ضيفهم على الجهاز/التربيزة
    if (order.orderItems.isNotEmpty) {
      await _applyOrderToTarget(order);
    }

    // غيّر الستاتس لـ done
    await FirebaseService.set(
        'shops/${widget.shopId}/customer_orders/$key/status', 'done');
    await _load();
  }

  /// ✅ يضيف order_items على الجهاز أو التربيزة الصح عبر Firebase مباشرةً
  Future<void> _applyOrderToTarget(_CustomerOrder order) async {
    try {
      final state = context.read<AppState>();

      if (order.deviceType == 'device') {
        // ── جهاز PS: ابحث بالاسم أو بالـ id ─────────────────────────────
        PSDevice? target;

        // أولاً: ابحث بـ display_name
        try {
          target = state.devices.firstWhere(
            (d) => d.displayName == order.deviceName,
          );
        } catch (_) {
          target = null;
        }

        // ثانياً: لو مش لاقي بالاسم، ابحث بالـ id
        if (target == null) {
          try {
            target = state.devices.firstWhere(
              (d) => d.id == order.deviceId,
            );
          } catch (_) {
            target = null;
          }
        }

        if (target != null && target.isActive) {
          // ضيف كل صنف على الجهاز
          for (final entry in order.orderItems.entries) {
            state.addOrder(target, entry.key, entry.value);
          }
        }

      } else if (order.deviceType == 'table') {
        // ── تربيزة بنج/بلياردو: ابحث بالاسم ─────────────────────────────
        int tableIdx = -1;
        for (int i = 0; i < state.tables.length; i++) {
          if (state.tables[i]['name'] == order.deviceName) {
            tableIdx = i;
            break;
          }
        }
        // fallback: استخدم device_id كـ index
        if (tableIdx == -1 && order.deviceId < state.tables.length) {
          tableIdx = order.deviceId;
        }

        if (tableIdx >= 0 && tableIdx < state.tables.length) {
          for (final entry in order.orderItems.entries) {
            state.addTableOrder(tableIdx, entry.key, entry.value);
          }
        }

      } else if (order.deviceType == 'drink_table') {
        // ── تربيزة مشروبات: ابحث بالاسم ─────────────────────────────────
        int dtIdx = -1;
        for (int i = 0; i < state.drinkTables.length; i++) {
          if (state.drinkTables[i]['name'] == order.deviceName) {
            dtIdx = i;
            break;
          }
        }
        // fallback: استخدم device_id كـ index
        if (dtIdx == -1 && order.deviceId < state.drinkTables.length) {
          dtIdx = order.deviceId;
        }

        if (dtIdx >= 0 && dtIdx < state.drinkTables.length) {
          for (final entry in order.orderItems.entries) {
            state.addDrinkTableOrder(dtIdx, entry.key, entry.value);
          }
        }
      }
    } catch (e) {
      // لو فيه error في الـ apply، بنكمل ونعلم الـ done على طول
      debugPrint('_applyOrderToTarget error: $e');
    }
  }

  Future<void> _delete(String key) async {
    await FirebaseService.delete(
        'shops/${widget.shopId}/customer_orders/$key');
    await _load();
  }

  Future<void> _clearDone() async {
    final done = _orders.where((o) => o.status == 'done').toList();
    for (final o in done) {
      await FirebaseService.delete(
          'shops/${widget.shopId}/customer_orders/${o.key}');
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _orders.where((o) => o.status == 'pending').toList();
    final done    = _orders.where((o) => o.status == 'done').toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: Row(children: [
          const Text('🛎️ طلبات العملاء',
              style: TextStyle(
                  color: Color(0xFF38bdf8), fontWeight: FontWeight.bold)),
          if (pending.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${pending.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
        leading: const BackButton(color: Colors.white),
        actions: [
          if (done.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.cleaning_services_outlined,
                  color: Colors.white38),
              tooltip: 'مسح المنجزة',
              onPressed: _clearDone,
            ),
          IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white54),
              onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF38bdf8)))
          : _orders.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      Text('لا يوجد طلبات حالياً',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 16)),
                      SizedBox(height: 6),
                      Text('بيتحدث كل 15 ثانية تلقائياً',
                          style: TextStyle(
                              color: Colors.white24, fontSize: 12)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (pending.isNotEmpty) ...[
                      _Header('🔴 جديدة (${pending.length})'),
                      ...pending.map((o) => _OrderTile(
                            order: o,
                            onDone: () => _markDone(o.key),
                            onDelete: () => _delete(o.key),
                          )),
                      const SizedBox(height: 12),
                    ],
                    if (done.isNotEmpty) ...[
                      _Header('✅ منجزة (${done.length})'),
                      ...done.map((o) => _OrderTile(
                            order: o,
                            onDone: () => _markDone(o.key),
                            onDelete: () => _delete(o.key),
                            isDone: true,
                          )),
                    ],
                  ],
                ),
    );
  }
}

// ─── Order Tile ───────────────────────────────────────────────────────────────

class _OrderTile extends StatelessWidget {
  final _CustomerOrder order;
  final VoidCallback onDone;
  final VoidCallback onDelete;
  final bool isDone;
  const _OrderTile({
    required this.order,
    required this.onDone,
    required this.onDelete,
    this.isDone = false,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateTime.fromMillisecondsSinceEpoch(order.timestamp);
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDone
                ? Colors.white12
                : Colors.orange.withOpacity(0.5),
            width: isDone ? 1 : 1.5),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF38bdf8).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF38bdf8).withOpacity(0.4)),
            ),
            child: Text(order.deviceName,
                style: const TextStyle(
                    color: Color(0xFF38bdf8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Text(timeStr,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 12)),
          const Spacer(),
          if (!isDone)
            GestureDetector(
              onTap: onDone,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4ade80).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF4ade80).withOpacity(0.5)),
                ),
                child: const Text('✅ تم',
                    style: TextStyle(
                        color: Color(0xFF4ade80),
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.red.withOpacity(0.5)),
              ),
              child: const Text('🗑 حذف',
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Text(order.orderText,
            style: TextStyle(
                fontSize: 15,
                color: isDone ? Colors.white38 : Colors.white,
                decoration:
                    isDone ? TextDecoration.lineThrough : null)),
        // ✅ عرض الأصناف بشكل واضح لو موجودة
        if (order.orderItems.isNotEmpty && !isDone) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: order.orderItems.entries.map((e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Text('${e.key} ×${e.value}',
                  style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            )).toList(),
          ),
        ],
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.bold)),
    );
  }
}

// ─── Model ────────────────────────────────────────────────────────────────────

class _CustomerOrder {
  final String key;
  final int deviceId;
  final String deviceName;
  final String deviceType;
  final String orderText;
  final Map<String, int> orderItems; // ✅ الأصناف والكميات
  final int timestamp;
  final String status;
  const _CustomerOrder({
    required this.key,
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.orderText,
    required this.orderItems,
    required this.timestamp,
    required this.status,
  });
}
