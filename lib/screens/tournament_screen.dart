import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';


// ═══════════════════════════════════════════════════════════════════════════════
// TOURNAMENT SCREEN — شاشة البطولات الرئيسية
// ═══════════════════════════════════════════════════════════════════════════════

class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key});
  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

// بعد
class _TournamentScreenState extends State<TournamentScreen> {

  @override
  void initState() {
    super.initState();
    context.read<AppState>().fetchTournamentsOnDemand();
  }

    void _deleteTournament(int index) {
      context.read<AppState>().deleteTournament(index);
    }
  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AppState>().isAdmin;
    final isLoading = context.watch<AppState>().isLoadingTournaments;
    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: const Row(children: [
          Text('🏆', style: TextStyle(fontSize: 20)),
          SizedBox(width: 8),
          Text('البطولات',
              style: TextStyle(color: Color(0xFFfbbf24), fontWeight: FontWeight.bold)),
        ]),
        leading: const BackButton(color: Colors.white),
        
actions: [
  if (isAdmin)
    IconButton(
      icon: const Icon(Icons.add_circle, color: Color(0xFFfbbf24), size: 28),
      tooltip: 'بطولة جديدة',
      onPressed: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const CreateTournamentScreen())),
    ),
],
      ),
      body: Builder(builder: (context) {
  final tournaments = context.watch<AppState>().tournaments;
        if (isLoading && tournaments.isEmpty)
  return const Center(child: CircularProgressIndicator(color: Color(0xFFfbbf24)));
  if (tournaments.isEmpty) {
    return _EmptyTournaments(
      isAdmin: isAdmin,
      onCreateTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const CreateTournamentScreen())),
    );
  }
  return ListView.builder(
    padding: const EdgeInsets.all(12),
    itemCount: tournaments.length,
    itemBuilder: (ctx, i) {
      final t = tournaments[i];
      return _TournamentCard(
        tournament: t,
        isAdmin: isAdmin,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => TournamentDetailScreen(
                    tournamentIndex: i,
                    tournament: t))),
        onDelete: isAdmin
            ? () => _confirmDelete(context, i, t['name'] ?? '')
            : null,
      );
    },
  );
}),
    );
  }

void _confirmDelete(BuildContext context, int index, String name) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1c2128),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('حذف البطولة؟', style: TextStyle(color: Colors.red)),
      content: Text('هيتم حذف بطولة "$name" نهائياً',
          style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
        FilledButton(
          onPressed: () { Navigator.pop(context); _deleteTournament(index); },
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('حذف'),
        ),
      ],
    ),
  );
}
}

// ═══════════════════════════════════════════════════════════════════════════════
// CREATE TOURNAMENT SCREEN — إنشاء بطولة جديدة
// ═══════════════════════════════════════════════════════════════════════════════

class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key});
  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _nameCtrl = TextEditingController();
  final _gameCtrl = TextEditingController();
  final _feeCtrl  = TextEditingController();
  final _maxCtrl  = TextEditingController(text: '8');
  bool _hasFee   = false;
  bool _saving   = false;

 

  @override
  void dispose() {
    _nameCtrl.dispose(); _gameCtrl.dispose();
    _feeCtrl.dispose(); _maxCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final game = _gameCtrl.text.trim();
    final maxP = int.tryParse(_maxCtrl.text.trim()) ?? 8;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('⚠️ اكتب اسم البطولة'), backgroundColor: Colors.orange));
      return;
    }
    if (maxP < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('⚠️ لازم يكون في 2 لاعبين على الأقل'),
          backgroundColor: Colors.orange));
      return;
    }
    setState(() => _saving = true);
  

    final fee = _hasFee ? (double.tryParse(_feeCtrl.text.trim()) ?? 0) : 0.0;
    final tournament = {
      'name': name,
      'game': game.isEmpty ? 'FIFA' : game,
      'max_players': maxP,
      'entry_fee': fee,
      'has_fee': _hasFee,
      'status': 'registration', // registration | ongoing | finished
      'players': <String, dynamic>{},
      'matches': <String, dynamic>{},
      'created_at': DateTime.now().toString(),
      'winner': null,
};
    
  context.read<AppState>().addTournament(tournament);
