import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // MobileAds.instance.initialize(); // Se mantiene para cuando configures tus IDs
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
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _cryoCoins   = prefs.getInt('cryo_coins') ?? 0;
        _highScore   = prefs.getInt('cryo_highscore') ?? 0;
        _selectedSkin = prefs.getString('selected_skin') ?? 'cyan';
      });
    } catch (e) {
      debugPrint("Error inicializando SharedPreferences: $e");
    }
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

Future<int> earnCoins(int score, int combo) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    int earned = (score ~/ 2) + (combo * 10);
    if (combo >= 8)   earned += 50;
    if (score > 5000) earned += 100;
    int current = (prefs.getInt('cryo_coins') ?? 0) + earned;
    await prefs.setInt('cryo_coins', current);
    return earned;
  } catch (e) {
    return 0;
  }
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
  final AudioPlayer _audio = AudioPlayer();
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
    // Se corrigen las llamadas para que no crasheen si MobileAds no está init
    try {
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
    } catch (e) {
      debugPrint("Ads no disponibles");
    }
  }

  void _startGame() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 45), (_) {
      if (_isFrozen) return;
      if (!mounted) return;
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

  void _onTap(TapDownDetails d) async {
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
    
    try {
      await _audio.play(AssetSource('sounds/tap.wav'));
    } catch (_) {}
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
    try {
      await _audio.play(AssetSource('sounds/quench.wav'));
    } catch (_) {}
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
    try {
      _rewardedAd?.show(onUserEarnedReward: (_, __) {
        _score *= 2;
        setState(() { _temperature = -30; _combo = (_combo / 2).floor();
          _isFrozen = true; _canRevive = false; });
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) { setState(() => _isFrozen = false); _startGame(); }
        });
      });
      _rewardedAd = null; _loadAds();
    } catch (e) {
      _restart();
    }
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
    _ringCtrl.dispose(); _audio.dispose();
    _rewardedAd?.dispose(); _interstitialAd?.dispose();
    super.dispose();
  }
}
// ══════════════════════════════════════════════════════════════
// MODO 2: HIGH SPEED (REACCIÓN PURA)
// ══════════════════════════════════════════════════════════════
class HighSpeedScreen extends StatefulWidget {
  final String selectedSkin;
  const HighSpeedScreen({super.key, required this.selectedSkin});
  @override State<HighSpeedScreen> createState() => _HighSpeedState();
}

class _HighSpeedState extends State<HighSpeedScreen> with SingleTickerProviderStateMixin {
  int _score = 0, _combo = 0;
  double _targetY = 0;
  bool _isActive = false;
  Timer? _timer;
  final Random _rng = Random();
  final AudioPlayer _audio = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _startMode();
  }

  void _startMode() {
    _timer = Timer.periodic(Duration(milliseconds: (800 - (_score ~/ 100)).clamp(300, 800)), (_) {
      if (!mounted) return;
      setState(() {
        _targetY = _rng.nextDouble() * 400 + 100;
        _isActive = true;
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _isActive) {
          setState(() { _isActive = false; _combo = 0; });
        }
      });
    });
  }

  void _handleTap() {
    if (_isActive) {
      HapticFeedback.lightImpact();
      setState(() {
        _isActive = false;
        _combo++;
        _score += 100 * _combo;
      });
      try { _audio.play(AssetSource('sounds/hit.wav')); } catch (_) {}
    } else {
      _gameOver();
    }
  }

  void _gameOver() async {
    _timer?.cancel();
    int coins = await earnCoins(_score, _combo);
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('FUERA DE SINCRONÍA', style: TextStyle(color: Colors.orangeAccent)),
        content: Text('Puntaje: $_score\nMonedas: +$coins'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    ).then((_) => Navigator.pop(context));
  }

  @override
  Widget build(BuildContext context) {
    List<Color> colors = getSkinColors(widget.selectedSkin);
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (_) => _handleTap(),
        child: Stack(
          children: [
            Positioned(top: 60, left: 20, child: Text('SCORE: $_score', style: const TextStyle(fontSize: 30, color: Colors.white))),
            if (_isActive)
              Positioned(
                top: _targetY,
                left: MediaQuery.of(context).size.width / 2 - 40,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: colors),
                    boxShadow: [BoxShadow(color: colors.first, blurRadius: 20)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() { _timer?.cancel(); _audio.dispose(); super.dispose(); }
}

// ══════════════════════════════════════════════════════════════
// MODO 3: PRECISION MÁXIMA (CONTROL DE LAZO)
// ══════════════════════════════════════════════════════════════
class PrecisionScreen extends StatefulWidget {
  final String selectedSkin;
  const PrecisionScreen({super.key, required this.selectedSkin});
  @override State<PrecisionScreen> createState() => _PrecisionState();
}

class _PrecisionState extends State<PrecisionScreen> {
  double _currentVal = 50.0;
  double _targetVal = 50.0;
  int _points = 0;
  Timer? _timer;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      setState(() {
        _currentVal += (_rng.nextDouble() - 0.5) * 4;
        if ((_currentVal - _targetVal).abs() < 5) {
          _points++;
          if (t.tick % 40 == 0) _targetVal = _rng.nextDouble() * 80 + 10;
        }
      });
      if (_currentVal < 0 || _currentVal > 100) _gameOver();
    });
  }

  void _gameOver() {
    _timer?.cancel();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('PRECISIÓN: $_points', style: const TextStyle(fontSize: 32, color: Colors.purpleAccent)),
          const SizedBox(height: 50),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(width: 300, height: 20, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10))),
                Positioned(left: _targetVal * 3, child: Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.green.withOpacity(0.5), shape: BoxShape.circle))),
                Positioned(left: _currentVal * 3, child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
              ],
            ),
          ),
          Slider(
            value: _currentVal.clamp(0, 100),
            min: 0, max: 100,
            onChanged: (v) => setState(() => _currentVal = v),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
}

