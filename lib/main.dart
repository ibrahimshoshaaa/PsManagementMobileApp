import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/app_state.dart';
import 'services/notification_service.dart';
import 'screens/activation_screen.dart';
import 'screens/home_screen.dart';
import 'screens/cashier_screen.dart';
import 'screens/customer_orders_screen.dart';
import 'screens/login_screen.dart';
import 'screens/shift_screen.dart';
import 'screens/splash_screen.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const PSApp(),
    ),
  );
}

class PSApp extends StatelessWidget {
  const PSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PS Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0b0e14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38bdf8),
          secondary: Color(0xFF4ade80),
          surface: Color(0xFF1c2128),
        ),
        cardColor: const Color(0xFF1c2128),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF38bdf8),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),

    builder: (context, child) {
  return Directionality(
    textDirection: TextDirection.rtl,
    child: child!,
  );
},
      
     home: const SplashScreen(nextScreen: AuthWrapper()),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {

  @override
  void initState() {
    super.initState();
    // سجّل الـ callback لما المستخدم يضغط على إشعار
    NotificationService.onNotificationTap = _handleNotificationTap;
  }

  void _handleNotificationTap(String payload) {
    if (!mounted) return;
    final state = context.read<AppState>();

    // بس لو التطبيق مفعّل والمستخدم logged in
    if (!state.isActivated) return;

    if (payload == 'orders') {
      final shopId = state.shopId ?? '';
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerOrdersScreen(shopId: shopId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (!state.isActivated) return const ActivationScreen();

    // Admin never needs a shift.
    if (state.isAdmin) return const HomeScreen();

    if (state.isCashier) {
      // ── Session persistence: if THIS cashier's shift is already open
      // in Firebase (restored on cold start), skip straight to the dashboard.
      if (state.hasOpenShift || state.isEndingShift) return const CashierScreen();
      // ── Shift lock: a different cashier is active on another device.
      if (state.isShiftLockedByOther) {
        return _ShiftLockedScreen(
          activeCashier: state.activeShiftByCashier!,
          onLogout: () => context.read<AppState>().logout(),
        );
      }

      // No shift open at all — show the start-shift screen.
      return ShiftStartScreen(
        cashierName: state.currentCashierName ?? 'كاشير',
        onShiftStarted: () {},
      );
    }

    return const LoginScreen();
  }
}

// ── Shift locked screen ───────────────────────────────────────────────────────
class _ShiftLockedScreen extends StatelessWidget {
  final String activeCashier;
  final VoidCallback onLogout;

  const _ShiftLockedScreen({
    required this.activeCashier,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1c2128),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.25),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.lock_clock,
                    size: 64, color: Colors.orange),
              ),
              const SizedBox(height: 28),
              const Text(
                'الشيفت مقفول',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1c2128),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(children: [
                  const Icon(Icons.person,
                      color: Colors.orange, size: 20),
                  const SizedBox(height: 8),
                  Text(
                    '"$activeCashier" شغال دلوقتي',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'لازم ينهي شيفته الأول عشان تقدر تبدأ',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ]),
              ),
              const SizedBox(height: 32),
              // Live refresh — the SSE will auto-navigate when the
              // lock clears, but give the user a manual escape too.
              const Text(
                'هيتحدث تلقائي لما الشيفت ينتهي',
                style:
                    TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: onLogout,
                child: const Text('رجوع لشاشة الدخول',
                    style: TextStyle(color: Colors.white38)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

