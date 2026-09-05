import '../models/customer.dart';
import 'firebase_service.dart';

class CustomerService {
  static const _path = 'customers';

  // ── جلب كل العملاء ─────────────────────────────────────────────────────────
  static Future<List<Customer>> fetchAll() async {
    final data = await FirebaseService.get(_path);
    if (data == null || data is! Map) return [];
    return data.entries
        .map((e) => Customer.fromMap(e.key as String, e.value as Map))
        .toList()
      ..sort((a, b) => b.lastVisit.compareTo(a.lastVisit));
  }

  // ── إضافة عميل جديد ────────────────────────────────────────────────────────
  static Future<Customer?> add(String phone, {String name = ''}) async {
    final now = DateTime.now().toIso8601String();
    final customer = Customer(
      id: '',
      name: name,
      phone: phone,
      visits: 0,
      totalSpent: 0,
      lastVisit: now,
    );
    final id = await FirebaseService.push(_path, customer.toMap());
    if (id == null) return null;
    return Customer(
      id: id,
      name: name,
      phone: phone,
      visits: 0,
      totalSpent: 0,
      lastVisit: now,
    );
  }

  // ── تحديث بيانات عميل ──────────────────────────────────────────────────────
  static Future<bool> update(Customer c) =>
      FirebaseService.patch('$_path/${c.id}', c.toMap());

  // ── تسجيل زيارة بعد انتهاء الجلسة ─────────────────────────────────────────
  static Future<void> recordVisit(String phone, double totalBill) async {
    final all = await fetchAll();
    final existing = all.where((c) => c.phone == phone).firstOrNull;
    if (existing != null) {
      existing.visits += 1;
      existing.totalSpent += totalBill;
      existing.lastVisit = DateTime.now().toIso8601String();
      await update(existing);
    } else {
      await add(phone);
      final fresh = (await fetchAll())
          .where((c) => c.phone == phone)
          .firstOrNull;
      if (fresh != null) {
        fresh.visits = 1;
        fresh.totalSpent = totalBill;
        fresh.lastVisit = DateTime.now().toIso8601String();
        await update(fresh);
      }
    }
  }

  // ── البحث بالرقم ───────────────────────────────────────────────────────────
  static Future<Customer?> findByPhone(String phone) async {
    final all = await fetchAll();
    return all.where((c) => c.phone == phone).firstOrNull;
  }

  // ── حذف عميل ───────────────────────────────────────────────────────────────
  static Future<bool> delete(String id) =>
      FirebaseService.delete('$_path/$id');
}
