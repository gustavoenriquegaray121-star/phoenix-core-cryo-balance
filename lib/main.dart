import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PhoenixCoreApp());
}

class PhoenixCoreApp extends StatelessWidget {
  const PhoenixCoreApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Phoenix Core',
      theme: ThemeData.dark(),
      home: const MainMenu(),
    );
  }
}

List<Color> getSkinColors(String skin) {
  switch (skin) {
    case 'gold':     return [Colors.amber, Colors.orange];
    case 'electric': return [Colors.blueAccent, Colors.lightBlue];
    case 'plasma':   return [Colors.orange, Colors.redAccent];
    case 'void':     return [Colors.grey.shade600, Colors.black];
    default:         return [Colors.cyan, Colors.blueAccent];
  }
}

Future<int> earnCoins(int score, int combo) async {
  final prefs = await SharedPreferences.getInstance();
  int earned = (score ~/ 2) + (combo * 10);
  if (combo >= 8)   earned += 50;
  if (score > 5000) earned += 100;
  int current = (prefs.getInt('cryo_coins') ?? 0) + earned;
  await prefs.setInt('cryo_coins', current);
  return earned;
}

// ══════════════════════════════════════════════════════════════
// AUDIO MANAGER — tap, quench, música generativa
// ══════════════════════════════════════════════════════════════
class AudioManager {
  static final AudioPlayer _tap    = AudioPlayer();
  static final AudioPlayer _quench = AudioPlayer();
  static bool _enabled = true;

  static Future<void> playTap() async {
    if (!_enabled) return;
    try { await _tap.play(AssetSource('sounds/tap.wav')); } catch (_) {}
  }

  static Future<void> playQuench() async {
    if (!_enabled) return;
    try { await _quench.play(AssetSource('sounds/quench.wav')); } catch (_) {}
  }

  static void toggle() => _enabled = !_enabled;
  static bool get enabled => _enabled;

  static void dispose() {
    _tap.dispose();
    _quench.dispose();
  }
}

// ══════════════════════════════════════════════════════════════
// TUTORIAL OVERLAY
// ══════════════════════════════════════════════════════════════
class TutorialOverlay extends StatelessWidget {
  final VoidCallback onDismiss;
  const TutorialOverlay({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.black.withOpacity(0.93),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('⚡ CÓMO JUGAR',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.cyan, letterSpacing: 2)),
                const SizedBox(height: 40),
                _tip('🔴', 'TAP directo en las bolas rojas\nantes de que lleguen al centro'),
                const SizedBox(height: 22),
                _tip('🌡️', 'Cada bola que pasa sube\nla temperatura del núcleo'),
                const SizedBox(height: 22),
                _tip('💥', 'Encadena combos para\nmultiplicar tu score'),
                const SizedBox(height: 22),
                _tip('❄️', 'COMBO x8 activa FREEZE:\nel tiempo se ralentiza'),
                const SizedBox(height: 22),
                _tip('☢️', 'Si la temperatura llega a 100μK\n¡QUENCH! Game Over'),
                const SizedBox(height: 22),
                _tip('🎵', 'La dificultad aumenta\nprogresivamente — ¡aguanta!'),
                const SizedBox(height: 44),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.cyan,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.5), blurRadius: 20)],
                  ),
                  child: const Text('¡ENTENDIDO! TAP PARA JUGAR',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tip(String emoji, String text) {
    return Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 30)),
      const SizedBox(width: 16),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.4))),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
// BARRA DE TEMPERATURA
// ══════════════════════════════════════════════════════════════
class TempBar extends StatelessWidget {
  final double temperature;
  const TempBar({super.key, required this.temperature});

  @override
  Widget build(BuildContext context) {
    double pct = (temperature.abs() / 100).clamp(0.0, 1.0);
    Color barColor = pct > 0.75 ? Colors.redAccent
        : pct > 0.5 ? Colors.orange
        : pct > 0.25 ? Colors.amber
        : Colors.cyan;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('TEMP NÚCLEO', style: TextStyle(fontSize: 11, color: barColor, letterSpacing: 1)),
          Text('${temperature.toStringAsFixed(1)} μK',
            style: TextStyle(fontSize: 13, color: barColor, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pct, backgroundColor: Colors.grey.shade800, color: barColor, minHeight: 8),
        ),
        if (pct > 0.75)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text('⚠️ PELIGRO CRÍTICO', style: TextStyle(fontSize: 10, color: Colors.redAccent.withOpacity(0.8), letterSpacing: 1)),
          ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MENÚ PRINCIPAL
// ══════════════════════════════════════════════════════════════
class MainMenu extends StatefulWidget {
  const MainMenu({super.key});
  @override State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> with SingleTickerProviderStateMixin {
  late AnimationController _glowAnim;
  int _cryoCoins = 0, _highScore = 0;
  String _selectedSkin = 'cyan';

  @override
  void initState() {
    super.initState();
    _loadData();
    _glowAnim = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _cryoCoins    = prefs.getInt('cryo_coins') ?? 0;
      _highScore    = prefs.getInt('cryo_highscore') ?? 0;
      _selectedSkin = prefs.getString('selected_skin') ?? 'cyan';
    });
  }

  @override
  void dispose() { _glowAnim.dispose(); super.dispose(); }

  void _goMode(Widget screen) {
    Navigator.push(context, PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => screen,
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    )).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        AnimatedBuilder(
          animation: _glowAnim,
          builder: (_, __) => Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(colors: [Colors.cyan.withOpacity(0.18 * _glowAnim.value), Colors.black]),
            ),
          ),
        ),
        SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                const Icon(Icons.monetization_on, color: Colors.amber, size: 26),
                const SizedBox(width: 6),
                Text('$_cryoCoins', style: const TextStyle(fontSize: 22, color: Colors.amber, fontWeight: FontWeight.bold)),
              ]),
              Text('HIGH: $_highScore', style: const TextStyle(fontSize: 18, color: Colors.white70)),
            ]),
          ),
          const Spacer(),
          const Text('PHOENIX CORE',
            style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: Colors.white,
              shadows: [Shadow(color: Colors.cyan, blurRadius: 20)])),
          const Text('CRYO BALANCE',
            style: TextStyle(fontSize: 22, color: Colors.cyan, letterSpacing: 3)),
          const SizedBox(height: 6),
          const Text('TAP LAS BOLAS • EVITA EL QUENCH',
            style: TextStyle(fontSize: 12, color: Colors.white30, letterSpacing: 1)),
          const SizedBox(height: 30),
          SizedBox(
            height: 360,
            child: PageView(
              controller: PageController(viewportFraction: 0.82),
              children: [
                _ModeCard(title: '¿EVITAR EL\nQUENCH?', subtitle: 'Mitigación directa de\ninestabilidad térmica', color: Colors.cyan, badge: 'ACTIVE', onTap: () => _goMode(CryoBalanceScreen(selectedSkin: _selectedSkin))),
                _ModeCard(title: 'ALTÍSIMA\nVELOCIDAD', subtitle: 'Protocolo de respuesta\nsub-90ns', color: Colors.orangeAccent, badge: 'BOOST', onTap: () => _goMode(HighSpeedScreen(selectedSkin: _selectedSkin))),
                _ModeCard(title: 'PRECISIÓN\nMÁXIMA', subtitle: 'Control predictivo\nde fase', color: Colors.purpleAccent, badge: 'ULTRA', onTap: () => _goMode(PrecisionScreen(selectedSkin: _selectedSkin))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('◀  DESLIZA PARA VER MODOS  ▶', style: TextStyle(fontSize: 11, color: Colors.white24, letterSpacing: 1)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ElevatedButton.icon(
              onPressed: () => _goMode(const SkinsScreen()),
              icon: const Icon(Icons.palette, color: Colors.black),
              label: const Text('SKINS', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
            ),
            const SizedBox(width: 16),
            IconButton(
              onPressed: () { AudioManager.toggle(); setState(() {}); },
              icon: Icon(AudioManager.enabled ? Icons.volume_up : Icons.volume_off, color: Colors.white54, size: 28),
            ),
          ]),
          const Spacer(),
        ])),
      ]),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title, subtitle, badge;
  final Color color;
  final VoidCallback onTap;
  const _ModeCard({required this.title, required this.subtitle, required this.badge, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [color.withOpacity(0.75), color.withOpacity(0.25), Colors.black]),
          boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 24, spreadRadius: 2)],
        ),
        child: Stack(children: [
          Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(title, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.white70)),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: color.withOpacity(0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: color, width: 1)),
              child: Text(badge, style: TextStyle(fontSize: 18, color: color, fontWeight: FontWeight.bold, shadows: [Shadow(color: color, blurRadius: 10)])),
            ),
          ])),
          Positioned(bottom: 18, right: 20, child: Text('JUGAR ▶', style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.bold))),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// QUENCH EXPLOSION PAINTER — efecto visual épico
