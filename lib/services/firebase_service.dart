import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ═══════════════════════════════════════════════════════════════════════════════
// FirebaseService — مقسّم لمسارات منفصلة حسب نوع البيانات
//
// 🔥 BANDWIDTH OPTIMIZATIONS APPLIED:
//   1. pullAllData() — يجيب static + realtime فقط. history/debts/tournaments/
//      shiftsHistory اتشالوا — بيتحملوا بس عند الطلب (on-demand).
//   2. getRecentHistory() — يستخدم limitToLast=20 افتراضياً بدل pull كامل.
//   3. listenToDevices() — بيشيل session_log من الـ payload اللي بيجي عبر SSE
//      (المقارنة بتتم في pushDevicesStateSlim).
//   4. pushDevicesStateSlim() — بيرسل devices بدون session_log.
//   5. الـ SSE listeners على history/shifts اتشالوا من الـ SyncService —
//      history SSE للأدمن فقط وبيستخدم limitToLast.
//
// المسارات:
//   realtime/devices_state      ← حالة الأجهزة (SSE - فوري)
//   realtime/tables_state       ← حالة التربيزات (SSE - فوري)
//   realtime/drink_tables_state ← حالة تربيزات المشروبات (SSE - فوري)
//   static/                     ← أسعار ومنيو وإعدادات (push عند التعديل)
//   records/history             ← السجلات اليومية (append فقط — لا pull كامل)
//   records/shifts              ← الشيفتات (on-demand فقط)
//   archives/                   ← الأرشيف (append فقط)
//   yearly_archives/            ← الأرشيف السنوي
//   subscription                ← بيانات الاشتراك
//   tournaments                 ← البطولات (on-demand فقط)
//   customer_orders             ← طلبات العملاء
// ═══════════════════════════════════════════════════════════════════════════════

class FirebaseService {
  // ══════════════════════════════════════════════════════════════════════════
  // MULTI-PROJECT CONFIG
  // ══════════════════════════════════════════════════════════════════════════
  // كل اكونت Firebase عنده prefix خاص بيه في الـ shopId
  // مثلاً: ps1_ABC → مشروع 1 | ps2_XYZ → مشروع 2
  // لو مفيش prefix معروف → بيروح للـ default
  // عشان تضيف مشروع جديد: زود entry في _projects بالـ prefix والـ url والـ secret
  // ──────────────────────────────────────────────────────────────────────────

  static const _projects = <String, Map<String, String>>{
    'ps1_': {
      'url':    'https://ps-harifa-default-rtdb.firebaseio.com',
      'secret': 'loFnECpWdlhEHnzGdPW1VoWKbZPepbgrqDVjTnEY',
    },
    'ps2_': {
      'url':    'https://psmanagementapp-default-rtdb.firebaseio.com',
      'secret': 'uy6vaerRBXq497rXIltP2F5NJCn75dyev9DeHeSF',
    },
    // 'ps3_': {
    //   'url':    'https://YOUR-THIRD-rtdb.firebaseio.com',
    //   'secret': 'YOUR_SECRET_HERE',
    // },
  };

  static const _defaultUrl    = 'https://ps-harifa-default-rtdb.firebaseio.com';
  static const _defaultSecret = 'loFnECpWdlhEHnzGdPW1VoWKbZPepbgrqDVjTnEY';

  static Map<String, String> _configFor(String? shopId) {
    if (shopId != null && shopId.isNotEmpty) {
      final lower = shopId.toLowerCase();
      for (final entry in _projects.entries) {
        if (lower.startsWith(entry.key.toLowerCase())) return entry.value;
      }
    }
    return {'url': _defaultUrl, 'secret': _defaultSecret};
  }

  /// الـ shopId الحالي — بيتضبط من AppState عند activateShop() و loadData()
  static String? _currentShopId;
  static void setShopId(String? id) => _currentShopId = id;

  static String _url(String path) {
    final cfg = _configFor(_currentShopId);
    return '${cfg["url"]}/$path.json?auth=${cfg["secret"]}';
  }

  /// مثل `_url` لكن بيقبل query params إضافية (مثلاً limitToLast)
  static String _urlWithQuery(String path, Map<String, String> params) {
    final cfg = _configFor(_currentShopId);
    final base = '${cfg["url"]}/$path.json?auth=${cfg["secret"]}';
    if (params.isEmpty) return base;
    final extra = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$base&$extra';
  }

  // ─── CRUD الأساسي ──────────────────────────────────────────────────────────