setState(() => _saving = false);
if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: const Text('بطولة جديدة 🏆',
            style: TextStyle(color: Color(0xFFfbbf24), fontWeight: FontWeight.bold)),
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ─── اسم البطولة ───────────────────────────────────────────────
          _SectionHeader('📋 معلومات البطولة'),
          const SizedBox(height: 8),
          _inputField(_nameCtrl, 'اسم البطولة (مثال: كأس رمضان)', Icons.emoji_events),
          const SizedBox(height: 10),
          _inputField(_gameCtrl, 'اللعبة (مثال: FIFA 25)', Icons.sports_esports),
          const SizedBox(height: 20),

          // ─── عدد اللاعبين ──────────────────────────────────────────────
          _SectionHeader('👥 إعدادات اللاعبين'),
          const SizedBox(height: 8),
          _inputField(_maxCtrl, 'الحد الأقصى للاعبين', Icons.people,
              type: TextInputType.number),
          const SizedBox(height: 4),
          const Text('  * الجدول بيتولد تلقائي حسب العدد',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 20),

          // ─── رسوم الاشتراك ─────────────────────────────────────────────
          _SectionHeader('💰 رسوم الاشتراك'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1c2128),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.payments_outlined, color: Color(0xFF4ade80), size: 20),
                const SizedBox(width: 10),
                const Expanded(child: Text('بطولة مدفوعة؟',
                    style: TextStyle(fontWeight: FontWeight.bold))),
                Switch(
                  value: _hasFee,
                  onChanged: (v) => setState(() => _hasFee = v),
                  activeColor: const Color(0xFF4ade80),
                ),
              ]),
              if (_hasFee) ...[
                const SizedBox(height: 10),
                _inputField(_feeCtrl, 'رسوم الاشتراك (ج)', Icons.attach_money,
                    type: TextInputType.number),
              ],
            ]),
          ),
          const SizedBox(height: 32),

          // ─── زرار حفظ ──────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.rocket_launch),
              label: Text(_saving ? 'جاري الإنشاء...' : 'إنشاء البطولة',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFfbbf24),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: const Color(0xFFfbbf24), size: 20),
        filled: true,
        fillColor: const Color(0xFF1c2128),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFfbbf24), width: 2)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOURNAMENT DETAIL SCREEN — تفاصيل البطولة
// ═══════════════════════════════════════════════════════════════════════════════

class TournamentDetailScreen extends StatefulWidget {
  final int tournamentIndex;
  final Map<String, dynamic> tournament;
  const TournamentDetailScreen({
    super.key, required this.tournamentIndex, required this.tournament});
  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}
class _TournamentDetailScreenState extends State<TournamentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic> _data = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _data = Map<String, dynamic>.from(widget.tournament);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
  setState(() => _loading = true);
  final tournaments = context.read<AppState>().tournaments;
  if (widget.tournamentIndex < tournaments.length) {
    _data = Map<String, dynamic>.from(tournaments[widget.tournamentIndex]);
  }
  setState(() => _loading = false);
}

  Map<String, dynamic> get _players =>
      Map<String, dynamic>.from(_data['players'] ?? {});
  Map<String, dynamic> get _matches =>
      Map<String, dynamic>.from(_data['matches'] ?? {});
  String get _status => _data['status']?.toString() ?? 'registration';
  int get _maxPlayers => (_data['max_players'] as num?)?.toInt() ?? 8;
  bool get _hasFee => _data['has_fee'] == true;
  double get _entryFee => (_data['entry_fee'] as num?)?.toDouble() ?? 0;
 

  // ─── إضافة لاعب ──────────────────────────────────────────────────────────
  void _showAddPlayerDialog() {
    final nameCtrl = TextEditingController();
    final teamCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1c2128),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.person_add, color: Color(0xFF4ade80)),
            SizedBox(width: 8),
            Text('إضافة لاعب', style: TextStyle(color: Color(0xFF4ade80), fontWeight: FontWeight.bold)),
          ]),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_hasFee)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.payments, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Text('رسوم الاشتراك: ${_entryFee.toStringAsFixed(0)} ج',
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                ]),
              ),
            if (_hasFee) const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'اسم اللاعب',
                labelStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.person, color: Color(0xFF4ade80)),
                filled: true, fillColor: const Color(0xFF0b0e14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4ade80), width: 2)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: teamCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'الفريق',
                labelStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.sports_soccer, color: Color(0xFF38bdf8)),
                filled: true, fillColor: const Color(0xFF0b0e14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF38bdf8), width: 2)),
              ),
            ),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final team = teamCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('⚠️ اكتب اسم اللاعب'),
                      backgroundColor: Colors.orange));
                  return;
                }
                if (team.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('⚠️ اكتب اسم الفريق'),
                      backgroundColor: Colors.orange));
                  return;
                }
                if (_players.length >= _maxPlayers) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('⚠️ الحد الأقصى للاعبين وصل!'),
                      backgroundColor: Colors.orange));
                  return;
                }
                final playerId = 'p_${DateTime.now().millisecondsSinceEpoch}';
                final newPlayers = Map<String, dynamic>.from(_players);
                newPlayers[playerId] = {
                  'name': name,
                  'team': team,
                  'joined_at': DateTime.now().toString(),
                  'fee_paid': !_hasFee,
                  'wins': 0,
                  'losses': 0,
                  'eliminated': false,
                };
                _data['players'] = newPlayers;
                context.read<AppState>().updateTournament(widget.tournamentIndex, _data);
                Navigator.pop(ctx);
                _load();
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4ade80),
                  foregroundColor: Colors.black),
              child: const Text('إضافة'),
            ),
          ],
        ),
    );
  }
  // ─── تأكيد دفع رسوم ──────────────────────────────────────────────────────
 void _toggleFeePaid(String playerId, bool current) {
  final newPlayers = Map<String, dynamic>.from(_players);
  (newPlayers[playerId] as Map)['fee_paid'] = !current;
  _data['players'] = newPlayers;
  context.read<AppState>().updateTournament(widget.tournamentIndex, _data);
  setState(() {});
}

  // ─── حذف لاعب ────────────────────────────────────────────────────────────
  void _removePlayer(String playerId) {
  final newPlayers = Map<String, dynamic>.from(_players);
  newPlayers.remove(playerId);
  _data['players'] = newPlayers;
  context.read<AppState>().updateTournament(widget.tournamentIndex, _data);
  setState(() {});
}

  // ─── توليد جدول المباريات (كأس) ─────────────────────────────────────────
  Future<void> _generateBracket() async {
    final players = Map<String, dynamic>.from(_players);
    if (players.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('⚠️ لازم في 2 لاعبين على الأقل'),
          backgroundColor: Colors.orange));
      return;
    }

    final playerIds = players.keys.toList()..shuffle(Random());
    final matches = <String, dynamic>{};
    int matchNum = 1;

    // أول دور: كل لاعبين بجوار بعض
    for (int i = 0; i + 1 < playerIds.length; i += 2) {
      final id = 'm_${matchNum++}';
      matches[id] = {
        'player1_id': playerIds[i],
        'player2_id': playerIds[i + 1],
        'player1_name': (players[playerIds[i]] as Map)['name'],
        'player2_name': (players[playerIds[i + 1]] as Map)['name'],
        'player1_team': (players[playerIds[i]] as Map)['team'],
        'player2_team': (players[playerIds[i + 1]] as Map)['team'],
        'round': 1,
        'status': 'pending', // pending | ongoing | finished
        'winner_id': null,
        'winner_name': null,
        'score1': null,
        'score2': null,
      };
    }

    // لو عدد اللاعبين فردي → Bye للأخير
    if (playerIds.length % 2 != 0) {
      final lastId = playerIds.last;
      final id = 'm_bye_${matchNum++}';
      matches[id] = {
        'player1_id': lastId,
        'player2_id': null,
        'player1_name': (players[lastId] as Map)['name'],
        'player2_name': 'BYE',
        'player1_team': (players[lastId] as Map)['team'],
        'player2_team': null,
        'round': 1,
        'status': 'finished',
        'winner_id': lastId,
        'winner_name': (players[lastId] as Map)['name'],
        'score1': 0,
        'score2': null,
        'is_bye': true,
      };
    }

    _data['matches'] = matches;