// ══════════════════════════════════════════════════════════════
class QuenchExplosionPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0
  final Color color;
  QuenchExplosionPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.6;
    final rng = Random(42);

    // Anillos expansivos
    for (int i = 0; i < 4; i++) {
      double r = maxRadius * progress * (0.4 + i * 0.2);
      double opacity = (1.0 - progress) * (0.8 - i * 0.15);
      if (opacity <= 0) continue;
      final paint = Paint()
        ..color = color.withOpacity(opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 - i * 0.5;
      canvas.drawCircle(center, r, paint);
    }

    // Rayos desde el centro
    for (int i = 0; i < 16; i++) {
      double angle = (i / 16) * 2 * pi + progress * 0.5;
      double len = maxRadius * progress * (0.5 + rng.nextDouble() * 0.5);
      double opacity = (1.0 - progress).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = color.withOpacity(opacity * 0.8)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      final end = Offset(center.dx + cos(angle) * len, center.dy + sin(angle) * len);
      // Rayo zigzag
      final mid = Offset(
        center.dx + cos(angle) * len * 0.5 + sin(angle) * 20 * (rng.nextDouble() - 0.5),
        center.dy + sin(angle) * len * 0.5 - cos(angle) * 20 * (rng.nextDouble() - 0.5),
      );
      final path = Path()..moveTo(center.dx, center.dy)..lineTo(mid.dx, mid.dy)..lineTo(end.dx, end.dy);
      canvas.drawPath(path, paint);
    }

    // Flash central
    if (progress < 0.3) {
      final flashPaint = Paint()..color = Colors.white.withOpacity((0.3 - progress) * 3);
      canvas.drawCircle(center, maxRadius * 0.15, flashPaint);
    }
  }

  @override
  bool shouldRepaint(QuenchExplosionPainter old) => old.progress != progress;
}

// ══════════════════════════════════════════════════════════════
// MODO 1: CRYO BALANCE — dificultad progresiva suave
// ══════════════════════════════════════════════════════════════
class CryoBalanceScreen extends StatefulWidget {
  final String selectedSkin;
  const CryoBalanceScreen({super.key, this.selectedSkin = 'cyan'});
  @override State<CryoBalanceScreen> createState() => _CryoBalanceState();
}

class _CryoBalanceState extends State<CryoBalanceScreen> with TickerProviderStateMixin {
  double _temperature = 0;
  int _combo = 0, _score = 0, _highScore = 0;
  int _segundosJugados = 0;
  bool _isFrozen = false;
  double _gameSpeed = 1.0, _coreScale = 1.0;
  bool _showTutorial = true;

  // Explosión de quench
  bool _showQuench = false;
  double _quenchProgress = 0.0;
  Timer? _quenchTimer;

  Timer? _gameTimer, _freezeTimer, _secondTimer;
  final Random _rng = Random();
  late AnimationController _ringCtrl;

  List<Map<String, dynamic>> _balls = [], _particles = [], _lightning = [];

  // ── Dificultad progresiva ──────────────────────────────────
  // Empieza muy fácil, se pone dificil gradualmente
  double get _spawnRate {
    if (_segundosJugados < 10) return 0.02;        // muy pocas bolas
    if (_segundosJugados < 25) return 0.04;        // pocas
    if (_segundosJugados < 45) return 0.06;        // normal
    if (_segundosJugados < 70) return 0.08;        // medio
    return min(0.13, 0.08 + (_segundosJugados - 70) * 0.001); // máximo gradual
  }

  double get _ballSpeed {
    double base = 2.5;
    double bonus = min(4.0, _segundosJugados * 0.06);
    return base + bonus + _rng.nextDouble() * 2.0;
  }

  double get _tempIncrement {
    if (_segundosJugados < 15) return 0.3;
    if (_segundosJugados < 35) return 0.55;
    if (_segundosJugados < 60) return 0.75;
    return min(1.2, 0.75 + (_segundosJugados - 60) * 0.008);
  }

