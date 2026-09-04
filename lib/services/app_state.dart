import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import '../models/device.dart';
import 'firebase_service.dart';
import 'notification_service.dart';
import '../services/shift_service.dart';
import 'sync_service.dart';
import 'audit_log_service.dart';
import '../models/buffet_category.dart';
import 'package:http/http.dart' as http;

// ═══════════════════════════════════════════════════════════════════════════════
// AppState — مُحسَّن لتخفيض استهلاك الـ bandwidth بنسبة 95%
//
// 🔥 BANDWIDTH OPTIMIZATIONS:
//   1. _pollAll() — لا يجيب history / debts / tournaments / shiftsHistory.
//      هذه البيانات تُحمَّل فقط عند الطلب (on-demand) عبر:
//        • fetchHistoryOnDemand()
//        • fetchDebtsOnDemand()
//        • fetchTournamentsOnDemand()
//        • fetchShiftsHistoryOnDemand()
//
//   2. session_log — لا يُرسل أبداً في الـ realtime sync.
//      يبقى في الذاكرة المحلية فقط، ويُرفع لـ Firebase مرة واحدة فقط
//      كجزء من السجل التاريخي عند stopDevice() / archiveAndClear().
//
//   3. _pollAll() — يُشغَّل فقط لما الـ SSE ينقطع (fallback).
//      مش بيجيب الـ static data (loaded once on login).
//
//   4. _fallbackPollTimer (كان 60 ثانية) — محذوف كلياً.
//      الـ static SSE listener بيغني عنه.
//
//   5. Static data — تُحمَّل مرة واحدة فقط في loadData().
//      التحديثات تصل عبر SSE (listenToStatic في SyncService).
//      لا poll دوري على الـ static node.
//
//   6. buildDevicesState — بيستخدم pushDevicesStateSlim (بدون session_log).
// ═══════════════════════════════════════════════════════════════════════════════

class AppState extends ChangeNotifier {
  List<PSDevice> devices = [];
  List<Map<String, dynamic>> history = [];
  Map<String, int> prices = {
    'ps4_normal': 25,
    'ps4_multi': 35,
    'ps5_normal': 40,
    'ps5_multi': 50,
    'match_ps4_normal': 10,
    'match_ps4_multi': 15,
    'match_ps5_normal': 15,
    'match_ps5_multi': 20,
    'ping_normal': 50,
    'billiard_normal': 40,
    'billiard_american': 50,
  };

  bool matchEnabled = true;
  Map<String, int> menu = {};
  List<BuffetCategory> buffetCategories = [];
  Map<String, String> _menuItemCategories = {};
  List<Map<String, dynamic>> tables = [];
  List<Map<String, dynamic>> drinkTables = [];
  List<Map<String, dynamic>> debts = [];
  List<Map<String, dynamic>> expenses = [];
  List<String> expenseCategories = ['إيجار', 'كهرباء', 'رواتب', 'صيانة', 'أخرى'];
  List<Map<String, dynamic>> tournaments = [];
  Map<String, int> inventory = {};
  Map<String, int> dailyInventorySummary = {};
  Map<String, int> menuBuyPrices = {};
  bool rechargeEnabled = false;
  double rechargeBalance = 0.0;
  List<Map<String, dynamic>> rechargeCards = [];
  List<Map<String, dynamic>> rechargeTransactions = [];
  Map<String, ShiftRecord> openShifts = {};
  List<ShiftRecord> shiftsHistory = [];

  // 🔥 FLAGS: هل البيانات الثقيلة اتحملت on-demand؟
  bool _historyLoaded = false;
  int _inventoryUpdatedAt = 0; // 🔥 timestamp آخر تحديث للمخزون محلياً
  bool _shiftsHistoryLoaded = false;
  bool _tournamentsLoaded = false;
  bool _debtsLoaded = false;

  // 🔥 FLAG: هل الـ static data اتحملت من Firebase؟ (مرة واحدة فقط)
  bool _staticLoaded = false;

  /// True لما يكون في fetch جاري (لإظهار loading indicator في الـ UI)
  bool isLoadingHistory = false;
  bool isLoadingShifts = false;
  bool isLoadingTournaments = false;
  bool isLoadingDebts = false;

  Map<String, dynamic> remoteOpenShifts = {};

  String? get activeShiftByCashier {
    for (final key in remoteOpenShifts.keys) {
      if (key != currentCashierName) return key;
    }
    return null;
  }

  bool get isShiftLockedByOther =>
      activeShiftByCashier != null && !hasOpenShift;

  String adminPasswordHash = '';
  String historyPasswordHash = '';
  bool historyPasswordEnabled = true;
  static const String _defaultHistoryHash =
      'ef797c8118f02dfb649607dd5d3f8c7623048c9c063d532cc95c5ed7a898a64f';

  List<Map<String, dynamic>> cashiers = [];
  String? currentCashierName;

  int numDevices = 0;
  bool isAdmin = false;
  bool isCashier = false;
  String shopName = 'Shosha PlayStation';

  Timer? _clockTimer;
  SyncService? _sync;

  // 🔥 BANDWIDTH FIX: _fallbackPollTimer حُذف كلياً.
  // كان بيجيب static data كل 60 ثانية — الـ SSE بيغني عنه.
  Timer? _historyPollTimer; // fallback لما SSE ينقطع — بس realtime بدون static/history

  bool _sseConnected = false;
  DateTime? _lastSseEvent;
  bool archiving = false;
  bool isEndingShift = false;

  String? shopId;
  bool isActivated = false;
  bool subscriptionActive = false;
  DateTime? subscriptionExpiry;

  final Set<int> _alertedDevices = {};
  final Set<int> _countdownAlertedDevices = {};
  final Set<int> _stoppingDevices = {};
  final Set<int> _stoppingTables = {};
  final Set<int> _checkoutDrinkTables = {};
  final Map<int, int> _localTableUpdateTs = {};

  String _myDeviceId = '';

  bool get isLoggedIn => isAdmin || isCashier;

  String? get userRole {
    if (isAdmin) return 'admin';
    if (isCashier) return 'cashier';
    return null;
  }

  bool get hasOpenShift =>
      currentCashierName != null &&
      openShifts.containsKey(currentCashierName);

  ShiftRecord? get currentShift =>
      currentCashierName != null ? openShifts[currentCashierName] : null;

  static String hashPassword(String p) =>
      sha256.convert(utf8.encode(p)).toString();

  static const String _defaultAdminHash =
      '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92';

  static const String _defaultCashierHash =
      'ef797c8118f02dfb649607dd5d3f8c7623048c9c063d532cc95c5ed7a898a64f';

  String get cashierPasswordHash =>
      cashiers.isNotEmpty
          ? cashiers.first['hash'] as String
          : _defaultCashierHash;

  Function(String deviceName, int minutes)? onTimerAlert;
  Function(PSDevice device)? onCountdownFinished;

  AppState() {
    adminPasswordHash = _defaultAdminHash;
    cashiers = [
      {'name': 'كاشير 1', 'hash': _defaultCashierHash}
    ];
    isCashier = false;
    _loadShopId();
    _startClock();
  }