_data['status'] = 'ongoing';
context.read<AppState>().updateTournament(widget.tournamentIndex, _data);
setState(() {});
_tabs.animateTo(1);
  }

  // ─── تسجيل نتيجة مباراة ──────────────────────────────────────────────────
  void _showResultDialog(String matchId, Map<String, dynamic> match) {
    final s1Ctrl = TextEditingController();
    final s2Ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.sports_score, color: Color(0xFFfbbf24)),
          SizedBox(width: 8),
          Text('تسجيل النتيجة', style: TextStyle(color: Color(0xFFfbbf24), fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: Column(children: [
              Text(match['player1_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
              Text(match['player1_team'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center),
            ])),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('VS', style: TextStyle(color: Color(0xFFfbbf24), fontWeight: FontWeight.bold))),
            Expanded(child: Column(children: [
              Text(match['player2_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
              Text(match['player2_team'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center),
            ])),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(
              controller: s1Ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofocus: true,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              decoration: _scoreDeco(),
            )),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('—', style: TextStyle(color: Colors.white54, fontSize: 24))),
            Expanded(child: TextField(
              controller: s2Ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              decoration: _scoreDeco(),
            )),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () async {
              final s1 = int.tryParse(s1Ctrl.text.trim());
              final s2 = int.tryParse(s2Ctrl.text.trim());
              if (s1 == null || s2 == null) return;
              if (s1 == s2) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('⚠️ في الكأس لازم يكون في فايز! ماينفعش تعادل'),
                    backgroundColor: Colors.orange));
                return;
              }
              Navigator.pop(context);
              await _saveMatchResult(matchId, match, s1, s2);
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFfbbf24),
                foregroundColor: Colors.black),
            child: const Text('حفظ النتيجة'),
          ),
        ],
      ),
    );
  }

  InputDecoration _scoreDeco() => InputDecoration(
    filled: true, fillColor: const Color(0xFF0b0e14),
    hintText: '0', hintStyle: const TextStyle(color: Colors.white24, fontSize: 24),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFfbbf24), width: 2)),
  );

  Future<void> _saveMatchResult(String matchId, Map<String, dynamic> match,
      int s1, int s2) async {
    final winnerId   = s1 > s2 ? match['player1_id'] : match['player2_id'];
    final winnerName = s1 > s2 ? match['player1_name'] : match['player2_name'];
    final loserId    = s1 > s2 ? match['player2_id'] : match['player1_id'];

    // ─── تحديث المباراة ────────────────────────────────────────────────
    final allMatches = Map<String, dynamic>.from(_matches);
    final updatedMatch = Map<String, dynamic>.from(allMatches[matchId] as Map);
    updatedMatch['score1']      = s1;
    updatedMatch['score2']      = s2;
    updatedMatch['winner_id']   = winnerId;
    updatedMatch['winner_name'] = winnerName;
    updatedMatch['status']      = 'finished';
    allMatches[matchId]         = updatedMatch;

    // ─── تحديث اللاعبين ────────────────────────────────────────────────
    final allPlayers = Map<String, dynamic>.from(_players);
    if (winnerId != null && allPlayers.containsKey(winnerId)) {
      final wp = Map<String, dynamic>.from(allPlayers[winnerId] as Map);
      wp['wins'] = (wp['wins'] as int? ?? 0) + 1;
      allPlayers[winnerId] = wp;
    }
    if (loserId != null && allPlayers.containsKey(loserId)) {
      final lp = Map<String, dynamic>.from(allPlayers[loserId] as Map);
      lp['losses']     = (lp['losses'] as int? ?? 0) + 1;
      lp['eliminated'] = true;
      allPlayers[loserId] = lp;
    }

    // ─── ولّد الدور القادم تلقائي؟ ───────────────────────────────────
    final currentRound   = (match['round'] as int? ?? 1);
    final roundMatches   = allMatches.values
        .where((m) => (m as Map)['round'] == currentRound)
        .toList();
    final allFinished    = roundMatches.every((m) => (m as Map)['status'] == 'finished');

    if (allFinished) {
      final winners = roundMatches
          .where((m) => (m as Map)['is_bye'] != true)
          .map((m) => (m as Map)['winner_id']?.toString())
          .where((id) => id != null)
          .toList();

      // بايات من الراوند القديم
      final byeWinners = roundMatches
          .where((m) => (m as Map)['is_bye'] == true)
          .map((m) => (m as Map)['winner_id']?.toString())
          .where((id) => id != null)
          .toList();

      final allWinners = [...winners, ...byeWinners];

      if (allWinners.length == 1) {
        // الفايز النهائي!
        _data['status'] = 'finished';
_data['winner'] = {
  'id': allWinners.first,
  'name': (allPlayers[allWinners.first] as Map?)?['name'] ?? '',
  'team': (allPlayers[allWinners.first] as Map?)?['team'] ?? '',
};
_data['matches'] = allMatches;
_data['players'] = allPlayers;
context.read<AppState>().updateTournament(widget.tournamentIndex, _data);
setState(() {});
if (mounted) _showWinnerDialog(allPlayers[allWinners.first] as Map);
return;
      }

      if (allWinners.length > 1) {
        // ولّد مباريات الدور القادم
        final nextRound = currentRound + 1;
        int matchNum    = allMatches.length + 1;
        final shuffled  = List<String?>.from(allWinners)..shuffle(Random());

        for (int i = 0; i + 1 < shuffled.length; i += 2) {
          final id = 'm_r${nextRound}_${matchNum++}';
          final p1 = allPlayers[shuffled[i]!] as Map;
          final p2 = allPlayers[shuffled[i + 1]!] as Map;
          allMatches[id] = {
            'player1_id': shuffled[i],
            'player2_id': shuffled[i + 1],
            'player1_name': p1['name'],
            'player2_name': p2['name'],
            'player1_team': p1['team'],
            'player2_team': p2['team'],
            'round': nextRound,
            'status': 'pending',
            'winner_id': null,
            'winner_name': null,
            'score1': null,
            'score2': null,
          };
        }
        if (shuffled.length % 2 != 0) {
          final byeId = shuffled.last!;
          final id    = 'm_bye_r${nextRound}_${matchNum++}';
          final bp    = allPlayers[byeId] as Map;
          allMatches[id] = {
            'player1_id': byeId, 'player2_id': null,
            'player1_name': bp['name'], 'player2_name': 'BYE',
            'player1_team': bp['team'], 'player2_team': null,
            'round': nextRound, 'status': 'finished',
            'winner_id': byeId, 'winner_name': bp['name'],
            'score1': 0, 'score2': null, 'is_bye': true,
          };
        }
      }
    }

    _data['matches'] = allMatches;
_data['players'] = allPlayers;
context.read<AppState>().updateTournament(widget.tournamentIndex, _data);
setState(() {});
  }

  void _showWinnerDialog(Map winner) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('🎉 انتهت البطولة!',
            style: TextStyle(color: Color(0xFFfbbf24), fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🏆', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 8),
          Text(winner['name']?.toString() ?? '',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(winner['team']?.toString() ?? '',
              style: const TextStyle(color: Color(0xFFfbbf24), fontSize: 15),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('مبروك الفوز! 🎊',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center),
        ]),
        actions: [
          Center(child: FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFfbbf24), foregroundColor: Colors.black),
            child: const Text('تمام 🎉', style: TextStyle(fontWeight: FontWeight.bold)),
          )),
        ],
      ),
    );
  }

  // ─── حساب الدور الحالي ───────────────────────────────────────────────────
  int get _currentRound {
    if (_matches.isEmpty) return 0;
    return _matches.values
        .map((m) => (m as Map)['round'] as int? ?? 1)
        .fold(0, (a, b) => a > b ? a : b);
  }

  List<Map<String, dynamic>> _matchesForRound(int round) =>
      _matches.entries
          .where((e) => (e.value as Map)['round'] == round)
          .map((e) {
            final m = Map<String, dynamic>.from(e.value as Map);
            m['_key'] = e.key;
            return m;
          })
          .toList()
        ..sort((a, b) => a['_key'].compareTo(b['_key']));

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AppState>().isAdmin;
    final winner  = _data['winner'] as Map?;
    final totalRevenue = _hasFee
        ? _players.values.where((p) => (p as Map)['fee_paid'] == true).length * _entryFee
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: Text(_data['name']?.toString() ?? 'البطولة',
            style: const TextStyle(color: Color(0xFFfbbf24), fontWeight: FontWeight.bold)),
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white54), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFFfbbf24),
          labelColor: const Color(0xFFfbbf24),
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.people, size: 18), text: 'اللاعبون'),
            Tab(icon: Icon(Icons.sports, size: 18), text: 'المباريات'),
            Tab(icon: Icon(Icons.leaderboard, size: 18), text: 'الترتيب'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFfbbf24)))
          : Column(children: [
              // ─── شريط الحالة ───────────────────────────────────────────────
              _StatusBanner(status: _status, winner: winner,
                  playersCount: _players.length, maxPlayers: _maxPlayers,
                  hasFee: _hasFee, totalRevenue: totalRevenue),

              // ─── أزرار الأدمن ───────────────────────────────────────────────
              if (isAdmin) _AdminActions(
                status: _status,
                playersCount: _players.length,
                onAddPlayer: _status == 'registration' ? _showAddPlayerDialog : null,
                onGenerateBracket: _status == 'registration' && _players.length >= 2
                    ? _generateBracket : null,
              ),

              Expanded(
                child: TabBarView(controller: _tabs, children: [
                  // ─── تاب اللاعبون ─────────────────────────────────────────
                  _PlayersTab(
                    players: _players, hasFee: _hasFee,
                    isAdmin: isAdmin && _status == 'registration',
                    onToggleFee: _toggleFeePaid,
                    onRemove: _removePlayer,
                  ),
                  // ─── تاب المباريات ────────────────────────────────────────
                  _BracketTab(
                    matches: _matches, currentRound: _currentRound,
                    isAdmin: isAdmin && _status == 'ongoing',
                    onResult: _showResultDialog,
                    matchesForRound: _matchesForRound,
                  ),
                  // ─── تاب الترتيب ──────────────────────────────────────────
                  _StandingsTab(players: _players, status: _status),
                ]),
              ),
            ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUB WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _StatusBanner extends StatelessWidget {
  final String status;
  final Map? winner;
  final int playersCount, maxPlayers;
  final bool hasFee;
  final double totalRevenue;
  const _StatusBanner({required this.status, required this.winner,
    required this.playersCount, required this.maxPlayers,
    required this.hasFee, required this.totalRevenue});

  @override
  Widget build(BuildContext context) {
    Color col; String label; IconData icon;
    switch (status) {
      case 'ongoing':   col = Colors.blue;   label = '🔴 جارية'; icon = Icons.play_circle; break;
      case 'finished':  col = const Color(0xFF4ade80); label = '✅ منتهية'; icon = Icons.check_circle; break;
      default:          col = Colors.orange; label = '📝 تسجيل'; icon = Icons.how_to_reg;
    }
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.withOpacity(0.4)),
      ),
      child: Column(children: [
        if (winner != null) ...[
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🏆', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('الفائز', style: TextStyle(color: Colors.white54, fontSize: 11)),
              Text(winner!['name']?.toString() ?? '',
                  style: const TextStyle(color: Color(0xFFfbbf24),
                      fontWeight: FontWeight.bold, fontSize: 16)),
              Text(winner!['team']?.toString() ?? '',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
          ]),
          const SizedBox(height: 10),
        ],
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _StatChip(icon, label, col),
          Container(width: 1, height: 30, color: Colors.white12),
          _StatChip(Icons.people, '$playersCount / $maxPlayers لاعب', Colors.white70),
          if (hasFee) ...[
            Container(width: 1, height: 30, color: Colors.white12),
            _StatChip(Icons.payments, '${totalRevenue.toStringAsFixed(0)} ج', const Color(0xFF4ade80)),
          ],
        ]),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _StatChip(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: color, size: 15),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
  ]);
}