  @override
  void initState() {
    super.initState();
    _loadHS();
    _checkTutorial();
    _ringCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _startGame();
    _startSecondTimer();
  }

  void _startSecondTimer() {
    _secondTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isFrozen && !_showTutorial) setState(() => _segundosJugados++);
    });
  }

  Future<void> _checkTutorial() async {
    final p = await SharedPreferences.getInstance();
    bool seen = p.getBool('tutorial_seen') ?? false;
    if (seen) setState(() => _showTutorial = false);
  }

  Future<void> _dismissTutorial() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('tutorial_seen', true);
    setState(() => _showTutorial = false);
  }

  Future<void> _loadHS() async {
    final p = await SharedPreferences.getInstance();
    setState(() => _highScore = p.getInt('cryo_highscore') ?? 0);
  }

  Future<void> _saveHS() async {
    if (_score <= _highScore) return;
    final p = await SharedPreferences.getInstance();
    await p.setInt('cryo_highscore', _score);
    setState(() => _highScore = _score);
  }

  void _startGame() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 45), (_) {
      if (_isFrozen || _showTutorial) return;
      setState(() {
        _temperature += _tempIncrement * _gameSpeed;

        if (_rng.nextDouble() < _spawnRate) {
          _balls.add({'x': _rng.nextDouble() * 260 + 50, 'y': -50.0, 'speed': _ballSpeed, 'hit': false});
        }
        if (_balls.length > 20) _balls.removeAt(0);

        for (var b in _balls) {
          b['y'] += b['speed'] * _gameSpeed;
          if (b['y'] > 380 && !b['hit']) {
            _temperature += 12.0;
            b['hit'] = true;
            HapticFeedback.vibrate();
          }
        }
        _balls.removeWhere((b) => b['y'] > 650);

        for (var p in _particles) { p['x'] += p['vx']; p['y'] += p['vy']; p['alpha'] -= 0.035; p['vx'] *= 0.96; p['vy'] *= 0.96; }
        _particles.removeWhere((p) => p['alpha'] <= 0);
        if (_particles.length > 100) _particles.removeRange(0, 20);

        if (_rng.nextDouble() < 0.05) {
          _lightning.add({'x': _rng.nextDouble() * 320, 'y': _rng.nextDouble() * 650, 'alpha': 1.0, 'len': 30 + _rng.nextDouble() * 50});
        }
        for (var l in _lightning) { l['alpha'] -= 0.10; }
        _lightning.removeWhere((l) => l['alpha'] <= 0);

        _temperature = _temperature.clamp(-120.0, 120.0);
        if (_temperature.abs() > 100) _triggerQuench();
      });
    });
  }

  void _triggerQuench() async {
    _gameTimer?.cancel(); _freezeTimer?.cancel(); _secondTimer?.cancel(); _ringCtrl.stop();
    await AudioManager.playQuench();
    setState(() { _showQuench = true; _quenchProgress = 0.0; });

    _quenchTimer?.cancel();
    _quenchTimer = Timer.periodic(const Duration(milliseconds: 30), (t) {
      setState(() => _quenchProgress += 0.025);
      if (_quenchProgress >= 1.0) {
        t.cancel();
        setState(() => _showQuench = false);
        _gameOver();
      }
    });
  }

  void _gameOver() async {
    await _saveHS();
    int coins = await earnCoins(_score, _combo);
    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      backgroundColor: Colors.grey.shade900,
      title: const Text('☢️ QUENCH DETECTADO', style: TextStyle(color: Colors.redAccent, fontSize: 26)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Score: $_score', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text('High: $_highScore', style: const TextStyle(color: Colors.white70)),
        Text('Combo: $_combo', style: const TextStyle(color: Colors.cyan)),
        Text('Tiempo: ${_segundosJugados}s', style: const TextStyle(color: Colors.white54)),
        const SizedBox(height: 12),
        Text('+$coins CryoCoins 🪙', style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
      actions: [
        TextButton(onPressed: () { Navigator.pop(context); _restart(); }, child: const Text('REINTENTAR', style: TextStyle(color: Colors.cyan))),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('MENÚ', style: TextStyle(color: Colors.white54))),
      ],
    ));
  }

  void _onTapDown(TapDownDetails d) {
    if (_showTutorial || _showQuench) return;
    final tapPos = d.localPosition;
    bool hitBall = false;

    setState(() {
      for (int i = _balls.length - 1; i >= 0; i--) {
        var b = _balls[i];
        double dx = (tapPos.dx - b['x'] - 22).abs();
        double dy = (tapPos.dy - b['y'] - 22).abs();
        if (dx < 42 && dy < 42 && !b['hit']) {
          _balls.removeAt(i);
          _spawnExplosion(tapPos.dx, tapPos.dy, Colors.cyanAccent);
          _combo++;
          _score += 50 * _combo;
          _temperature = (_temperature - 14).clamp(-120.0, 120.0);
          hitBall = true;
          break;
        }
      }
      if (!hitBall) {
        _combo = (_combo - 1).clamp(0, 999);
        _temperature = (_temperature + 4).clamp(-120.0, 120.0);
      } else {
        HapticFeedback.mediumImpact();
        if (_combo >= 8 && _combo % 4 == 0) _freeze();
      }
      _coreScale = hitBall ? 1.25 : 1.05;
    });

    if (hitBall) AudioManager.playTap();
    Future.delayed(const Duration(milliseconds: 120), () { if (mounted) setState(() => _coreScale = 1.0); });
  }

  void _spawnExplosion(double x, double y, Color c) {
    for (int i = 0; i < 18; i++) {
      double angle = (i / 18) * 2 * pi;
      double speed = 3 + _rng.nextDouble() * 6;
      _particles.add({
        'x': x, 'y': y,
        'vx': cos(angle) * speed,
        'vy': sin(angle) * speed,
        'alpha': 1.0,
        'color': c,
      });
    }
  }

  void _freeze() {
    if (_isFrozen) return;
    setState(() { _isFrozen = true; _gameSpeed = 0.2; });
    _freezeTimer?.cancel();
    _freezeTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() { _isFrozen = false; _gameSpeed = 1.0; });
    });
  }

  void _restart() {
    setState(() {
      _temperature = 0; _combo = 0; _score = 0; _segundosJugados = 0;
      _balls.clear(); _particles.clear(); _lightning.clear();
      _isFrozen = false; _gameSpeed = 1.0; _coreScale = 1.0;
      _showQuench = false; _quenchProgress = 0.0;
    });
    _ringCtrl.repeat();
    _startGame();
    _startSecondTimer();
  }

  List<Color> get _gradient {
    if (_temperature.abs() > 70) return [Colors.redAccent, Colors.deepOrange];
    if (_temperature.abs() > 40) return [Colors.orange, Colors.amber];
    return getSkinColors(widget.selectedSkin);
  }

  // Nivel visual de dificultad
  String get _levelLabel {
    if (_segundosJugados < 10) return '▶ FASE 1 — INICIO';
    if (_segundosJugados < 25) return '▶▶ FASE 2 — ACTIVANDO';
    if (_segundosJugados < 45) return '▶▶▶ FASE 3 — ALERTA';
    if (_segundosJugados < 70) return '⚡ FASE 4 — CRÍTICO';
    return '☢️ FASE 5 — QUENCH INMINENTE';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isFrozen ? const Color(0xFF0A1A2E) : Colors.black,
      body: Stack(children: [
        // Fondo con pulso cuando es peligroso
        if (_temperature.abs() > 60)
          AnimatedBuilder(
            animation: _ringCtrl,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [Colors.red.withOpacity(0.08 + 0.04 * sin(_ringCtrl.value * 2 * pi)), Colors.black],
                ),
              ),
            ),
          ),

        GestureDetector(
          onTapDown: _onTapDown,
          child: Stack(children: [
            // Header: Score + Combo
            Positioned(top: 50, left: 20, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$_score', style: const TextStyle(fontSize: 38, color: Colors.white, fontWeight: FontWeight.bold)),
              Text('HIGH: $_highScore', style: const TextStyle(fontSize: 12, color: Colors.white38)),
            ])),
            Positioned(top: 50, right: 20, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('×$_combo', style: TextStyle(fontSize: 38, color: _combo >= 8 ? Colors.purpleAccent : Colors.cyan, fontWeight: FontWeight.bold)),
              if (_combo >= 8)
                Text('FREEZE EN ${8 - (_combo % 4)} COMBO', style: const TextStyle(fontSize: 10, color: Colors.purpleAccent)),
              Text(_levelLabel, style: const TextStyle(fontSize: 10, color: Colors.white30)),
            ])),

            // Barra temperatura
            Positioned(top: 112, left: 0, right: 0, child: TempBar(temperature: _temperature)),

            // Hint inicial
            if (_combo == 0 && _score == 0 && _segundosJugados < 5)
              const Positioned(top: 160, left: 0, right: 0,
                child: Text('👆 TAP DIRECTO EN LAS BOLAS ROJAS', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.white30, letterSpacing: 1))),

            // Núcleo central
            Center(child: ScaleTransition(
              scale: AlwaysStoppedAnimation(_coreScale),
              child: RotationTransition(
                turns: _ringCtrl,
                child: Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: _gradient),
                    boxShadow: [BoxShadow(
                      color: _gradient.first.withOpacity(0.9),
                      blurRadius: 60 + (_combo * 3).toDouble(),
                      spreadRadius: 4,
                    )],
                  ),
                  child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(_combo >= 8 ? '❄️' : '🔥', style: const TextStyle(fontSize: 30)),
                    const Text('PHOENIX\nCORE', textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                    Text('${_segundosJugados}s', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ])),
                ),
              ),
            )),

            // Bolas rojas
            ..._balls.map((b) => Positioned(
              left: b['x'], top: b['y'],
              child: Container(width: 44, height: 44,
                decoration: BoxDecoration(
                  color: b['hit'] ? Colors.red.withOpacity(0.2) : Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: b['hit'] ? [] : [BoxShadow(color: Colors.red.withOpacity(0.7), blurRadius: 12)],
                )))),

            // Partículas de explosión
            ..._particles.map((p) => Positioned(
              left: p['x'], top: p['y'],
              child: Opacity(opacity: (p['alpha'] as double).clamp(0.0, 1.0),
                child: Container(width: 6, height: 6,
                  decoration: BoxDecoration(color: p['color'] as Color, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: (p['color'] as Color).withOpacity(0.5), blurRadius: 4)],
                  ))))),

            // Rayos de fondo
            ..._lightning.map((l) => Positioned(
              left: l['x'], top: l['y'],
              child: Opacity(opacity: (l['alpha'] as double).clamp(0.0, 1.0),
                child: Container(width: 2, height: l['len'] as double, color: Colors.blueAccent.withOpacity(0.6))))),

            // FREEZE overlay
            if (_isFrozen)
              Container(
                color: Colors.cyan.withOpacity(0.10),
                child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('❄️', style: TextStyle(fontSize: 60)),
                  Text('FREEZE', style: TextStyle(fontSize: 52, color: Colors.cyan, fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.cyan, blurRadius: 20)])),
                  Text('TIEMPO RALENTIZADO', style: TextStyle(fontSize: 14, color: Colors.lightBlueAccent, letterSpacing: 2)),
                ])),
              ),
          ]),
        ),

        // Tutorial encima de todo
        if (_showTutorial) TutorialOverlay(onDismiss: _dismissTutorial),

        // Explosión de quench
        if (_showQuench)
          Positioned.fill(child: CustomPaint(
            painter: QuenchExplosionPainter(progress: _quenchProgress, color: Colors.redAccent),
          )),
        if (_showQuench && _quenchProgress > 0.1 && _quenchProgress < 0.7)
          Center(child: Text('☢️ QUENCH',
            style: TextStyle(fontSize: 54, fontWeight: FontWeight.bold, color: Colors.redAccent,
              shadows: [Shadow(color: Colors.redAccent.withOpacity(1.0 - _quenchProgress), blurRadius: 30)]))),
      ]),
    );
  }

  @override
  void dispose() {
    _gameTimer?.cancel(); _freezeTimer?.cancel(); _secondTimer?.cancel();
    _quenchTimer?.cancel(); _ringCtrl.dispose();
    super.dispose();
  }
}

