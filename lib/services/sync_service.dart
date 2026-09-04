import 'dart:async'; 
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';

typedef DataMap = Map<String, dynamic>;

class SyncCallbacks { 
  final void Function(
    Map<String, dynamic> rawData,
    List<Map<String, dynamic>> devices,
  ) onRemoteDevices;

  final void Function(Map<String, dynamic> rawData, List<Map<String, dynamic>> tables) onRemoteTables;
  final void Function(Map<String, dynamic> rawData, List<Map<String, dynamic>> drinkTables) onRemoteDrinkTables;
  final void Function(Map<String, dynamic> data) onRemoteStatic;
  final void Function(List<Map<String, dynamic>> history) onRemoteHistory;
  final void Function(Map<String, int> summary) onRemoteDailySummary;
  final void Function(List<Map<String, dynamic>> shifts) onRemoteShiftsHistory;

  final List<Map<String, dynamic>> Function() buildDevicesState;
  final List<Map<String, dynamic>> Function() buildTables;
  final List<Map<String, dynamic>> Function() buildDrinkTables;
  final DataMap Function() buildStaticData;
  final List<Map<String, dynamic>> Function() buildHistory;
  final Map<String, dynamic> Function() buildOpenShifts;
  final List<Map<String, dynamic>> Function() buildShiftsHistory;
  final List<Map<String, dynamic>> Function() buildDebts;
  final List<Map<String, dynamic>> Function() buildTournaments;
  final void Function(Map<String, dynamic> openShifts) onRemoteOpenShifts;

  const SyncCallbacks({
    required this.onRemoteDevices,
    required this.onRemoteTables,
    required this.onRemoteDrinkTables,
    required this.buildDevicesState,
    required this.buildTables,
    required this.buildDrinkTables,
    required this.buildStaticData,
    required this.buildHistory,
    required this.buildOpenShifts,
    required this.buildShiftsHistory,
    required this.buildDebts,
    required this.buildTournaments,
    required this.onRemoteStatic,
    required this.onRemoteOpenShifts,
    required this.onRemoteDailySummary,
    required this.onRemoteShiftsHistory,
    required this.onRemoteHistory,
  });
}

class SyncService {
  final String shopId;
  final SyncCallbacks callbacks;
  final String senderId;

  StreamSubscription? _openShiftsSSE;
  StreamSubscription? _historySSE;
  Timer? _debounceTimer;
  StreamSubscription? _devicesSSE;
  StreamSubscription? _tablesSSE;
  StreamSubscription? _drinkTablesSSE;
  StreamSubscription? _staticSSE;

  bool _paused = false;
  bool _disposed = false;

  bool _pendingDevices = false;
  bool _pendingTables = false;
  bool _pendingStatic = false;
  bool _pendingHistory = false;
  bool _pendingDebts = false;
  bool _pendingShifts = false;
  bool _pendingTournaments = false;

  SyncService({
    required this.shopId,
    required this.callbacks,
    required this.senderId,
  });

  void start() {
    _startDevicesSSE();
    _startTablesSSE();
    _startDrinkTablesSSE();
    _startStaticSSE();
    _startOpenShiftsSSE();
    // history: لا SSE هنا — بتشتغل بس لما الأدمن يسجل دخول عبر startHistorySSE()
  }

  /// بيشتغل بس لما الأدمن يسجل دخول — الكاشير مش محتاج يشوف السجل لحظياً
  void startHistorySSE() {
    if (_disposed) return;
    _historySSE?.cancel();
    _historySSE = FirebaseService.listenToHistory(
      shopId,
      onData: (history) {
        if (_disposed || _paused) return;
        callbacks.onRemoteHistory(history);
      },
      onError: (_) {},
      retryDelay: const Duration(seconds: 2),
    );
  }

  /// بيتوقف لما الأدمن يخرج
  void stopHistorySSE() {
    _historySSE?.cancel();
    _historySSE = null;
  }

  void _startOpenShiftsSSE() {
    _openShiftsSSE?.cancel();
    _openShiftsSSE = FirebaseService.listenToOpenShifts(
      shopId,
      senderId: senderId,
      onData: (openShifts) {
        if (_disposed || _paused) return;
        callbacks.onRemoteOpenShifts(openShifts);
      },
      onError: (_) {},
      retryDelay: const Duration(seconds: 2),
    );
  }


  void pause() => _paused = true;

  void resume() {
    _paused = false;
    _flushPending();
  }

  void dispose() {
    _disposed = true;
    _devicesSSE?.cancel();
    _tablesSSE?.cancel();
    _drinkTablesSSE?.cancel();
    _staticSSE?.cancel();
    _openShiftsSSE?.cancel();
    _historySSE?.cancel();
    _debounceTimer?.cancel();
  }

  void _startDevicesSSE() {
    _devicesSSE?.cancel();
    _devicesSSE = FirebaseService.listenToDevices(
      shopId,
      onData: (rawData, devices) {
        if (_disposed || _paused) return;
        callbacks.onRemoteDevices(rawData, devices);
      },
      onError: (_) {},
      retryDelay: const Duration(seconds: 2),
    );
  }

  void _startTablesSSE() {
    _tablesSSE?.cancel();
    _tablesSSE = FirebaseService.listenToTables(
      shopId,
      onData: (rawData, tables) {
        if (_disposed || _paused) return;
        callbacks.onRemoteTables(rawData, tables);
      },
      onError: (_) {},
      retryDelay: const Duration(seconds: 2),
    );
  }