class _AdminActions extends StatelessWidget {
  final String status;
  final int playersCount;
  final VoidCallback? onAddPlayer, onGenerateBracket;
  const _AdminActions({required this.status, required this.playersCount,
    this.onAddPlayer, this.onGenerateBracket});
  @override
  Widget build(BuildContext context) {
    if (status == 'finished') return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        if (status == 'registration') ...[
          Expanded(child: SizedBox(height: 38,
            child: OutlinedButton.icon(
              onPressed: onAddPlayer,
              icon: const Icon(Icons.person_add, size: 16, color: Color(0xFF4ade80)),
              label: const Text('إضافة لاعب', style: TextStyle(color: Color(0xFF4ade80), fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF4ade80)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          )),
          const SizedBox(width: 8),
          Expanded(child: SizedBox(height: 38,
            child: FilledButton.icon(
              onPressed: onGenerateBracket,
              icon: const Icon(Icons.account_tree, size: 16),
              label: const Text('ابدأ البطولة', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                backgroundColor: onGenerateBracket != null
                    ? const Color(0xFFfbbf24) : Colors.white24,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          )),
        ],
      ]),
    );
  }
}

class _PlayersTab extends StatelessWidget {
  final Map<String, dynamic> players;
  final bool hasFee, isAdmin;
  final void Function(String, bool) onToggleFee;
  final void Function(String) onRemove;
  const _PlayersTab({required this.players, required this.hasFee,
    required this.isAdmin, required this.onToggleFee, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.people_outline, size: 64, color: Colors.white12),
        SizedBox(height: 12),
        Text('لا يوجد لاعبون بعد', style: TextStyle(color: Colors.white54, fontSize: 16)),
        SizedBox(height: 4),
        Text('اضغط "إضافة لاعب" لتسجيل المشاركين',
            style: TextStyle(color: Colors.white24, fontSize: 12)),
      ]),
    );
    final entries = players.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: entries.length,
      itemBuilder: (ctx, i) {
        final id = entries[i].key;
        final p  = Map<String, dynamic>.from(entries[i].value as Map);
        final eliminated = p['eliminated'] == true;
        final feePaid    = p['fee_paid'] == true;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1c2128),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: eliminated ? Colors.red.withOpacity(0.3)
                  : const Color(0xFF4ade80).withOpacity(0.3),
              width: eliminated ? 1 : 1.5,
            ),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: eliminated
                    ? Colors.red.withOpacity(0.15)
                    : const Color(0xFF4ade80).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text('${i + 1}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: eliminated ? Colors.red : const Color(0xFF4ade80)))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(p['name']?.toString() ?? '',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14,
                        decoration: eliminated ? TextDecoration.lineThrough : null,
                        color: eliminated ? Colors.white38 : Colors.white)),
                if (eliminated) ...[
                  const SizedBox(width: 6),
                  const Text('❌', style: TextStyle(fontSize: 11)),
                ],
              ]),
              Text('🎮 ${p['team']?.toString() ?? ''}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ])),
            // إحصائيات
            Column(children: [
              Text('${p['wins'] ?? 0}W / ${p['losses'] ?? 0}L',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
              if (hasFee) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: isAdmin ? () => onToggleFee(id, feePaid) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: feePaid
                          ? const Color(0xFF4ade80).withOpacity(0.15)
                          : Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: feePaid
                              ? const Color(0xFF4ade80).withOpacity(0.5)
                              : Colors.red.withOpacity(0.5)),
                    ),
                    child: Text(feePaid ? '✅ دفع' : '⏳ لم يدفع',
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold,
                            color: feePaid ? const Color(0xFF4ade80) : Colors.red)),
                  ),
                ),
              ],
            ]),
            if (isAdmin) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => onRemove(id),
                child: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
              ),
            ],
          ]),
        );
      },
    );
  }
}