// ══════════════════════════════════════════════════════════════
// MODO 2: ALTA VELOCIDAD
// ══════════════════════════════════════════════════════════════
class HighSpeedScreen extends StatefulWidget {
  final String selectedSkin;
  const HighSpeedScreen({super.key, this.selectedSkin = 'cyan'});
  @override State<HighSpeedScreen> createState() => _HighSpeedState();
}

class _HighSpeedState extends State<HighSpeedScreen> with TickerProviderStateMixin {
  double _temperature = 0;
  int _combo = 0, _score = 0, _multiplier = 1, _highScore = 0;
  int _segundosJugados = 0;
  bool _isFrozen = false;
  double _gameSpeed = 1.0, _coreScale = 1.0;

  bool _showQuench = false;
  double _quenchProgress = 0.0;
  Timer? _quenchTimer;

  Timer? _gameTimer, _freezeTimer, _secondTimer;
  final Random _rng = Random();
  late AnimationController _ringCtrl;

  List<Map<String, dynamic>> _balls = [], _particles = [];

  double get _spawnRate {
    if (_segundosJugados < 8)  return 0.04;
    if (_segundosJugados < 20) return 0.08;
    if (_segundosJugados < 40) return 0.13;
    return min(0.20, 0.13 + (_segundosJugados - 40) * 0.002);
  }