  void _startDrinkTablesSSE() {
    _drinkTablesSSE?.cancel();
    _drinkTablesSSE = FirebaseService.listenToDrinkTables(
      shopId,
      senderId: senderId, // ✅ FIX: متعملش merge لو احنا اللي بعتنا
      onData: (rawData, drinkTables) {
        if (_disposed || _paused) return;
        callbacks.onRemoteDrinkTables(rawData, drinkTables);
      },
      onError: (_) {},
      retryDelay: const Duration(seconds: 2),
    );
  }

  void _startStaticSSE() {
    _staticSSE?.cancel();
    _staticSSE = FirebaseService.listenToStatic(
      shopId,
      senderId: senderId, // ✅ FIX: متعملش applyStatic لو احنا اللي بعتنا
      onData: (data) {
        if (_disposed || _paused) return;
        callbacks.onRemoteStatic(data);
      },
      onError: (_) {},
      retryDelay: const Duration(seconds: 2),
    );
  }



  Future<void> pushDevices() async {
    if (_paused || _disposed) {
      _pendingDevices = true;
      return;
    }
    _pendingDevices = false;
    try {
      final devices = callbacks.buildDevicesState();
      await FirebaseService.pushDevicesState(shopId, devices, senderId);
    } catch (_) {
      _pendingDevices = true;
    }
  }

  Future<void> pushSingleDevice(int deviceIndex, Map<String, dynamic> deviceData) async {
    if (_paused || _disposed) return;
    try {
      // 🔥 FIX: بدل patch على جهاز واحد، نبعت كل الأجهزة بـ set
      // عشان Firebase SSE يبعت path=/ والموبايلات التانية تستقبل التغيير فوراً
      final allDevices = callbacks.buildDevicesState();
      await FirebaseService.pushDevicesStateSlim(shopId, allDevices, senderId);
    } catch (_) {
      _pendingDevices = true; 
    }
  }

  void schedulePushTables() {
    _pendingTables = true;
    _scheduleDebounce();
  }

  void schedulePushStatic() {
    _pendingStatic = true;
    _scheduleDebounce();
  }



  Future<void> pushSingleHistory(Map<String, dynamic> record) async {
    if (_paused || _disposed) return;
    try {
      await FirebaseService.appendSingleHistoryRecord(shopId, record);
    } catch (_) {
      _pendingHistory = true;
    }
  }

  void schedulePushShifts() {
    _pendingShifts = true;
    _scheduleDebounce();
  }

  void schedulePushDebts() {
    _pendingDebts = true;
    _scheduleDebounce();
  }

  void schedulePushTournaments() {
    _pendingTournaments = true;
    _scheduleDebounce();
  }

  Future<void> _flushPending() async {
    if (_disposed) return;

    if (_pendingDevices) await pushDevices();
    if (_pendingTables) await _pushTables();
    if (_pendingStatic) await _pushStatic();
    if (_pendingHistory) await pushSingleHistory(callbacks.buildHistory().isNotEmpty ? callbacks.buildHistory().last : {});
    if (_pendingShifts) await _pushShifts();
    if (_pendingDebts) await _pushDebts();
    if (_pendingTournaments) await _pushTournaments();
  }

  Future<void> flushAll() => _flushPending();

  void _scheduleDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: 800),
      _flushPending,
    );
  }

  Future<void> _pushTables() async {
    if (_paused || _disposed) return;
    _pendingTables = false;
    try {
      await Future.wait([
        FirebaseService.pushTablesState(shopId, callbacks.buildTables(), senderId),
        FirebaseService.pushDrinkTablesState(shopId, callbacks.buildDrinkTables(), senderId),
      ]);
    } catch (_) {
      _pendingTables = true;
    }
  }

  Future<void> _pushStatic() async {
    if (_paused || _disposed) return;
    _pendingStatic = false;
    try {
      await FirebaseService.pushStaticData(
          shopId, callbacks.buildStaticData(), senderId); // ✅ FIX
    } catch (_) {
      _pendingStatic = true;
    }
  }

  Future<void> _pushShifts() async {
    if (_paused || _disposed) return;
    _pendingShifts = false;
    try {
      await Future.wait([
        FirebaseService.pushOpenShifts(
            shopId, callbacks.buildOpenShifts(), senderId), 
        FirebaseService.pushShiftsHistory(
            shopId, callbacks.buildShiftsHistory()),
      ]);
    } catch (_) {
      _pendingShifts = true;
    }
  }

  Future<void> _pushDebts() async {
    if (_paused || _disposed) return;
    _pendingDebts = false;
    try {
      await FirebaseService.pushDebts(shopId, callbacks.buildDebts());
    } catch (_) {
      _pendingDebts = true;
    }
  }

  Future<void> _pushTournaments() async {
    if (_paused || _disposed) return;
    _pendingTournaments = false;
    try {
      await FirebaseService.pushTournaments(
          shopId, callbacks.buildTournaments());
    } catch (_) {
      _pendingTournaments = true;
    }
  }

  static Future<void> saveLocal(
      String shopId, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_data_$shopId', jsonEncode(data));
    } catch (_) {}
  }

  static Future<DataMap?> loadLocal(String shopId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('app_data_$shopId');
      if (raw == null) return null;
      return Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }
}