class _BracketTab extends StatelessWidget {
  final Map<String, dynamic> matches;
  final int currentRound;
  final bool isAdmin;
  final void Function(String, Map<String, dynamic>) onResult;
  final List<Map<String, dynamic>> Function(int) matchesForRound;
  const _BracketTab({required this.matches, required this.currentRound,
    required this.isAdmin, required this.onResult, required this.matchesForRound});

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) return const Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.account_tree_outlined, size: 64, color: Colors.white12),
        SizedBox(height: 12),
        Text('لم يبدأ الجدول بعد', style: TextStyle(color: Colors.white54, fontSize: 16)),
        SizedBox(height: 4),
        Text('اضغط "ابدأ البطولة" لتوليد المباريات',
            style: TextStyle(color: Colors.white24, fontSize: 12)),
      ]),
    );

    return ListView(
      padding: const EdgeInsets.all(12),
      children: List.generate(currentRound, (ri) {
        final round   = ri + 1;
        final rMatches = matchesForRound(round);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFfbbf24).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFfbbf24).withOpacity(0.5)),
                ),
                child: Text(_roundLabel(round, currentRound, rMatches.length),
                    style: const TextStyle(color: Color(0xFFfbbf24),
                        fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ]),
          ),
          ...rMatches.map((m) => _MatchCard(
            match: m, isAdmin: isAdmin,
            onResult: () => onResult(m['_key'], m),
          )),
        ]);
      }),
    );
  }

  String _roundLabel(int round, int total, int matchCount) {
    if (matchCount == 1 && round == total) return '🏆 النهائي';
    if (matchCount == 2 && round == total) return '🥈 نصف النهائي';
    if (matchCount == 4 && round == total) return '🥉 ربع النهائي';
    return 'الدور ${_arabicNum(round)}';
  }

  String _arabicNum(int n) {
    const nums = ['الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس'];
    return n <= nums.length ? nums[n - 1] : '$n';
  }
}