  double get _ballSpeed {
    double base = 4.0 + min(8.0, _segundosJugados * 0.12);
    return base + _rng.nextDouble() * 3.0;
  }

  @override
  void initState() {
    super.initState();
    _loadHS();
    _ringCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _startGame();
    _secondTimer = Timer.periodic(const Duration(seconds: 1), (_) { if (!_isFrozen) setState(() => _segundosJugados++); });
  }

  Future<void> _loadHS() async {
    final p = await SharedPreferences.getInstance();
    setState(() => _highScore = p.getInt('highspeed_highscore') ?? 0);
  }

  Future<void> _saveHS() async {
    if (_score <= _highScore) return;
    final p = await SharedPreferences.getInstance();
    await p.setInt('highspeed_highscore', _score);
    setState(() => _highScore = _score);
  }

  void _startGame() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (_isFrozen) return;
      setState(() {
        double tempInc = _segundosJugados < 15 ? 0.6 : _segundosJugados < 35 ? 1.0 : min(1.8, 1.0 + (_segundosJugados - 35) * 0.02);
        _temperature += tempInc * _gameSpeed + _combo * 0.08;

        if (_rng.nextDouble() < _spawnRate) {
          _balls.add({'x': _rng.nextDouble() * 260 + 50, 'y': -50.0, 'speed': _ballSpeed, 'hit': false});
        }
        if (_balls.length > 25) _balls.removeAt(0);

        for (var b in _balls) {
          b['y'] += b['speed'] * _gameSpeed;
          if (b['y'] > 380 && !b['hit']) { _temperature += 20.0; b['hit'] = true; HapticFeedback.vibrate(); }
        }
        _balls.removeWhere((b) => b['y'] > 650);

        for (var p in _particles) { p['x'] += p['vx']; p['y'] += p['vy']; p['alpha'] -= 0.05; p['vx'] *= 0.95; p['vy'] *= 0.95; }
        _particles.removeWhere((p) => p['alpha'] <= 0);
        if (_particles.length > 80) _particles.removeRange(0, 15);

        _multiplier = 1 + (_combo ~/ 5);
        _temperature = _temperature.clamp(-120.0, 120.0);
        if (_temperature.abs() > 100) _triggerQuench();
      });
    });
  }

  void _triggerQuench() async {
    _gameTimer?.cancel(); _freezeTimer?.cancel(); _secondTimer?.cancel(); _ringCtrl.stop();
    await AudioManager.playQuench();
    setState(() { _showQuench = true; _quenchProgress = 0.0; });
    _quenchTimer?.cancel();
    _quenchTimer = Timer.periodic(const Duration(milliseconds: 30), (t) {
      setState(() => _quenchProgress += 0.025);
      if (_quenchProgress >= 1.0) { t.cancel(); setState(() => _showQuench = false); _gameOver(); }
    });
  }

  void _onTapDown(TapDownDetails d) {
    if (_showQuench) return;
    final tapPos = d.localPosition;
    bool hitBall = false;
    setState(() {
      for (int i = _balls.length - 1; i >= 0; i--) {
        var b = _balls[i];
        double dx = (tapPos.dx - b['x'] - 22).abs();
        double dy = (tapPos.dy - b['y'] - 22).abs();
        if (dx < 48 && dy < 48 && !b['hit']) {
          _balls.removeAt(i);
          for (int j = 0; j < 20; j++) {
            double angle = (j / 20) * 2 * pi;
            double speed = 4 + _rng.nextDouble() * 8;
            _particles.add({'x': tapPos.dx, 'y': tapPos.dy, 'vx': cos(angle) * speed, 'vy': sin(angle) * speed, 'alpha': 1.0, 'color': Colors.orangeAccent});
          }
          _combo++;
          _score += (100 * _combo) * _multiplier;
          _temperature = (_temperature - 20).clamp(-120.0, 120.0);
          HapticFeedback.heavyImpact();
          hitBall = true;
          break;
        }
      }
      if (!hitBall) { _combo = 0; _temperature += 12; }
      else { if (_combo >= 6 && _combo % 3 == 0) _freeze(); }
      _coreScale = hitBall ? 1.3 : 1.0;
    });
    if (hitBall) AudioManager.playTap();
    Future.delayed(const Duration(milliseconds: 90), () { if (mounted) setState(() => _coreScale = 1.0); });
  }

  void _freeze() {
    if (_isFrozen) return;
    setState(() { _isFrozen = true; _gameSpeed = 0.18; });
    _freezeTimer?.cancel();
    _freezeTimer = Timer(const Duration(milliseconds: 1600), () { if (mounted) setState(() { _isFrozen = false; _gameSpeed = 1.0; }); });
  }

  void _gameOver() async {
    await _saveHS();
    int coins = await earnCoins(_score, _combo);
    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      backgroundColor: Colors.grey.shade900,
      title: const Text('⚡ VELOCIDAD MÁXIMA', style: TextStyle(color: Colors.orangeAccent, fontSize: 26)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Score: $_score', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text('High: $_highScore', style: const TextStyle(color: Colors.white70)),
        Text('×$_multiplier', style: const TextStyle(color: Colors.purpleAccent)),
        Text('Tiempo: ${_segundosJugados}s', style: const TextStyle(color: Colors.white54)),
        const SizedBox(height: 12),
        Text('+$coins CryoCoins 🪙', style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
      actions: [
        TextButton(onPressed: () { Navigator.pop(context); _restart(); }, child: const Text('REINTENTAR', style: TextStyle(color: Colors.orange))),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('MENÚ', style: TextStyle(color: Colors.white54))),
      ],
    ));
  }

  void _restart() {
    setState(() { _temperature = 0; _combo = 0; _score = 0; _multiplier = 1; _segundosJugados = 0; _balls.clear(); _particles.clear(); _isFrozen = false; _gameSpeed = 1.0; _coreScale = 1.0; _showQuench = false; _quenchProgress = 0.0; });
    _ringCtrl.repeat(); _startGame();
    _secondTimer = Timer.periodic(const Duration(seconds: 1), (_) { if (!_isFrozen) setState(() => _segundosJugados++); });
  }

  List<Color> get _gradient { if (_temperature.abs() > 50) return [Colors.orangeAccent, Colors.redAccent]; return getSkinColors(widget.selectedSkin); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isFrozen ? const Color(0xFF0A1A2E) : Colors.black,
      body: Stack(children: [
        GestureDetector(
          onTapDown: _onTapDown,
          child: Stack(children: [
            Positioned(top: 50, left: 20, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$_score', style: const TextStyle(fontSize: 38, color: Colors.white, fontWeight: FontWeight.bold)),
              Text('HIGH: $_highScore', style: const TextStyle(fontSize: 12, color: Colors.white38)),
            ])),
            Positioned(top: 50, right: 20, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('×$_multiplier', style: const TextStyle(fontSize: 38, color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
              Text('COMBO $_combo', style: const TextStyle(fontSize: 13, color: Colors.orangeAccent)),
              Text('${_segundosJugados}s', style: const TextStyle(fontSize: 11, color: Colors.white30)),
            ])),
            Positioned(top: 112, left: 0, right: 0, child: TempBar(temperature: _temperature)),
            Center(child: ScaleTransition(
              scale: AlwaysStoppedAnimation(_coreScale),
              child: RotationTransition(turns: _ringCtrl, child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: _gradient),
                  boxShadow: [BoxShadow(color: _gradient.first.withOpacity(0.9), blurRadius: 60 + (_combo * 3).toDouble(), spreadRadius: 4)]),
                child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('⚡', style: TextStyle(fontSize: 30)),
                  const Text('ALTA\nVELOCIDAD', textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                ])),
              )),
            )),
            ..._balls.map((b) => Positioned(left: b['x'], top: b['y'],
              child: Container(width: 44, height: 44,
                decoration: BoxDecoration(color: b['hit'] ? Colors.red.withOpacity(0.2) : Colors.redAccent, shape: BoxShape.circle,
                  boxShadow: b['hit'] ? [] : [BoxShadow(color: Colors.orange.withOpacity(0.7), blurRadius: 14)])))),
            ..._particles.map((p) => Positioned(left: p['x'], top: p['y'],
              child: Opacity(opacity: (p['alpha'] as double).clamp(0.0, 1.0),
                child: Container(width: 7, height: 7, decoration: BoxDecoration(color: p['color'] as Color, shape: BoxShape.circle))))),
            if (_isFrozen)
              Container(color: Colors.cyan.withOpacity(0.10),
                child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('❄️', style: TextStyle(fontSize: 60)),
                  Text('FREEZE', style: TextStyle(fontSize: 52, color: Colors.cyan, fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.cyan, blurRadius: 20)])),
                ]))),
          ]),
        ),
        if (_showQuench) Positioned.fill(child: CustomPaint(painter: QuenchExplosionPainter(progress: _quenchProgress, color: Colors.orangeAccent))),
        if (_showQuench && _quenchProgress > 0.1 && _quenchProgress < 0.7)
          Center(child: Text('☢️ QUENCH', style: TextStyle(fontSize: 54, fontWeight: FontWeight.bold, color: Colors.orangeAccent,
            shadows: [Shadow(color: Colors.orange.withOpacity(1.0 - _quenchProgress), blurRadius: 30)]))),
      ]),
    );
  }

  @override
  void dispose() { _gameTimer?.cancel(); _freezeTimer?.cancel(); _secondTimer?.cancel(); _quenchTimer?.cancel(); _ringCtrl.dispose(); super.dispose(); }
}

