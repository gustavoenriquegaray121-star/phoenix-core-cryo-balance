import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PhoenixCoreApp());
}

// ══════════════════════════════════════════════════════════════
// APP ROOT
// ══════════════════════════════════════════════════════════════
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

// ══════════════════════════════════════════════════════════════
// SKIN HELPERS
// ══════════════════════════════════════════════════════════════
List<Color> getSkinColors(String skin) {
  switch (skin) {
    case 'gold':     return [Colors.amber, Colors.orange];
    case 'electric': return [Colors.blueAccent, Colors.lightBlue];
    case 'plasma':   return [Colors.orange, Colors.redAccent];
    case 'void':     return [Colors.grey, Colors.black];
    default:         return [Colors.cyan, Colors.blueAccent];
  }
}

// ══════════════════════════════════════════════════════════════
// MENÚ PRINCIPAL
// ══════════════════════════════════════════════════════════════
class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> with SingleTickerProviderStateMixin {
  late AnimationController _glowAnim;
  int _cryoCoins = 0;
  int _highScore = 0;
  String _selectedSkin = 'cyan';

  @override
  void initState() {
    super.initState();
    _loadData();
    _glowAnim = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
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
  void dispose() {
    _glowAnim.dispose();
    super.dispose();
  }

  void _goMode(Widget screen) {
    Navigator.push(context, PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => screen,
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    )).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.cyan.withOpacity(0.18 * _glowAnim.value),
                    Colors.black
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Icon(Icons.monetization_on, color: Colors.amber, size: 26),
                        const SizedBox(width: 6),
                        Text('$_cryoCoins',
                            style: const TextStyle(fontSize: 22, color: Colors.amber, fontWeight: FontWeight.bold)),
                      ]),
                      Text('HIGH: $_highScore',
                          style: const TextStyle(fontSize: 18, color: Colors.white70)),
                    ],
                  ),
                ),
                const Spacer(),
                const Text('PHOENIX CORE',
                    style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: Colors.white,
                        shadows: [Shadow(color: Colors.cyan, blurRadius: 20)])),
                const Text('CRYO BALANCE',
                    style: TextStyle(fontSize: 22, color: Colors.cyan, letterSpacing: 3)),
                const SizedBox(height: 36),
                SizedBox(
                  height: 360,
                  child: PageView(
                    controller: PageController(viewportFraction: 0.82),
                    children: [
                      _ModeCard(
                        title: '¿EVITAR EL\nQUENCH?',
                        subtitle: 'Mitigación directa de\ninestabilidad térmica',
                        color: Colors.cyan,
                        score: 'ACTIVE',
                        onTap: () => _goMode(CryoBalanceScreen(selectedSkin: _selectedSkin)),
                      ),
                      _ModeCard(
                        title: 'ALTÍSIMA\nVELOCIDAD',
                        subtitle: 'Protocolo de respuesta\nsub-90ns',
                        color: Colors.orangeAccent,
                        score: 'BOOST',
                        onTap: () => _goMode(HighSpeedScreen(selectedSkin: _selectedSkin)),
                      ),
                      _ModeCard(
                        title: 'PRECISIÓN\nMÁXIMA',
                        subtitle: 'Control predictivo\nde fase',
                        color: Colors.purpleAccent,
                        score: 'ULTRA',
                        onTap: () => _goMode(PrecisionScreen(selectedSkin: _selectedSkin)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: () => _goMode(const SkinsScreen()),
                  icon: const Icon(Icons.palette, color: Colors.black),
                  label: const Text('SKINS', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan,
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TARJETA DE MODO
// ══════════════════════════════════════════════════════════════
class _ModeCard extends StatelessWidget {
  final String title, subtitle, score;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title, required this.subtitle,
    required this.score,  required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.75), color.withOpacity(0.25), Colors.black],
          ),
          boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 24, spreadRadius: 2)],
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 10),
                  Text(subtitle, textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Colors.white70)),
                  const SizedBox(height: 18),
                  Text(score, style: TextStyle(fontSize: 30, color: color, fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: color, blurRadius: 12)])),
                ],
              ),
            ),
            Positioned(
              bottom: 18, right: 20,
              child: Text('JUGAR ▶',
                  style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// LÓGICA DE MONEDAS
// ══════════════════════════════════════════════════════════════
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
// MODO 1: CRYO BALANCE
// ══════════════════════════════════════════════════════════════
class CryoBalanceScreen extends StatefulWidget {
  final String selectedSkin;
  const CryoBalanceScreen({super.key, this.selectedSkin = 'cyan'});
  @override State<CryoBalanceScreen> createState() => _CryoBalanceState();
}

class _CryoBalanceState extends State<CryoBalanceScreen>
    with SingleTickerProviderStateMixin {

  double _temperature = 0;
  int _combo = 0, _score = 0, _highScore = 0;
  bool _isFrozen = false;
  double _gameSpeed = 1.0, _coreScale = 1.0;
  bool _canRevive = true;

  Timer? _gameTimer, _freezeTimer;
  final Random _rng = Random();
  late AnimationController _ringCtrl;

  List<Map<String, dynamic>> _balls = [];
  List<Map<String, dynamic>> _particles = [];
  List<Map<String, dynamic>> _lightning = [];

  @override
  void initState() {
    super.initState();
    _loadHS();
    _ringCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _startGame();
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
      if (_isFrozen) return;
      setState(() {
        double diff = 1.0 + log(_score + 1) / 5;

        _temperature += (_rng.nextDouble() * 0.9 * diff * _gameSpeed) + (_combo * 0.05);

        if (_rng.nextDouble() < 0.09 * diff) {
          _balls.add({'x': _rng.nextDouble() * 280 + 40, 'y': -60.0,
            'speed': 4.5 + _rng.nextDouble() * 4.0 * diff, 'hit': false});
        }
        if (_balls.length > 25) _balls.removeAt(0);

        for (var b in _balls) {
          b['y'] += b['speed'];
          if (b['y'] > 340 && !b['hit']) { _temperature += 15.0; b['hit'] = true; HapticFeedback.vibrate(); }
        }
        _balls.removeWhere((b) => b['y'] > 620);

        for (var p in _particles) { p['x'] += p['vx']; p['y'] += p['vy']; p['alpha'] -= 0.04; }
        _particles.removeWhere((p) => p['alpha'] <= 0);

        if (_rng.nextDouble() < 0.08) {
          _lightning.add({'x': _rng.nextDouble() * 300, 'y': _rng.nextDouble() * 600, 'alpha': 1.0});
        }
        for (var l in _lightning) { l['alpha'] -= 0.08; }
        _lightning.removeWhere((l) => l['alpha'] <= 0);

        _temperature = _temperature.clamp(-120.0, 120.0);
        if (_temperature.abs() > 100) _gameOver();
      });
    });
  }

  void _onTapDown(TapDownDetails d) {
    final tapPos = d.localPosition;
    bool hitBall = false;

    setState(() {
      for (int i = _balls.length - 1; i >= 0; i--) {
        var b = _balls[i];
        double dx = (tapPos.dx - b['x'] - 22).abs();
        double dy = (tapPos.dy - b['y'] - 22).abs();

        if (dx < 40 && dy < 40 && !b['hit']) {
          _balls.removeAt(i);
          _spawnExplosion(tapPos.dx, tapPos.dy);
          _combo++;
          _score += 50 * _combo;
          _temperature = (_temperature - 15).clamp(-120.0, 120.0);
          HapticFeedback.mediumImpact();
          hitBall = true;
          break; 
        }
      }

      if (!hitBall) {
        _combo = (_combo - 1).clamp(0, 999);
        _temperature = (_temperature + 5).clamp(-120.0, 120.0);
      } else {
        if (_combo >= 8 && _combo % 4 == 0) _freeze();
      }
      _coreScale = 1.2;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _coreScale = 1.0);
    });
  }

  void _spawnExplosion(double x, double y) {
    for (int i = 0; i < 15; i++) {
      _particles.add({
        'x': x, 'y': y,
        'vx': (_rng.nextDouble() - 0.5) * 10,
        'vy': (_rng.nextDouble() - 0.5) * 10,
        'alpha': 1.0
      });
    }
  }

  void _freeze() {
    if (_isFrozen) return;
    setState(() { _isFrozen = true; _gameSpeed = 0.25; });
    _freezeTimer?.cancel();
    _freezeTimer = Timer(const Duration(milliseconds: 1700), () {
      if (mounted) setState(() { _isFrozen = false; _gameSpeed = 1.0; });
    });
  }

  void _gameOver() async {
    _gameTimer?.cancel(); _freezeTimer?.cancel(); _ringCtrl.stop();
    await _saveHS();
    int coins = await earnCoins(_score, _combo);
    if (!mounted) return;

    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('QUENCH DETECTADO',
            style: TextStyle(color: Colors.redAccent, fontSize: 28)),
        content: Text(
          'Score: $_score\nHigh: $_highScore\nCombo: $_combo\n\n+$coins CryoCoins 🪙',
          style: const TextStyle(color: Colors.white70, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); _restart(); },
            child: const Text('REINTENTAR', style: TextStyle(color: Colors.cyan))),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('MENÚ', style: TextStyle(color: Colors.white54))),
        ],
      ),
    );
  }

  void _restart() {
    setState(() {
      _temperature = 0; _combo = 0; _score = 0;
      _balls.clear(); _particles.clear(); _lightning.clear();
      _isFrozen = false; _gameSpeed = 1.0; _coreScale = 1.0; _canRevive = true;
    });
    _ringCtrl.repeat(); _startGame();
  }

  List<Color> get _gradient {
    if (_temperature.abs() > 70) return [Colors.redAccent, Colors.deepOrange];
    if (_temperature.abs() > 40) return [Colors.orange, Colors.amber];
    return getSkinColors(widget.selectedSkin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isFrozen ? Colors.blueGrey.shade900 : Colors.black,
      body: GestureDetector(
        onTapDown: _onTapDown,
        child: Stack(children: [
          Positioned(top: 50, left: 20,
            child: Text('${_temperature.toStringAsFixed(1)} μK',
              style: TextStyle(fontSize: 48, color: _gradient.first, fontWeight: FontWeight.bold))),
          Positioned(top: 50, right: 20,
            child: Text('$_score', style: const TextStyle(fontSize: 36, color: Colors.white))),
          Positioned(top: 100, right: 20,
            child: Text('×$_combo',
              style: TextStyle(fontSize: 36, color: _combo >= 8 ? Colors.purpleAccent : Colors.cyan))),
          Center(
            child: ScaleTransition(
              scale: AlwaysStoppedAnimation(_coreScale),
              child: RotationTransition(
                turns: _ringCtrl,
                child: Container(
                  width: 215, height: 215,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: _gradient),
                    boxShadow: [BoxShadow(
                      color: _gradient.first.withOpacity(0.9),
                      blurRadius: 70 + (_combo * 2).toDouble(), spreadRadius: 5)],
                  ),
                  child: const Center(child: Text('PHOENIX\nCORE',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
                ),
              ),
            ),
          ),
          ..._balls.map((b) => Positioned(left: b['x'], top: b['y'],
            child: Container(width: 44, height: 44,
              decoration: BoxDecoration(
                color: b['hit'] ? Colors.red.withOpacity(0.3) : Colors.redAccent, 
                shape: BoxShape.circle,
                boxShadow: [if(!b['hit']) const BoxShadow(color: Colors.red, blurRadius: 10)]
              )))),
          ..._particles.map((p) => Positioned(left: p['x'], top: p['y'],
            child: Opacity(opacity: p['alpha'],
              child: Container(width: 6, height: 6,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))))),
          if (_isFrozen)
            Container(color: Colors.cyan.withOpacity(0.13),
              child: const Center(child: Text('FREEZE',
                style: TextStyle(fontSize: 54, color: Colors.cyan, fontWeight: FontWeight.bold)))),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _gameTimer?.cancel(); _freezeTimer?.cancel();
    _ringCtrl.dispose();
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

class _HighSpeedState extends State<HighSpeedScreen>
    with SingleTickerProviderStateMixin {

  double _temperature = 0;
  int _combo = 0, _score = 0, _multiplier = 1, _highScore = 0;
  bool _isFrozen = false;
  double _gameSpeed = 1.0, _coreScale = 1.0;
  bool _canRevive = true;

  Timer? _gameTimer, _freezeTimer;
  final Random _rng = Random();
  late AnimationController _ringCtrl;

  List<Map<String, dynamic>> _balls = [];
  List<Map<String, dynamic>> _particles = [];
  List<Map<String, dynamic>> _lightning = [];

  @override
  void initState() {
    super.initState();
    _loadHS();
    _ringCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _startGame();
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
        double diff = 1.0 + log(_score + 1) / 3;
        _temperature += (_rng.nextDouble() * 1.8 * diff * _gameSpeed) + (_combo * 0.1);

        if (_rng.nextDouble() < 0.14 * diff) {
          _balls.add({'x': _rng.nextDouble() * 280 + 40, 'y': -60.0,
            'speed': 6.5 + _rng.nextDouble() * 6.0 * diff, 'hit': false});
        }
        if (_balls.length > 25) _balls.removeAt(0);

        for (var b in _balls) {
          b['y'] += b['speed'];
          if (b['y'] > 340 && !b['hit']) { _temperature += 20.0; b['hit'] = true; HapticFeedback.vibrate(); }
        }
        _balls.removeWhere((b) => b['y'] > 620);

        for (var p in _particles) { p['x'] += p['vx']; p['y'] += p['vy']; p['alpha'] -= 0.05; }
        _particles.removeWhere((p) => p['alpha'] <= 0);

        if (_multiplier != 1 + (_combo ~/ 5)) HapticFeedback.mediumImpact();
        _multiplier = 1 + (_combo ~/ 5);
        _temperature = _temperature.clamp(-120.0, 120.0);
        if (_temperature.abs() > 100) _gameOver();
      });
    });
  }

  void _onTapDown(TapDownDetails d) {
    final tapPos = d.localPosition;
    bool hitBall = false;

    setState(() {
      for (int i = _balls.length - 1; i >= 0; i--) {
        var b = _balls[i];
        double dx = (tapPos.dx - b['x'] - 22).abs();
        double dy = (tapPos.dy - b['y'] - 22).abs();

        if (dx < 50 && dy < 50 && !b['hit']) {
          _balls.removeAt(i);
          _spawnExplosion(tapPos.dx, tapPos.dy);
          _combo++;
          _score += (100 * _combo) * _multiplier;
          _temperature = (_temperature - 20).clamp(-120.0, 120.0);
          HapticFeedback.heavyImpact();
          hitBall = true;
          break;
        }
      }

      if (!hitBall) {
        _combo = 0;
        _temperature += 10;
      } else {
        if (_combo >= 6 && _combo % 3 == 0) _freeze();
      }
      _coreScale = 1.3;
    });

    Future.delayed(const Duration(milliseconds: 90), () {
      if (mounted) setState(() => _coreScale = 1.0);
    });
  }

  void _spawnExplosion(double x, double y) {
    for (int i = 0; i < 20; i++) {
      _particles.add({
        'x': x, 'y': y,
        'vx': (_rng.nextDouble() - 0.5) * 15,
        'vy': (_rng.nextDouble() - 0.5) * 15,
        'alpha': 1.0
      });
    }
  }

  void _freeze() {
    if (_isFrozen) return;
    setState(() { _isFrozen = true; _gameSpeed = 0.22; });
    _freezeTimer?.cancel();
    _freezeTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() { _isFrozen = false; _gameSpeed = 1.0; });
    });
  }

  void _gameOver() async {
    _gameTimer?.cancel(); _freezeTimer?.cancel(); _ringCtrl.stop();
    await _saveHS();
    int coins = await earnCoins(_score, _combo);
    if (!mounted) return;

    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('VELOCIDAD MÁXIMA',
            style: TextStyle(color: Colors.orangeAccent, fontSize: 28)),
        content: Text(
          'Score: $_score\nHigh: $_highScore\nCombo: $_combo\n×$_multiplier\n\n+$coins CryoCoins 🪙',
          style: const TextStyle(color: Colors.white70, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); _restart(); },
            child: const Text('REINTENTAR', style: TextStyle(color: Colors.orange))),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('MENÚ', style: TextStyle(color: Colors.white54))),
        ],
      ),
    );
  }

  void _restart() {
    setState(() {
      _temperature = 0; _combo = 0; _score = 0; _multiplier = 1;
      _balls.clear(); _particles.clear(); _lightning.clear();
      _isFrozen = false; _gameSpeed = 1.0; _coreScale = 1.0; _canRevive = true;
    });
    _ringCtrl.repeat(); _startGame();
  }

  List<Color> get _gradient {
    if (_temperature.abs() > 50) return [Colors.orangeAccent, Colors.redAccent];
    return getSkinColors(widget.selectedSkin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isFrozen ? Colors.blueGrey.shade900 : Colors.black,
      body: GestureDetector(
        onTapDown: _onTapDown,
        child: Stack(children: [
          Positioned(top: 50, left: 20,
            child: Text('${_temperature.toStringAsFixed(1)} μK',
              style: TextStyle(fontSize: 46, color: _gradient.first, fontWeight: FontWeight.bold))),
          Positioned(top: 50, right: 20,
            child: Text('$_score', style: const TextStyle(fontSize: 34, color: Colors.white))),
          Positioned(top: 100, right: 20,
            child: Text('×$_multiplier',
              style: const TextStyle(fontSize: 38, color: Colors.purpleAccent))),
          Center(
            child: ScaleTransition(
              scale: AlwaysStoppedAnimation(_coreScale),
              child: RotationTransition(
                turns: _ringCtrl,
                child: Container(
                  width: 215, height: 215,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: _gradient),
                    boxShadow: [BoxShadow(
                      color: _gradient.first.withOpacity(0.9),
                      blurRadius: 70 + (_combo * 2).toDouble(), spreadRadius: 5)],
                  ),
                  child: const Center(child: Text('ALTA\nVELOCIDAD',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold))),
                ),
              ),
            ),
          ),
          ..._balls.map((b) => Positioned(left: b['x'], top: b['y'],
            child: Container(width: 44, height: 44,
              decoration: BoxDecoration(
                color: b['hit'] ? Colors.red.withOpacity(0.2) : Colors.redAccent, 
                shape: BoxShape.circle,
                boxShadow: [if(!b['hit']) const BoxShadow(color: Colors.orange, blurRadius: 15)]
              )))),
          ..._particles.map((p) => Positioned(left: p['x'], top: p['y'],
            child: Opacity(opacity: p['alpha'],
              child: Container(width: 7, height: 7,
                decoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle))))),
          if (_isFrozen)
            Container(color: Colors.cyan.withOpacity(0.13),
              child: const Center(child: Text('FREEZE',
                style: TextStyle(fontSize: 54, color: Colors.cyan, fontWeight: FontWeight.bold)))),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _gameTimer?.cancel(); _freezeTimer?.cancel();
    _ringCtrl.dispose();
    super.dispose();
  }
}