class _MatchCard extends StatelessWidget {
  final Map<String, dynamic> match;
  final bool isAdmin;
  final VoidCallback onResult;
  const _MatchCard({required this.match, required this.isAdmin, required this.onResult});

  @override
  Widget build(BuildContext context) {
    final status    = match['status']?.toString() ?? 'pending';
    final finished  = status == 'finished';
    final isBye     = match['is_bye'] == true;
    final winnerId  = match['winner_id']?.toString();
    final p1Id      = match['player1_id']?.toString();

    Color borderCol = finished
        ? const Color(0xFF4ade80).withOpacity(0.3) : Colors.white12;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          // ─── لاعب 1 ────────────────────────────────────────────────
          _PlayerRow(
            name: match['player1_name']?.toString() ?? '',
            team: match['player1_team']?.toString() ?? '',
            score: match['score1'],
            isWinner: finished && winnerId == p1Id,
            isLoser: finished && winnerId != p1Id && !isBye,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              const Expanded(child: Divider(color: Colors.white12)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(isBye ? 'BYE' : 'VS',
                    style: TextStyle(
                        color: finished ? const Color(0xFF4ade80) : Colors.white38,
                        fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const Expanded(child: Divider(color: Colors.white12)),
            ]),
          ),
          // ─── لاعب 2 ────────────────────────────────────────────────
          if (!isBye) _PlayerRow(
            name: match['player2_name']?.toString() ?? '',
            team: match['player2_team']?.toString() ?? '',
            score: match['score2'],
            isWinner: finished && winnerId == match['player2_id']?.toString(),
            isLoser: finished && winnerId != match['player2_id']?.toString(),
          ),
          // ─── زرار تسجيل النتيجة ────────────────────────────────────
          if (isAdmin && !finished && !isBye) ...[
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: 34,
              child: FilledButton.icon(
                onPressed: onResult,
                icon: const Icon(Icons.sports_score, size: 15),
                label: const Text('تسجيل النتيجة', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFfbbf24),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
            ),
          ],
          if (finished && !isBye)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.check_circle, color: Color(0xFF4ade80), size: 14),
                const SizedBox(width: 4),
                Text('الفائز: ${match['winner_name']}',
                    style: const TextStyle(color: Color(0xFF4ade80),
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final String name, team;
  final dynamic score;
  final bool isWinner, isLoser;
  const _PlayerRow({required this.name, required this.team,
    this.score, this.isWinner = false, this.isLoser = false});
  @override
  Widget build(BuildContext context) {
    final color = isWinner ? const Color(0xFF4ade80) : isLoser ? Colors.white38 : Colors.white;
    return Row(children: [
      if (isWinner) const Icon(Icons.emoji_events, color: Color(0xFFfbbf24), size: 16),
      if (!isWinner) const SizedBox(width: 16),
      const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: color,
            fontSize: 13, decoration: isLoser ? TextDecoration.lineThrough : null)),
        Text(team, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ])),
      if (score != null)
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: isWinner ? const Color(0xFF4ade80).withOpacity(0.2) : Colors.white10,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isWinner ? const Color(0xFF4ade80) : Colors.white12),
          ),
          child: Center(child: Text('$score',
              style: TextStyle(fontWeight: FontWeight.bold,
                  color: isWinner ? const Color(0xFF4ade80) : Colors.white54,
                  fontSize: 14))),
        ),
    ]);
  }
}