// ══════════════════════════════════════════════════════════════
// MODO 3: PRECISIÓN MÁXIMA
// ══════════════════════════════════════════════════════════════
class PrecisionScreen extends StatefulWidget {
  final String selectedSkin;
  const PrecisionScreen({super.key, this.selectedSkin = 'cyan'});
  @override State<PrecisionScreen> createState() => _PrecisionState();
}

class _PrecisionState extends State<PrecisionScreen> with TickerProviderStateMixin {
  double _temperature = 0;
  int _combo = 0, _score = 0, _multiplier = 1, _highScore = 0;
  int _segundosJugados = 0;
  bool _isFrozen = false;
  double _gameSpeed = 1.0, _coreScale = 1.0;

  bool _showQuench = false;
  double _quenchProgress = 0.0;
  Timer? _quenchTimer;

  Timer? _gameTimer, _freezeTimer, _secondTimer;
  final Random _rng = Random();
  late AnimationController _ringCtrl;

  List<Map<String, dynamic>> _balls = [], _particles = [], _floatingScores = [], _lightning = [];

  double get _spawnRate {
    if (_segundosJugados < 12) return 0.015;
    if (_segundosJugados < 30) return 0.035;
    if (_segundosJugados < 55) return 0.055;
    return min(0.09, 0.055 + (_segundosJugados - 55) * 0.001);
  }

  double get _ballSpeed {
    double base = 2.0 + min(3.5, _segundosJugados * 0.05);
    return base + _rng.nextDouble() * 1.5;
  }

  @override
  void initState() {
    super.initState();
    _loadHS();
    _ringCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _startGame();
    _secondTimer = Timer.periodic(const Duration(seconds: 1), (_) { if (!_isFrozen) setState(() => _segundosJugados++); });
  }

  Future<void> _loadHS() async {
    final p = await SharedPreferences.getInstance();
    setState(() => _highScore = p.getInt('precision_highscore') ?? 0);
  }

  Future<void> _saveHS() async {
    if (_score <= _highScore) return;
    final p = await SharedPreferences.getInstance();
    await p.setInt('precision_highscore', _score);
    setState(() => _highScore = _score);
  }

