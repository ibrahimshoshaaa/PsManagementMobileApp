// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin { 
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _error = false;
  String? _selectedCashierName; // الكاشير اللي اتاختار
  bool _showAdminLogin = false;  // إظهار تسجيل دخول الأدمن

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween(begin: 0.0, end: 24.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeCtrl);
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

 void _tryLogin() {
  final result = context.read<AppState>().login(
    _controller.text,
    targetRole: _showAdminLogin ? 'admin' : 'cashier',
    targetCashierName: _selectedCashierName,
  );

  if (result == null) {
    setState(() => _error = true);
    _shakeCtrl.forward(from: 0);
  }
}
  // لما المستخدم يضغط على بروفايل كاشير
  void _onCashierSelected(String name) {
    setState(() {
      _selectedCashierName = name;
      _showAdminLogin = false;
      _controller.clear();
      _error = false;
    });
  }

  // لما المستخدم يضغط على زرار الأدمن
  void _onAdminSelected() {
    setState(() {
      _selectedCashierName = null;
      _showAdminLogin = true;
      _controller.clear();
      _error = false;
    });
  }

  // رجوع لشاشة الاختيار
  void _goBack() {
    setState(() {
      _selectedCashierName = null;
      _showAdminLogin = false;
      _controller.clear();
      _error = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // لو اختار كاشير أو أدمن → اعرض شاشة الباسورد
    if (_selectedCashierName != null || _showAdminLogin) {
      return _PasswordScreen(
        name: _showAdminLogin ? 'الأدمن' : _selectedCashierName!,
        isAdmin: _showAdminLogin,
        controller: _controller,
        obscure: _obscure,
        error: _error,
        shakeAnim: _shakeAnim,
        shakeCtrl: _shakeCtrl,
        onToggleObscure: () => setState(() => _obscure = !_obscure),
        onChanged: () => setState(() => _error = false),
        onLogin: _tryLogin,
        onBack: _goBack,
      );
    }

    // شاشة اختيار الكاشير
    return _SelectionScreen(
      cashiers: state.cashiers,
      onCashierSelected: _onCashierSelected,
      onAdminSelected: _onAdminSelected,
      shopName: state.shopName,
    );
  }
}

// ─── شاشة اختيار الكاشير ──────────────────────────────────────────────────────

class _SelectionScreen extends StatelessWidget {
  final List<Map<String, dynamic>> cashiers;
  final void Function(String) onCashierSelected;
  final VoidCallback onAdminSelected;
  final String shopName;

  const _SelectionScreen({
    required this.cashiers,
    required this.onCashierSelected,
    required this.onAdminSelected,
    required this.shopName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ── أيقونة وعنوان ────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1c2128),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38bdf8).withOpacity(0.25),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(Icons.sports_esports,
                    size: 56, color: Color(0xFF38bdf8)),
              ),
              const SizedBox(height: 16),
              Text(
                shopName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF38bdf8),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'اختار حسابك للدخول',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 14),
              ),
              const SizedBox(height: 32),

  // ── الأدمن ───────────────────────────────────────────────────
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '👑 الإدارة',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1),
                ),
              ),
              const SizedBox(height: 10),
              _ProfileCard(
                name: 'الأدمن',
                index: -1,
                isAdmin: true,
                onTap: onAdminSelected,
                fullWidth: true,
              ),
              const SizedBox(height: 24),

              // ── الكاشيرين ────────────────────────────────────────────────
              if (cashiers.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '🧾 الكاشيرين',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1),
                  ),
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cashiers.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.1,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (ctx, i) {
                    final name =
                        cashiers[i]['name'] as String? ?? 'كاشير ${i + 1}';
                    return _ProfileCard(
                      name: name,
                      index: i,
                      isAdmin: false,
                      onTap: () => onCashierSelected(name),
                    );
                  },
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── كارت البروفايل ───────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final String name;
  final int index;
  final bool isAdmin;
  final VoidCallback onTap;
  final bool fullWidth;

  const _ProfileCard({
    required this.name,
    required this.index,
    required this.isAdmin,
    required this.onTap,
    this.fullWidth = false,
  });

  // ألوان الأفاتار بتتغير حسب الـ index
  Color get _avatarColor {
    if (isAdmin) return Colors.amber;
    const colors = [
      Color(0xFF38bdf8),
      Color(0xFF4ade80),
      Colors.purple,
      Colors.orange,
      Colors.pinkAccent,
      Colors.tealAccent,
    ];
    return colors[index % colors.length];
  }

  String get _initials {
    if (name.isEmpty) return 'K';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1c2128),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _avatarColor.withOpacity(0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _avatarColor.withOpacity(0.08),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: fullWidth
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Avatar(initials: _initials, color: _avatarColor, size: 44),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _avatarColor,
                        ),
                      ),
                      Text(
                        'دخول كأدمن',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios,
                      color: _avatarColor.withOpacity(0.5), size: 16),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Avatar(initials: _initials, color: _avatarColor, size: 52),
                  const SizedBox(height: 10),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _avatarColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'اضغط للدخول',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── أفاتار ───────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String initials;
  final Color color;
  final double size;

  const _Avatar(
      {required this.initials, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.38,
          ),
        ),
      ),
    );
  }
}

