class PSDevice {
  int id;
  String displayName;
  String mode; // 'normal' or 'multi'
  String deviceType; // 'ps4' or 'ps5'
  String status; // 'متاح' or 'شغال'
  int? startTime; // unix timestamp seconds
  int addedSeconds;
  bool isPaused;
  int? pauseStartTime;
  Map<String, int> orders;
  String timerText;
  int? timerAlertMinutes; // تايمر تنبيه

  // ✅ حقول العد التنازلي الجديدة
  bool isCountdown;           // هل الجلسة بوقت محدد؟
  int? countdownTotalSeconds; // إجمالي الوقت المحدد بالثواني
  bool countdownAlertSent;    // هل تم إرسال إشعار انتهاء الوقت؟

  List<Map<String, dynamic>> sessionLog; // سجل الجلسة

  PSDevice({required this.id, this.deviceType = 'ps4'})
      : displayName = 'PS $id',
        mode = 'normal',
        status = 'متاح',
        startTime = null,
        addedSeconds = 0,
        isPaused = false,
        pauseStartTime = null,
        orders = {},
        timerText = '00:00:00',
        timerAlertMinutes = null,
        isCountdown = false,
        countdownTotalSeconds = null,
        countdownAlertSent = false,
        sessionLog = [];

  bool get isRunning => startTime != null && !isPaused;
  bool get isActive => startTime != null;

  int get elapsedSeconds {
    if (startTime == null) return 0;
    if (isPaused && pauseStartTime != null) {
      return (pauseStartTime! - startTime!) + addedSeconds;
    }
    return (DateTime.now().millisecondsSinceEpoch ~/ 1000 - startTime!) +
        addedSeconds;
  }

  /// ثواني متبقية في العد التنازلي (0 لو خلص)
  int get remainingSeconds {
    if (!isCountdown || countdownTotalSeconds == null) return 0;
    final remaining = countdownTotalSeconds! - elapsedSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  /// هل انتهى وقت العد التنازلي؟
  bool get countdownFinished =>
      isCountdown && countdownTotalSeconds != null && elapsedSeconds >= countdownTotalSeconds!;

  double calculateTimePrice(Map<String, int> prices) {
    if (startTime == null) return 0;
    final key = '${deviceType}_$mode';
    final rate = prices[key] ?? (deviceType == 'ps5' ? 35 : 25);
    return (elapsedSeconds / 3600) * rate;
  }

  double getBuffetPrice(Map<String, int> menu) {
    double total = 0;
    orders.forEach((item, qty) {
      total += qty * (menu[item] ?? 0);
    });
    return total;
  }

  void updateTimer() {
    if (isCountdown && countdownTotalSeconds != null) {
      // عد تنازلي
      final remaining = remainingSeconds;
      final h = remaining ~/ 3600;
      final m = (remaining % 3600) ~/ 60;
      final sec = remaining % 60;
      timerText =
          '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    } else {
      // عد تصاعدي عادي
      final s = elapsedSeconds;
      final h = s ~/ 3600;
      final m = (s % 3600) ~/ 60;
      final sec = s % 60;
      timerText =
          '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        'mode': mode,
        'device_type': deviceType,
        'status': status,
        'start_time': startTime,
        'added_seconds': addedSeconds,
        'is_paused': isPaused,
        'pause_start_time': pauseStartTime,
        'orders': orders,
        'timer_alert_minutes': timerAlertMinutes,
        'is_countdown': isCountdown,
        'countdown_total_seconds': countdownTotalSeconds,
        'countdown_alert_sent': countdownAlertSent,
        'session_log': sessionLog,
      };

  factory PSDevice.fromJson(Map<String, dynamic> j, int id) {
    final d = PSDevice(id: id, deviceType: j['device_type'] ?? 'ps4');
    d.displayName = j['display_name'] ?? 'PS $id';
    d.mode = j['mode'] ?? 'normal';
    d.status = j['status'] ?? 'متاح';
    d.startTime = j['start_time'];
    d.addedSeconds = j['added_seconds'] ?? 0;
    d.isPaused = j['is_paused'] ?? false;
    d.pauseStartTime = j['pause_start_time'];
    d.orders = Map<String, int>.from(j['orders'] ?? {});
    d.timerAlertMinutes = j['timer_alert_minutes'];
    d.isCountdown = j['is_countdown'] ?? false;
    d.countdownTotalSeconds = j['countdown_total_seconds'];
    d.countdownAlertSent = j['countdown_alert_sent'] ?? false;
    d.sessionLog = List<Map<String, dynamic>>.from(
      (j['session_log'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
    );
    return d;
  }
}