// ══════════════════════════════════════════════════════════════
// MODO 3: PRECISIÓN MÁXIMA
// ══════════════════════════════════════════════════════════════
class PrecisionScreen extends StatefulWidget {
  final String selectedSkin;
  const PrecisionScreen({super.key, this.selectedSkin = 'cyan'});
  @override State<PrecisionScreen> createState() => _PrecisionState();
}

class _PrecisionState extends State<PrecisionScreen>
    with SingleTickerProviderStateMixin {

  double _temperature = 0;
  int _combo = 0, _score = 0, _multiplier = 1, _highScore = 0;
  bool _isFrozen = false;
  double _gameSpeed = 1.0, _coreScale = 1.0;
  bool _canRevive = true;

  Timer? _gameTimer, _freezeTimer;
  final Random _rng = Random();
  late AnimationController _ringCtrl;

  List<Map<String, dynamic>> _balls = [];
  List<Map<String, dynamic>> _particles = [];
  List<Map<String, dynamic>> _floatingScores = [];
  List<Map<String, dynamic>> _lightning = [];

  @override
  void initState() {
    super.initState();
    _loadHS();
    _ringCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _startGame();
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
        double diff = 1.0 + log(_score + 1) / 5;
        _temperature += (_rng.nextDouble() * 0.9 * diff * _gameSpeed) + (_combo * 0.04);

        if (_rng.nextDouble() < 0.065 * diff) {
          _balls.add({'x': _rng.nextDouble() * 280 + 40, 'y': -60.0,
            'speed': 3.5 + _rng.nextDouble() * 3.5 * diff, 'hit': false});
        }
        if (_balls.length > 25) _balls.removeAt(0);

        for (var b in _balls) {
          b['y'] += b['speed'];
          if (b['y'] > 340 && !b['hit']) { _temperature += 25.0; b['hit'] = true; HapticFeedback.vibrate(); }
        }
        _balls.removeWhere((b) => b['y'] > 620);

        for (var p in _particles) { p['x'] += p['vx']; p['y'] += p['vy']; p['alpha'] -= 0.04; }
        _particles.removeWhere((p) => p['alpha'] <= 0);

        for (var f in _floatingScores) { f['y'] -= 2.2; f['alpha'] -= 0.03; }
        _floatingScores.removeWhere((f) => f['alpha'] <= 0);

        if (_rng.nextDouble() < 0.06) {
          _lightning.add({'x': _rng.nextDouble() * 300, 'y': _rng.nextDouble() * 600, 'alpha': 1.0});
        }
        for (var l in _lightning) { l['alpha'] -= 0.07; }
        _lightning.removeWhere((l) => l['alpha'] <= 0);

        _temperature = _temperature.clamp(-120.0, 120.0);
        if (_temperature.abs() > 100) _gameOver();
      });
    });
  }

  void _onTapDown(TapDownDetails d) {
    final tapPos = d.localPosition;
    bool hitBall = false;

    setState(() {
      for (int i = _balls.length - 1; i >= 0; i--) {
        var b = _balls[i];
        double dx = (tapPos.dx - b['x'] - 22).abs();
        double dy = (tapPos.dy - b['y'] - 22).abs();

        if (dx < 45 && dy < 45 && !b['hit']) {
          _balls.removeAt(i);
          _spawnExplosion(tapPos.dx, tapPos.dy);
          _combo++;
          int pts = (300 + _rng.nextInt(200)) * _multiplier;
          _score += pts;
          _floatingScores.add({'text': '+$pts', 'x': tapPos.dx, 'y': tapPos.dy, 'alpha': 1.0});
          _temperature = (_temperature - 25).clamp(-120.0, 120.0);
          HapticFeedback.heavyImpact();
          hitBall = true;
          break;
        }
      }

      if (!hitBall) {
        _multiplier = 1;
        _combo = 0;
      } else {
        _multiplier = (_multiplier + 1).clamp(1, 15);
        if (_combo >= 10 && _combo % 5 == 0) _freeze();
      }
      _coreScale = 1.4;
    });

    Future.delayed(const Duration(milliseconds: 110), () {
      if (mounted) setState(() => _coreScale = 1.0);
    });
  }

  void _spawnExplosion(double x, double y) {
    for (int i = 0; i < 25; i++) {
      _particles.add({
        'x': x, 'y': y,
        'vx': (_rng.nextDouble() - 0.5) * 12,
        'vy': (_rng.nextDouble() - 0.5) * 12,
        'alpha': 1.0
      });
    }
  }

  void _freeze() {
    if (_isFrozen) return;
    setState(() { _isFrozen = true; _gameSpeed = 0.18; });
    _freezeTimer?.cancel();
    _freezeTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() { _isFrozen = false; _gameSpeed = 1.0; });
    });
  }

  void _gameOver() async {
    _gameTimer?.cancel(); _freezeTimer?.cancel(); _ringCtrl.stop();
    await _saveHS();
    int coins = await earnCoins(_score, _combo);
    if (!mounted) return;

    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('PRECISIÓN MÁXIMA',
            style: TextStyle(color: Colors.cyanAccent, fontSize: 28)),
        content: Text(
          'Score: $_score\nHigh: $_highScore\nCombo: $_combo\n×$_multiplier\n\n+$coins CryoCoins 🪙',
          style: const TextStyle(color: Colors.white70, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); _restart(); },
            child: const Text('REINTENTAR', style: TextStyle(color: Colors.cyan))),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('MENÚ', style: TextStyle(color: Colors.white54))),
        ],
      ),
    );
  }

  void _restart() {
    setState(() {
      _temperature = 0; _combo = 0; _score = 0; _multiplier = 1;
      _balls.clear(); _particles.clear(); _floatingScores.clear(); _lightning.clear();
      _isFrozen = false; _gameSpeed = 1.0; _coreScale = 1.0; _canRevive = true;
    });
    _ringCtrl.repeat(); _startGame();
  }

  List<Color> get _gradient =>
    _isFrozen ? [Colors.lightBlueAccent, Colors.cyan] : getSkinColors(widget.selectedSkin);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isFrozen ? Colors.blueGrey.shade900 : Colors.black,
      body: GestureDetector(
        onTapDown: _onTapDown,
        child: Stack(children: [
          Positioned(top: 50, left: 20,
            child: Text('${_temperature.toStringAsFixed(1)} μK',
              style: TextStyle(fontSize: 46, color: _gradient.first, fontWeight: FontWeight.bold))),
          Positioned(top: 50, right: 20,
            child: Text('$_score', style: const TextStyle(fontSize: 34, color: Colors.white))),
          Positioned(top: 100, right: 20,
            child: Text('×$_multiplier',
              style: const TextStyle(fontSize: 44, color: Colors.purpleAccent))),
          Center(
            child: ScaleTransition(
              scale: AlwaysStoppedAnimation(_coreScale),
              child: RotationTransition(
                turns: _ringCtrl,
                child: Container(
                  width: 215, height: 215,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: _gradient),
                    boxShadow: [BoxShadow(
                      color: _gradient.first.withOpacity(0.9),
                      blurRadius: 70 + (_combo * 2).toDouble(), spreadRadius: 5)],
                  ),
                  child: const Center(child: Text('PRECISIÓN',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
                ),
              ),
            ),
          ),
          ..._balls.map((b) => Positioned(left: b['x'], top: b['y'],
            child: Container(width: 44, height: 44,
              decoration: BoxDecoration(
                color: b['hit'] ? Colors.red.withOpacity(0.1) : Colors.redAccent, 
                shape: BoxShape.circle,
                boxShadow: [if(!b['hit']) const BoxShadow(color: Colors.cyanAccent, blurRadius: 12)]
              )))),
          ..._particles.map((p) => Positioned(left: p['x'], top: p['y'],
            child: Opacity(opacity: p['alpha'],
              child: Container(width: 5, height: 5,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))))),
          ..._floatingScores.map((f) => Positioned(
            left: f['x'], top: f['y'],
            child: Opacity(opacity: f['alpha'],
              child: Text(f['text'],
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.cyanAccent))))),
          if (_isFrozen)
            Container(color: Colors.cyan.withOpacity(0.18),
              child: const Center(child: Text('FREEZE\nCONTROL PREDICTIVO',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 42, color: Colors.cyanAccent, fontWeight: FontWeight.bold)))),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _gameTimer?.cancel(); _freezeTimer?.cancel();
    _ringCtrl.dispose();
    super.dispose();
  }
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
    'cyan':     {'price': 0,    'desc': 'Clásico fresco'},
    'gold':     {'price': 500,  'desc': 'Oro eterno'},
    'electric': {'price': 1200, 'desc': 'Rayos eléctricos'},
    'plasma':   {'price': 800,  'desc': 'Plasma ardiente'},
    'void':     {'price': 2000, 'desc': 'Vacío estelar'},
  };

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _cryoCoins    = p.getInt('cryo_coins') ?? 0;
      _selectedSkin = p.getString('selected_skin') ?? 'cyan';
    });
  }

  Future<void> _buyOrSelect(String skin) async {
    final p = await SharedPreferences.getInstance();
    int price = _skins[skin]!['price'] as int;
    bool unlocked = price == 0 || (p.getBool('unlocked_$skin') ?? false);

    if (!unlocked && _cryoCoins >= price) {
      _cryoCoins -= price;
      await p.setInt('cryo_coins', _cryoCoins);
      await p.setBool('unlocked_$skin', true);
      unlocked = true;
    }

    if (unlocked) {
      await p.setString('selected_skin', skin);
      setState(() => _selectedSkin = skin);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('¡$skin activado! 🔥')));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Necesitas ${price - _cryoCoins} CryoCoins más')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Skins del Núcleo'), backgroundColor: Colors.cyan.shade900),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.monetization_on, color: Colors.amber, size: 30),
            const SizedBox(width: 8),
            Text('$_cryoCoins CryoCoins',
              style: const TextStyle(fontSize: 26, color: Colors.amber, fontWeight: FontWeight.bold)),
          ]),
        ),
        Expanded(
          child: ListView(children: _skins.keys.map((skin) {
            bool isSelected = _selectedSkin == skin;
            int price = _skins[skin]!['price'] as int;
            List<Color> colors = getSkinColors(skin);

            return Card(
              color: Colors.grey.shade900,
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: colors),
                    boxShadow: [BoxShadow(color: colors.first.withOpacity(0.7), blurRadius: 16)],
                  ),
                ),
                title: Text(skin.toUpperCase(),
                  style: TextStyle(color: colors.first, fontSize: 20, fontWeight: FontWeight.bold)),
                subtitle: Text(_skins[skin]!['desc'],
                  style: const TextStyle(color: Colors.white70)),
                trailing: isSelected
                  ? const Icon(Icons.check_circle, color: Colors.greenAccent, size: 28)
                  : Text(price == 0 ? 'GRATIS' : '$price 🪙',
                      style: TextStyle(
                        color: price == 0 ? Colors.greenAccent : Colors.amber,
                        fontSize: 16, fontWeight: FontWeight.bold)),
                onTap: () => _buyOrSelect(skin),
              ),
            );
          }).toList()),
        ),
      ]),
    );
  }
}