  void _startGame() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 45), (_) {
      if (_isFrozen) return;
      setState(() {
        double tempInc = _segundosJugados < 20 ? 0.25 : _segundosJugados < 50 ? 0.5 : min(0.9, 0.5 + (_segundosJugados - 50) * 0.01);
        _temperature += tempInc * _gameSpeed + _combo * 0.03;

        if (_rng.nextDouble() < _spawnRate) {
          _balls.add({'x': _rng.nextDouble() * 260 + 50, 'y': -50.0, 'speed': _ballSpeed, 'hit': false});
        }
        if (_balls.length > 20) _balls.removeAt(0);

        for (var b in _balls) {
          b['y'] += b['speed'] * _gameSpeed;
          if (b['y'] > 380 && !b['hit']) { _temperature += 25.0; b['hit'] = true; HapticFeedback.vibrate(); }
        }
        _balls.removeWhere((b) => b['y'] > 650);

        for (var p in _particles) { p['x'] += p['vx']; p['y'] += p['vy']; p['alpha'] -= 0.035; p['vx'] *= 0.96; p['vy'] *= 0.96; }
        _particles.removeWhere((p) => p['alpha'] <= 0);
        for (var f in _floatingScores) { f['y'] -= 2.5; f['alpha'] -= 0.028; }
        _floatingScores.removeWhere((f) => f['alpha'] <= 0);
        if (_rng.nextDouble() < 0.05) _lightning.add({'x': _rng.nextDouble() * 320, 'y': _rng.nextDouble() * 650, 'alpha': 1.0, 'len': 40.0 + _rng.nextDouble() * 60});
        for (var l in _lightning) { l['alpha'] -= 0.07; }
        _lightning.removeWhere((l) => l['alpha'] <= 0);

        _temperature = _temperature.clamp(-120.0, 120.0);
        if (_temperature.abs() > 100) _triggerQuench();
      });
    });
  }

  void _triggerQuench() async {
    _gameTimer?.cancel(); _freezeTimer?.cancel(); _secondTimer?.cancel(); _ringCtrl.stop();
    await AudioManager.playQuench();
    setState(() { _showQuench = true; _quenchProgress = 0.0; });
    _quenchTimer?.cancel();
    _quenchTimer = Timer.periodic(const Duration(milliseconds: 30), (t) {
      setState(() => _quenchProgress += 0.025);
      if (_quenchProgress >= 1.0) { t.cancel(); setState(() => _showQuench = false); _gameOver(); }
    });
  }

  void _onTapDown(TapDownDetails d) {
    if (_showQuench) return;
    final tapPos = d.localPosition;
    bool hitBall = false;
    setState(() {
      for (int i = _balls.length - 1; i >= 0; i--) {
        var b = _balls[i];
        double dx = (tapPos.dx - b['x'] - 22).abs();
        double dy = (tapPos.dy - b['y'] - 22).abs();
        if (dx < 44 && dy < 44 && !b['hit']) {
          _balls.removeAt(i);
          for (int j = 0; j < 24; j++) {
            double angle = (j / 24) * 2 * pi;
            double speed = 3 + _rng.nextDouble() * 7;
            _particles.add({'x': tapPos.dx, 'y': tapPos.dy, 'vx': cos(angle) * speed, 'vy': sin(angle) * speed, 'alpha': 1.0, 'color': Colors.cyanAccent});
          }
          _combo++;
          int pts = (300 + _rng.nextInt(200)) * _multiplier;
          _score += pts;
          _floatingScores.add({'text': '+$pts', 'x': tapPos.dx - 30, 'y': tapPos.dy - 20, 'alpha': 1.0});
          _temperature = (_temperature - 25).clamp(-120.0, 120.0);
          HapticFeedback.heavyImpact();
          hitBall = true;
          break;
        }
      }
      if (!hitBall) { _multiplier = 1; _combo = 0; }
      else { _multiplier = (_multiplier + 1).clamp(1, 15); if (_combo >= 10 && _combo % 5 == 0) _freeze(); }
      _coreScale = hitBall ? 1.4 : 1.0;
    });
    if (hitBall) AudioManager.playTap();
    Future.delayed(const Duration(milliseconds: 110), () { if (mounted) setState(() => _coreScale = 1.0); });
  }

  void _freeze() {
    if (_isFrozen) return;
    setState(() { _isFrozen = true; _gameSpeed = 0.15; });
    _freezeTimer?.cancel();
    _freezeTimer = Timer(const Duration(milliseconds: 2500), () { if (mounted) setState(() { _isFrozen = false; _gameSpeed = 1.0; }); });
  }

  void _gameOver() async {
    await _saveHS();
    int coins = await earnCoins(_score, _combo);
    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      backgroundColor: Colors.grey.shade900,
      title: const Text('🎯 PRECISIÓN MÁXIMA', style: TextStyle(color: Colors.cyanAccent, fontSize: 26)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Score: $_score', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text('High: $_highScore', style: const TextStyle(color: Colors.white70)),
        Text('×$_multiplier alcanzado', style: const TextStyle(color: Colors.purpleAccent)),
        Text('Tiempo: ${_segundosJugados}s', style: const TextStyle(color: Colors.white54)),
        const SizedBox(height: 12),
        Text('+$coins CryoCoins 🪙', style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
      actions: [
        TextButton(onPressed: () { Navigator.pop(context); _restart(); }, child: const Text('REINTENTAR', style: TextStyle(color: Colors.cyan))),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('MENÚ', style: TextStyle(color: Colors.white54))),
      ],
    ));
  }

  void _restart() {
    setState(() { _temperature = 0; _combo = 0; _score = 0; _multiplier = 1; _segundosJugados = 0; _balls.clear(); _particles.clear(); _floatingScores.clear(); _lightning.clear(); _isFrozen = false; _gameSpeed = 1.0; _coreScale = 1.0; _showQuench = false; _quenchProgress = 0.0; });
    _ringCtrl.repeat(); _startGame();
    _secondTimer = Timer.periodic(const Duration(seconds: 1), (_) { if (!_isFrozen) setState(() => _segundosJugados++); });
  }

  List<Color> get _gradient => _isFrozen ? [Colors.lightBlueAccent, Colors.cyan] : getSkinColors(widget.selectedSkin);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isFrozen ? const Color(0xFF0A1A2E) : Colors.black,
      body: Stack(children: [
        GestureDetector(
          onTapDown: _onTapDown,
          child: Stack(children: [
            Positioned(top: 50, left: 20, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$_score', style: const TextStyle(fontSize: 38, color: Colors.white, fontWeight: FontWeight.bold)),
              Text('HIGH: $_highScore', style: const TextStyle(fontSize: 12, color: Colors.white38)),
            ])),
            Positioned(top: 50, right: 20, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('×$_multiplier', style: const TextStyle(fontSize: 44, color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
              Text('COMBO $_combo', style: const TextStyle(fontSize: 13, color: Colors.cyanAccent)),
              Text('${_segundosJugados}s', style: const TextStyle(fontSize: 11, color: Colors.white30)),
            ])),
            Positioned(top: 112, left: 0, right: 0, child: TempBar(temperature: _temperature)),
            Center(child: ScaleTransition(
              scale: AlwaysStoppedAnimation(_coreScale),
              child: RotationTransition(turns: _ringCtrl, child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: _gradient),
                  boxShadow: [BoxShadow(color: _gradient.first.withOpacity(0.9), blurRadius: 60 + (_combo * 3).toDouble(), spreadRadius: 4)]),
                child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('🎯', style: TextStyle(fontSize: 30)),
                  const Text('PRECISIÓN', textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ])),
              )),
            )),
            ..._balls.map((b) => Positioned(left: b['x'], top: b['y'],
              child: Container(width: 44, height: 44,
                decoration: BoxDecoration(color: b['hit'] ? Colors.red.withOpacity(0.1) : Colors.redAccent, shape: BoxShape.circle,
                  boxShadow: b['hit'] ? [] : [const BoxShadow(color: Colors.cyanAccent, blurRadius: 12)])))),
            ..._particles.map((p) => Positioned(left: p['x'], top: p['y'],
              child: Opacity(opacity: (p['alpha'] as double).clamp(0.0, 1.0),
                child: Container(width: 5, height: 5, decoration: BoxDecoration(color: p['color'] as Color, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: (p['color'] as Color).withOpacity(0.5), blurRadius: 4)]))))),
            ..._floatingScores.map((f) => Positioned(left: f['x'], top: f['y'],
              child: Opacity(opacity: (f['alpha'] as double).clamp(0.0, 1.0),
                child: Text(f['text'], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.cyanAccent,
                  shadows: [Shadow(color: Colors.cyan, blurRadius: 8)]))))),
            ..._lightning.map((l) => Positioned(left: l['x'], top: l['y'],
              child: Opacity(opacity: (l['alpha'] as double).clamp(0.0, 1.0),
                child: Container(width: 1.5, height: l['len'] as double, color: Colors.blueAccent.withOpacity(0.6))))),
            if (_isFrozen)
              Container(color: Colors.cyan.withOpacity(0.10),
                child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('❄️', style: TextStyle(fontSize: 60)),
                  Text('FREEZE', style: TextStyle(fontSize: 52, color: Colors.cyan, fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.cyan, blurRadius: 20)])),
                  Text('CONTROL PREDICTIVO', style: TextStyle(fontSize: 13, color: Colors.lightBlueAccent, letterSpacing: 2)),
                ]))),
          ]),
        ),
        if (_showQuench) Positioned.fill(child: CustomPaint(painter: QuenchExplosionPainter(progress: _quenchProgress, color: Colors.cyanAccent))),
        if (_showQuench && _quenchProgress > 0.1 && _quenchProgress < 0.7)
          Center(child: Text('☢️ QUENCH', style: TextStyle(fontSize: 54, fontWeight: FontWeight.bold, color: Colors.cyanAccent,
            shadows: [Shadow(color: Colors.cyan.withOpacity(1.0 - _quenchProgress), blurRadius: 30)]))),
      ]),
    );
  }

  @override
  void dispose() { _gameTimer?.cancel(); _freezeTimer?.cancel(); _secondTimer?.cancel(); _quenchTimer?.cancel(); _ringCtrl.dispose(); super.dispose(); }
}

