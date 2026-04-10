import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
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
                        subtitle: 'Mantén el equilibrio\no sufre el desastre',
                        color: Colors.cyan,
                        score: '58,000 ×14',
                        onTap: () => _goMode(CryoBalanceScreen(selectedSkin: _selectedSkin)),
                      ),
                      _ModeCard(
                        title: 'ALTÍSIMA\nVELOCIDAD',
                        subtitle: 'Tapa en el\nmomento perfecto',
                        color: Colors.orangeAccent,
                        score: '26,450 ×4',
                        onTap: () => _goMode(HighSpeedScreen(selectedSkin: _selectedSkin)),
                      ),
                      _ModeCard(
                        title: 'PRECISIÓN\nMÁXIMA',
                        subtitle: 'Desata el caos\nen FREEZE',
                        color: Colors.purpleAccent,
                        score: '119.3 μK ×10',
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
  int _gamesPlayed = 0;

  Timer? _gameTimer, _freezeTimer;
  final Random _rng = Random();
  late AnimationController _ringCtrl;

  List<Map<String, dynamic>> _balls = [];
  List<Map<String, dynamic>> _particles = [];
  List<Map<String, dynamic>> _lightning = [];

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

  @override
  void initState() {
    super.initState();
    _loadHS();
    _loadAds();
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

  void _loadAds() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (_) => _rewardedAd = null,
      ),
    );
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  void _startGame() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 45), (_) {
      if (_isFrozen) return;
      setState(() {
        double diff = 1.0 + log(_score + 1) / 5;

        _temperature += (_rng.nextDouble() * 0.9 * diff * _gameSpeed) + (_combo * 0.06);

        if (_rng.nextDouble() < 0.09 * diff) {
          _balls.add({'x': _rng.nextDouble() * 280 + 40, 'y': -60.0,
            'speed': 4.5 + _rng.nextDouble() * 4.0 * diff, 'hit': false});
        }
        if (_balls.length > 25) _balls.removeAt(0);

        for (var b in _balls) {
          b['y'] += b['speed'];
          if (b['y'] > 340 && !b['hit']) { _temperature += 10.0; b['hit'] = true; }
        }
        _balls.removeWhere((b) => b['y'] > 620);

        for (var p in _particles) { p['y'] -= p['speed']; p['alpha'] -= 0.04; }
        _particles.removeWhere((p) => p['alpha'] <= 0);
        if (_particles.length > 80) _particles.removeAt(0);

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

  void _onTap(TapDownDetails d) {
    HapticFeedback.mediumImpact();
    double best = 0;
    for (var b in _balls) {
      if (b['hit']) continue;
      double dist = (b['y'] - 340).abs();
      if (dist < 88) best = max(best, (88 - dist) / 88);
    }
    double cooling = 12 + best * 26;
    setState(() {
      _temperature = (_temperature - cooling).clamp(-120.0, 120.0);
      if (best > 0.80) {
        HapticFeedback.heavyImpact(); _combo++; _score += 32 * _combo; _spawnParticles(20);
      } else if (best > 0.50) {
        _combo++; _score += 16 * _combo; _spawnParticles(10);
      } else {
        _combo = (_combo - 2).clamp(0, 9999);
      }
      _coreScale = 1.35;
      if (_combo >= 8 && _combo % 4 == 0) _freeze();
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _coreScale = 1.0);
    });
  }

  void _spawnParticles(int n) {
    for (int i = 0; i < n; i++) {
      _particles.add({'x': 130 + _rng.nextDouble() * 110 - 55, 'y': 340.0,
        'speed': 3.8 + _rng.nextDouble() * 3.8, 'alpha': 1.0});
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
    _gamesPlayed++;
    if (_gamesPlayed % 3 == 0) { _interstitialAd?.show(); _loadAds(); }
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
          if (_canRevive && _rewardedAd != null)
            TextButton(
              onPressed: () { Navigator.pop(context); _revive(); },
              child: const Text('VER ANUNCIO → x2 SCORE', style: TextStyle(color: Colors.greenAccent))),
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

  void _revive() {
    _rewardedAd?.show(onUserEarnedReward: (_, __) {
      _score *= 2;
      setState(() { _temperature = -30; _combo = (_combo / 2).floor();
        _isFrozen = true; _canRevive = false; });
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) { setState(() => _isFrozen = false); _startGame(); }
      });
    });
    _rewardedAd = null; _loadAds();
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
        onTapDown: _onTap,
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
              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)))),
          ..._particles.map((p) => Positioned(left: p['x'], top: p['y'],
            child: Opacity(opacity: p['alpha'],
              child: Container(width: 9, height: 9,
                decoration: const BoxDecoration(color: Colors.cyan, shape: BoxShape.circle))))),
          ..._lightning.map((l) => Positioned(left: l['x'], top: l['y'],
            child: Opacity(opacity: l['alpha'],
              child: Container(width: 2, height: 40, color: Colors.blueAccent)))),
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
    _rewardedAd?.dispose(); _interstitialAd?.dispose();
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
  int _gamesPlayed = 0;

  Timer? _gameTimer, _freezeTimer;
  final Random _rng = Random();
  late AnimationController _ringCtrl;

  List<Map<String, dynamic>> _balls = [];
  List<Map<String, dynamic>> _particles = [];
  List<Map<String, dynamic>> _lightning = [];

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

  @override
  void initState() {
    super.initState();
    _loadHS();
    _loadAds();
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

  void _loadAds() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (_) => _rewardedAd = null,
      ),
    );
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  void _startGame() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (_isFrozen) return;
      setState(() {
        double diff = 1.0 + log(_score + 1) / 3;
        _temperature += (_rng.nextDouble() * 1.8 * diff * _gameSpeed) + (_combo * 0.12);

        if (_rng.nextDouble() < 0.14 * diff) {
          _balls.add({'x': _rng.nextDouble() * 280 + 40, 'y': -60.0,
            'speed': 6.5 + _rng.nextDouble() * 6.0 * diff, 'hit': false});
        }
        if (_balls.length > 25) _balls.removeAt(0);

        for (var b in _balls) {
          b['y'] += b['speed'];
          if (b['y'] > 340 && !b['hit']) { _temperature += 10.0; b['hit'] = true; }
        }
        _balls.removeWhere((b) => b['y'] > 620);

        for (var p in _particles) { p['y'] -= p['speed']; p['alpha'] -= 0.045; }
        _particles.removeWhere((p) => p['alpha'] <= 0);
        if (_particles.length > 80) _particles.removeAt(0);

        if (_rng.nextDouble() < 0.10) {
          _lightning.add({'x': _rng.nextDouble() * 300, 'y': _rng.nextDouble() * 600, 'alpha': 1.0});
        }
        for (var l in _lightning) { l['alpha'] -= 0.08; }
        _lightning.removeWhere((l) => l['alpha'] <= 0);

        _multiplier = 1 + (_combo ~/ 4);
        _temperature = _temperature.clamp(-120.0, 120.0);
        if (_temperature.abs() > 100) _gameOver();
      });
    });
  }

  void _onTap(TapDownDetails d) {
    HapticFeedback.mediumImpact();
    double best = 0;
    for (var b in _balls) {
      if (b['hit']) continue;
      double dist = (b['y'] - 340).abs();
      if (dist < 88) best = max(best, (88 - dist) / 88);
    }
    double cooling = 10 + best * 22;
    setState(() {
      _temperature = (_temperature - cooling).clamp(-120.0, 120.0);
      if (best > 0.75) {
        HapticFeedback.heavyImpact(); _combo++; _score += (28 * _combo) * _multiplier; _spawnParticles(22);
      } else if (best > 0.45) {
        _combo++; _score += (14 * _combo) * _multiplier; _spawnParticles(12);
      } else {
        _combo = (_combo - 3).clamp(0, 9999);
      }
      _coreScale = 1.4;
      if (_combo >= 6 && _combo % 3 == 0) _freeze();
    });
    Future.delayed(const Duration(milliseconds: 90), () {
      if (mounted) setState(() => _coreScale = 1.0);
    });
  }

  void _spawnParticles(int n) {
    for (int i = 0; i < n; i++) {
      _particles.add({'x': 130 + _rng.nextDouble() * 110 - 55, 'y': 340.0,
        'speed': 4.5 + _rng.nextDouble() * 4.5, 'alpha': 1.0});
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
    _gamesPlayed++;
    if (_gamesPlayed % 3 == 0) { _interstitialAd?.show(); _loadAds(); }
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
          if (_canRevive && _rewardedAd != null)
            TextButton(
              onPressed: () { Navigator.pop(context); _revive(); },
              child: const Text('VER ANUNCIO → x2 SCORE', style: TextStyle(color: Colors.greenAccent))),
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

  void _revive() {
    _rewardedAd?.show(onUserEarnedReward: (_, __) {
      _score *= 2;
      setState(() { _temperature = -35; _combo = (_combo / 2).floor();
        _isFrozen = true; _canRevive = false; });
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) { setState(() => _isFrozen = false); _startGame(); }
      });
    });
    _rewardedAd = null; _loadAds();
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
        onTapDown: _onTap,
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
                  child: const Center(child: Text('ALTÍSIMA\nVELOCIDAD',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold))),
                ),
              ),
            ),
          ),
          ..._balls.map((b) => Positioned(left: b['x'], top: b['y'],
            child: Container(width: 44, height: 44,
              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)))),
          ..._particles.map((p) => Positioned(left: p['x'], top: p['y'],
            child: Opacity(opacity: p['alpha'],
              child: Container(width: 9, height: 9,
                decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle))))),
          ..._lightning.map((l) => Positioned(left: l['x'], top: l['y'],
            child: Opacity(opacity: l['alpha'],
              child: Container(width: 2, height: 40, color: Colors.orangeAccent)))),
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
    _rewardedAd?.dispose(); _interstitialAd?.dispose();
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
  int _gamesPlayed = 0;

  Timer? _gameTimer, _freezeTimer;
  final Random _rng = Random();
  late AnimationController _ringCtrl;

  List<Map<String, dynamic>> _balls = [];
  List<Map<String, dynamic>> _particles = [];
  List<Map<String, dynamic>> _floatingScores = [];
  List<Map<String, dynamic>> _lightning = [];

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

  @override
  void initState() {
    super.initState();
    _loadHS();
    _loadAds();
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

  void _loadAds() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (_) => _rewardedAd = null,
      ),
    );
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  void _startGame() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 45), (_) {
      if (_isFrozen) return;
      setState(() {
        double diff = 1.0 + log(_score + 1) / 5;
        _temperature += (_rng.nextDouble() * 0.9 * diff * _gameSpeed) + (_combo * 0.06);

        if (_rng.nextDouble() < 0.065 * diff) {
          _balls.add({'x': _rng.nextDouble() * 280 + 40, 'y': -60.0,
            'speed': 3.2 + _rng.nextDouble() * 3.0 * diff, 'hit': false});
        }
        if (_balls.length > 25) _balls.removeAt(0);

        for (var b in _balls) {
          b['y'] += b['speed'];
          if (b['y'] > 340 && !b['hit']) { _temperature += 10.0; b['hit'] = true; }
        }
        _balls.removeWhere((b) => b['y'] > 620);

        for (var p in _particles) { p['y'] -= p['speed']; p['alpha'] -= 0.038; }
        _particles.removeWhere((p) => p['alpha'] <= 0);
        if (_particles.length > 80) _particles.removeAt(0);

        for (var f in _floatingScores) { f['y'] -= 2.2; f['alpha'] -= 0.028; }
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

  void _onTap(TapDownDetails d) {
    HapticFeedback.mediumImpact();
    double best = 0;
    for (var b in _balls) {
      if (b['hit']) continue;
      double dist = (b['y'] - 340).abs();
      if (dist < 92) best = max(best, (92 - dist) / 92);
    }
    double cooling = 14 + best * 32;
    setState(() {
      _temperature = (_temperature - cooling).clamp(-120.0, 120.0);
      if (best > 0.82) {
        HapticFeedback.heavyImpact(); _combo++;
        int pts = (280 + _rng.nextInt(140)) * _multiplier;
        _score += pts;
        _floatingScores.add({'text': '+$pts', 'x': 110 + _rng.nextDouble() * 100,
          'y': 320.0, 'alpha': 1.0, 'color': Colors.cyanAccent});
        _spawnParticles(28);
        _multiplier = (_multiplier + 1).clamp(1, 12);
      } else if (best > 0.55) {
        _combo++;
        int pts = (110 + _rng.nextInt(80)) * _multiplier;
        _score += pts;
        _floatingScores.add({'text': '+$pts', 'x': 110 + _rng.nextDouble() * 100,
          'y': 320.0, 'alpha': 1.0, 'color': Colors.white});
        _spawnParticles(14);
        _multiplier = (_multiplier + 1).clamp(1, 12);
      } else {
        _combo = (_combo - 3).clamp(0, 9999); _multiplier = 1;
      }
      _coreScale = 1.45;
      if (_combo >= 10 && _combo % 5 == 0) _freeze();
    });
    Future.delayed(const Duration(milliseconds: 110), () {
      if (mounted) setState(() => _coreScale = 1.0);
    });
  }

  void _spawnParticles(int n) {
    for (int i = 0; i < n; i++) {
      _particles.add({'x': 130 + _rng.nextDouble() * 110 - 55, 'y': 340.0,
        'speed': 4.0 + _rng.nextDouble() * 4.0, 'alpha': 1.0});
    }
  }

  void _freeze() {
    if (_isFrozen) return;
    setState(() { _isFrozen = true; _gameSpeed = 0.18; _multiplier = 10; });
    _freezeTimer?.cancel();
    _freezeTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() { _isFrozen = false; _gameSpeed = 1.0; _multiplier = 1; });
    });
  }

  void _gameOver() async {
    _gameTimer?.cancel(); _freezeTimer?.cancel(); _ringCtrl.stop();
    await _saveHS();
    int coins = await earnCoins(_score, _combo);
    _gamesPlayed++;
    if (_gamesPlayed % 3 == 0) { _interstitialAd?.show(); _loadAds(); }
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
          if (_canRevive && _rewardedAd != null)
            TextButton(
              onPressed: () { Navigator.pop(context); _revive(); },
              child: const Text('VER ANUNCIO → x2 SCORE', style: TextStyle(color: Colors.greenAccent))),
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

  void _revive() {
    _rewardedAd?.show(onUserEarnedReward: (_, __) {
      _score *= 2;
      setState(() { _temperature = -25; _combo = (_combo / 2).floor();
        _multiplier = 1; _isFrozen = true; _canRevive = false; });
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) { setState(() => _isFrozen = false); _startGame(); }
      });
    });
    _rewardedAd = null; _loadAds();
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
        onTapDown: _onTap,
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
              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)))),
          ..._particles.map((p) => Positioned(left: p['x'], top: p['y'],
            child: Opacity(opacity: p['alpha'],
              child: Container(width: 9, height: 9,
                decoration: const BoxDecoration(color: Colors.cyan, shape: BoxShape.circle))))),
          ..._floatingScores.map((f) => Positioned(
            left: f['x'], top: f['y'],
            child: Opacity(opacity: f['alpha'],
              child: Text(f['text'],
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: f['color']))))),
          ..._lightning.map((l) => Positioned(left: l['x'], top: l['y'],
            child: Opacity(opacity: l['alpha'],
              child: Container(width: 2, height: 40, color: Colors.blueAccent)))),
          if (_isFrozen)
            Container(color: Colors.cyan.withOpacity(0.18),
              child: const Center(child: Text('FREEZE\nDESATA EL CAOS',
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
    _rewardedAd?.dispose(); _interstitialAd?.dispose();
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