  static Future<dynamic> get(String path) async {
    try {
      final r = await http
          .get(Uri.parse(_url(path)))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) return jsonDecode(r.body);
    } catch (e) {
      print('Firebase GET error [$path]: $e');
    }
    return null;
  }

  static Future<bool> set(String path, dynamic data) async {
    try {
      final r = await http
          .put(Uri.parse(_url(path)), body: jsonEncode(data))
          .timeout(const Duration(seconds: 10));
      return r.statusCode == 200;
    } catch (e) {
      print('Firebase SET error [$path]: $e');
      return false;
    }
  }

  static Future<bool> patch(String path, dynamic data) async {
    try {
      final r = await http
          .patch(Uri.parse(_url(path)), body: jsonEncode(data))
          .timeout(const Duration(seconds: 10));
      return r.statusCode == 200;
    } catch (e) {
      print('Firebase PATCH error [$path]: $e');
      return false;
    }
  }

  static Future<bool> post(String path, dynamic data) async {
    try {
      final r = await http
          .post(Uri.parse(_url(path)), body: jsonEncode(data))
          .timeout(const Duration(seconds: 10));
      return r.statusCode == 200;
    } catch (e) {
      print('Firebase POST error [$path]: $e');
      return false;
    }
  }

  static Future<String?> push(String path, dynamic data) async {
    try {
      final r = await http
          .post(Uri.parse(_url(path)), body: jsonEncode(data))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        return jsonDecode(r.body)['name'];
      }
    } catch (e) {
      print('Firebase PUSH error [$path]: $e');
    }
    return null;
  }

  static Future<bool> delete(String path) async {
    try {
      final r = await http
          .delete(Uri.parse(_url(path)))
          .timeout(const Duration(seconds: 10));
      return r.statusCode == 200;
    } catch (e) {
      print('Firebase DELETE error [$path]: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // مسارات المحل — مقسّمة حسب نوع البيانات
  // ═══════════════════════════════════════════════════════════════════════════

  static String devicesStatePath(String shopId) =>
      'shops/$shopId/realtime/devices_state';

  static String tablesStatePath(String shopId) =>
      'shops/$shopId/realtime/tables_state';

  static String drinkTablesStatePath(String shopId) =>
      'shops/$shopId/realtime/drink_tables_state';

  static String tablesPath(String shopId) =>
      'shops/$shopId/operational/tables';

  static String drinkTablesPath(String shopId) =>
      'shops/$shopId/operational/drink_tables';

  static String staticDataPath(String shopId) =>
      'shops/$shopId/static';

  static String pricesPath(String shopId) =>
      'shops/$shopId/static/prices';

  static String menuPath(String shopId) =>
      'shops/$shopId/static/menu';

  static String inventoryPath(String shopId) =>
      'shops/$shopId/static/inventory';

  static String settingsPath(String shopId) =>
      'shops/$shopId/static/settings';

  static String cashiersPath(String shopId) =>
      'shops/$shopId/static/cashiers';

  // 🔥 BANDWIDTH: debts انتقل لـ static — يتحمل مرة واحدة مع الـ static node
  // وبيتحدث on-demand بس لما الأدمن يفتح شاشة الديون
  static String debtsPath(String shopId) =>
      'shops/$shopId/static/debts';

  static String historyPath(String shopId) =>
      'shops/$shopId/records/history';

  static String dailySummaryPath(String shopId) =>
      'shops/$shopId/records/daily_summary';

  static String shiftsHistoryPath(String shopId) =>
      'shops/$shopId/records/shifts_history';

  static String openShiftsPath(String shopId) =>
      'shops/$shopId/records/open_shifts';

  static String shopArchivePath(String shopId) =>
      'shops/$shopId/archives';

  /// مسار التفاصيل الكاملة للأرشيف اليومي (منفصل عن الإجماليات)
  static String shopArchiveDetailsPath(String shopId) =>
      'shops/$shopId/archive_details';

  /// مسار تفاصيل أرشيف يوم بعينه
  static String shopArchiveDetailPath(String shopId, String archiveId) =>
      'shops/$shopId/archive_details/$archiveId';

  static String shopYearlyArchivePath(String shopId) =>
      'shops/$shopId/yearly_archives';

  static String shopSubscriptionPath(String shopId) =>
      'shops/$shopId/subscription';

  static String shopTournamentsPath(String shopId) =>
      'shops/$shopId/tournaments';

  static String customerOrdersPath(String shopId) =>
      'shops/$shopId/customer_orders';

  static String shopDataPath(String shopId) =>
      'shops/$shopId/app_data';

  // ═══════════════════════════════════════════════════════════════════════════
  // Push منفصل لكل نوع بيانات
  // ═══════════════════════════════════════════════════════════════════════════

  // 🔥 BANDWIDTH FIX #1: pushDevicesStateSlim — بيشيل session_log من كل جهاز
  // قبل الإرسال. session_log يبقى محلي بس ويتحفظ في التاريخ لما الجلسة تنتهي.
  static Future<bool> pushDevicesStateSlim(
      String shopId,
      List<Map<String, dynamic>> devicesState,
      String senderId) async {
    // Strip session_log from every device before transmitting —
    // prevents continuously-growing arrays from being synced every second.
    final slim = devicesState.map((d) {
      final copy = Map<String, dynamic>.from(d);
      copy.remove('session_log'); // 🔥 الحمل الأكبر — محذوف من الـ realtime sync
      return copy;
    }).toList();

    return set(devicesStatePath(shopId), {
      'devices': slim,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
      'sender_id': senderId,
    });
  }

  /// Legacy full push — استخدمه بس في حالات استثنائية (مثلاً archive)
  static Future<bool> pushDevicesState(
      String shopId,
      List<Map<String, dynamic>> devicesState,
      String senderId) async {
    return set(devicesStatePath(shopId), {
      'devices': devicesState,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
      'sender_id': senderId,
    });
  }

  // 🔥 BANDWIDTH FIX #1b: pushSingleDeviceState — بيشيل session_log من الجهاز الواحد
  static Future<bool> pushSingleDeviceState(
      String shopId,
      int deviceIndex,
      Map<String, dynamic> deviceData,
      String senderId) async {
    final slim = Map<String, dynamic>.from(deviceData);
    slim.remove('session_log'); // 🔥 شيل الـ log من الـ PATCH الفردي كمان
    final updateData = {
      'devices/$deviceIndex': slim,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
      'sender_id': senderId,
    };
    return patch(devicesStatePath(shopId), updateData);
  }

  static Future<bool> pushTablesState(
      String shopId,
      List<Map<String, dynamic>> tables,
      String senderId) async {
    return set(tablesStatePath(shopId), {
      'tables': tables,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
      'sender_id': senderId,
    });
  }

  static Future<bool> pushDrinkTablesState(
      String shopId,
      List<Map<String, dynamic>> drinkTables,
      String senderId) async {
    return set(drinkTablesStatePath(shopId), {
      'drink_tables': drinkTables,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
      'sender_id': senderId,
    });
  }

  // 🔥 RACE CONDITION FIX: بيبعت تربيزة مشروبات واحدة بـ PATCH بدل كل الـ state
  // بيحل الـ race condition لأن كل تربيزة بتتحدث independently
  // لما تضيف أوردر على تربيزة 1 وبعدين تربيزة 2 بسرعة — مش بيـoverwrite بعض
  static Future<bool> pushSingleDrinkTable(
      String shopId,
      int index,
      Map<String, dynamic> drinkTableData,
      String senderId) async {
    final updateData = {
      'drink_tables/$index': drinkTableData,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
      'sender_id': senderId,
    };
    return patch(drinkTablesStatePath(shopId), updateData);
  }

  static Future<bool> pushTables(
      String shopId, List<Map<String, dynamic>> tables) async {
    return set(tablesPath(shopId), tables);
  }

  static Future<bool> pushDrinkTables(
      String shopId, List<Map<String, dynamic>> drinkTables) async {
    return set(drinkTablesPath(shopId), drinkTables);
  }

  static Future<bool> pushStaticData(
      String shopId, Map<String, dynamic> staticData,
      [String? senderId]) async {
    final data = Map<String, dynamic>.from(staticData);
    if (senderId != null) data['_sender_id'] = senderId;
    // 🔥 FIX: PATCH مش SET — عشان منمسحش حقول بيكتبها تطبيق تاني (بايثون)
    // مش موجودة في الـ payload بتاع الفلاتر (زي expenses, expense_categories).
    // SET كانت بتستبدل عقدة static/ بالكامل وتمسح أي حقل مش معروف للفلاتر.
    return patch(staticDataPath(shopId), data);
  }

  static Future<bool> appendSingleHistoryRecord(
      String shopId, Map<String, dynamic> singleRecord) async {
    return post(historyPath(shopId), singleRecord);
  }

  static Future<bool> pushOpenShifts(
      String shopId,
      Map<String, dynamic> openShifts,
      [String? senderId]) async {
    final data = Map<String, dynamic>.from(openShifts);
    if (senderId != null) data['_sender_id'] = senderId;
    return set(openShiftsPath(shopId), data);
  }

  // 🔥 BANDWIDTH FIX #3: pushShiftsHistory و pushDebts و pushTournaments
  // هي write-only operations — لا polling عليهم. بيتكتبوا بس عند التغيير.
  static Future<bool> pushShiftsHistory(
      String shopId, List<Map<String, dynamic>> shifts) async {
    return set(shiftsHistoryPath(shopId), shifts);
  }

  static Future<bool> pushDebts(
      String shopId, List<Map<String, dynamic>> debts) async {
    return set(debtsPath(shopId), debts);
  }

  static Future<bool> pushTournaments(
      String shopId, List<Map<String, dynamic>> tournaments) async {
    return set(shopTournamentsPath(shopId), tournaments);
  }

  // ─── أرشيف (إجماليات فقط) ──────────────────────────────────────────────

  /// يكتب الإجماليات فقط في `archives` — بدون حفظ تفاصيل الجلسات.
  static Future<String?> pushArchive({
    required String shopId,
    required String date,
    required double totalTime,
    required double totalBuffet,
    required double totalOverall,
  }) async {
    return push(shopArchivePath(shopId), {
      'date': date,
      'total_time': totalTime,
      'total_buffet': totalBuffet,
      'total_overall': totalOverall,
    });
  }

  /// يجيب التفاصيل الكاملة لأرشيف يوم معيّن (استخدمه عند الطلب فقط).
  static Future<List<Map<String, dynamic>>?> getArchiveDetails(
      String shopId, String archiveId) async {
    try {
      final data = await get(shopArchiveDetailPath(shopId, archiveId));
      if (data == null || data is! Map) return null;
      final records = data['records'];
      if (records == null) return [];
      if (records is List) {
        return records
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
      }
      return [];
    } catch (e) {
      print('Firebase getArchiveDetails error [$archiveId]: $e');
      return null;
    }
  }

  /// يجيب قائمة إجماليات الأرشيف بدون الجلسات (خفيف جداً).
  static Future<List<Map<String, dynamic>>> getArchivesList(
      String shopId) async {
    try {
      final data = await get(shopArchivePath(shopId));
      if (data == null) return [];
      if (data is Map) {
        return data.entries.map((e) {
          final m = Map<String, dynamic>.from(e.value as Map);
          m['_id'] = e.key;
          return m;
        }).toList()
          ..sort((a, b) {
            final da = DateTime.tryParse(a['date']?.toString() ?? '');
            final db = DateTime.tryParse(b['date']?.toString() ?? '');
            if (da == null || db == null) return 0;
            return db.compareTo(da);
          });
      }
      return [];
    } catch (e) {
      print('Firebase getArchivesList error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Pull منفصل لكل نوع بيانات
  // ═══════════════════════════════════════════════════════════════════════════

  // 🔥 BANDWIDTH FIX #3: limitToLast=20 — مش بنسحب كل السجلات أبداً.
  // الأدمن ممكن يحمل أكتر بـ fetchHistoryOnDemand() في AppState.
  /// بيجيب آخر [limit] سجل من history باستخدام limitToLast
  static Future<List<Map<String, dynamic>>> getRecentHistory(
    String shopId, {
    int limit = 20, // 🔥 خفّضنا من 200 لـ 20 — كفاية للعرض اليومي
  }) async {
    try {
      final url = _urlWithQuery(historyPath(shopId), {
        'limitToLast': limit.toString(),
        'orderBy': r'"$key"',
      });
      final r = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return [];
      final body = jsonDecode(r.body);
      if (body == null) return [];
      if (body is List) {
        return body
            .whereType<Map>()
            .map((h) => Map<String, dynamic>.from(h))
            .toList();
      }
      if (body is Map) {
        final list = body.values
            .whereType<Map>()
            .map((h) => Map<String, dynamic>.from(h))
            .toList();
        list.sort((a, b) {
          final da = DateTime.tryParse(a['date']?.toString() ?? '');
          final db = DateTime.tryParse(b['date']?.toString() ?? '');
          if (da == null || db == null) return 0;
          return da.compareTo(db);
        });
        return list;
      }
      return [];
    } catch (e) {
      print('Firebase getRecentHistory error: $e');
      return [];
    }
  }

  // 🔥 BANDWIDTH FIX #3b: getFullHistory — للأرشفة فقط، مش للعرض العادي.
  // استخدمه بس في archiveAndClear() — ولا تستخدمه في أي poll.
  static Future<List<Map<String, dynamic>>> getFullHistory(
      String shopId) async {
    try {
      final data = await get(historyPath(shopId));
      if (data == null) return [];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((h) => Map<String, dynamic>.from(h))
            .toList();
      }
      if (data is Map) {
        final list = data.values
            .whereType<Map>()
            .map((h) => Map<String, dynamic>.from(h))
            .toList();
        _sortHistoryByDate(list);
        return list;
      }
      return [];
    } catch (e) {
      print('Firebase getFullHistory error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // pullAllData — الآن يجيب static + realtime فقط (خفيف جداً)
  // history/debts/tournaments/shiftsHistory = on-demand فقط
  // ═══════════════════════════════════════════════════════════════════════════

  // 🔥 BANDWIDTH FIX #1 + #4: pullAllData بيجيب 5 nodes بدل 12.
  // المحذوف: history (on-demand), shiftsHistory (on-demand),
  //           debts (اتنقل لـ static), tournaments (on-demand).
  // static يتحمل مرة واحدة فقط — مش في كل poll.
  static Future<Map<String, dynamic>?> pullAllData(String shopId) async {
    try {
      final results = await Future.wait([
        get(devicesStatePath(shopId)),      // realtime — SSE بيغنيك عنه عادةً
        get(tablesStatePath(shopId)),       // realtime
        get(drinkTablesStatePath(shopId)),  // realtime
        get(staticDataPath(shopId)),        // 🔥 static — مرة واحدة عند الـ login
        get(openShiftsPath(shopId)),        // خفيف — map صغير
        get(dailySummaryPath(shopId)),      // خفيف — map صغير
        get(tablesPath(shopId)),            // operational tables config
        get(drinkTablesPath(shopId)),       // operational drink tables config
      ]);

      final devicesData      = results[0];
      final tablesRealtime   = results[1];
      final drinkRealtime    = results[2];
      final staticData       = results[3];
      final openShiftsData   = results[4];
      final dailySummaryData = results[5];
      final tablesOld        = results[6];
      final drinkOld         = results[7];

      final combined = <String, dynamic>{};

      // ── Devices ───────────────────────────────────────────────────────────
      if (devicesData != null && devicesData is Map) {
        final devices = devicesData['devices'];
        if (devices != null) combined['devices_state'] = devices;
      }

      // ── Tables ────────────────────────────────────────────────────────────
      if (tablesRealtime != null && tablesRealtime is Map) {
        final t = tablesRealtime['tables'];
        combined['tables'] = (t != null && t is List) ? t : [];
      } else if (tablesOld != null) {
        combined['tables'] = tablesOld is List ? tablesOld : [];
      }

      // ── Drink Tables ──────────────────────────────────────────────────────
      if (drinkRealtime != null && drinkRealtime is Map) {
        final d = drinkRealtime['drink_tables'];
        combined['drink_tables'] = (d != null && d is List) ? d : [];
      } else if (drinkOld != null) {
        combined['drink_tables'] = drinkOld is List ? drinkOld : [];
      }

      // ── Static Data ───────────────────────────────────────────────────────
      // 🔥 static يتحمل مرة واحدة هنا فقط — مش بيتحمل تاني في أي poll
      if (staticData != null && staticData is Map) {
        final s = Map<String, dynamic>.from(staticData);
        combined['prices']               = s['prices'];
        combined['menu']                 = s['menu'];
        combined['inventory']            = s['inventory'];
        combined['cashiers']             = s['cashiers'];
        combined['admin_password_hash']  = s['admin_password_hash'];
        combined['shop_name']            = s['shop_name'];
        combined['match_enabled']        = s['match_enabled'];
        combined['num_devices']          = s['num_devices'];
        combined['debts']                = s['debts'] ?? [];  // debts في static
        combined['history_password_hash']     = s['history_password_hash'];
        combined['history_password_enabled']  = s['history_password_enabled'];
        combined['buffet_categories']    = s['buffet_categories'];
        combined['menu_item_categories'] = s['menu_item_categories'];
        combined['menu_buy_prices']      = s['menu_buy_prices'];
        combined['expenses']             = s['expenses'];
        combined['expense_categories']   = s['expense_categories'];
        combined['recharge_enabled']     = s['recharge_enabled'];
        combined['recharge_balance']     = s['recharge_balance'];
        combined['recharge_cards']       = s['recharge_cards'];
        combined['recharge_transactions']= s['recharge_transactions'];
      }

      // ── Open Shifts ───────────────────────────────────────────────────────
      if (openShiftsData != null && openShiftsData is Map) {
        combined['open_shifts'] = Map<String, dynamic>.from(openShiftsData);
      }

      // ── Daily Summary ─────────────────────────────────────────────────────
      if (dailySummaryData != null && dailySummaryData is Map) {
        combined['daily_inventory_summary'] =
            Map<String, dynamic>.from(dailySummaryData);
      }

      // 🔥 history/shifts_history/tournaments — NOT included here.
      // يتحملوا on-demand بـ fetchHistoryOnDemand() / fetchShiftsHistoryOnDemand()
      // / fetchTournamentsOnDemand() في AppState.
      combined['history']        = []; // placeholder — بيتحمل on-demand
      combined['shifts_history'] = []; // placeholder
      combined['tournaments']    = []; // placeholder

      combined['last_updated'] = DateTime.now().millisecondsSinceEpoch;

      return combined;
    } catch (e) {
      print('Firebase pullAllData error: $e');
      return null;
    }
  }

  // ─── On-Demand Fetchers (يُستدعوا من AppState فقط عند الحاجة) ─────────────

  // 🔥 BANDWIDTH FIX #1: هذه الـ methods تُستدعى فقط لما الأدمن يفتح الشاشة

  /// يجيب آخر [limit] سجل — يُستدعى بس لما يفتح شاشة السجل
  static Future<List<Map<String, dynamic>>> fetchHistoryOnDemand(
      String shopId, {int limit = 50}) =>
      getRecentHistory(shopId, limit: limit);

  /// يجيب تاريخ الشيفتات — يُستدعى بس لما يفتح شاشة الشيفتات
  static Future<List<Map<String, dynamic>>> fetchShiftsHistoryOnDemand(
      String shopId) async {
    try {
      // 🔥 limitToLast=50 — مش بنسحب كل الشيفتات القديمة
      final url = _urlWithQuery(shiftsHistoryPath(shopId), {
        'limitToLast': '50',
        'orderBy': r'"$key"',
      });
      final r =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return [];
      final body = jsonDecode(r.body);
      if (body == null) return [];
      if (body is List) {
        return body
            .whereType<Map>()
            .map((s) => Map<String, dynamic>.from(s))
            .toList();
      }
      if (body is Map) {
        return body.values
            .whereType<Map>()
            .map((s) => Map<String, dynamic>.from(s))
            .toList();
      }
      return [];
    } catch (e) {
      print('Firebase fetchShiftsHistoryOnDemand error: $e');
      return [];
    }
  }

  /// يجيب البطولات — يُستدعى بس لما يفتح شاشة البطولات
  static Future<List<Map<String, dynamic>>> fetchTournamentsOnDemand(
      String shopId) async {
    try {
      final data = await get(shopTournamentsPath(shopId));
      if (data == null) return [];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((t) => Map<String, dynamic>.from(t))
            .toList();
      }
      return [];
    } catch (e) {
      print('Firebase fetchTournamentsOnDemand error: $e');
      return [];
    }
  }

  /// يجيب الديون — يُستدعى بس لما يفتح شاشة الديون (debts في static عادةً)
  static Future<List<Map<String, dynamic>>> fetchDebtsOnDemand(
      String shopId) async {
    try {
      final data = await get(debtsPath(shopId));
      if (data == null) return [];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((d) => Map<String, dynamic>.from(d))
            .toList();
      }
      return [];
    } catch (e) {
      print('Firebase fetchDebtsOnDemand error: $e');
      return [];
    }
  }

  // ─── Devices State ─────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>?> pullDevicesState(
      String shopId) async {
    try {
      final data = await get(devicesStatePath(shopId));
      if (data == null || data is! Map) return null;
      final devices = data['devices'];
      if (devices == null) return null;
      if (devices is List) {
        return devices
            .map((d) => Map<String, dynamic>.from(d as Map))
            .toList();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ─── SSE Listeners ─────────────────────────────────────────────────────────

  // 🔥 BANDWIDTH FIX #2: listenToDevices — بيفلتر session_log من أي SSE event جاي
  // عشان حتى لو جهاز تاني أرسل session_log بالغلط، احنا بنشيله قبل التطبيق
  static StreamSubscription<dynamic> listenToDevices(
    String shopId, {
    required void Function(
      Map<String, dynamic> rawData,
      List<Map<String, dynamic>> devices,
    ) onData,
    void Function(Object error)? onError,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    return listen(
      devicesStatePath(shopId),
      onData: (payload) {
        if (payload == null || payload is! Map) return;

        final eventPath = payload['path'] as String?;
        final eventData = payload['data'];

        // 🔥 FIX: partial patch من pushSingleDeviceState
        // Firebase بيبعت path = '/devices/3' مش '/'
        if (eventPath != null && eventPath.startsWith('/devices/') && eventData is Map) {
          try {
            final parts = eventPath.split('/');
            if (parts.length >= 3) {
              final idx = int.tryParse(parts[2]);
              if (idx != null) {
                final deviceData = Map<String, dynamic>.from(eventData);
                deviceData.remove('session_log');
                // ابعت الجهاز الواحد في list عشان onRemoteDevices يعالجه
                // sender_id موجود في الـ root node — نجيبه من payload
                final rootSenderId = payload['sender_id']?.toString() ?? '';
                final rawData = <String, dynamic>{
                  'sender_id': rootSenderId,
                  'single_device_index': idx,
                  'devices': [deviceData],
                };
                onData(rawData, [deviceData]);
              }
            }
          } catch (_) {}
          return; // مش نكمل للـ full state processing
        }

        if (eventData != null && eventData is Map) {
          final devices = eventData['devices'];
          if (devices is List) {
            try {
              final typed = devices
                  .map((d) {
                    if (d == null) return <String, dynamic>{};
                    final copy = Map<String, dynamic>.from(d as Map);
                    copy.remove('session_log'); // 🔥 شيل session_log من الـ SSE
                    return copy;
                  })
                  .toList();
              final rawData = Map<String, dynamic>.from(eventData);
              onData(rawData, typed);
            } catch (_) {}
          }
        }
      },
      onError: onError,
      retryDelay: retryDelay,
    );
  }

  static StreamSubscription<dynamic> listenToTables(
    String shopId, {
    required void Function(
        Map<String, dynamic> rawData,
        List<Map<String, dynamic>> tables) onData,
    void Function(Object error)? onError,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    return listen(
      tablesStatePath(shopId),
      onData: (payload) {
        if (payload == null || payload is! Map) return;
        final eventData = payload['data'];
        if (eventData == null || eventData is! Map) return;
        final tables = eventData['tables'];
        if (tables == null) return;
        if (tables is List) {
          try {
            final typed = tables
                .map((t) => t != null
                    ? Map<String, dynamic>.from(t as Map)
                    : <String, dynamic>{})
                .toList();
            final rawData = Map<String, dynamic>.from(eventData);
            onData(rawData, typed);
          } catch (_) {}
        }
      },
      onError: onError,
      retryDelay: retryDelay,
    );
  }

  static StreamSubscription<dynamic> listenToDrinkTables(
    String shopId, {
    String? senderId, // ✅ FIX: زي listenToTables و listenToStatic
    required void Function(
        Map<String, dynamic> rawData,
        List<Map<String, dynamic>> drinkTables) onData,
    void Function(Object error)? onError,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    return listen(
      drinkTablesStatePath(shopId),
      onData: (payload) {
        if (payload == null || payload is! Map) return;

        final eventPath = payload['path'] as String?;
        final eventData = payload['data'];

        // 🔥 RACE CONDITION FIX: handle partial patch من pushSingleDrinkTable
        // Firebase بيبعت path = '/drink_tables/2' مش '/'
        if (eventPath != null &&
            eventPath.startsWith('/drink_tables/') &&
            eventData is Map) {
          try {
            final parts = eventPath.split('/');
            if (parts.length >= 3) {
              final idx = int.tryParse(parts[2]);
              if (idx != null) {
                // لو احنا اللي بعتنا — تجاهل
                final patchSenderId = payload['sender_id']?.toString() ?? '';
                if (senderId != null && patchSenderId == senderId) return;
                final tableData = Map<String, dynamic>.from(eventData);
                final rawData = <String, dynamic>{
                  'sender_id': patchSenderId,
                  'single_drink_table_index': idx,
                };
                onData(rawData, [tableData]);
              }
            }
          } catch (_) {}
          return; // مش نكمل للـ full state processing
        }

        if (eventData == null || eventData is! Map) return;
        // ✅ FIX: لو احنا اللي بعتنا التغيير — متعملش merge تاني
        // ده بيمنع overwrite الطلبات لما تضيف أوردر على تربيزة 1 وبعدين 2
        if (senderId != null && eventData['sender_id'] == senderId) return;
        final drinkTables = eventData['drink_tables'];
        if (drinkTables == null) return;
        if (drinkTables is List) {
          try {
            final typed = drinkTables
                .map((t) => t != null
                    ? Map<String, dynamic>.from(t as Map)
                    : <String, dynamic>{})
                .toList();
            final rawData = Map<String, dynamic>.from(eventData);
            onData(rawData, typed);
          } catch (_) {}
        }
      },
      onError: onError,
      retryDelay: retryDelay,
    );
  }

  // 🔥 BANDWIDTH FIX #1b: listenToHistory — استخدمه بس للأدمن وبـ limitToLast
  // مش بيتنصت في الـ SyncService العادي للكاشيرين
  static StreamSubscription<dynamic> listenToHistory(
    String shopId, {
    int limit = 20, // 🔥 خفّفنا من 200 لـ 20
    required void Function(List<Map<String, dynamic>> history) onData,
    void Function(Object error)? onError,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    final fullUrl = _urlWithQuery(historyPath(shopId), {
      'limitToLast': limit.toString(),
      'orderBy': r'"$key"',
    });
    return _listenRaw(
      fullUrl,
      onData: (payload) {
        if (payload == null || payload is! Map) return;
        final data = payload['data'];
        if (data == null) {
          onData([]);
          return;
        }
        if (data is Map) {
          try {
            final typed = data.values
                .map((h) => Map<String, dynamic>.from(h as Map))
                .toList();
            _sortHistoryByDate(typed);
            onData(typed);
          } catch (_) {}
        } else if (data is List) {
          try {
            final typed = data
                .map((h) => h != null
                    ? Map<String, dynamic>.from(h as Map)
                    : <String, dynamic>{})
                .toList();
            _sortHistoryByDate(typed);
            onData(typed);
          } catch (_) {}
        }
      },
      onError: onError,
      retryDelay: retryDelay,
    );
  }

  /// فارز السجلات من الأقدم للأحدث حسب حقل date أو timestamp
  static void _sortHistoryByDate(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      final aVal = a['date'] ?? a['timestamp'] ?? a['created_at'];
      final bVal = b['date'] ?? b['timestamp'] ?? b['created_at'];
      if (aVal == null && bVal == null) return 0;
      if (aVal == null) return -1;
      if (bVal == null) return 1;
      if (aVal is num && bVal is num) return aVal.compareTo(bVal);
      return aVal.toString().compareTo(bVal.toString());
    });
  }

  static StreamSubscription<dynamic> listenToDailySummary(
    String shopId, {
    required void Function(Map<String, int> summary) onData,
    void Function(Object error)? onError,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    return listen(
      dailySummaryPath(shopId),
      onData: (payload) {
        if (payload == null || payload is! Map) return;
        final data = payload['data'];
        if (data == null) {
          onData({});
          return;
        }
        if (data is Map) {
          try {
            final typed = Map<String, int>.from(
              data.map(
                  (k, v) => MapEntry(k.toString(), (v as num).toInt())),
            );
            onData(typed);
          } catch (_) {}
        }
      },
      onError: onError,
      retryDelay: retryDelay,
    );
  }

  // 🔥 BANDWIDTH FIX: listenToShiftsHistory — مش مستخدمة في الـ SyncService العادي.
  // بس الأدمن يستخدمها on-demand لما يفتح شاشة الشيفتات.
  static StreamSubscription<dynamic> listenToShiftsHistory(
    String shopId, {
    required void Function(List<Map<String, dynamic>> shifts) onData,
    void Function(Object error)? onError,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    return listen(
      shiftsHistoryPath(shopId),
      onData: (payload) {
        if (payload == null || payload is! Map) return;
        final data = payload['data'];
        if (data == null) {
          onData([]);
          return;
        }
        if (data is List) {
          try {
            final typed = data
                .map((s) => s != null
                    ? Map<String, dynamic>.from(s as Map)
                    : <String, dynamic>{})
                .toList();
            onData(typed);
          } catch (_) {}
        }
      },
      onError: onError,
      retryDelay: retryDelay,
    );
  }

  // 🔥 BANDWIDTH FIX #4: listenToStatic — بيتنصت على الـ static node.
  // بيُستخدم لمزامنة التغييرات (أسعار / منيو) من الأدمن للكاشيرين فوراً.
  // مش محتاجين نعمل poll على static كل 60 ثانية بعد كده.
  static StreamSubscription<dynamic> listenToStatic(
    String shopId, {
    String? senderId,
    required void Function(Map<String, dynamic> data) onData,
    void Function(Object error)? onError,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    return listen(
      staticDataPath(shopId),
      onData: (payload) {
        if (payload == null || payload is! Map) return;
        final raw = payload['data'];
        if (raw == null || raw is! Map) return;
        try {
          final data = Map<String, dynamic>.from(raw);
          // ✅ FIX: لو احنا اللي بعتنا التغيير — متعملش applyStatic تاني
          if (senderId != null && data['_sender_id'] == senderId) return;
          data.remove('_sender_id');
          onData(data);
        } catch (_) {}
      },
      onError: onError,
      retryDelay: retryDelay,
    );
  }

  static StreamSubscription<dynamic> listenToOpenShifts(
    String shopId, {
    String? senderId,
    required void Function(Map<String, dynamic> openShifts) onData,
    void Function(Object error)? onError,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    return listen(
      openShiftsPath(shopId),
      onData: (payload) {
        if (payload == null || payload is! Map) return;
        final raw = payload['data'];
        if (raw is Map) {
          final data = Map<String, dynamic>.from(raw);
          if (senderId != null && data['_sender_id'] == senderId) return;
          data.remove('_sender_id');
          onData(data);
        } else {
          onData({});
        }
      },
      onError: onError,
      retryDelay: retryDelay,
    );
  }

  // ─── SSE Core ──────────────────────────────────────────────────────────────

  static StreamSubscription<dynamic> listen(
    String path, {
    required void Function(dynamic data) onData,
    void Function(Object error)? onError,
    void Function()? onDone,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    final controller = StreamController<dynamic>.broadcast();
    bool cancelled = false;

    Future<void> connect() async {
      while (!cancelled) {
        http.Client? client;
        try {
          client = http.Client();
          final request = http.Request('GET', Uri.parse(_url(path)));
          request.headers['Accept'] = 'text/event-stream';
          request.headers['Cache-Control'] = 'no-cache';

          final response = await client.send(request);

          if (response.statusCode != 200) {
            client.close();
            await Future.delayed(retryDelay);
            continue;
          }

          StringBuffer buffer = StringBuffer();

          await for (final chunk
              in response.stream.transform(utf8.decoder)) {
            if (cancelled) break;

            buffer.write(chunk);
            final raw = buffer.toString();
            final blocks = raw.split('\n\n');

            for (int i = 0; i < blocks.length - 1; i++) {
              _processSSEBlock(blocks[i], controller);
            }
            buffer = StringBuffer(blocks.last);
          }
        } catch (e) {
          if (!cancelled) onError?.call(e);
        } finally {
          client?.close();
        }

        if (!cancelled) await Future.delayed(retryDelay);
      }

      if (!controller.isClosed) controller.close();
      onDone?.call();
    }

    connect();

    final subscription = controller.stream.listen(
      onData,
      onError: onError,
    );

    return _CancellableSubscription(subscription, onCancel: () {
      cancelled = true;
    });
  }

  /// مثل [listen] بالظبط لكن بياخد URL كامل بدل path —
  /// بيُستخدم لما محتاجين نضيف query params زي limitToLast
  static StreamSubscription<dynamic> _listenRaw(
    String fullUrl, {
    required void Function(dynamic data) onData,
    void Function(Object error)? onError,
    void Function()? onDone,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    final controller = StreamController<dynamic>.broadcast();
    bool cancelled = false;

    Future<void> connect() async {
      while (!cancelled) {
        http.Client? client;
        try {
          client = http.Client();
          final request = http.Request('GET', Uri.parse(fullUrl));
          request.headers['Accept'] = 'text/event-stream';
          request.headers['Cache-Control'] = 'no-cache';

          final response = await client.send(request);

          if (response.statusCode != 200) {
            client.close();
            await Future.delayed(retryDelay);
            continue;
          }

          StringBuffer buffer = StringBuffer();

          await for (final chunk in response.stream.transform(utf8.decoder)) {
            if (cancelled) break;
            buffer.write(chunk);
            final raw = buffer.toString();
            final blocks = raw.split('\n\n');
            for (int i = 0; i < blocks.length - 1; i++) {
              _processSSEBlock(blocks[i], controller);
            }
            buffer = StringBuffer(blocks.last);
          }
        } catch (e) {
          if (!cancelled) onError?.call(e);
        } finally {
          client?.close();
        }
        if (!cancelled) await Future.delayed(retryDelay);
      }
      if (!controller.isClosed) controller.close();
      onDone?.call();
    }

    connect();

    final subscription = controller.stream.listen(onData, onError: onError);
    return _CancellableSubscription(subscription, onCancel: () {
      cancelled = true;
    });
  }

  static void _processSSEBlock(
      String block, StreamController<dynamic> controller) {
    String? eventType;
    String? dataLine;

    for (final line in block.split('\n')) {
      if (line.startsWith('event:')) {
        eventType = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLine = line.substring(5).trim();
      }
    }

    if ((eventType == 'put' || eventType == 'patch') && dataLine != null) {
      try {
        final parsed = jsonDecode(dataLine);
        if (!controller.isClosed) {
          controller.add({
            'event': eventType,
            'path': parsed['path'],
            'data': parsed['data'],
          });
        }
      } catch (_) {}
    }
  }

  static Future<Map<String, dynamic>?> getSubscriptionWithTimestamp(
      String shopId) async {
    try {
      final subFuture = http
          .get(Uri.parse(_url(shopSubscriptionPath(shopId))))
          .timeout(const Duration(seconds: 10));

      final timeFuture = http
          .get(Uri.parse(() { final c = _configFor(_currentShopId); return '${c["url"]}/.json?shallow=true&auth=${c["secret"]}'; }()))
          .timeout(const Duration(seconds: 10));

      final results = await Future.wait([subFuture, timeFuture]);

      final subResponse = results[0];
      final timeResponse = results[1];

      if (subResponse.statusCode != 200) return null;

      final subData = jsonDecode(subResponse.body);
      if (subData == null || subData is! Map) return null;

      final result = Map<String, dynamic>.from(subData);

      final dateHeader = timeResponse.headers['date'];
      if (dateHeader != null) {
        try {
          final serverTime = DateTime.parse(dateHeader);
          result['_server_time_ms'] = serverTime.millisecondsSinceEpoch;
        } catch (_) {
          result['_server_time_ms'] = DateTime.now().millisecondsSinceEpoch;
        }
      } else {
        result['_server_time_ms'] = DateTime.now().millisecondsSinceEpoch;
      }

      return result;
    } catch (e) {
      print('Firebase getSubscriptionWithTimestamp error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getSubscription(String shopId) async {
    // ✅ FIX: بنمرر shopId مباشرة لـ _configFor عشان نختار المشروع الصح
    // قبل كده كانت بتعتمد على _currentShopId اللي بيكون null وقت التحقق
    // فكانت دايماً بتروح على المشروع الـ default (PS1) حتى لو الكود PS2
    final cfg = _configFor(shopId);
    final path = shopSubscriptionPath(shopId);
    final url = '${cfg["url"]}/$path.json?auth=${cfg["secret"]}';
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (data == null || data is! Map) return null;
        return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      print('Firebase getSubscription error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>> getAllOpenShifts(String shopId) async {
    try {
      final data = await get(openShiftsPath(shopId));
      if (data == null || data is! Map) return {};
      return Map<String, dynamic>.from(data);
    } catch (_) {
      return {};
    }
  }
}

// ─── CancellableSubscription ─────────────────────────────────────────────────

class _CancellableSubscription<T> implements StreamSubscription<T> {
  final StreamSubscription<T> _inner;
  final void Function() onCancel;

  _CancellableSubscription(this._inner, {required this.onCancel});

  @override
  Future<void> cancel() {
    onCancel();
    return _inner.cancel();
  }

  @override
  bool get isPaused => _inner.isPaused;
  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);
  @override
  void resume() => _inner.resume();
  @override
  void onData(void Function(T data)? handleData) => _inner.onData(handleData);
  @override
  void onError(Function? handleError) => _inner.onError(handleError);
  @override
  void onDone(void Function()? handleDone) => _inner.onDone(handleDone);
  @override
  Future<E> asFuture<E>([E? futureValue]) => _inner.asFuture(futureValue);
}