// ─── شاشة إدخال الباسورد ─────────────────────────────────────────────────────

class _PasswordScreen extends StatelessWidget {
  final String name;
  final bool isAdmin;
  final TextEditingController controller;
  final bool obscure;
  final bool error;
  final Animation<double> shakeAnim;
  final AnimationController shakeCtrl;
  final VoidCallback onToggleObscure;
  final VoidCallback onChanged;
  final VoidCallback onLogin;
  final VoidCallback onBack;

  const _PasswordScreen({
    required this.name,
    required this.isAdmin,
    required this.controller,
    required this.obscure,
    required this.error,
    required this.shakeAnim,
    required this.shakeCtrl,
    required this.onToggleObscure,
    required this.onChanged,
    required this.onLogin,
    required this.onBack,
  });

  Color get _color => isAdmin ? Colors.amber : const Color(0xFF38bdf8);

  String get _initials {
    if (name.isEmpty) return 'K';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // ── زرار الرجوع ──────────────────────────────────────────────
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: onBack,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_ios,
                            color: Colors.white54, size: 14),
                        SizedBox(width: 4),
                        Text('رجوع',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── أفاتار الكاشير ──────────────────────────────────────────
              _Avatar(initials: _initials, color: _color, size: 80),
              const SizedBox(height: 16),

              Text(
                name,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isAdmin ? 'دخول كأدمن' : 'أدخل كلمة السر',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),

              const SizedBox(height: 36),

              // ── حقل الباسورد ─────────────────────────────────────────────
              AnimatedBuilder(
                animation: shakeAnim,
                builder: (ctx, child) => Transform.translate(
                  offset: Offset(
                    shakeCtrl.isAnimating
                        ? (shakeCtrl.value < 0.5
                            ? -shakeAnim.value
                            : shakeAnim.value)
                        : 0,
                    0,
                  ),
                  child: child,
                ),
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  style: const TextStyle(fontSize: 20, letterSpacing: 4),
                  decoration: InputDecoration(
                    hintText: '••••••',
                    hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: const Color(0xFF1c2128),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: _color),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                          color: error
                              ? Colors.red
                              : Colors.white.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: _color, width: 2),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscure
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.white54),
                      onPressed: onToggleObscure,
                    ),
                    errorText: error ? 'كلمة السر غلط!' : null,
                  ),
                  onSubmitted: (_) => onLogin(),
                  onChanged: (_) => onChanged(),
                ),
              ),

              const SizedBox(height: 24),

              // ── زرار الدخول ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: onLogin,
                  icon: const Icon(Icons.login),
                  label: const Text('دخول',
                      style: TextStyle(fontSize: 18)),
                  style: FilledButton.styleFrom(
                    backgroundColor: _color,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