  int matchPriceFor(PSDevice d) {
    final key = 'match_${d.deviceType}_${d.mode}';
    return prices[key] ?? prices['match_ps4_normal'] ?? 10;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CLOCK
  // ══════════════════════════════════════════════════════════════════════════

void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      bool anyActive = false;
      for (var d in devices) {
        if (d.isActive) {
          anyActive = true;
          d.updateTimer();
          _checkTimerAlert(d);
          _checkCountdownAlert(d);
        }
      }
      // دايماً notify عشان الـ UI يتحدث فوراً بعد أي تغيير
      notifyListeners();
    });
  }

  void _checkTimerAlert(PSDevice d) {
    if (d.timerAlertMinutes == null) return;
    final alertSeconds = d.timerAlertMinutes! * 60;
    final elapsed = d.elapsedSeconds;
    if (elapsed >= alertSeconds && !_alertedDevices.contains(d.id)) {
      _alertedDevices.add(d.id);
      NotificationService.showTimerAlert(d.displayName, d.timerAlertMinutes!);
      onTimerAlert?.call(d.displayName, d.timerAlertMinutes!);
    }
  }

  void _checkCountdownAlert(PSDevice d) {
    if (!d.isCountdown || d.countdownTotalSeconds == null) return;
    if (d.countdownAlertSent) return;
    if (!d.countdownFinished) return;

    d.countdownAlertSent = true;
    _countdownAlertedDevices.add(d.id);

    if (!d.isPaused) {
      d.isPaused = true;
      d.pauseStartTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    }

    NotificationService.showTimerAlert(
      d.displayName,
      d.countdownTotalSeconds! ~/ 60,
    );

    onCountdownFinished?.call(d);
    _saveDevices();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SYNC
  // ══════════════════════════════════════════════════════════════════════════

  DateTime? _syncStartTime;

  void _startSync() {
    _syncStartTime = DateTime.now();
    _sync?.dispose();
    _sync = SyncService(
      shopId: shopId!,
      senderId: _myDeviceId,
      callbacks: SyncCallbacks(
        onRemoteDevices: (rawData, remoteDevices) {
          if (rawData['sender_id'] == _myDeviceId) return;
          _markSseAlive();
          // 🔥 FIX: لو جاي جهاز واحد بس (partial patch) — merge جزئي
          final singleIdx = rawData['single_device_index'] as int?;
          if (singleIdx != null && remoteDevices.length == 1) {
            _mergeSingleDevice(remoteDevices.first);
          } else {
            _mergeRemoteDevices(remoteDevices);
          }
          notifyListeners();
        },
        onRemoteTables: (rawData, remoteTables) {
          if (rawData['sender_id'] == _myDeviceId) return;
          _markSseAlive();
          _mergeRemoteTables(remoteTables);
          notifyListeners();
        },
        onRemoteDrinkTables: (rawData, remoteDrinkTables) {
          if (rawData['sender_id'] == _myDeviceId) return;
          _markSseAlive();
          // 🔥 RACE CONDITION FIX: لو SSE جاب partial patch (تربيزة واحدة)
          final singleIdx = rawData['single_drink_table_index'] as int?;
          if (singleIdx != null && remoteDrinkTables.length == 1) {
            _mergeSingleRemoteDrinkTable(singleIdx, remoteDrinkTables.first);
          } else {
            _mergeRemoteDrinkTables(remoteDrinkTables);
          }
          notifyListeners();
        },
        onRemoteStatic: (data) {
          // 🔥 BANDWIDTH FIX #4: static يصل عبر SSE — لا poll دوري
          // ✅ FIX: لو احنا اللي بعتنا التغيير — متعملش applyStatic تاني
          if (data['_sender_id'] == _myDeviceId) return;
          _markSseAlive();
          _applyStaticData(data);
          notifyListeners();
        },
        onRemoteDailySummary: (remoteSummary) {
          dailyInventorySummary = remoteSummary;
          notifyListeners();
        },
        // 🔥 BANDWIDTH FIX #1: onRemoteHistory — بس للأدمن، limit=1 من الـ SSE
        onRemoteHistory: (remoteHistory) {
          for (final record in remoteHistory) {
            final alreadyExists = history.any((h) => h['date'] == record['date']);
            if (!alreadyExists) {
              history.add(record);
              notifyListeners();
            }
          }
        },
        // 🔥 BANDWIDTH FIX #1: onRemoteShiftsHistory — بيتم on-demand، مش SSE دايم
        onRemoteShiftsHistory: (remoteShifts) {
          final typed = remoteShifts
              .map((s) => ShiftRecord.fromJson(s))
              .toList();
          if (typed.length != shiftsHistory.length) {
            shiftsHistory = typed;
            notifyListeners();
          }
        },
        onRemoteOpenShifts: (raw) {
          if (raw['_sender_id'] == _myDeviceId) return;
          remoteOpenShifts = raw;
          notifyListeners();
        },
        // 🔥 BANDWIDTH FIX #2: buildDevicesState — session_log مش موجود في الـ payload
        // session_log بيبقى في الذاكرة المحلية بس، ويتحفظ في history عند stopDevice
        buildDevicesState: () => devices.map((d) {
          final json = d.toJson();
          json.remove('session_log'); // 🔥 مش بنرسله في الـ realtime sync أبداً
          return json;
        }).toList(),
        buildTables: () => tables,
        buildDrinkTables: () => drinkTables,
        buildStaticData: _buildStaticData,
        buildHistory: () => history,
        buildOpenShifts: () =>
            openShifts.map((k, v) => MapEntry(k, v.toJson())),
        buildShiftsHistory: () =>
            shiftsHistory.map((s) => s.toJson()).toList(),
        buildDebts: () => debts,
        buildTournaments: () => tournaments,
      ),
    );
    _sync!.start();

    // 🔥 BANDWIDTH FIX: Polling ذكي — فقط لما SSE ينقطع > 60 ثانية
    // لا يجيب static / history / debts / tournaments / shiftsHistory
    _historyPollTimer?.cancel();

    _historyPollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final appJustStarted = _syncStartTime != null &&
          DateTime.now().difference(_syncStartTime!).inSeconds < 60;
      if (appJustStarted) return;

      final sseStale = _lastSseEvent == null ||
          DateTime.now().difference(_lastSseEvent!).inSeconds > 60;
      if (sseStale && !archiving) {
        _sseConnected = false;
        _pollRealtimeOnly(); // 🔥 بس realtime — لا static ولا history ولا ثقيل
      }
    });

    // 🔥 BANDWIDTH FIX #4: _fallbackPollTimer حُذف كلياً.
    // الـ static SSE listener في SyncService بيغني عنه تماماً.
    // لو الأدمن غيّر سعر، الـ SSE بيوصّله لكل الأجهزة فوراً.
  }

  void _markSseAlive() {
    _sseConnected = true;
    _lastSseEvent = DateTime.now();
  }

  // 🔥 BANDWIDTH FIX #1 + #3 + #4: _pollRealtimeOnly — بيجيب realtime فقط
  // المحذوف: static (SSE بيغني عنه) + history + debts + tournaments + shiftsHistory
  // ده بيشتغل بس لما الـ SSE ينقطع — fallback خفيف جداً
  Future<void> _pollRealtimeOnly() async {
    if (shopId == null || archiving) return;
    try {
      final results = await Future.wait([
        FirebaseService.get(FirebaseService.openShiftsPath(shopId!)),
        FirebaseService.get(FirebaseService.dailySummaryPath(shopId!)),
        FirebaseService.get(FirebaseService.devicesStatePath(shopId!)),
        FirebaseService.get(FirebaseService.tablesStatePath(shopId!)),
        FirebaseService.get(FirebaseService.drinkTablesStatePath(shopId!)),
        // 🔥 لا static — بيتحمل مرة واحدة ويتحدث عبر SSE
        // 🔥 لا history — on-demand
        // 🔥 لا debts — في static
        // 🔥 لا tournaments — on-demand
        // 🔥 لا shiftsHistory — on-demand
      ]);

      bool changed = false;

      // ── الشيفتات المفتوحة ─────────────────────────────────────────────────
      final remoteOpenShiftsData = results[0];
      if (remoteOpenShiftsData != null && remoteOpenShiftsData is Map) {
        final raw = Map<String, dynamic>.from(remoteOpenShiftsData);
        raw.remove('_sender_id');
        final typed = raw.map((k, v) =>
            MapEntry(k, ShiftRecord.fromJson(Map<String, dynamic>.from(v))));
        typed.forEach((name, shift) {
          if (!openShifts.containsKey(name)) {
            openShifts[name] = shift;
            changed = true;
          }
        });
        openShifts.removeWhere((name, _) {
          if (!typed.containsKey(name)) {
            changed = true;
            return true;
          }
          return false;
        });
      }

      // ── ملخص المخزون اليومي ───────────────────────────────────────────────
      final remoteSummary = results[1];
      if (remoteSummary != null && remoteSummary is Map) {
        final typed = Map<String, int>.from(
            remoteSummary.map((k, v) =>
                MapEntry(k.toString(), (v as num).toInt())));
        if (typed.length != dailyInventorySummary.length) {
          dailyInventorySummary = typed;
          changed = true;
        }
      }

      // ── حالة الأجهزة ──────────────────────────────────────────────────────
      final remoteDevicesData = results[2];
      if (remoteDevicesData != null && remoteDevicesData is Map) {
        // 🔥 FIX: لو احنا اللي بعتنا التغيير ده — متعملش merge
        final devSenderId = remoteDevicesData['sender_id']?.toString();
        if (devSenderId != _myDeviceId) {
          final devices = remoteDevicesData['devices'];
          if (devices is List) {
            final typed = devices
                .map((d) {
                  if (d == null) return <String, dynamic>{};
                  final copy = Map<String, dynamic>.from(d as Map);
                  copy.remove('session_log'); // 🔥 شيل session_log دايماً
                  return copy;
                })
                .toList();
            _mergeRemoteDevices(typed);
            changed = true;
          }
        }
      }

      // ── حالة التربيزات ────────────────────────────────────────────────────
      final remoteTablesData = results[3];
      if (remoteTablesData != null && remoteTablesData is Map) {
        final t = remoteTablesData['tables'];
        if (t is List) {
          _mergeRemoteTables(t
              .map((e) => e != null
                  ? Map<String, dynamic>.from(e as Map)
                  : <String, dynamic>{})
              .toList());
          changed = true;
        }
      }

      // ── حالة تربيزات المشروبات ────────────────────────────────────────────
      final remoteDrinkData = results[4];
      if (remoteDrinkData != null && remoteDrinkData is Map) {
        final d = remoteDrinkData['drink_tables'];
        if (d is List) {
          _mergeRemoteDrinkTables(d
              .map((e) => e != null
                  ? Map<String, dynamic>.from(e as Map)
                  : <String, dynamic>{})
              .toList());
          changed = true;
        }
      }

      if (changed) notifyListeners();
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ON-DEMAND FETCHERS — يُستدعوا من الـ UI فقط عند الحاجة
  // ══════════════════════════════════════════════════════════════════════════

  // 🔥 BANDWIDTH FIX #1: هذه الـ methods تُستدعى من الـ UI
  // لما الأدمن/الكاشير يفتح الشاشة المناسبة فقط

  /// يُستدعى لما يفتح شاشة السجل — بيجيب آخر 50 سجل
  Future<void> fetchHistoryOnDemand({int limit = 50}) async {
    if (shopId == null || isLoadingHistory) return;
    if (_historyLoaded && history.isNotEmpty && limit <= 50) return; // 🔥 محمّل بالفعل (الـ refresh اليدوي بـ limit=300 بيتجاوز الـ check)
    isLoadingHistory = true;
    notifyListeners();
    try {
      final remote =
          await FirebaseService.fetchHistoryOnDemand(shopId!, limit: limit);
      if (remote.isNotEmpty) {
        history = remote;
        _historyLoaded = true;
        await SyncService.saveLocal(shopId!, _buildDataDict());
      }
    } catch (_) {} finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  /// يُستدعى لما يفتح شاشة الشيفتات
  Future<void> fetchShiftsHistoryOnDemand() async {
    if (shopId == null || isLoadingShifts) return;
    if (_shiftsHistoryLoaded && shiftsHistory.isNotEmpty) return; // 🔥 محمّل بالفعل
    isLoadingShifts = true;
    notifyListeners();
    try {
      final remote =
          await FirebaseService.fetchShiftsHistoryOnDemand(shopId!);
      if (remote.isNotEmpty) {
        shiftsHistory = remote
            .map((s) => ShiftRecord.fromJson(s))
            .toList();
        _shiftsHistoryLoaded = true;
        await SyncService.saveLocal(shopId!, _buildDataDict()); // 🔥 حفظ محلي
      }
    } catch (_) {} finally {
      isLoadingShifts = false;
      notifyListeners();
    }
  }

  /// يُستدعى لما يفتح شاشة البطولات
  Future<void> fetchTournamentsOnDemand() async {
    if (shopId == null || isLoadingTournaments) return;
    if (_tournamentsLoaded && tournaments.isNotEmpty) return; // 🔥 محمّل بالفعل
    isLoadingTournaments = true;
    notifyListeners();
    try {
      final remote = await FirebaseService.fetchTournamentsOnDemand(shopId!);
      if (remote.isNotEmpty) {
        tournaments = remote;
        _tournamentsLoaded = true;
        await SyncService.saveLocal(shopId!, _buildDataDict()); // 🔥 حفظ محلي
      }
    } catch (_) {} finally {
      isLoadingTournaments = false;
      notifyListeners();
    }
  }

  /// يُستدعى لما يفتح شاشة الديون (debts موجودة في static عادةً —
  /// ده للـ refresh اليدوي فقط)
  Future<void> fetchDebtsOnDemand() async {
    if (shopId == null || isLoadingDebts) return;
    if (_debtsLoaded && debts.isNotEmpty) return; // 🔥 محمّل بالفعل
    isLoadingDebts = true;
    notifyListeners();
    try {
      final remote = await FirebaseService.fetchDebtsOnDemand(shopId!);
      debts = remote;
      _debtsLoaded = true;
      await SyncService.saveLocal(shopId!, _buildDataDict()); // 🔥 حفظ محلي
    } catch (_) {} finally {
      isLoadingDebts = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MERGE HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  void _mergeRemoteHistory(List<Map<String, dynamic>> remoteHistory) {
    if (remoteHistory.isEmpty) return;
    if (remoteHistory.length > history.length) {
      history = remoteHistory;
    }
  }

  static List<Map<String, dynamic>> _historyFromFirebase(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((h) => Map<String, dynamic>.from(h))
          .toList();
    }
    if (raw is Map) {
      final list = raw.values
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
  }

  void _mergeRemoteDevices(List<Map<String, dynamic>> remoteDevices) {
    if (remoteDevices.isEmpty) return;

    final remoteIds = remoteDevices
        .map((j) => (j['id'] as num?)?.toInt() ?? 0)
        .toSet();

    devices.removeWhere((d) => !remoteIds.contains(d.id));

    for (final remoteJson in remoteDevices) {
      final remoteId = (remoteJson['id'] as num?)?.toInt() ?? 0;
      final idx = devices.indexWhere((d) => d.id == remoteId);
      if (idx != -1) {
        // 🔥 احتفظ بـ session_log المحلي — لا تستبدله بالريموت (مفيش فيه)
        final localLog = devices[idx].sessionLog;
        final updated = PSDevice.fromJson(remoteJson, remoteId);
        updated.sessionLog = localLog; // استعادة الـ log المحلي
        updated.updateTimer();
        devices[idx] = updated;
      } else {
        final newDevice = PSDevice.fromJson(remoteJson, remoteId);
        newDevice.updateTimer();
        devices.add(newDevice);
      }
    }
  }

  // 🔥 FIX: merge جهاز واحد بس بدون ما نمسح باقي الأجهزة
  void _mergeSingleDevice(Map<String, dynamic> remoteJson) {
    final remoteId = (remoteJson['id'] as num?)?.toInt() ?? 0;
    final idx = devices.indexWhere((d) => d.id == remoteId);
    if (idx != -1) {
      final localLog = devices[idx].sessionLog;
      final updated = PSDevice.fromJson(remoteJson, remoteId);
      updated.sessionLog = localLog;
      updated.updateTimer();
      devices[idx] = updated;
    }
  }

  void _mergeRemoteTables(List<Map<String, dynamic>> remoteTables) {
    if (remoteTables.isEmpty) return;
    while (tables.length < remoteTables.length) {
      tables.add(remoteTables[tables.length]);
    }
    for (int i = 0; i < remoteTables.length; i++) {
      tables[i] = remoteTables[i];
    }
    if (remoteTables.length < tables.length) {
      tables.removeRange(remoteTables.length, tables.length);
    }
  }

  void _mergeRemoteDrinkTables(
      List<Map<String, dynamic>> remoteDrinkTables) {
    if (remoteDrinkTables.isEmpty) return;
    while (drinkTables.length < remoteDrinkTables.length) {
      drinkTables.add(remoteDrinkTables[drinkTables.length]);
    }
    for (int i = 0; i < remoteDrinkTables.length; i++) {
      final remote = remoteDrinkTables[i];
      final local = drinkTables[i];
      final localOrders = Map<String, int>.from(local['orders'] ?? {});
      final remoteOrders = Map<String, int>.from(remote['orders'] ?? {});
      // 🔥 RACE CONDITION FIX: لو المحلي فيه طلبات والريموت فاضي
      // ده يعني غالباً race condition — خد الريموت في باقي الحقول بس
      if (localOrders.isNotEmpty && remoteOrders.isEmpty) {
        drinkTables[i] = {...remote, 'orders': localOrders};
      } else {
        drinkTables[i] = remote;
      }
    }
    if (remoteDrinkTables.length < drinkTables.length) {
      drinkTables.removeRange(remoteDrinkTables.length, drinkTables.length);
    }
  }

  // 🔥 RACE CONDITION FIX: يُستدعى من onRemoteDrinkTables لما SSE يبعت
  // single_drink_table_index (partial patch من pushSingleDrinkTable)
  void _mergeSingleRemoteDrinkTable(int index, Map<String, dynamic> remoteTable) {
    if (index < 0 || index >= drinkTables.length) return;
    final localOrders = Map<String, int>.from(drinkTables[index]['orders'] ?? {});
    final remoteOrders = Map<String, int>.from(remoteTable['orders'] ?? {});
    if (localOrders.isNotEmpty && remoteOrders.isEmpty) {
      drinkTables[index] = {...remoteTable, 'orders': localOrders};
    } else {
      drinkTables[index] = remoteTable;
    }
  }

  void _applyStaticData(Map<String, dynamic> s) {
    if (s['history_password_enabled'] != null) {
      historyPasswordEnabled = s['history_password_enabled'];
    }
    if (s['expenses'] != null) {
      expenses = List<Map<String, dynamic>>.from(
          (s['expenses'] as List).map((e) => Map<String, dynamic>.from(e)));
    }
    if (s['expense_categories'] != null) {
      expenseCategories =
          List<String>.from(s['expense_categories'] as List);
    }
    if (s['prices'] != null) {
      _migratePrices(Map<String, dynamic>.from(s['prices']));
    }
    if (s['menu'] != null) {
      menu = Map<String, int>.from(s['menu']);
    }
    if (s['buffet_categories'] != null) {
      buffetCategories = (s['buffet_categories'] as List)
          .map((c) =>
              BuffetCategory.fromJson(Map<String, dynamic>.from(c)))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    if (s['menu_item_categories'] != null) {
      _menuItemCategories =
          Map<String, String>.from(s['menu_item_categories']);
    }
    if (s['inventory'] != null) {
      final remoteInv = Map<String, int>.from(s['inventory']);
      final remoteTs = (s['inventory_updated_at'] as num?)?.toInt() ?? 0;
      // 🔥 FIX: لو الـ remote أحدث من المحلي → حدّث، لو أقدم → سيبه
      if (remoteTs >= _inventoryUpdatedAt) {
        inventory = remoteInv;
        _inventoryUpdatedAt = remoteTs;
      } else {
        // بس أضف أصناف جديدة مش موجودة محلياً
        for (final entry in remoteInv.entries) {
          inventory.putIfAbsent(entry.key, () => entry.value);
        }
        inventory.removeWhere((k, _) => !remoteInv.containsKey(k));
      }
    }
    if (s['cashiers'] != null) {
      cashiers = List<Map<String, dynamic>>.from(
          (s['cashiers'] as List)
              .map((c) => Map<String, dynamic>.from(c)));
    }
    if (s['admin_password_hash'] != null) {
      adminPasswordHash = s['admin_password_hash'];
    }
    if (s['shop_name'] != null) {
      shopName = s['shop_name'];
    } else if (s['settings'] != null &&
        (s['settings'] as Map)['shop_name'] != null) {
      shopName = (s['settings'] as Map)['shop_name'];
    }
    if (s['match_enabled'] != null) {
      matchEnabled = s['match_enabled'];
    } else if (s['settings'] != null &&
        (s['settings'] as Map)['match_enabled'] != null) {
      matchEnabled = (s['settings'] as Map)['match_enabled'];
    }
    if (s['history_password_hash'] != null) {
      historyPasswordHash = s['history_password_hash'];
    }
    // 🔥 debts في static — بيتحمل مع الـ static data مش on-demand منفصل
    if (s['debts'] != null) {
      debts = List<Map<String, dynamic>>.from(
          (s['debts'] as List)
              .map((d) => Map<String, dynamic>.from(d)));
    }
    if (s['recharge_enabled'] != null) rechargeEnabled = s['recharge_enabled'];
    if (s['recharge_balance'] != null) {
      rechargeBalance = (s['recharge_balance'] as num).toDouble();
    }
    if (s['recharge_cards'] != null) {
      rechargeCards = List<Map<String, dynamic>>.from(
          (s['recharge_cards'] as List)
              .map((c) => Map<String, dynamic>.from(c)));
    }
    if (s['recharge_transactions'] != null) {
      rechargeTransactions = List<Map<String, dynamic>>.from(
          (s['recharge_transactions'] as List)
              .map((t) => Map<String, dynamic>.from(t)));
    }
    if (s['menu_buy_prices'] != null) {
      menuBuyPrices = Map<String, int>.from(s['menu_buy_prices']);
    }
  }

  void _mergeRemoteOperational(Map<String, dynamic> data) {
    if (data.containsKey('tables') && data['tables'] != null) {
      final remoteTables = data['tables'];
      if (remoteTables is List) {
        final updatedTables = remoteTables
            .map((t) => Map<String, dynamic>.from(t as Map))
            .toList();
        for (int i = 0;
            i < updatedTables.length && i < tables.length;
            i++) {
          if (tables[i]['start_time'] == null) {
            tables[i] = updatedTables[i];
          }
        }
        if (updatedTables.length > tables.length) {
          tables.addAll(updatedTables.sublist(tables.length));
        }
      }
    }

    if (data.containsKey('drink_tables') && data['drink_tables'] != null) {
      final remoteDrink = data['drink_tables'];
      if (remoteDrink is List) {
        final updatedDrink = remoteDrink
            .map((t) => Map<String, dynamic>.from(t as Map))
            .toList();
        for (int i = 0;
            i < updatedDrink.length && i < drinkTables.length;
            i++) {
          final localOrders =
              Map<String, int>.from(drinkTables[i]['orders'] ?? {});
          if (localOrders.isEmpty) {
            drinkTables[i] = updatedDrink[i];
          }
        }
        if (updatedDrink.length > drinkTables.length) {
          drinkTables.addAll(updatedDrink.sublist(drinkTables.length));
        }
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACTIVATION SYSTEM
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadShopId() async {
    final prefs = await SharedPreferences.getInstance();

    String? savedDeviceId = prefs.getString('device_id');
    if (savedDeviceId == null) {
      savedDeviceId = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString('device_id', savedDeviceId);
    }
    _myDeviceId = savedDeviceId;

    final savedId = prefs.getString('shop_id');

    if (savedId == null) {
      notifyListeners();
      return;
    }

    shopId = savedId;
    FirebaseService.setShopId(savedId); // ✅ MULTI-PROJECT

    final localData = await SyncService.loadLocal(savedId);
    if (localData != null) {
      _applyData(localData);
      notifyListeners();
    }

    final cachedExpiry = prefs.getString('sub_expires_$savedId');
    if (cachedExpiry != null) {
      final expiry = DateTime.tryParse(cachedExpiry);
      if (expiry != null) {
        subscriptionExpiry = expiry;

        if (DateTime.now().isBefore(expiry)) {
          // ✅ الاشتراك لسه شغال — يشتغل حتى لو مفيش نت
          isActivated = true;
          subscriptionActive = true;
          notifyListeners();
          _startSync();
          _restoreOpenShiftFromFirebase();
          await _restoreLoginState();
          notifyListeners();
          _checkSubscriptionOnline(); // في الخلفية بس — مش blocking
          return;
        } else {
          // ❌ الاشتراك خلص — صفحة الكود مباشرة بدون ما نحتاج نت
          isActivated = false;
          subscriptionActive = false;
          notifyListeners();
          return;
        }
      }
    }

    // مفيش كاش خالص = أول مرة = لازم نت + كود
    isActivated = false;
    subscriptionActive = false;
    notifyListeners();
  }

  Future<void> _restoreOpenShiftFromFirebase() async {
    if (shopId == null) return;
    try {
      final raw = await FirebaseService.getAllOpenShifts(shopId!);
      if (raw.isEmpty) return;

      final cleanRaw = Map<String, dynamic>.from(raw)..remove('_sender_id');
      if (cleanRaw.isEmpty) return;

      remoteOpenShifts = cleanRaw;
      final updatedOpenShifts = <String, ShiftRecord>{};
      cleanRaw.forEach((name, value) {
        if (value is Map) {
          updatedOpenShifts[name] =
              ShiftRecord.fromJson(Map<String, dynamic>.from(value));
        }
      });
      updatedOpenShifts.forEach((name, shift) {
        openShifts.putIfAbsent(name, () => shift);
      });
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _checkSubscriptionOnline() async {
    if (shopId == null) return;
    try {
      final sub = await FirebaseService.getSubscription(shopId!);
      if (sub == null) {
        isActivated = false;
        subscriptionActive = false;
        notifyListeners();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final active = sub['active'] as bool? ?? false;
      final expiresStr = sub['expires'] as String?;

      if (!active) {
        isActivated = false;
        subscriptionActive = false;
        subscriptionExpiry =
            expiresStr != null ? DateTime.tryParse(expiresStr) : null;
        notifyListeners();
        return;
      }

      if (expiresStr != null) {
        final firebaseExpiry = DateTime.tryParse(expiresStr);
        if (firebaseExpiry != null) {
          await prefs.setString('sub_expires_$shopId', expiresStr);
          subscriptionExpiry = firebaseExpiry;

          if (DateTime.now().isAfter(firebaseExpiry)) {
            isActivated = false;
            subscriptionActive = false;
            notifyListeners();
            return;
          }
        }
      }

      isActivated = true;
      subscriptionActive = true;
      _startSync();
      await _restoreLoginState();
      notifyListeners();
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final cachedExpiry = prefs.getString('sub_expires_$shopId');
      if (cachedExpiry != null) {
        final expiry = DateTime.tryParse(cachedExpiry);
        if (expiry != null && DateTime.now().isBefore(expiry)) {
          isActivated = true;
          subscriptionActive = true;
          subscriptionExpiry = expiry;
          notifyListeners();
          _startSync();
        }
      }
    }
  }

  Future<String?> activateShop(String code) async {
    final id = code.trim().toUpperCase();
    if (id.isEmpty) return '⚠️ اكتب كود التفعيل';
    try {
      final sub = await FirebaseService.getSubscription(id);
      if (sub == null) return '❌ كود غلط، تأكد من الكود وحاول تاني';
      final active = sub['active'] as bool? ?? false;
      if (!active) return '❌ هذا المحل موقوف، تواصل مع المطور';
      final expiresStr = sub['expires'] as String?;
      if (expiresStr != null) {
        final expiry = DateTime.tryParse(expiresStr);
        if (expiry != null && DateTime.now().isAfter(expiry)) {
          final d = '${expiry.day}/${expiry.month}/${expiry.year}';
          return '❌ انتهى الاشتراك في $d، تواصل مع المطور للتجديد';
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('sub_expires_$id', expiresStr);
        subscriptionExpiry = expiry;
      }
      shopId = id;
      FirebaseService.setShopId(id); // ✅ MULTI-PROJECT
      subscriptionActive = true;
      isActivated = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shop_id', id);
      final shopNameFromFb = sub['shop_name'] as String?;
      if (shopNameFromFb != null && shopNameFromFb.isNotEmpty) {
        shopName = shopNameFromFb;
      }
      await loadData();
      notifyListeners();
      return null;
    } catch (e) {
      return '❌ تعذر الاتصال بالسيرفر، تأكد من الإنترنت وحاول تاني';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOAD DATA
  // ══════════════════════════════════════════════════════════════════════════

  // 🔥 BANDWIDTH FIX #4: loadData — static يتحمل مرة واحدة فقط هنا.
  // بعد كده الـ SSE بيحدّث الـ static تلقائياً لو في تغيير.
  Future<void> loadData() async {
    if (shopId == null) return;

    final local = await SyncService.loadLocal(shopId!);
    if (local != null) {
      _applyData(local);
      notifyListeners();
      // لو عندنا cache محلي حديث (أقل من 5 دقايق) مش محتاجين pull كامل
      final lastUpdated = local['last_updated'] as int?;
      if (lastUpdated != null) {
        final age = DateTime.now().millisecondsSinceEpoch - lastUpdated;
        if (age < 5 * 60 * 1000) {
          _staticLoaded = true; // اعتبر الـ static محملة من الـ cache
          _startSync();
          return;
        }
      }
    }

    try {
      // 🔥 pullAllData بيجيب static + realtime فقط (بدون history/shifts/tournaments)
      final remoteData = await FirebaseService.pullAllData(shopId!);
      if (remoteData != null) {
        _applyData(remoteData);
        _staticLoaded = true; // static اتحملت من Firebase
        await SyncService.saveLocal(shopId!, remoteData);
        notifyListeners();
      }
    } catch (_) {}

    _startSync();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // APPLY DATA
  // ══════════════════════════════════════════════════════════════════════════

  void _applyData(Map<String, dynamic> data) {
    if (data['history_password_enabled'] != null) {
      historyPasswordEnabled = data['history_password_enabled'];
    }
    // 🔥 history — بيتحمل من الـ cache المحلي بس (لو موجود)
    // لا يتحمل من Firebase في loadData (on-demand فقط)
    if (data['history'] != null) {
      history = _historyFromFirebase(data['history']);
    }

    final histHash =
        data['history_password_hash'] ?? data['static']?['history_password_hash'];
    if (histHash != null) historyPasswordHash = histHash;

    final pricesRaw = data['prices'] ?? data['static']?['prices'];
    if (pricesRaw != null) {
      final raw = Map<String, dynamic>.from(pricesRaw);
      _migratePrices(raw);
    }

    final buyPricesRaw =
        data['menu_buy_prices'] ?? data['static']?['menu_buy_prices'];
    if (buyPricesRaw != null) {
      menuBuyPrices = Map<String, int>.from(buyPricesRaw);
    }

    final menuRaw = data['menu'] ?? data['static']?['menu'];
    if (menuRaw != null) {
      menu = Map<String, int>.from(menuRaw);
    }

    final catsRaw =
        data['buffet_categories'] ?? data['static']?['buffet_categories'];
    if (catsRaw != null && catsRaw is List) {
      buffetCategories = (catsRaw as List)
          .map((c) =>
              BuffetCategory.fromJson(Map<String, dynamic>.from(c)))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    } else if (buffetCategories.isEmpty) {
      buffetCategories = BuffetCategory.defaults;
    }

    final catMapRaw =
        data['menu_item_categories'] ?? data['static']?['menu_item_categories'];
    if (catMapRaw != null && catMapRaw is Map) {
      _menuItemCategories = Map<String, String>.from(catMapRaw);
    }

    final inventoryRaw =
        data['inventory'] ?? data['static']?['inventory'];
    if (inventoryRaw != null) {
      inventory = Map<String, int>.from(inventoryRaw);
    }

    final summaryRaw =
        data['daily_inventory_summary'] ?? data['daily_summary'];
    if (summaryRaw != null) {
      dailyInventorySummary = Map<String, int>.from(summaryRaw);
    }

    // 🔥 debts في static — بيتحمل مع باقي الـ static data
    final debtsRaw = data['debts'] ?? data['static']?['debts'];
    if (debtsRaw != null) {
      debts = List<Map<String, dynamic>>.from(
          (debtsRaw as List).map((d) => Map<String, dynamic>.from(d)));
    }

    final expensesRaw = data['expenses'] ?? data['static']?['expenses'];
    if (expensesRaw != null) {
      expenses = List<Map<String, dynamic>>.from(
          (expensesRaw as List).map((e) => Map<String, dynamic>.from(e)));
    }
    final expCatsRaw =
        data['expense_categories'] ?? data['static']?['expense_categories'];
    if (expCatsRaw != null) {
      expenseCategories = List<String>.from(expCatsRaw as List);
    }

    final rechargeEnabledRaw =
        data['recharge_enabled'] ?? data['static']?['recharge_enabled'];
    if (rechargeEnabledRaw != null) rechargeEnabled = rechargeEnabledRaw;
    final rechargeBalanceRaw =
        data['recharge_balance'] ?? data['static']?['recharge_balance'];
    if (rechargeBalanceRaw != null) {
      rechargeBalance = (rechargeBalanceRaw as num).toDouble();
    }
    final rechargeCardsRaw =
        data['recharge_cards'] ?? data['static']?['recharge_cards'];
    if (rechargeCardsRaw != null) {
      rechargeCards = List<Map<String, dynamic>>.from(
          (rechargeCardsRaw as List)
              .map((c) => Map<String, dynamic>.from(c)));
    }
    final rechargeTxRaw =
        data['recharge_transactions'] ?? data['static']?['recharge_transactions'];
    if (rechargeTxRaw != null) {
      rechargeTransactions = List<Map<String, dynamic>>.from(
          (rechargeTxRaw as List)
              .map((t) => Map<String, dynamic>.from(t)));
    }

    final tablesRaw = data['tables'] ?? data['operational']?['tables'];
    if (tablesRaw != null) {
      tables = List<Map<String, dynamic>>.from(
          (tablesRaw as List).map((t) => Map<String, dynamic>.from(t)));
    }

    final drinkRaw =
        data['drink_tables'] ?? data['operational']?['drink_tables'];
    if (drinkRaw != null) {
      drinkTables = List<Map<String, dynamic>>.from(
          (drinkRaw as List).map((t) => Map<String, dynamic>.from(t)));
    }

    final settingsRaw = data['static']?['settings'];
    final adminHash =
        data['admin_password_hash'] ?? settingsRaw?['admin_password_hash'];
    if (adminHash != null) adminPasswordHash = adminHash;

    final shopNameRaw = data['shop_name'] ?? settingsRaw?['shop_name'];
    if (shopNameRaw != null) shopName = shopNameRaw;

    final matchEnabledRaw =
        data['match_enabled'] ?? settingsRaw?['match_enabled'];
    if (matchEnabledRaw != null) matchEnabled = matchEnabledRaw;

    final cashiersRaw = data['cashiers'] ?? data['static']?['cashiers'];
    if (cashiersRaw != null) {
      cashiers = List<Map<String, dynamic>>.from(
          (cashiersRaw as List).map((c) => Map<String, dynamic>.from(c)));
    } else if (data['cashier_password_hash'] != null) {
      cashiers = [
        {'name': 'كاشير 1', 'hash': data['cashier_password_hash'] as String}
      ];
    }
    if (cashiers.isEmpty) {
      cashiers = [{'name': 'كاشير 1', 'hash': _defaultCashierHash}];
    }

    // 🔥 tournaments — بيتحمل من الـ cache المحلي فقط (on-demand من Firebase)
    final tournamentsRaw = data['tournaments'];
    if (tournamentsRaw != null && tournamentsRaw is List) {
      tournaments = List<Map<String, dynamic>>.from(
          (tournamentsRaw as List)
              .map((t) => Map<String, dynamic>.from(t)));
    }

    // 🔥 shiftsHistory — بيتحمل من الـ cache المحلي فقط (on-demand من Firebase)
    final shiftsHistoryRaw =
        data['shifts_history'] ?? data['records']?['shifts_history'];
    if (shiftsHistoryRaw != null && shiftsHistoryRaw is List) {
      shiftsHistory = List<ShiftRecord>.from(
        (shiftsHistoryRaw as List).map(
          (s) => ShiftRecord.fromJson(Map<String, dynamic>.from(s)),
        ),
      );
    }

    final openShiftsRaw =
        data['open_shifts'] ?? data['records']?['open_shifts'];
    if (openShiftsRaw != null) {
      final raw = Map<String, dynamic>.from(openShiftsRaw);
      openShifts = raw.map((k, v) => MapEntry(
          k, ShiftRecord.fromJson(Map<String, dynamic>.from(v))));
    }

    List? devStates;
    if (data['realtime']?['devices_state']?['devices'] != null) {
      devStates =
          data['realtime']['devices_state']['devices'] as List;
    } else if (data['devices_state'] != null) {
      devStates = data['devices_state'] as List;
    } else if (data['devices'] != null) {
      devStates = data['devices'] as List;
    }

    if (devStates != null) {
      devices = [];
      for (int i = 0; i < devStates.length; i++) {
        devices.add(PSDevice.fromJson(
            Map<String, dynamic>.from(devStates[i]), i + 1));
      }
      numDevices = devices.length;
      for (var d in devices) {
        d.updateTimer();
      }
    }

    numDevices = data['num_devices'] ?? devices.length;
  }

  void _migratePrices(Map<String, dynamic> raw) {
    if (raw.containsKey('match_price') &&
        !raw.containsKey('match_ps4_normal')) {
      final old = (raw['match_price'] as num).toInt();
      raw['match_ps4_normal'] = old;
      raw['match_ps4_multi'] = (old * 1.5).round();
      raw['match_ps5_normal'] = (old * 1.5).round();
      raw['match_ps5_multi'] = (old * 2).round();
      raw.remove('match_price');
    }
    if (raw.containsKey('normal') && !raw.containsKey('ps4_normal')) {
      prices = {
        'ps4_normal': raw['normal'] ?? 25,
        'ps4_multi': raw['multi'] ?? 35,
        'ps5_normal': 40,
        'ps5_multi': 50,
        'match_ps4_normal': raw['match_ps4_normal'] ?? 10,
        'match_ps4_multi': raw['match_ps4_multi'] ?? 15,
        'match_ps5_normal': raw['match_ps5_normal'] ?? 15,
        'match_ps5_multi': raw['match_ps5_multi'] ?? 20,
      };
    } else {
      prices = raw.map((k, v) => MapEntry(k, (v as num).toInt()));
      prices.putIfAbsent('match_ps4_normal', () => 10);
      prices.putIfAbsent('match_ps4_multi', () => 15);
      prices.putIfAbsent('match_ps5_normal', () => 15);
      prices.putIfAbsent('match_ps5_multi', () => 20);
      prices.putIfAbsent('ping_normal', () => 20);
      prices.putIfAbsent('billiard_normal', () => 25);
      prices.putIfAbsent('billiard_american', () => 30);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD DATA
  // ══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _buildDataDict() {
    return {
      'history': history,
      'history_password_enabled': historyPasswordEnabled,
      'prices': prices,
      'inventory': inventory,
      'inventory_updated_at': _inventoryUpdatedAt, // 🔥 timestamp للمخزون
      'daily_inventory_summary': dailyInventorySummary,
      'menu': menu,
      'buffet_categories': buffetCategories.map((c) => c.toJson()).toList(),
      'menu_item_categories': _menuItemCategories,
      'tables': tables,
      'drink_tables': drinkTables,
      'debts': debts,
      'recharge_enabled': rechargeEnabled,
      'recharge_balance': rechargeBalance,
      'recharge_cards': rechargeCards,
      'recharge_transactions': rechargeTransactions,
      'num_devices': numDevices,
      'admin_password_hash': adminPasswordHash,
      'cashiers': cashiers,
      'cashier_password_hash': cashierPasswordHash,
      'shop_name': shopName,
      'menu_buy_prices': menuBuyPrices,
      'match_enabled': matchEnabled,
      'tournaments': tournaments,
      'shifts_history': shiftsHistory.map((s) => s.toJson()).toList(),
      'open_shifts': openShifts.map((k, v) => MapEntry(k, v.toJson())),
      // 🔥 devices_state في الـ local cache بدون session_log — توفير مساحة
      'devices_state': devices.map((d) {
        final json = d.toJson();
        json.remove('session_log');
        return json;
      }).toList(),
      'last_updated': DateTime.now().millisecondsSinceEpoch,
      'expenses': expenses,
      'expense_categories': expenseCategories,
    };
  }

  Map<String, dynamic> _buildStaticData() {
    return {
      'history_password_enabled': historyPasswordEnabled,
      'prices': prices,
      'menu': menu,
      'expenses': expenses,
      'expense_categories': expenseCategories,
      'buffet_categories': buffetCategories.map((c) => c.toJson()).toList(),
      'menu_item_categories': _menuItemCategories,
      'inventory': inventory,
      'inventory_updated_at': _inventoryUpdatedAt, // 🔥 timestamp للمخزون
      'daily_inventory_summary': dailyInventorySummary,
      'cashiers': cashiers,
      'cashier_password_hash': cashierPasswordHash,
      'admin_password_hash': adminPasswordHash,
      'menu_buy_prices': menuBuyPrices,
      'shop_name': shopName,
      'match_enabled': matchEnabled,
      'settings': {
        'num_devices': numDevices,
      },
      'debts': debts, // 🔥 debts في static — بيتحمل مع الـ static مرة واحدة
      'recharge_enabled': rechargeEnabled,
      'recharge_balance': rechargeBalance,
      'recharge_cards': rechargeCards,
      'recharge_transactions': rechargeTransactions,
      'history_password_hash': historyPasswordHash.isEmpty
          ? _defaultHistoryHash
          : historyPasswordHash,
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SAVE DATA
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> saveData() async {
    if (shopId == null) return;
    await SyncService.saveLocal(shopId!, _buildDataDict());
    await FirebaseService.pushStaticData(shopId!, _buildStaticData(), _myDeviceId);
  }

  Future<void> _saveDevices({int? deviceId}) async {
    if (shopId == null) return;
    final data = _buildDataDict();
    await SyncService.saveLocal(shopId!, data);

    if (deviceId != null) {
      final idx = devices.indexWhere((d) => d.id == deviceId);
      if (idx != -1) {
        // 🔥 pushSingleDevice في SyncService بيستخدم pushSingleDeviceState (بدون session_log)
        await _sync?.pushSingleDevice(idx, devices[idx].toJson());
      }
    } else {
      await _sync?.pushDevices();
    }
    _pushSummary(); // 🔥 حدّث active_devices في summary عند كل تغيير في الأجهزة
  }

  Future<void> _saveSingleHistoryRecord(
      Map<String, dynamic> newRecord) async {
    if (shopId == null) return;
    await SyncService.saveLocal(shopId!, _buildDataDict());
    await _sync?.pushSingleHistory(newRecord);
    _pushSummary(); // 🔥 حدّث summary node بعد كل سجل جديد
  }

  Future<void> _saveTables({
    int? tableIndex,
    bool tablesChanged = true,
    bool drinkTablesChanged = false,
  }) async {
    if (shopId == null) return;
    await SyncService.saveLocal(shopId!, _buildDataDict());
    final futures = <Future>[];
    if (tablesChanged) {
      futures.add(
          FirebaseService.pushTablesState(shopId!, tables, _myDeviceId));
    }
    if (drinkTablesChanged) {
      futures.add(FirebaseService.pushDrinkTablesState(
          shopId!, drinkTables, _myDeviceId));
    }
    if (futures.isNotEmpty) await Future.wait(futures);
    // ✅ FIX: schedulePushTables بس لو tables العادية تغيرت
    // لو drinkTables تغيرت — احنا بعتنا فوراً فوق، مش محتاجين debounce تاني
    // الـ debounce كان بيبعت نسخة قديمة من drinkTables وبيـoverwrite التغييرات
    if (tablesChanged && !drinkTablesChanged) {
      _sync?.schedulePushTables();
    }
    _pushSummary(); // 🔥 حدّث summary عند أي تغيير في التربيزات
  }

  // 🔥 RACE CONDITION FIX: بيبعت تربيزة مشروبات واحدة بـ PATCH بدل كل الـ state
  // يُستخدم في addDrinkTableOrder و setDrinkTableOrders بدل _saveTables
  Future<void> _saveSingleDrinkTable(int index) async {
    if (shopId == null) return;
    await SyncService.saveLocal(shopId!, _buildDataDict());
    await FirebaseService.pushSingleDrinkTable(
        shopId!, index, drinkTables[index], _myDeviceId);
    _pushSummary();
  }

  Future<void> _saveHistory() async {
    if (shopId == null) return;
    await SyncService.saveLocal(shopId!, _buildDataDict());
    if (history.isNotEmpty) {
      await _sync?.pushSingleHistory(history.last);
    }
  }

  Future<void> _pushStaticOnly() async {
    if (shopId == null) return;
    await FirebaseService.pushStaticData(shopId!, _buildStaticData(), _myDeviceId);
    await SyncService.saveLocal(shopId!, _buildDataDict());
  }

  // 🔥 SUMMARY NODE: يكتب ملخص الإيرادات في realtime/summary
  // الـ Worker يقرأ منها بدل جلب records/history كاملة (توفير 95% bandwidth)
  Future<void> _pushSummary() async {
    if (shopId == null) return;
    try {
      final totalTime   = history.fold(0.0, (s, h) => s + ((h['time_cost']   as num?)?.toDouble() ?? 0));
      final totalBuffet = history.fold(0.0, (s, h) => s + ((h['buffet_cost'] as num?)?.toDouble() ?? 0));
      final rechargeRev = history
          .where((h) => h['device_type'] == 'recharge')
          .fold(0.0, (s, h) => s + ((h['total'] as num?)?.toDouble() ?? 0));
      final activeCount = devices.where((d) => d.isActive).length;

      // أعلى كاشير
      final cashierMap = <String, double>{};
      for (final r in history) {
        final c = r['cashier']?.toString();
        if (c != null) cashierMap[c] = (cashierMap[c] ?? 0) + ((r['total'] as num?)?.toDouble() ?? 0);
      }
      String topCashier = '—';
      if (cashierMap.isNotEmpty) {
        final top = cashierMap.entries.reduce((a, b) => a.value >= b.value ? a : b);
        topCashier = '${top.key} (${top.value.toStringAsFixed(1)} ج)';
      }

      await FirebaseService.set(
        'shops/$shopId/realtime/summary',
        {
          'total_revenue':   totalTime + totalBuffet,
          'game_revenue':    totalTime,
          'buffet_revenue':  totalBuffet,
          'recharge_revenue': rechargeRev,
          'sessions_count':  history.length,
          'active_devices':  activeCount,
          'top_cashier':     topCashier,
          'last_updated':    DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {}
  }

  Future<void> _saveTournaments() async {
    if (shopId == null) return;
    await FirebaseService.set(
      FirebaseService.shopTournamentsPath(shopId!),
      tournaments,
    );
    await SyncService.saveLocal(shopId!, _buildDataDict());
  }

  Future<void> _pushShiftsToFirebase() async {
    if (shopId == null) return;
    final shiftsJson = shiftsHistory.map((s) => s.toJson()).toList();
    await FirebaseService.set(
      FirebaseService.shiftsHistoryPath(shopId!),
      shiftsJson,
    );
    await SyncService.saveLocal(shopId!, _buildDataDict());
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SESSION LOG — محلي بس، لا يتحمل على Firebase إلا عند stopDevice
  // ══════════════════════════════════════════════════════════════════════════

  // 🔥 BANDWIDTH FIX #2: _logEvent — يضيف للـ local session_log فقط
  // لا يتحمل على Firebase — session_log بيتحمل مرة واحدة فقط في stopDevice
  void _logEvent(PSDevice d, String type, {String? note, int? minutes}) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final role = isAdmin ? 'أدمن' : (currentCashierName ?? 'كاشير');
    d.sessionLog.add({
      'type': type,
      'time': timeStr,
      'timestamp': now.millisecondsSinceEpoch,
      'role': role,
      if (note != null) 'note': note,
      if (minutes != null) 'minutes': minutes,
    });
    // 🔥 لا pushDevicesState هنا — session_log محلي بس
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DEVICE ACTIONS
  // ══════════════════════════════════════════════════════════════════════════

  void startDevice(PSDevice d, String mode, {int? countdownSeconds}) {
    d.mode = mode;
    d.status = 'شغال';
    d.startTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    d.addedSeconds = 0;
    d.isPaused = false;
    d.sessionLog = [];

    final modeLabel = mode == 'multi' ? 'مالتي' : 'عادي';

    if (countdownSeconds != null && countdownSeconds > 0) {
      d.isCountdown = true;
      d.countdownTotalSeconds = countdownSeconds;
      d.countdownAlertSent = false;
      _countdownAlertedDevices.remove(d.id);
      _logEvent(d, 'start',
          note: 'بدأ اللعب (عد تنازلي: ${countdownSeconds ~/ 60} دقيقة)');
      AuditLogService.logDevice(
        action: AuditAction.deviceStart,
        deviceName: d.displayName,
        deviceType: d.deviceType,
        extra: '$modeLabel — ${countdownSeconds ~/ 60} دقيقة محددة',
      );
    } else {
      d.isCountdown = false;
      d.countdownTotalSeconds = null;
      d.countdownAlertSent = false;
      _countdownAlertedDevices.remove(d.id);
      _logEvent(d, 'start', note: 'بدأ اللعب');
      AuditLogService.logDevice(
        action: AuditAction.deviceStart,
        deviceName: d.displayName,
        deviceType: d.deviceType,
        extra: '$modeLabel — مفتوح',
      );
    }

    _alertedDevices.remove(d.id);
    _saveDevices(deviceId: d.id);
    if (shopId != null) {
      _notifyTelegram(shopId!, 'session_start', {
        'deviceName': d.displayName,
        'cashier': currentCashierName ?? 'أدمن',
        'mode': modeLabel,
        'countdown': countdownSeconds != null ? (countdownSeconds ~/ 60) : null,
        'startTime': DateTime.now().toIso8601String(),
      });
    }
    d.updateTimer();
    notifyListeners();
  }

  void togglePause(PSDevice d) {
    if (d.isPaused) {
      final pausedDuration =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) -
              d.pauseStartTime!;
      d.startTime = d.startTime! + pausedDuration;
      d.isPaused = false;
      d.pauseStartTime = null;

      if (d.isCountdown && d.countdownFinished) {
        d.isCountdown = false;
        d.countdownTotalSeconds = null;
        d.countdownAlertSent = false;
        _countdownAlertedDevices.remove(d.id);
      }

      _logEvent(d, 'resume', note: 'استأنف اللعب');
      AuditLogService.logDevice(
          action: AuditAction.deviceResume,
          deviceName: d.displayName,
          deviceType: d.deviceType);
    } else {
      d.isPaused = true;
      d.pauseStartTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      _logEvent(d, 'pause', note: 'إيقاف مؤقت');
      AuditLogService.logDevice(
          action: AuditAction.devicePause,
          deviceName: d.displayName,
          deviceType: d.deviceType);
    }
    _saveDevices(deviceId: d.id);
    notifyListeners();
  }

  void addMatchRecord(PSDevice d) {
    final matchPrice = matchPriceFor(d);
    final record = {
      'id': d.id,
      'name': d.displayName,
      'device_type': d.deviceType,
      'duration': '1 ماتش',
      'elapsed_seconds': 0,
      'play_mode': d.mode,
      'time_cost': matchPrice.toDouble(),
      'buffet_cost': 0.0,
      'total': matchPrice.toDouble(),
      'orders': <String, int>{},
      'date': DateTime.now().toString(),
      'is_match': true,
      'cashier': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
    };
    history.add(record);
    if (shopId != null) {
      _notifyTelegram(shopId!, 'match', {
        'deviceName': d.displayName,
        'price': matchPrice,
        'cashier': currentCashierName ?? 'أدمن',
      });
    }
    AuditLogService.logDevice(
      action: AuditAction.matchRecorded,
      deviceName: d.displayName,
      deviceType: d.deviceType,
      extra: '$matchPrice ج',
    );
    _saveSingleHistoryRecord(record);
    notifyListeners();
  }

  void addTableGameRecord(int tableIndex) {
    final t = tables[tableIndex];
    final gamePrice = (t['game_price'] as num?)?.toInt() ?? 0;
    if (gamePrice <= 0) return;
    final record = {
      'id': tableIndex,
      'name': t['name'],
      'device_type': 'table',
      'duration': '1 جيم',
      'elapsed_seconds': 0,
      'play_mode': 'game',
      'time_cost': gamePrice.toDouble(),
      'buffet_cost': 0.0,
      'total': gamePrice.toDouble(),
      'orders': <String, int>{},
      'date': DateTime.now().toString(),
      'is_game': true,
      'cashier': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
    };
    history.add(record);
    AuditLogService.logTable(
      action: AuditAction.tableGameRecord,
      tableName: t['name'] ?? '',
      extra: '$gamePrice ج',
    );
    _saveSingleHistoryRecord(record);
    notifyListeners();
  }

  void setMatchEnabled(bool val) {
    matchEnabled = val;
    AuditLogService.log(
      action: AuditAction.matchToggled,
      actionDetails: val ? 'فعّل زرار الماتش' : 'عطّل زرار الماتش',
    );
    _pushStaticOnly();
    notifyListeners();
  }

  void addTime(PSDevice d, int minutes) {
    if (d.isCountdown && d.countdownTotalSeconds != null) {
      d.countdownTotalSeconds = d.countdownTotalSeconds! + minutes * 60;
      if (d.countdownTotalSeconds! < 0) d.countdownTotalSeconds = 0;
      if (minutes > 0 && d.countdownAlertSent) {
        d.countdownAlertSent = false;
        _countdownAlertedDevices.remove(d.id);
        if (d.isPaused) {
          final pausedDuration =
              (DateTime.now().millisecondsSinceEpoch ~/ 1000) -
                  d.pauseStartTime!;
          d.startTime = d.startTime! + pausedDuration;
          d.isPaused = false;
          d.pauseStartTime = null;
        }
      }
    } else {
      if (d.startTime != null) {
        d.startTime = d.startTime! - minutes * 60;
      }
    }

    final role = isAdmin ? 'أدمن' : (currentCashierName ?? 'كاشير');
    final action = minutes > 0
        ? 'أضاف $minutes دقيقة ($role)'
        : 'خصم ${minutes.abs()} دقيقة ($role)';
    _logEvent(d, 'add_time', note: action, minutes: minutes);
    AuditLogService.logDevice(
      action: AuditAction.deviceAddTime,
      deviceName: d.displayName,
      deviceType: d.deviceType,
      extra: minutes > 0 ? '+$minutes دقيقة' : '${minutes} دقيقة',
    );
    _saveDevices(deviceId: d.id);
    notifyListeners();
  }

  void setDeviceTimer(PSDevice d, int? minutes) {
    d.timerAlertMinutes = minutes;
    if (minutes == null) _alertedDevices.remove(d.id);
    _saveDevices(deviceId: d.id);
    notifyListeners();
  }

  void cancelDevice(PSDevice d) {
    AuditLogService.logDevice(
        action: AuditAction.deviceCancel,
        deviceName: d.displayName,
        deviceType: d.deviceType);
    d.status = 'متاح';
    d.startTime = null;
    d.addedSeconds = 0;
    d.isPaused = false;
    d.pauseStartTime = null;
    d.orders = {};
    d.timerText = '00:00:00';
    d.timerAlertMinutes = null;
    d.isCountdown = false;
    d.countdownTotalSeconds = null;
    d.countdownAlertSent = false;
    d.sessionLog = [];
    _alertedDevices.remove(d.id);
    _countdownAlertedDevices.remove(d.id);
    _saveDevices(deviceId: d.id);
    notifyListeners();
  }

  // 🔥 BANDWIDTH FIX #2: stopDevice — session_log يتحفظ في السجل التاريخي هنا فقط
  // هي المرة الوحيدة اللي بيتحمل فيها session_log على Firebase (كجزء من record)
  Map<String, dynamic> stopDevice(PSDevice d) {
    if (_stoppingDevices.contains(d.id)) return {};
    if (!d.isActive && d.orders.isEmpty) return {};

    if (!d.isActive && d.orders.isNotEmpty) {
      final buffetPrice = d.getBuffetPrice(menu);
      final timePrice = 0.0;
      final record = {
        'id': d.id,
        'name': d.displayName,
        'device_type': d.deviceType,
        'duration': '0س 0د',
        'elapsed_seconds': 0,
        'play_mode': d.mode,
        'time_cost': 0.0,
        'buffet_cost': buffetPrice,
        'total': buffetPrice,
        'orders': Map<String, int>.from(d.orders),
        'date': DateTime.now().toString(),
        'session_log': [], // بوفيه بدون جلسة — مفيش log
        'cashier': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
      };
      d.orders.forEach((item, qty) => _deductFromInventory(item, qty));
      history.add(record);
      if (shopId != null) {
        _notifyTelegram(shopId!, 'session_end', {
          'deviceName': d.displayName,
          'mode': d.mode == 'multi' ? 'مالتي' : 'عادي',
          'cashier': currentCashierName ?? 'أدمن',
          'startTime': '-',
          'endTime': DateTime.now().toString().substring(0, 16),
          'timeCost': timePrice,
          'buffetCost': buffetPrice,
          'total': buffetPrice,
          'orders': d.orders.isNotEmpty
              ? d.orders.entries.map((e) => '${e.key} ×${e.value}').join(', ')
              : null,
        });
      }
      d.orders = {};
      _saveDevices(deviceId: d.id);
      _saveSingleHistoryRecord(record);
      notifyListeners();
      return record;
    }

    _stoppingDevices.add(d.id);
    late Map<String, dynamic> record;
    try {
    _logEvent(d, 'stop', note: 'انتهت الجلسة');
    final timePrice = d.isActive ? d.calculateTimePrice(prices) : 0.0;
    final buffetPrice = d.getBuffetPrice(menu);

    AuditLogService.logDevice(
      action: AuditAction.deviceStop,
      deviceName: d.displayName,
      deviceType: d.deviceType,
      extra:
          'لعب: ${timePrice.toStringAsFixed(1)} ج | بوفيه: ${buffetPrice.toStringAsFixed(1)} ج | إجمالي: ${(timePrice + buffetPrice).toStringAsFixed(1)} ج',
    );

    final elapsed = d.elapsedSeconds;
    final h = elapsed ~/ 3600;
    final m = (elapsed % 3600) ~/ 60;

    record = {
      'id': d.id,
      'name': d.displayName,
      'device_type': d.deviceType,
      'duration': '${h}س ${m}د',
      'elapsed_seconds': elapsed,
      'play_mode': d.mode,
      'time_cost': timePrice,
      'buffet_cost': buffetPrice,
      'total': timePrice + buffetPrice,
      'orders': Map<String, int>.from(d.orders),
      'date': DateTime.now().toString(),
      // 🔥 session_log يتحفظ هنا فقط (مرة واحدة) في السجل التاريخي
      // مش بيتحمل على الـ realtime node أبداً
      'session_log': List<Map<String, dynamic>>.from(d.sessionLog),
      'cashier': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
      if (d.isCountdown) 'was_countdown': true,
      if (d.countdownTotalSeconds != null)
        'countdown_total_seconds': d.countdownTotalSeconds,
    };

    d.orders.forEach((item, qty) {
      _deductFromInventory(item, qty);
    });
    history.add(record);

    if (shopId != null) {
      _notifyTelegram(shopId!, 'session_end', {
        'deviceName': d.displayName,
        'mode': d.mode == 'multi' ? 'مالتي' : 'عادي',
        'cashier': currentCashierName ?? 'أدمن',
        'startTime': DateTime.fromMillisecondsSinceEpoch(
                (d.startTime ?? 0) * 1000)
            .toString()
            .substring(0, 16),
        'endTime': DateTime.now().toString().substring(0, 16),
        'timeCost': timePrice,
        'buffetCost': buffetPrice,
        'total': timePrice + buffetPrice,
      });
    }

    d.status = 'متاح';
    d.startTime = null;
    d.addedSeconds = 0;
    d.isPaused = false;
    d.pauseStartTime = null;
    d.orders = {};
    d.timerText = '00:00:00';
    d.timerAlertMinutes = null;
    d.isCountdown = false;
    d.countdownTotalSeconds = null;
    d.countdownAlertSent = false;
    d.sessionLog = []; // 🔥 امسح الـ local log بعد الحفظ
    _alertedDevices.remove(d.id);
    _countdownAlertedDevices.remove(d.id);
    } finally {
      _stoppingDevices.remove(d.id);
    }
    _saveDevices(deviceId: d.id);
    _saveSingleHistoryRecord(record);
    notifyListeners();
    return record;
  }

  String? addOrder(PSDevice d, String item, int qty) {
    if (qty > 0) {
      // ✅ FIX: أي صنف كميته صفر أو مش محدودة في inventory ممنوع تماماً
      final available = inventory[item] ?? 0;
      if (available <= 0) {
        return 'نفد "$item" من المخزن!';
      }
      final currentInOrder = d.orders[item] ?? 0;
      final totalNeeded = currentInOrder + qty;
      if (totalNeeded > available) {
        return 'الكمية المتاحة من "$item" هي $available فقط!';
      }
    }
    d.orders[item] = (d.orders[item] ?? 0) + qty;
    if (d.orders[item]! <= 0) d.orders.remove(item);

    AuditLogService.logDevice(
      action:
          qty > 0 ? AuditAction.buffetItemAdded : AuditAction.buffetItemRemoved,
      deviceName: d.displayName,
      extra: '$item ×${qty.abs()}',
    );

    _saveDevices(deviceId: d.id);
    notifyListeners();
    return null;
  }

  void transferSession(PSDevice from, PSDevice to) {
    if (!from.isActive || to.isActive) return;
    to.mode = from.mode;
    to.startTime = from.startTime;
    to.addedSeconds = from.addedSeconds;
    to.isPaused = from.isPaused;
    to.pauseStartTime = from.pauseStartTime;
    to.orders = Map<String, int>.from(from.orders);
    to.status = 'شغال';
    to.timerAlertMinutes = from.timerAlertMinutes;
    to.sessionLog = List<Map<String, dynamic>>.from(from.sessionLog);
    to.isCountdown = from.isCountdown;
    to.countdownTotalSeconds = from.countdownTotalSeconds;
    to.countdownAlertSent = from.countdownAlertSent;
    _logEvent(to, 'transfer',
        note: 'تم نقل الجلسة من ${from.displayName}');

    AuditLogService.logDevice(
      action: AuditAction.deviceTransfer,
      deviceName: from.displayName,
      extra: to.displayName,
    );

    from.status = 'متاح';
    from.startTime = null;
    from.addedSeconds = 0;
    from.isPaused = false;
    from.pauseStartTime = null;
    from.orders = {};
    from.timerText = '00:00:00';
    from.timerAlertMinutes = null;
    from.isCountdown = false;
    from.countdownTotalSeconds = null;
    from.countdownAlertSent = false;
    from.sessionLog = [];
    _alertedDevices.remove(from.id);
    _countdownAlertedDevices.remove(from.id);

    _saveDevices(deviceId: from.id);
    _saveDevices(deviceId: to.id);
    notifyListeners();
  }

  // 🔥 BANDWIDTH FIX: archiveAndClear — بيجيب الـ history الكاملة مرة واحدة
  // للأرشفة باستخدام getFullHistory() — ده الاستثناء الوحيد لـ pull كامل
  Future<bool> archiveAndClear() async {
    if (shopId == null) return false;
    _sync?.pause();
    archiving = true;

    try {
      // 🔥 جيب الـ history الكاملة من Firebase للأرشفة (الاستثناء الوحيد)
      List<Map<String, dynamic>> recordsToArchive = history;
      if (history.isEmpty) {
        // لو الـ history الـ local فاضية، جيبها من Firebase
        recordsToArchive = await FirebaseService.getFullHistory(shopId!);
      }

      if (recordsToArchive.isEmpty) return false;

      final totalTime = recordsToArchive.fold(
          0.0, (s, h) => s + ((h['time_cost'] as num?)?.toDouble() ?? 0));
      final totalBuffet = recordsToArchive.fold(
          0.0, (s, h) => s + ((h['buffet_cost'] as num?)?.toDouble() ?? 0));
      final date = DateTime.now().toString();

      String? archiveId;
      for (int i = 0; i < 3 && archiveId == null; i++) {
        archiveId = await FirebaseService.pushArchive(
          shopId: shopId!,
          date: date,
          totalTime: totalTime,
          totalBuffet: totalBuffet,
          totalOverall: totalTime + totalBuffet,
        );
        if (archiveId == null) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      if (archiveId == null) return false;

      AuditLogService.log(
        action: AuditAction.dayArchived,
        actionDetails:
            'أرشف اليوم | ${recordsToArchive.length} جلسة | إجمالي: ${(totalTime + totalBuffet).toStringAsFixed(1)} ج',
        extra: {
          'sessions_count': recordsToArchive.length,
          'total': totalTime + totalBuffet
        },
      );

      history.clear();
      _historyLoaded = false; // reset — لازم يتحمل on-demand بعد الأرشفة
      await FirebaseService.set(FirebaseService.historyPath(shopId!), []);
      await _saveHistory();
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    } finally {
      archiving = false;
      _sync?.resume();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DEVICE MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  void addDevice(String name, String type) {
    final id = devices.length + 1;
    final d = PSDevice(id: id, deviceType: type);
    d.displayName = name;
    devices.add(d);
    numDevices = devices.length;
    AuditLogService.log(
        action: AuditAction.deviceAdded,
        actionDetails: 'أضاف جهاز "$name" (${type.toUpperCase()})');
    _saveDevices();
    notifyListeners();
  }

  void removeDevice(int index) {
    final name = devices[index].displayName;
    AuditLogService.log(
        action: AuditAction.deviceRemoved,
        actionDetails: 'حذف الجهاز "$name"');
    devices.removeAt(index);
    for (int i = 0; i < devices.length; i++) {
      devices[i].id = i + 1;
    }
    numDevices = devices.length;
    _saveDevices();
    notifyListeners();
  }

  void updateNumDevices(int count) {
    numDevices = count;
    if (count > devices.length) {
      for (int i = devices.length + 1; i <= count; i++) {
        devices.add(PSDevice(id: i));
      }
    } else {
      devices = devices.sublist(0, count);
    }
    _saveDevices();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TABLE ACTIONS
  // ══════════════════════════════════════════════════════════════════════════

  void addTable(String name, int ratePerHour,
      {String tableType = 'ping', int gamePrice = 0}) {
    tables.add({
      'name': name,
      'rate': ratePerHour,
      'table_type': tableType,
      'game_price': gamePrice,
      'start_time': null,
      'is_paused': false,
      'pause_start_time': null,
      'orders': <String, int>{},
    });
    _saveTables();
    notifyListeners();
  }

  void removeTable(int index) {
    tables.removeAt(index);
    _saveTables();
    notifyListeners();
  }

  void updateTableSettings(int index, String name, int rate,
      {String? tableType, int? gamePrice}) {
    tables[index]['name'] = name;
    tables[index]['rate'] = rate;
    if (tableType != null) tables[index]['table_type'] = tableType;
    if (gamePrice != null) tables[index]['game_price'] = gamePrice;
    _saveTables();
    notifyListeners();
  }

  void startTable(int index, {
    String playMode = 'normal',
    int? countdownSeconds,
    int? customRate,
    String? whatsappNumber,
  }) {
    tables[index]['start_time'] =
        DateTime.now().millisecondsSinceEpoch ~/ 1000;
    tables[index]['is_paused'] = false;
    tables[index]['pause_start_time'] = null;
    tables[index]['play_mode'] = playMode;
    tables[index]['whatsapp_number'] = whatsappNumber;

    if (customRate != null) {
      tables[index]['session_rate'] = customRate;
    } else {
      tables[index].remove('session_rate');
    }

    if (countdownSeconds != null && countdownSeconds > 0) {
      tables[index]['is_countdown'] = true;
      tables[index]['countdown_total_seconds'] = countdownSeconds;
      tables[index]['countdown_alert_sent'] = false;
    } else {
      tables[index]['is_countdown'] = false;
      tables[index]['countdown_total_seconds'] = null;
      tables[index]['countdown_alert_sent'] = false;
    }

    final modeLabel = playMode == 'american'
        ? 'أمريكاني'
        : playMode == 'multi'
            ? 'مالتي'
            : 'عادي';
    final extra = countdownSeconds != null
        ? '$modeLabel — ${countdownSeconds ~/ 60} دقيقة محددة'
        : '$modeLabel — مفتوح';

    AuditLogService.logTable(
      action: AuditAction.tableStart,
      tableName: tables[index]['name'] ?? '',
      extra: extra,
    );
    if (shopId != null) {
      _notifyTelegram(shopId!, 'session_start', {
        'deviceName': tables[index]['name'] ?? 'تربيزة',
        'cashier': currentCashierName ?? 'أدمن',
        'mode': modeLabel,
        'countdown':
            countdownSeconds != null ? (countdownSeconds ~/ 60) : null,
        'startTime': DateTime.now().toIso8601String(),
      });
    }
    _saveTables(tableIndex: index);
    notifyListeners();
  }

  void toggleTablePause(int index) {
    final t = tables[index];
    if (t['is_paused'] == true) {
      final paused = (DateTime.now().millisecondsSinceEpoch ~/ 1000) -
          (t['pause_start_time'] ?? 0);
      t['start_time'] = (t['start_time'] ?? 0) + paused;
      t['is_paused'] = false;
      t['pause_start_time'] = null;
      AuditLogService.logTable(
          action: AuditAction.tableResume, tableName: t['name'] ?? '');
    } else {
      t['is_paused'] = true;
      t['pause_start_time'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      AuditLogService.logTable(
          action: AuditAction.tablePause, tableName: t['name'] ?? '');
    }
    _saveTables();
    notifyListeners();
  }

  void cancelTable(int index) {
    AuditLogService.logTable(
        action: AuditAction.tableCancel,
        tableName: tables[index]['name'] ?? '');
    tables[index]['start_time'] = null;
    tables[index]['is_paused'] = false;
    tables[index]['pause_start_time'] = null;
    tables[index]['orders'] = <String, int>{};
    _saveTables();
    notifyListeners();
  }

  Map<String, dynamic> stopTable(int index) {
    if (_stoppingTables.contains(index)) return {};
    final t = tables[index];
    final startTime = t['start_time'] as int?;
    if (startTime == null) return {};
    _stoppingTables.add(index);

    int elapsed;
    if (t['is_paused'] == true && t['pause_start_time'] != null) {
      elapsed = (t['pause_start_time'] as int) - startTime;
    } else {
      elapsed =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) - startTime;
    }

    final rate =
        ((t['session_rate'] ?? t['rate']) as num).toDouble();
    final timeCost = (elapsed / 3600) * rate;
    final Map<String, int> orders =
        Map<String, int>.from(t['orders'] ?? {});
    double buffetCost = 0;
    orders.forEach((item, qty) => buffetCost += qty * (menu[item] ?? 0));

    AuditLogService.logTable(
      action: AuditAction.tableStop,
      tableName: t['name'] ?? '',
      extra: 'إجمالي: ${(timeCost + buffetCost).toStringAsFixed(1)} ج',
    );

    final h = elapsed ~/ 3600;
    final m = (elapsed % 3600) ~/ 60;

    final record = {
      'id': index,
      'name': t['name'],
      'device_type': 'table',
      'duration': '${h}س ${m}د',
      'elapsed_seconds': elapsed,
      'play_mode': t['play_mode'] ?? 'normal',
      'time_cost': timeCost,
      'buffet_cost': buffetCost,
      'total': timeCost + buffetCost,
      'orders': orders,
      'rate': rate,
      'date': DateTime.now().toString(),
      'cashier': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
      'whatsapp_number': t['whatsapp_number'],
    };

    orders.forEach((item, qty) {
      _deductFromInventory(item, qty);
    });
    history.add(record);
    if (shopId != null) {
      _notifyTelegram(shopId!, 'session_end', {
        'deviceName': t['name'] ?? '',
        'timeCost': timeCost,
        'buffetCost': buffetCost,
        'total': timeCost + buffetCost,
        'cashier': currentCashierName ?? 'أدمن',
      });
    }

    tables[index]['start_time'] = null;
    tables[index]['is_paused'] = false;
    tables[index]['pause_start_time'] = null;
    tables[index]['orders'] = <String, int>{};
    tables[index]['whatsapp_number'] = null;
    _stoppingTables.remove(index);

    _saveTables(tableIndex: index);
    _saveSingleHistoryRecord(record);
    notifyListeners();
    return record;
  }

  String? addTableOrder(int index, String item, int qty) {
    if (qty > 0) {
      // ✅ FIX: أي صنف كميته صفر أو مش محدودة في inventory ممنوع تماماً
      final available = inventory[item] ?? 0;
      if (available <= 0) {
        return 'نفد "$item" من المخزن!';
      }
      final orders = Map<String, int>.from(tables[index]['orders'] ?? {});
      final currentInOrder = orders[item] ?? 0;
      final totalNeeded = currentInOrder + qty;
      if (totalNeeded > available) {
        return 'الكمية المتاحة هي $available فقط!';
      }
    }
    final orders = Map<String, int>.from(tables[index]['orders'] ?? {});
    orders[item] = (orders[item] ?? 0) + qty;
    if (orders[item]! <= 0) orders.remove(item);
    tables[index]['orders'] = orders;

    final tableName = tables[index]['name']?.toString() ?? 'تربيزة';
    AuditLogService.logTable(
      action: qty > 0
          ? AuditAction.tableOrderAdded
          : AuditAction.tableOrderRemoved,
      tableName: tableName,
      extra: '$item ×${qty.abs()}',
    );

    _saveTables(tableIndex: index);
    notifyListeners();
    return null;
  }

  int tableElapsed(int index) {
    final t = tables[index];
    final startTime = t['start_time'] as int?;
    if (startTime == null) return 0;
    if (t['is_paused'] == true && t['pause_start_time'] != null) {
      return (t['pause_start_time'] as int) - startTime;
    }
    return (DateTime.now().millisecondsSinceEpoch ~/ 1000) - startTime;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DRINK TABLES
  // ══════════════════════════════════════════════════════════════════════════

  void addDrinkTable(String name) {
    drinkTables.add({'name': name, 'orders': <String, int>{}});
    _saveTables(drinkTablesChanged: true);
    notifyListeners();
  }

  void removeDrinkTable(int index) {
    drinkTables.removeAt(index);
    _saveTables(drinkTablesChanged: true);
    notifyListeners();
  }

  void updateDrinkTableName(int index, String name) {
    drinkTables[index]['name'] = name;
    _saveTables(drinkTablesChanged: true);
    notifyListeners();
  }

  String? addDrinkTableOrder(int index, String item, int qty) {
    if (qty > 0) {
      // ✅ FIX: أي صنف كميته صفر أو مش محدودة في inventory ممنوع تماماً
      final available = inventory[item] ?? 0;
      if (available <= 0) {
        return 'نفد "$item" من المخزن!';
      }
      final orders =
          Map<String, int>.from(drinkTables[index]['orders'] ?? {});
      final currentInOrder = orders[item] ?? 0;
      final totalNeeded = currentInOrder + qty;
      if (totalNeeded > available) {
        return 'الكمية المتاحة هي $available فقط!';
      }
    }
    final orders =
        Map<String, int>.from(drinkTables[index]['orders'] ?? {});
    orders[item] = (orders[item] ?? 0) + qty;
    if (orders[item]! <= 0) orders.remove(item);
    drinkTables[index]['orders'] = orders;

    final dtName =
        drinkTables[index]['name']?.toString() ?? 'تربيزة مشروبات';
    AuditLogService.log(
      action: qty > 0
          ? AuditAction.drinkTableOrderAdded
          : AuditAction.drinkTableOrderRemoved,
      actionDetails: qty > 0
          ? 'أضاف "$item ×${qty.abs()}" لـ "$dtName"'
          : 'أزال "$item ×${qty.abs()}" من "$dtName"',
      extra: {'table_name': dtName, 'item': item, 'qty': qty},
    );

    _saveSingleDrinkTable(index); // 🔥 RACE FIX: patch تربيزة واحدة بس
    notifyListeners();
    return null;
  }

  void setDrinkTableOrders(int index, Map<String, int> orders) {
    drinkTables[index]['orders'] = orders;
    _saveSingleDrinkTable(index); // 🔥 RACE FIX: patch تربيزة واحدة بس
    notifyListeners();
  }

  Map<String, dynamic> checkoutDrinkTable(int index) {
    if (_checkoutDrinkTables.contains(index)) return {};
    final t = drinkTables[index];
    final Map<String, int> orders =
        Map<String, int>.from(t['orders'] ?? {});
    if (orders.isEmpty) return {};
    _checkoutDrinkTables.add(index);
    double total = 0;
    orders.forEach((item, qty) {
      total += qty * (menu[item] ?? 0);
    });

    AuditLogService.logTable(
      action: AuditAction.drinkTableCheckout,
      tableName: t['name'] ?? '',
      extra: 'إجمالي: ${total.toStringAsFixed(1)} ج',
    );

    final record = {
      'id': index,
      'name': t['name'],
      'device_type': 'drink_table',
      'duration': '-',
      'elapsed_seconds': 0,
      'play_mode': 'drink',
      'time_cost': 0.0,
      'buffet_cost': total,
      'total': total,
      'orders': orders,
      'date': DateTime.now().toString(),
      'cashier': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
    };

    orders.forEach((item, qty) {
      _deductFromInventory(item, qty);
    });
    history.add(record);
    if (shopId != null) {
      _notifyTelegram(shopId!, 'session_end', {
        'deviceName': t['name'] ?? '',
        'mode': 'مشروبات',
        'cashier': currentCashierName ?? 'أدمن',
        'startTime': '-',
        'endTime': DateTime.now().toString().substring(0, 16),
        'timeCost': 0.0,
        'buffetCost': total,
        'total': total,
        'orders': orders.entries.map((e) => '${e.key} ×${e.value}').join(', '),
      });
    }
    drinkTables[index]['orders'] = <String, int>{};
    _checkoutDrinkTables.remove(index);

    _saveTables(tablesChanged: false, drinkTablesChanged: true);
    _saveSingleHistoryRecord(record);
    notifyListeners();
    return record;
  }

  void transferDrinkTableToDevice(int drinkIndex, PSDevice device) {
    final Map<String, int> orders =
        Map<String, int>.from(drinkTables[drinkIndex]['orders'] ?? {});
    if (!device.isActive) {
      device.mode = 'normal';
      device.status = 'شغال';
      device.startTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      device.addedSeconds = 0;
      device.isPaused = false;
      device.sessionLog = [];
      _logEvent(device, 'start',
          note: 'بدأ اللعب (تحويل من طاولة طلبات)');
      _alertedDevices.remove(device.id);
    }
    orders.forEach((item, qty) {
      device.orders[item] = (device.orders[item] ?? 0) + qty;
    });
    drinkTables[drinkIndex]['orders'] = <String, int>{};
    _saveTables(tablesChanged: false, drinkTablesChanged: true);
    _saveDevices();
    notifyListeners();
  }

  void transferDrinkTableOrdersOnly(int drinkIndex, PSDevice device) {
    final Map<String, int> orders =
        Map<String, int>.from(drinkTables[drinkIndex]['orders'] ?? {});
    orders.forEach((item, qty) {
      device.orders[item] = (device.orders[item] ?? 0) + qty;
    });
    drinkTables[drinkIndex]['orders'] = <String, int>{};
    _saveTables(tablesChanged: false, drinkTablesChanged: true);
    _saveDevices();
    notifyListeners();
  }

  Future<void> transferDrinkTableOrdersToTable(
      int drinkIndex, int tableIndex) async {
    final Map<String, int> orders =
        Map<String, int>.from(drinkTables[drinkIndex]['orders'] ?? {});
    if (orders.isEmpty) return;
    final existing =
        Map<String, int>.from(tables[tableIndex]['orders'] ?? {});
    orders.forEach((item, qty) {
      existing[item] = (existing[item] ?? 0) + qty;
    });
    tables[tableIndex]['orders'] = existing;
    drinkTables[drinkIndex]['orders'] = <String, int>{};
    notifyListeners();
    if (shopId != null) {
      Future.wait([
        FirebaseService.pushTablesState(shopId!, tables, _myDeviceId),
        FirebaseService.pushDrinkTablesState(
            shopId!, drinkTables, _myDeviceId),
      ]);
      SyncService.saveLocal(shopId!, _buildDataDict());
    }
  }

  void transferDrinkTableToTable(int drinkIndex, int tableIndex) {
    final Map<String, int> orders =
        Map<String, int>.from(drinkTables[drinkIndex]['orders'] ?? {});
    final t = tables[tableIndex];
    if (t['start_time'] == null) {
      t['start_time'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      t['is_paused'] = false;
      t['pause_start_time'] = null;
    }
    final existing = Map<String, int>.from(t['orders'] ?? {});
    orders.forEach((item, qty) {
      existing[item] = (existing[item] ?? 0) + qty;
    });
    tables[tableIndex]['orders'] = existing;
    drinkTables[drinkIndex]['orders'] = <String, int>{};
    _saveTables(tablesChanged: true, drinkTablesChanged: true);
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MENU & INVENTORY
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> addMenuItem(String name, int price, {int buyPrice = 0, String? categoryId}) async {
    menu[name] = price;
    if (buyPrice > 0) menuBuyPrices[name] = buyPrice;
    // ✅ FIX: أي صنف جديد بيتضاف تلقائياً للمخزون بكمية صفر
    // عشان الفحص في addOrder/addTableOrder/addDrinkTableOrder يشتغل صح
    if (!inventory.containsKey(name)) {
      inventory[name] = 0;
    }
    if (buffetCategories.isEmpty) {
      buffetCategories = BuffetCategory.defaults;
    }
    // ✅ FIX: نحط الكاتيجوري اللي اختارها المستخدم مباشرة
    if (categoryId != null) {
      _menuItemCategories[name] = categoryId;
    } else if (!_menuItemCategories.containsKey(name)) {
      _menuItemCategories[name] = 'other';
    }
    AuditLogService.log(
        action: AuditAction.menuItemAdded,
        actionDetails: 'أضاف منتج "$name" بسعر $price ج',
        extra: {'item': name, 'price': price});
    notifyListeners();
    if (shopId != null) {
      await FirebaseService.pushStaticData(shopId!, _buildStaticData(), _myDeviceId);
    }
    await SyncService.saveLocal(shopId!, _buildDataDict());
  }

  Future<void> removeMenuItem(String name) async {
    menu.remove(name);
    _menuItemCategories.remove(name);
    inventory.remove(name);
    menuBuyPrices.remove(name);
    dailyInventorySummary.remove(name);
    AuditLogService.log(
        action: AuditAction.menuItemDeleted,
        actionDetails: 'حذف منتج "$name" من البوفيه');
    notifyListeners();
    if (shopId != null) {
      await FirebaseService.pushStaticData(shopId!, _buildStaticData(), _myDeviceId);
    }
    await SyncService.saveLocal(shopId!, _buildDataDict());
  }

  Future<void> updateMenuItem(String oldName, String newName, int price,
      {int buyPrice = 0}) async {
    menu.remove(oldName);
    menu[newName] = price;
    menuBuyPrices.remove(oldName);
    if (buyPrice > 0) menuBuyPrices[newName] = buyPrice;
    if (_menuItemCategories.containsKey(oldName)) {
      _menuItemCategories[newName] = _menuItemCategories.remove(oldName)!;
    }
    notifyListeners();
    if (shopId != null) {
      await FirebaseService.pushStaticData(shopId!, _buildStaticData(), _myDeviceId);
    }
    await SyncService.saveLocal(shopId!, _buildDataDict());
  }

  void _deductFromInventory(String item, int qty) {
    if (inventory.containsKey(item)) {
      inventory[item] = (inventory[item]! - qty).clamp(0, 99999);
    }
    dailyInventorySummary[item] =
        (dailyInventorySummary[item] ?? 0) + qty;
    _inventoryUpdatedAt = DateTime.now().millisecondsSinceEpoch; // 🔥 حدّث الـ timestamp
    _pushStaticOnly();
  }

  void addInventory(String item, int qty) {
    inventory[item] = (inventory[item] ?? 0) + qty;
    _inventoryUpdatedAt = DateTime.now().millisecondsSinceEpoch;
    _pushStaticOnly();
    notifyListeners();
  }

  void setInventoryItem(String item, int qty) {
    inventory[item] = qty;
    _inventoryUpdatedAt = DateTime.now().millisecondsSinceEpoch;
    _pushStaticOnly();
    notifyListeners();
  }

  void resetInventoryItem(String item) {
    inventory[item] = 0;
    _pushStaticOnly();
    notifyListeners();
  }

  void resetDailySummary() {
    dailyInventorySummary.clear();
    _pushStaticOnly();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUFFET CATEGORIES
  // ══════════════════════════════════════════════════════════════════════════

  String? menuItemCategory(String item) =>
      _menuItemCategories[item] ?? 'other';

  void setMenuItemCategory(String item, String categoryId) {
    _menuItemCategories[item] = categoryId;
    _pushStaticOnly();
    notifyListeners();
  }

  void addCategory(String name, String emoji) {
    final id = 'cat_${DateTime.now().millisecondsSinceEpoch}';
    buffetCategories.add(BuffetCategory(
      id: id,
      name: name,
      emoji: emoji,
      sortOrder: buffetCategories.length,
    ));
    AuditLogService.log(
      action: AuditAction.menuItemAdded,
      actionDetails: 'أضاف قسم بوفيه "$name"',
    );
    _pushStaticOnly();
    notifyListeners();
  }

  void updateCategory(String id, String name, String emoji) {
    final idx = buffetCategories.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    buffetCategories[idx] = BuffetCategory(
      id: id,
      name: name,
      emoji: emoji,
      sortOrder: buffetCategories[idx].sortOrder,
    );
    _pushStaticOnly();
    notifyListeners();
  }

  void deleteCategory(String id) {
    _menuItemCategories.updateAll(
        (item, catId) => catId == id ? 'other' : catId);
    buffetCategories.removeWhere((c) => c.id == id);
    for (int i = 0; i < buffetCategories.length; i++) {
      buffetCategories[i].sortOrder = i;
    }
    _pushStaticOnly();
    notifyListeners();
  }

  void reorderCategory(int oldIndex, int newIndex) {
    final cat = buffetCategories.removeAt(oldIndex);
    buffetCategories.insert(newIndex, cat);
    for (int i = 0; i < buffetCategories.length; i++) {
      buffetCategories[i].sortOrder = i;
    }
    _pushStaticOnly();
    notifyListeners();
  }

  void restoreDefaultCategories() {
    buffetCategories = BuffetCategory.defaults;
    for (final item in menu.keys) {
      if (!_menuItemCategories.containsKey(item)) {
        _menuItemCategories[item] = 'other';
      }
    }
    _pushStaticOnly();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AUTH
  // ══════════════════════════════════════════════════════════════════════════

  void updateShopName(String name) {
    final old = shopName;
    shopName = name;
    AuditLogService.log(
        action: AuditAction.shopNameChanged,
        actionDetails: 'غيّر اسم المحل من "$old" إلى "$name"');
    _pushStaticOnly();
    notifyListeners();
  }

  String? login(String password,
      {required String targetRole, String? targetCashierName}) {
    final hash = hashPassword(password);

    if (targetRole == 'admin') {
      if (hash == adminPasswordHash) {
        isAdmin = true;
        isCashier = false;
        currentCashierName = null;
        _saveLoginState('admin', null);
        AuditLogService.configure(
            shopId: shopId, cashierName: 'أدمن', isAdmin: true);
        AuditLogService.log(
            action: AuditAction.login,
            actionDetails: 'دخل الأدمن للنظام');
        _sync?.startHistorySSE();
        notifyListeners();
        return 'admin';
      }
      return null;
    }

    if (targetRole == 'cashier' && targetCashierName != null) {
      for (final c in cashiers) {
        if (c['name'] == targetCashierName && c['hash'] == hash) {
          isCashier = true;
          isAdmin = false;
          currentCashierName = c['name'] as String;
          _saveLoginState('cashier', currentCashierName);
          AuditLogService.configure(
              shopId: shopId,
              cashierName: currentCashierName,
              isAdmin: false);
          AuditLogService.log(
              action: AuditAction.login,
              actionDetails:
                  'دخل الكاشير "${currentCashierName}" للنظام');
          notifyListeners();
          return 'cashier';
        }
      }
      return null;
    }

    return null;
  }

  void logout() {
    AuditLogService.log(
        action: AuditAction.logout,
        actionDetails: 'خرج من النظام');
    _sync?.stopHistorySSE();
    isAdmin = false;
    isCashier = false;
    currentCashierName = null;
    _clearLoginState();
    AuditLogService.configure(
        shopId: shopId, cashierName: null, isAdmin: false);
    notifyListeners();
  }

  void changePassword(String newPass) {
    adminPasswordHash = hashPassword(newPass);
    AuditLogService.log(
        action: AuditAction.passwordChanged,
        actionDetails: 'غيّر كلمة سر الأدمن');
    _pushStaticOnly();
    notifyListeners();
  }

  void changeCashierPassword(String newPass) {
    if (cashiers.isNotEmpty) {
      cashiers[0]['hash'] = hashPassword(newPass);
      _pushStaticOnly();
    }
  }

  void changeHistoryPassword(String newPass) {
    historyPasswordHash = hashPassword(newPass);
    _pushStaticOnly();
    notifyListeners();
  }

  void setHistoryPasswordEnabled(bool val) {
    historyPasswordEnabled = val;
    _pushStaticOnly();
    notifyListeners();
  }

  void updatePrices(Map<String, int> newPrices) {
    prices = newPrices;
    AuditLogService.log(
        action: AuditAction.pricesUpdated,
        actionDetails: 'حدّث الأسعار');
    _pushStaticOnly();
    notifyListeners();
  }

  void updateDeviceName(PSDevice d, String name) {
    final old = d.displayName;
    d.displayName = name;
    AuditLogService.log(
        action: AuditAction.deviceRenamed,
        actionDetails: 'غيّر اسم الجهاز من "$old" إلى "$name"');
    _saveDevices();
    notifyListeners();
  }

  void updateDeviceType(PSDevice d, String type) {
    d.deviceType = type;
    _saveDevices();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CASHIER MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  void addCashier(String name, String password) {
    cashiers.add({'name': name.trim(), 'hash': hashPassword(password)});
    AuditLogService.log(
        action: AuditAction.cashierAdded,
        actionDetails: 'أضاف كاشير جديد "$name"');
    _pushStaticOnly();
    notifyListeners();
  }

  void removeCashier(int index) {
    if (cashiers.length <= 1) return;
    final name = cashiers[index]['name'] as String? ?? '';
    AuditLogService.log(
        action: AuditAction.cashierRemoved,
        actionDetails: 'حذف الكاشير "$name"');
    cashiers.removeAt(index);
    _pushStaticOnly();
    notifyListeners();
  }

  void updateCashierName(int index, String name) {
    cashiers[index]['name'] = name.trim();
    _pushStaticOnly();
    notifyListeners();
  }

  void updateCashierPassword(int index, String newPassword) {
    cashiers[index]['hash'] = hashPassword(newPassword);
    _pushStaticOnly();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EXPENSES
  // ══════════════════════════════════════════════════════════════════════════

  void addExpense(String title, double amount, String category,
      {String? note}) {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    expenses.add({
      'id': now.millisecondsSinceEpoch.toString(),
      'title': title,
      'amount': amount,
      'category': category,
      'date': dateStr,
      'note': note,
      'added_by': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
      'created_at': now.toIso8601String(),
    });
    AuditLogService.log(
      action: AuditAction.expenseAdded,
      actionDetails:
          'أضاف مصروف "$title" ($category) بمبلغ ${amount.toStringAsFixed(1)} ج',
      extra: {'title': title, 'amount': amount, 'category': category},
    );
    _pushStaticOnly();
    notifyListeners();
  }

  void deleteExpense(String id) {
    final exp =
        expenses.firstWhere((e) => e['id'] == id, orElse: () => {});
    expenses.removeWhere((e) => e['id'] == id);
    AuditLogService.log(
      action: AuditAction.expenseDeleted,
      actionDetails: 'حذف مصروف "${exp['title'] ?? ''}"',
    );
    _pushStaticOnly();
    notifyListeners();
  }

  void updateExpense(String id, String title, double amount, String category,
      {String? note}) {
    final idx = expenses.indexWhere((e) => e['id'] == id);
    if (idx == -1) return;
    expenses[idx] = {
      ...expenses[idx],
      'title': title,
      'amount': amount,
      'category': category,
      'note': note,
      'updated_at': DateTime.now().toIso8601String(),
    };
    AuditLogService.log(
      action: AuditAction.expenseUpdated,
      actionDetails:
          'عدّل مصروف "$title" ($category) — ${amount.toStringAsFixed(1)} ج',
    );
    _pushStaticOnly();
    notifyListeners();
  }

  void addExpenseCategory(String name) {
    if (!expenseCategories.contains(name)) {
      expenseCategories.add(name);
      _pushStaticOnly();
      notifyListeners();
    }
  }

  void removeExpenseCategory(String name) {
    expenseCategories.remove(name);
    _pushStaticOnly();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DEBTS
  // ══════════════════════════════════════════════════════════════════════════

  void addDebt(String name, double amount, String date, {String? note}) {
    debts.add({
      'name': name,
      'amount': amount,
      'date': date,
      'paid': false,
      'note': note,
      'created_at': DateTime.now().toString(),
      'payment_history': <Map<String, dynamic>>[],
      'created_by': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
    });
    AuditLogService.logDebt(
        action: AuditAction.debtAdded,
        personName: name,
        amount: amount);
    _pushStaticOnly();
    notifyListeners();
  }

  void addToDebt(int index, double amount, {String? note}) {
    final name = debts[index]['name'] as String? ?? '';
    final current =
        (debts[index]['amount'] as num?)?.toDouble() ?? 0;
    debts[index]['amount'] = current + amount;
    debts[index]['paid'] = false;
    final h = List<Map<String, dynamic>>.from(
        debts[index]['payment_history'] as List? ?? []);
    h.add({
      'type': 'add',
      'amount': amount,
      'note': note,
      'date': DateTime.now().toString(),
      'by': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
    });
    debts[index]['payment_history'] = h;
    AuditLogService.logDebt(
        action: AuditAction.debtAmountAdded,
        personName: name,
        amount: amount);
    _pushStaticOnly();
    notifyListeners();
  }

  void markDebtPaid(int index) {
    final amount =
        (debts[index]['amount'] as num?)?.toDouble() ?? 0;
    final name = debts[index]['name'] as String? ?? '';
    debts[index]['paid'] = true;
    final h = List<Map<String, dynamic>>.from(
        debts[index]['payment_history'] as List? ?? []);
    h.add({
      'type': 'pay',
      'amount': amount,
      'date': DateTime.now().toString(),
      'by': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
    });
    debts[index]['payment_history'] = h;
    debts[index]['amount'] = 0.0;
    AuditLogService.logDebt(
        action: AuditAction.debtPaid, personName: name, amount: amount);
    _pushStaticOnly();
    notifyListeners();
  }

  void partialPayDebt(int index, double amount) {
    final name = debts[index]['name'] as String? ?? '';
    final current =
        (debts[index]['amount'] as num?)?.toDouble() ?? 0;
    final newAmount = (current - amount).clamp(0, double.infinity);
    if (newAmount <= 0) {
      debts[index]['paid'] = true;
      debts[index]['amount'] = 0.0;
    } else {
      debts[index]['amount'] = newAmount;
    }
    debts[index]['last_partial_pay'] = DateTime.now().toString();
    final h = List<Map<String, dynamic>>.from(
        debts[index]['payment_history'] as List? ?? []);
    h.add({
      'type': 'pay',
      'amount': amount,
      'date': DateTime.now().toString(),
      'by': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
    });
    debts[index]['payment_history'] = h;
    AuditLogService.logDebt(
        action: AuditAction.debtPartialPaid,
        personName: name,
        amount: amount);
    _pushStaticOnly();
    notifyListeners();
  }

  void deleteDebt(int index) {
    final name = debts[index]['name'] as String? ?? '';
    final amount =
        (debts[index]['amount'] as num?)?.toDouble() ?? 0;
    AuditLogService.logDebt(
        action: AuditAction.debtDeleted,
        personName: name,
        amount: amount);
    debts.removeAt(index);
    _pushStaticOnly();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TOURNAMENTS
  // ══════════════════════════════════════════════════════════════════════════

  int addTournament(Map<String, dynamic> tournament) {
    tournaments.add(Map<String, dynamic>.from(tournament));
    AuditLogService.log(
      action: AuditAction.tournamentCreated,
      actionDetails:
          'أنشأ بطولة "${tournament['name']}" للعبة ${tournament['game']}',
    );
    _saveTournaments();
    notifyListeners();
    return tournaments.length - 1;
  }

  void updateTournament(int index, Map<String, dynamic> data) {
    if (index < 0 || index >= tournaments.length) return;
    tournaments[index] = Map<String, dynamic>.from(data);
    _saveTournaments();
    notifyListeners();
  }

  void deleteTournament(int index) {
    if (index < 0 || index >= tournaments.length) return;
    final name = tournaments[index]['name'] as String? ?? '';
    AuditLogService.log(
        action: AuditAction.tournamentDeleted,
        actionDetails: 'حذف البطولة "$name"');
    tournaments.removeAt(index);
    _saveTournaments();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SHIFT MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> startShift(String cashierName) async {
    if (isShiftLockedByOther) return;

    final shift = ShiftRecord(
      cashierName: cashierName,
      startTime: DateTime.now(),
      transactions: [],
    );
    openShifts[cashierName] = shift;
    currentCashierName = cashierName;
    isCashier = true;
    isAdmin = false;

    AuditLogService.configure(
        shopId: shopId, cashierName: cashierName, isAdmin: false);
    AuditLogService.log(
      action: AuditAction.shiftStarted,
      actionDetails: 'بدأ الكاشير "$cashierName" شيفته',
    );

    if (shopId != null) {
      await FirebaseService.pushOpenShifts(
        shopId!,
        openShifts.map((k, v) => MapEntry(k, v.toJson())),
        _myDeviceId,
      );
    }

    final data = _buildDataDict();
    await SyncService.saveLocal(shopId!, data);

    _notifyTelegram(shopId!, 'shift_start', {
      'cashier': cashierName,
      'time': DateTime.now().toString(),
    });
    notifyListeners();
  }

  Future<ShiftRecord?> endShift() async {
    isEndingShift = true;
    notifyListeners();
    final cashierName = currentCashierName;
    if (cashierName == null || !openShifts.containsKey(cashierName)) {
      return null;
    }

    final shift = openShifts[cashierName]!;
    final shiftStart = shift.startTime;

    final shiftTransactions = history.where((h) {
      final date = DateTime.tryParse(h['date']?.toString() ?? '');
      if (date == null) return false;
      return date.isAfter(shiftStart) &&
          h['cashier']?.toString() == cashierName;
    }).toList();

    final closedShift = ShiftRecord(
      cashierName: cashierName,
      startTime: shiftStart,
      endTime: DateTime.now(),
      transactions: shiftTransactions,
    );

    AuditLogService.log(
      action: AuditAction.shiftEnded,
      actionDetails:
          'أنهى الكاشير "$cashierName" شيفته | ${closedShift.sessionCount} جلسة | ${closedShift.totalRevenue.toStringAsFixed(1)} ج',
      extra: {
        'sessions_count': closedShift.sessionCount,
        'total_revenue': closedShift.totalRevenue,
        'duration_minutes': closedShift.duration.inMinutes,
      },
    );

    shiftsHistory.add(closedShift);
    openShifts.remove(cashierName);

    if (shopId != null) {
      await Future.wait([
        FirebaseService.pushOpenShifts(
          shopId!,
          openShifts.map((k, v) => MapEntry(k, v.toJson())),
          _myDeviceId,
        ),
        FirebaseService.pushShiftsHistory(
          shopId!,
          shiftsHistory.map((s) => s.toJson()).toList(),
        ),
      ]);
    }

    final data = _buildDataDict();
    await SyncService.saveLocal(shopId!, data);
    _notifyTelegram(shopId!, 'shift_end', {
      'cashier': cashierName,
      'sessions': closedShift.sessionCount,
      'total': closedShift.totalRevenue,
      'duration': closedShift.duration.inMinutes,
    });
    isEndingShift = false;
    notifyListeners();
    return closedShift;
  }

  void clearShiftsHistory() {
    shiftsHistory.clear();
    _pushShiftsToFirebase();
    _sync?.schedulePushShifts();
    notifyListeners();
  }

  void deleteShift(int index) {
    if (index < 0 || index >= shiftsHistory.length) return;
    final cashier = shiftsHistory[index].cashierName;
    AuditLogService.log(
      action: AuditAction.shiftEnded,
      actionDetails: 'حذف تقرير شيفت "$cashier"',
    );
    shiftsHistory.removeAt(index);
    _pushShiftsToFirebase();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RECHARGE
  // ══════════════════════════════════════════════════════════════════════════

  void setRechargeEnabled(bool val) {
    rechargeEnabled = val;
    _pushStaticOnly();
    notifyListeners();
  }

  void addRechargeCard(String name, double value) {
    rechargeCards.add({'name': name, 'value': value});
    _pushStaticOnly();
    notifyListeners();
  }

  void removeRechargeCard(int index) {
    rechargeCards.removeAt(index);
    _pushStaticOnly();
    notifyListeners();
  }

  void addRechargeBalance(double amount, String note) {
    rechargeBalance += amount;
    rechargeTransactions.add({
      'type': 'top_up',
      'name': note,
      'value': amount,
      'cashier': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
      'date': DateTime.now().toString(),
    });
    _pushStaticOnly();
    notifyListeners();
  }

  void addRechargeTransaction({
    required String type,
    required String name,
    required double value,
  }) {
    rechargeTransactions.add({
      'type': type,
      'name': name,
      'value': value,
      'cashier': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
      'date': DateTime.now().toString(),
    });

    if (type == 'card' || type == 'free') {
      rechargeBalance -= value;
    }

    if (type == 'card' || type == 'free') {
      final record = {
        'id': 0,
        'name': name,
        'device_type': 'recharge',
        'duration': '-',
        'elapsed_seconds': 0,
        'play_mode': type,
        'time_cost': value,
        'buffet_cost': 0.0,
        'total': value,
        'orders': <String, int>{},
        'date': DateTime.now().toString(),
        'cashier': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
      };
      history.add(record);
      _saveSingleHistoryRecord(record);

      if (shopId != null) {
        _notifyTelegram(shopId!, 'recharge', {
          'type': type == 'card' ? 'كارت' : 'شحن حر',
          'name': name,
          'value': value,
          'cashier': currentCashierName ?? 'أدمن',
        });
      }
    }

    _pushStaticOnly();
    notifyListeners();
  }

  Future<void> clearRechargeTransactions() async {
    rechargeTransactions.clear();
    notifyListeners();
    if (shopId != null) {
      await FirebaseService.pushStaticData(shopId!, _buildStaticData(), _myDeviceId);
      await SyncService.saveLocal(shopId!, _buildDataDict());
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOGIN STATE PERSISTENCE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _saveLoginState(String role, String? cashierName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('login_role', role);
    if (cashierName != null) {
      await prefs.setString('login_cashier_name', cashierName);
    } else {
      await prefs.remove('login_cashier_name');
    }
  }

  Future<void> _clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('login_role');
    await prefs.remove('login_cashier_name');
  }

  Future<void> _restoreLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('login_role');
    if (role == null) return;

    if (role == 'admin') {
      isAdmin = true;
      isCashier = false;
      currentCashierName = null;
      AuditLogService.configure(
          shopId: shopId, cashierName: 'أدمن', isAdmin: true);
      _sync?.startHistorySSE();
    } else if (role == 'cashier') {
      final name = prefs.getString('login_cashier_name');
      if (name != null) {
        isCashier = true;
        isAdmin = false;
        currentCashierName = name;
        AuditLogService.configure(
            shopId: shopId, cashierName: name, isAdmin: false);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TELEGRAM
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _notifyTelegram(
      String shopId, String type, Map<String, dynamic> data) async {
    try {
      await http.post(
        Uri.parse(
            'https://psmanagement.iibrahimshosha.workers.dev/notify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'secret': 'PSFCIMU25112001',
          'shopId': shopId,
          'type': type,
          'data': data,
        }),
      );
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DISPOSE
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _clockTimer?.cancel();
    _historyPollTimer?.cancel();
    // 🔥 _fallbackPollTimer حُذف — مش محتاجين نلغيه
    _sync?.flushAll();
    _sync?.dispose();
    super.dispose();
  }
}