class _StandingsTab extends StatelessWidget {
  final Map<String, dynamic> players;
  final String status;
  const _StandingsTab({required this.players, required this.status});

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const Center(
      child: Text('لا يوجد لاعبون بعد', style: TextStyle(color: Colors.white54)));

    final sorted = players.entries.toList()
      ..sort((a, b) {
        final pa = a.value as Map;
        final pb = b.value as Map;
        final elimA = pa['eliminated'] == true ? 1 : 0;
        final elimB = pb['eliminated'] == true ? 1 : 0;
        if (elimA != elimB) return elimA.compareTo(elimB);
        final winsA = (pa['wins'] as int? ?? 0);
        final winsB = (pb['wins'] as int? ?? 0);
        return winsB.compareTo(winsA);
      });

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sorted.length,
      itemBuilder: (ctx, i) {
        final p = Map<String, dynamic>.from(sorted[i].value as Map);
        final eliminated = p['eliminated'] == true;
        final wins   = p['wins'] as int? ?? 0;
        final losses = p['losses'] as int? ?? 0;
        Color rowColor;
        Widget rankWidget;
        if (i == 0 && !eliminated) {
          rowColor = const Color(0xFFfbbf24);
          rankWidget = const Text('🥇', style: TextStyle(fontSize: 20));
        } else if (i == 1 && !eliminated) {
          rowColor = Colors.white70;
          rankWidget = const Text('🥈', style: TextStyle(fontSize: 20));
        } else if (i == 2 && !eliminated) {
          rowColor = Colors.orange;
          rankWidget = const Text('🥉', style: TextStyle(fontSize: 20));
        } else {
          rowColor = eliminated ? Colors.white24 : Colors.white54;
          rankWidget = Text('${i + 1}',
              style: TextStyle(color: rowColor, fontWeight: FontWeight.bold, fontSize: 16));
        }
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1c2128),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: i == 0 && !eliminated
                  ? const Color(0xFFfbbf24).withOpacity(0.5) : Colors.white10,
              width: i == 0 && !eliminated ? 1.5 : 1,
            ),
          ),
          child: Row(children: [
            SizedBox(width: 32, child: Center(child: rankWidget)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p['name']?.toString() ?? '',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                      color: eliminated ? Colors.white38 : Colors.white,
                      decoration: eliminated ? TextDecoration.lineThrough : null)),
              Text('🎮 ${p['team']?.toString() ?? ''}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ])),
            Row(children: [
              _StatBadge('$wins', 'فوز', const Color(0xFF4ade80)),
              const SizedBox(width: 6),
              _StatBadge('$losses', 'خسارة', Colors.red),
              if (eliminated) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('خرج', style: TextStyle(color: Colors.red, fontSize: 10)),
                ),
              ],
            ]),
          ]),
        );
      },
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatBadge(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
    Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
  ]);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOURNAMENT CARD — كارت البطولة في الشاشة الرئيسية