// ══════════════════════════════════════════════════════════════
// PANTALLA DE SKINS (TIENDA Y SELECCIÓN)
// ══════════════════════════════════════════════════════════════
class SkinsScreen extends StatefulWidget {
  const SkinsScreen({super.key});
  @override State<SkinsScreen> createState() => _SkinsScreenState();
}

class _SkinsScreenState extends State<SkinsScreen> {
  int _cryoCoins = 0;
  String _selectedSkin = 'cyan';
  final Map<String, bool> _unlocked = {};

  final Map<String, Map<String, dynamic>> _skinData = {
    'cyan':     {'price': 0,    'desc': 'ESTÁNDAR CRIOGÉNICO'},
    'gold':     {'price': 1000, 'desc': 'EDICIÓN PLATINO'},
    'electric': {'price': 2500, 'desc': 'FLUJO DE ELECTRONES'},
    'plasma':   {'price': 5000, 'desc': 'ESTADO CUÁNTICO'},
    'void':     {'price': 10000,'desc': 'VACÍO ABSOLUTO'},
  };

  @override
  void initState() {
    super.initState();
    _loadSkins();
  }

  Future<void> _loadSkins() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _cryoCoins = p.getInt('cryo_coins') ?? 0;
      _selectedSkin = p.getString('selected_skin') ?? 'cyan';
      for (var key in _skinData.keys) {
        _unlocked[key] = key == 'cyan' ? true : (p.getBool('skin_$key') ?? false);
      }
    });
  }

  void _handleSkin(String key) async {
    final p = await SharedPreferences.getInstance();
    if (_unlocked[key] == true) {
      await p.setString('selected_skin', key);
      setState(() => _selectedSkin = key);
    } else if (_cryoCoins >= _skinData[key]!['price']) {
      setState(() {
        _cryoCoins -= _skinData[key]!['price'] as int;
        _unlocked[key] = true;
      });
      await p.setInt('cryo_coins', _cryoCoins);
      await p.setBool('skin_$key', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('SELECTOR DE NÚCLEO'), backgroundColor: Colors.black),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.monetization_on, color: Colors.amber),
                const SizedBox(width: 10),
                Text('$_cryoCoins', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber)),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15),
              itemCount: _skinData.length,
              itemBuilder: (context, index) {
                String key = _skinData.keys.elementAt(index);
                bool isLocked = !(_unlocked[key] ?? false);
                return GestureDetector(
                  onTap: () => _handleSkin(key),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _selectedSkin == key ? Colors.cyan : Colors.transparent, width: 3),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 50, height: 50, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: getSkinColors(key)))),
                        const SizedBox(height: 10),
                        Text(key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(isLocked ? '\$${_skinData[key]!['price']}' : 'DESBLOQUEADO', style: TextStyle(color: isLocked ? Colors.amber : Colors.green, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
// ══════════════════════════════════════════════════════════════
// MODO 3: PRECISION MÁXIMA - LÓGICA DE CONTROL DETALLADA
// ══════════════════════════════════════════════════════════════
class PrecisionScreen extends StatefulWidget {
  final String selectedSkin;
  const PrecisionScreen({super.key, required this.selectedSkin});
  @override State<PrecisionScreen> createState() => _PrecisionState();
}

class _PrecisionState extends State<PrecisionScreen> {
  // Variables de estado del Lazo de Control Criogénico
  double _currentVal = 50.0;
  double _targetVal = 50.0;
  double _errorInertia = 0.0;
  int _points = 0;
  int _multiplier = 1;
  bool _isStable = true;
  
  Timer? _timer;
  Timer? _targetTimer;
  final Random _rng = Random();
  final AudioPlayer _audio = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _startControlLoop();
    _startTargetDrift();
  }

  // Simulación de la deriva térmica del sensor
  void _startTargetDrift() {
    _targetTimer = Timer.periodic(const Duration(seconds: 3), (t) {
      if (!mounted) return;
      setState(() {
        _targetVal = 15.0 + _rng.nextDouble() * 70.0; // Rango de operación nominal
      });
    });
  }

  void _startControlLoop() {
    _timer = Timer.periodic(const Duration(milliseconds: 16), (t) { // 60fps Loop
      if (!mounted) return;
      setState(() {
        // Simulación de ruido térmico y fluctuación de presión
        double noise = (_rng.nextDouble() - 0.5) * 1.8;
        _currentVal += noise + _errorInertia;
        
        // El error acumulado genera inestabilidad (Simulando el Quench parcial)
        double diff = (_currentVal - _targetVal).abs();
        
        if (diff < 6.5) {
          _isStable = true;
          _points += 1 * _multiplier;
          if (_points % 500 == 0) _multiplier++;
        } else {
          _isStable = false;
          _multiplier = 1;
          // Inercia de error: si te alejas, el sistema tiende a descontrolarse
          _errorInertia += (_currentVal > _targetVal ? 0.05 : -0.05);
        }

        // Límites de seguridad del módulo
        if (_currentVal < 0 || _currentVal > 100) {
          _gameOver();
        }
      });
    });
  }

  void _adjustControl(double delta) {
    setState(() {
      _currentVal += delta;
      // La intervención manual reduce la inercia de error (Compensación de Latencia)
      _errorInertia *= 0.8; 
    });
    HapticFeedback.selectionClick();
  }

  void _gameOver() async {
    _timer?.cancel();
    _targetTimer?.cancel();
    int earned = await earnCoins(_points, _multiplier);
    
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text("PÉRDIDA DE VACÍO", style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
        content: Text("Puntos de Precisión: $_points\nMultiplicador Máx: x$_multiplier\nCryoCoins: +$earned"),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text("VOLVER AL PANEL", style: TextStyle(color: Colors.cyan)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Indicador de estabilidad visual
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: _isStable ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.2),
                  blurRadius: 100, spreadRadius: 50
                )
              ]
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("STABILITY CONTROL", style: TextStyle(fontSize: 18, letterSpacing: 4, color: Colors.white.withOpacity(0.5))),
              const SizedBox(height: 10),
              Text("$_points", style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 40),
              // Representación del Lazo de Control
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(15)
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Línea de Objetivo (Target)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 500),
                        left: (MediaQuery.of(context).size.width - 80) * (_targetVal / 100),
                        child: Container(width: 4, height: 80, color: Colors.cyan.withOpacity(0.5)),
                      ),
                      // Cursor de Usuario (Current)
                      Positioned(
                        left: (MediaQuery.of(context).size.width - 80) * (_currentVal / 100),
                        child: Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isStable ? Colors.greenAccent : Colors.redAccent,
                            boxShadow: [BoxShadow(color: _isStable ? Colors.green : Colors.red, blurRadius: 15)]
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 60),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlBtn(icon: Icons.arrow_back_ios, onHold: () => _adjustControl(-1.5)),
                  _ControlBtn(icon: Icons.arrow_forward_ios, onHold: () => _adjustControl(1.5)),
                ],
              ),
              const SizedBox(height: 20),
              const Text("AJUSTE MICROMÉTRICO", style: TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _targetTimer?.cancel();
    super.dispose();
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onHold;
  const _ControlBtn({required this.icon, required this.onHold});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => Timer.periodic(const Duration(milliseconds: 50), (t) => onHold()),
      onTap: onHold,
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white10)
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }
}