// ══════════════════════════════════════════════════════════════
// PANTALLA DE SKINS
// ══════════════════════════════════════════════════════════════
class SkinsScreen extends StatefulWidget {
  const SkinsScreen({super.key});
  @override State<SkinsScreen> createState() => _SkinsScreenState();
}

class _SkinsScreenState extends State<SkinsScreen> {
  int _cryoCoins = 0;
  String _selectedSkin = 'cyan';

  final Map<String, Map<String, dynamic>> _skins = {
    'cyan':     {'price': 0,    'desc': 'Clásico criogénico'},
    'gold':     {'price': 500,  'desc': 'Oro del fénix'},
    'electric': {'price': 1200, 'desc': 'Plasma eléctrico'},
    'plasma':   {'price': 800,  'desc': 'Fuego de plasma'},
    'void':     {'price': 2000, 'desc': 'Vacío estelar'},
  };

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final p = await SharedPreferences.getInstance();
    setState(() { _cryoCoins = p.getInt('cryo_coins') ?? 0; _selectedSkin = p.getString('selected_skin') ?? 'cyan'; });
  }

  Future<void> _buyOrSelect(String skin) async {
    final p = await SharedPreferences.getInstance();
    int price = _skins[skin]!['price'] as int;
    bool unlocked = price == 0 || (p.getBool('unlocked_$skin') ?? false);
    if (!unlocked && _cryoCoins >= price) { _cryoCoins -= price; await p.setInt('cryo_coins', _cryoCoins); await p.setBool('unlocked_$skin', true); unlocked = true; }
    if (unlocked) { await p.setString('selected_skin', skin); setState(() => _selectedSkin = skin); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('¡$skin activado! 🔥'))); }
    else { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Necesitas ${price - _cryoCoins} CryoCoins más'))); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Skins del Núcleo'), backgroundColor: Colors.cyan.shade900),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.monetization_on, color: Colors.amber, size: 30),
          const SizedBox(width: 8),
          Text('$_cryoCoins CryoCoins', style: const TextStyle(fontSize: 26, color: Colors.amber, fontWeight: FontWeight.bold)),
        ])),
        Expanded(child: ListView(children: _skins.keys.map((skin) {
          bool isSelected = _selectedSkin == skin;
          int price = _skins[skin]!['price'] as int;
          List<Color> colors = getSkinColors(skin);
          return Card(color: Colors.grey.shade900, margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16), child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(width: 56, height: 56,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: colors),
                boxShadow: [BoxShadow(color: colors.first.withOpacity(0.7), blurRadius: 16)])),
            title: Text(skin.toUpperCase(), style: TextStyle(color: colors.first, fontSize: 20, fontWeight: FontWeight.bold)),
            subtitle: Text(_skins[skin]!['desc'], style: const TextStyle(color: Colors.white70)),
            trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.greenAccent, size: 28)
              : Text(price == 0 ? 'GRATIS' : '$price 🪙',
                style: TextStyle(color: price == 0 ? Colors.greenAccent : Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
            onTap: () => _buyOrSelect(skin),
          ));
        }).toList())),
      ]),
    );
  }
}