// ═══════════════════════════════════════════════════════════════════════════════

class _TournamentCard extends StatelessWidget {
  final Map<String, dynamic> tournament;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  const _TournamentCard({required this.tournament, required this.isAdmin,
    required this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final status  = tournament['status']?.toString() ?? 'registration';
    final players = Map<String, dynamic>.from(tournament['players'] ?? {});
    final maxP    = (tournament['max_players'] as num?)?.toInt() ?? 8;
    final winner  = tournament['winner'] as Map?;

    Color col; String statusLabel;
    switch (status) {
      case 'ongoing':  col = Colors.blue;   statusLabel = '🔴 جارية'; break;
      case 'finished': col = const Color(0xFF4ade80); statusLabel = '✅ منتهية'; break;
      default:         col = Colors.orange; statusLabel = '📝 تسجيل';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1c2128),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: col.withOpacity(0.4)),
          boxShadow: status == 'ongoing'
              ? [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 12, spreadRadius: 1)]
              : [],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('🏆', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tournament['name']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('🎮 ${tournament['game']?.toString() ?? 'FIFA'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: col.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: col.withOpacity(0.5))),
              child: Text(statusLabel,
                  style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            if (isAdmin && onDelete != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline, color: Colors.red, size: 20)),
            ],
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _InfoPill(Icons.people, '${players.length}/$maxP لاعب', Colors.white54),
            const SizedBox(width: 8),
            if (tournament['has_fee'] == true)
              _InfoPill(Icons.payments, '${(tournament['entry_fee'] as num?)?.toInt() ?? 0} ج', const Color(0xFF4ade80)),
            if (winner != null) ...[
              const SizedBox(width: 8),
              _InfoPill(Icons.emoji_events, winner['name']?.toString() ?? '', const Color(0xFFfbbf24)),
            ],
          ]),
        ]),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _InfoPill(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontSize: 11)),
    ]),
  );
}

class _EmptyTournaments extends StatelessWidget {
  final bool isAdmin;
  final VoidCallback onCreateTap;
  const _EmptyTournaments({required this.isAdmin, required this.onCreateTap});

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: const Color(0xFF1c2128),
            boxShadow: [BoxShadow(color: const Color(0xFFfbbf24).withOpacity(0.2),
                blurRadius: 40, spreadRadius: 8)]),
        child: const Text('🏆', style: TextStyle(fontSize: 60)),
      ),
      const SizedBox(height: 24),
      const Text('لا يوجد بطولات', style: TextStyle(fontSize: 22,
          fontWeight: FontWeight.bold, color: Color(0xFFfbbf24))),
      const SizedBox(height: 8),
      const Text('أنشئ أول بطولة وابدأ المنافسة!',
          style: TextStyle(color: Colors.white54, fontSize: 14),
          textAlign: TextAlign.center),
      if (isAdmin) ...[
        const SizedBox(height: 28),
        SizedBox(width: double.infinity, height: 52,
          child: FilledButton.icon(
            onPressed: onCreateTap,
            icon: const Icon(Icons.add),
            label: const Text('إنشاء بطولة جديدة', style: TextStyle(fontSize: 16)),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFfbbf24), foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          ),
        ),
      ],
    ]),
  ));
}

// ─── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 4, bottom: 4),
    child: Text(title, style: const TextStyle(
        color: Colors.white38, fontSize: 12,
        fontWeight: FontWeight.bold, letterSpacing: 1)),
  );
}
