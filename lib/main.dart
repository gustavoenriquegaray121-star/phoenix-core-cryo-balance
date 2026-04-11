import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const PhoenixCoreApp());
}

// ══════════════════════════════════════════════════════════
//  COLORS & CONSTANTS
// ══════════════════════════════════════════════════════════
const Color cFire    = Color(0xFFFF5500);
const Color cIce     = Color(0xFF00DDFF);
const Color cGold    = Color(0xFFFFCC00);
const Color cDanger  = Color(0xFFFF1144);
const Color cShield  = Color(0xFF8855FF);
const Color cFrost   = Color(0xFFAAEEFF);
const Color cBg      = Color(0xFF010810);
const Color cWarlord = Color(0xFF4488FF);

const double kPhoenixSize = 28.0;
const double kEnemyR      = 20.0;
const double kBossR       = 48.0;
const double kNucleusR    = 36.0;
const double kCoreHeatPerHit       = 0.06;
const double kCoreHeatPerEnemyPass = 0.10;
const double kCombatDuration       = 28.0;

// ══════════════════════════════════════════════════════════
//  ENUMS
// ══════════════════════════════════════════════════════════
enum AppScreen  { intro, menu, playing, gameOver }
enum GamePhase  { combat, decision, boss }
enum EnemyKind  { interceptor, frigate, parasite, corrupter }

// ══════════════════════════════════════════════════════════
//  INTRO SYSTEM
// ══════════════════════════════════════════════════════════
class IntroScene {
  final String location;
  final String speaker;      // '' = no speaker box
  final String speakerColor; // 'gold','ice','red','white'
  final String dialogue;
  final IntroSceneType type;
  const IntroScene({
    required this.location,
    required this.speaker,
    required this.speakerColor,
    required this.dialogue,
    required this.type,
  });
}

enum IntroSceneType { cafeteria, hangar, enemySide, cockpit, battle }

const _introScenes = [
  IntroScene(
    location: 'CAFÉ ALTEA — BASE PHOENIX',
    speaker: 'GENERAL G-G',
    speakerColor: 'gold',
    dialogue:
        'Usuario. El Núcleo Cuántico debe llegar hoy al Cuadrante 7 de la Nebulosa de Orión.\nLa colonia Elysium se está quedando sin energía.\nSin ese núcleo… perdemos tres millones de personas en menos de 72 horas.',
    type: IntroSceneType.cafeteria,
  ),
  IntroScene(
    location: 'CAFÉ ALTEA — BASE PHOENIX',
    speaker: 'USUARIO',
    speakerColor: 'ice',
    dialogue: 'Entendido.\n¿Mi nave?',
    type: IntroSceneType.cafeteria,
  ),
  IntroScene(
    location: 'CAFÉ ALTEA — BASE PHOENIX',
    speaker: 'GENERAL G-G',
    speakerColor: 'gold',
    dialogue: 'Ya casi terminan las reparaciones.\nVe al hangar.',
    type: IntroSceneType.cafeteria,
  ),
  IntroScene(
    location: 'DOCK 7A — PHOENIX PROJECT',
    speaker: 'USUARIO',
    speakerColor: 'ice',
    dialogue:
        'Núcleo asegurado.\nSistemas en línea.\nPhoenix Project… listo para volar.',
    type: IntroSceneType.hangar,
  ),
  IntroScene(
    location: 'LADO ENEMIGO — UBICACIÓN DESCONOCIDA',
    speaker: 'THE FROZEN WARLORD',
    speakerColor: 'red',
    dialogue:
        'Phoenix Protocol…\npor eso perdí.\nAhora lo conozco.\nSé cómo bloquearlo.',
    type: IntroSceneType.enemySide,
  ),
  IntroScene(
    location: 'LADO ENEMIGO — UBICACIÓN DESCONOCIDA',
    speaker: 'THE FROZEN WARLORD',
    speakerColor: 'red',
    dialogue:
        'La próxima vez que nos encontremos…\nese pájaro no volverá a abrir sus alas.',
    type: IntroSceneType.enemySide,
  ),
  IntroScene(
    location: 'CABINA — NAVE PHOENIX',
    speaker: 'USUARIO',
    speakerColor: 'ice',
    dialogue: '¿Qué carajos…?\nEs él…\nThe Frozen Warlord.\nPensé que lo había destruido.',
    type: IntroSceneType.cockpit,
  ),
  IntroScene(
    location: 'NEBULOSA DE ORIÓN — CUADRANTE 7',
    speaker: 'USUARIO',
    speakerColor: 'ice',
    dialogue: 'Te vencí una vez…\nY te voy a vencer otra vez.',
    type: IntroSceneType.battle,
  ),
];

// ══════════════════════════════════════════════════════════
//  AUDIO MANAGER
// ══════════════════════════════════════════════════════════
class AudioManager {
  final _shoot  = AudioPlayer();
  final _alarm  = AudioPlayer();
  final _boom   = AudioPlayer();
  bool _alarmOn = false;

  Future<void> playShoot() async {
    try { await _shoot.stop(); await _shoot.play(AssetSource('sounds/tap.wav'), volume: 0.3); } catch (_) {}
  }

  Future<void> playExplosion() async {
    try {
      final p = AudioPlayer();
      await p.play(AssetSource('sounds/tap.wav'), volume: 0.7);
      p.onPlayerComplete.listen((_) => p.dispose());
    } catch (_) {}
  }

  Future<void> startAlarm() async {
    if (_alarmOn) return;
    _alarmOn = true;
    try { await _alarm.setReleaseMode(ReleaseMode.loop); await _alarm.play(AssetSource('sounds/quench.wav'), volume: 0.5); } catch (_) {}
  }

  Future<void> stopAlarm() async {
    _alarmOn = false;
    try { await _alarm.stop(); } catch (_) {}
  }

  Future<void> playQuench() async {
    try { await _boom.play(AssetSource('sounds/quench.wav'), volume: 1.0); } catch (_) {}
  }

  void dispose() { _shoot.dispose(); _alarm.dispose(); _boom.dispose(); }
}

// ══════════════════════════════════════════════════════════
//  DATA MODELS
// ══════════════════════════════════════════════════════════
class PlayerBuild {
  double damage, fireRate, maxEnergy, cooling, shieldEfficiency;
  List<String> modules;
  PlayerBuild({this.damage=10, this.fireRate=1.0, this.maxEnergy=100,
               this.cooling=1.0, this.shieldEfficiency=1.0, List<String>? modules})
      : modules = modules ?? [];
}

class Player {
  double x, energy=100, heat=0;
  bool shieldActive=false;
  double shieldTimer=0;
  PlayerBuild build;
  Player(this.x, {PlayerBuild? build})
      : build = build ?? PlayerBuild(),
        energy = build?.maxEnergy ?? 100;
}

class Enemy {
  double x, y, hp, maxHp, vx, vy;
  EnemyKind kind;
  bool dead=false;
  double hitFlash=0, actionTimer=0, animT=0;
  Enemy({required this.x, required this.y, required this.hp,
         required this.vx, this.vy=90, this.kind=EnemyKind.interceptor})
      : maxHp=hp;
}

class Bullet {
  double x, y, damage;
  bool isEnemy;
  Bullet(this.x, this.y, this.damage, {this.isEnemy=false});
}

class FloatingText {
  double x, y, life;
  String text; Color color;
  FloatingText(this.x, this.y, this.text, this.color) : life=1.0;
}

class Particle {
  double x, y, vx, vy, life, maxLife, size;
  Color color; bool isFrost;
  Particle({required this.x, required this.y, required this.vx, required this.vy,
            required this.life, required this.color, this.size=4, this.isFrost=false})
      : maxLife=life;
}

class UpgradeOption {
  final String title, description, emoji;
  final Color color;
  final void Function(PlayerBuild) apply;
  const UpgradeOption({required this.title, required this.description,
      required this.emoji, required this.color, required this.apply});
}

// ══════════════════════════════════════════════════════════
//  PHASE ENGINE
// ══════════════════════════════════════════════════════════
class PhaseEngine {
  GamePhase phase = GamePhase.combat;
  double timer=0; int cycleCount=0;

  void update(double dt, {required VoidCallback onDecision, required VoidCallback onBoss}) {
    timer += dt;
    if (phase==GamePhase.combat && timer>=kCombatDuration) {
      cycleCount++; timer=0;
      if (cycleCount%3==0) { phase=GamePhase.boss; onBoss(); }
      else { phase=GamePhase.decision; onDecision(); }
    }
  }
  void endDecision() { phase=GamePhase.combat; timer=0; }
  void endBoss()     { phase=GamePhase.combat; timer=0; }
  double get combatProgress => phase==GamePhase.combat ? (timer/kCombatDuration).clamp(0,1) : 1.0;
}

// ══════════════════════════════════════════════════════════
//  RESOURCE SYSTEM
// ══════════════════════════════════════════════════════════
class ResourceSystem {
  double energy=100, heat=0, entropy=0;

  void update(double dt, PlayerBuild b) {
    heat   = (heat   - 8*b.cooling*dt).clamp(0,100);
    energy = (energy + 4*dt).clamp(0,b.maxEnergy);
    entropy = (entropy + 0.3*dt).clamp(0,100);
    if (heat>85) energy -= 15*dt;
  }
  void applyShoot(PlayerBuild b) { energy-=2.5; heat+=4/b.cooling; entropy+=0.4; }
  bool   get overheating => heat>80;
  double get heatFrac    => heat/100;
  double get energyFrac  => (energy/100).clamp(0,1);
  double get entropyFrac => entropy/100;
}

// ══════════════════════════════════════════════════════════
//  AI ADAPT
// ══════════════════════════════════════════════════════════
class AIAdapt {
  double aggression=1.0, swarmDensity=1.0, counterFire=0.5;
  void analyze(PlayerBuild b) {
    if (b.damage>15)  aggression   = (aggression+0.15).clamp(1,3);
    if (b.fireRate>1.5) swarmDensity=(swarmDensity+0.20).clamp(1,3);
    if (b.shieldEfficiency>1.3) counterFire=(counterFire+0.30).clamp(0.5,2);
  }
  double get spawnInterval => (1.8/aggression).clamp(0.4,2.0);
  int    get waveSize      => (2+swarmDensity).round();
}

// ══════════════════════════════════════════════════════════
//  APP ROOT
// ══════════════════════════════════════════════════════════
class PhoenixCoreApp extends StatelessWidget {
  const PhoenixCoreApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    home: const AppRoot(),
  );
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});
  @override State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  AppScreen _screen = AppScreen.intro;
  int _score=0, _best=0;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance()
        .then((p) => setState(() => _best=p.getInt('best_v4')??0));
  }

  void _onIntroDone() => setState(() => _screen=AppScreen.menu);
  void _start()       => setState(() { _score=0; _screen=AppScreen.playing; });

  void _gameOver(int score) async {
    if (score>_best) {
      _best=score;
      final p = await SharedPreferences.getInstance();
      await p.setInt('best_v4',_best);
    }
    setState(() { _score=score; _screen=AppScreen.gameOver; });
  }

  @override
  Widget build(BuildContext context) => switch (_screen) {
    AppScreen.intro    => IntroScreen(onDone: _onIntroDone),
    AppScreen.menu     => MenuScreen(best: _best, onStart: _start),
    AppScreen.playing  => GameScreen(key: const ValueKey('g'), onGameOver: _gameOver),
    AppScreen.gameOver => GameOverScreen(score: _score, best: _best,
        onRestart: _start,
        onMenu: () => setState(() => _screen=AppScreen.menu)),
  };
}

// ══════════════════════════════════════════════════════════
//  INTRO SCREEN
// ══════════════════════════════════════════════════════════
class IntroScreen extends StatefulWidget {
  final VoidCallback onDone;
  const IntroScreen({super.key, required this.onDone});
  @override State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  int _sceneIndex = 0;
  int _charIndex  = 0;
  late AnimationController _typeCtrl;
  late String _currentText;
  bool _fullShown = false;

  @override
  void initState() {
    super.initState();
    _currentText = '';
    _typeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 40));
    _typeCtrl.addListener(_onTypeTick);
    _startScene();
  }

  void _startScene() {
    _charIndex  = 0;
    _currentText = '';
    _fullShown  = false;
    _typeCtrl.repeat();
  }

  void _onTypeTick() {
    final full = _introScenes[_sceneIndex].dialogue;
    if (_charIndex < full.length) {
      setState(() {
        _charIndex++;
        _currentText = full.substring(0, _charIndex);
      });
    } else {
      _typeCtrl.stop();
      setState(() => _fullShown = true);
    }
  }

  void _next() {
    if (!_fullShown) {
      // Skip to full text
      _typeCtrl.stop();
      setState(() {
        _currentText = _introScenes[_sceneIndex].dialogue;
        _fullShown = true;
      });
      return;
    }
    if (_sceneIndex < _introScenes.length - 1) {
      setState(() => _sceneIndex++);
      _startScene();
    } else {
      widget.onDone();
    }
  }

  @override
  void dispose() { _typeCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final scene  = _introScenes[_sceneIndex];
    final size   = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (_) => _next(),
        child: Stack(children: [
          // Scene background painter
          CustomPaint(
            painter: _IntroBgPainter(scene: scene, size: size),
            child: const SizedBox.expand(),
          ),
          // Location tag
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  border: Border.all(color: cGold.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(scene.location,
                    style: const TextStyle(
                        color: cGold, fontSize: 10,
                        fontFamily: 'Orbitron', letterSpacing: 2)),
              ),
            ),
          ),
          // Dialogue box
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _DialogueBox(
              speaker: scene.speaker,
              speakerColor: _speakerColor(scene.speakerColor),
              text: _currentText,
              fullShown: _fullShown,
              isLast: _sceneIndex == _introScenes.length - 1,
            ),
          ),
          // Scene counter
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: Text('${_sceneIndex+1}/${_introScenes.length}',
                style: TextStyle(color: Colors.white38, fontSize: 10,
                    fontFamily: 'Orbitron')),
          ),
        ]),
      ),
    );
  }

  Color _speakerColor(String s) => switch (s) {
    'gold'  => cGold,
    'ice'   => cIce,
    'red'   => cDanger,
    _       => Colors.white,
  };
}

class _DialogueBox extends StatelessWidget {
  final String speaker, text;
  final Color speakerColor;
  final bool fullShown, isLast;
  const _DialogueBox({required this.speaker, required this.speakerColor,
      required this.text, required this.fullShown, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(0),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.85), Colors.black.withOpacity(0.97)],
        ),
        border: Border(top: BorderSide(color: speakerColor.withOpacity(0.6), width: 1.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (speaker.isNotEmpty) ...[
          Row(children: [
            Container(width: 3, height: 16,
                decoration: BoxDecoration(color: speakerColor,
                    boxShadow: [BoxShadow(color: speakerColor, blurRadius: 6)])),
            const SizedBox(width: 8),
            Text(speaker, style: TextStyle(color: speakerColor, fontSize: 12,
                fontFamily: 'Orbitron', fontWeight: FontWeight.bold,
                shadows: [Shadow(color: speakerColor.withOpacity(0.6), blurRadius: 8)])),
          ]),
          const SizedBox(height: 10),
        ],
        Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 14,
                height: 1.6, fontFamily: 'Orbitron')),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (fullShown)
            Row(children: [
              Text(isLast ? 'INICIAR MISIÓN' : 'SIGUIENTE',
                  style: TextStyle(color: speakerColor, fontSize: 10,
                      fontFamily: 'Orbitron', letterSpacing: 1.5)),
              const SizedBox(width: 6),
              Icon(isLast ? Icons.rocket_launch : Icons.arrow_forward_ios,
                  color: speakerColor, size: 14),
            ])
          else
            Text('toca para continuar',
                style: TextStyle(color: Colors.white24, fontSize: 9,
                    fontFamily: 'Orbitron')),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  INTRO BACKGROUND PAINTER
// ══════════════════════════════════════════════════════════
class _IntroBgPainter extends CustomPainter {
  final IntroScene scene;
  final Size size;
  const _IntroBgPainter({required this.scene, required this.size});

  @override
  void paint(Canvas canvas, Size sz) {
    switch (scene.type) {
      case IntroSceneType.cafeteria:   _drawCafeteria(canvas, sz);
      case IntroSceneType.hangar:      _drawHangar(canvas, sz);
      case IntroSceneType.enemySide:   _drawEnemySide(canvas, sz);
      case IntroSceneType.cockpit:     _drawCockpit(canvas, sz);
      case IntroSceneType.battle:      _drawBattle(canvas, sz);
    }
  }

  void _drawCafeteria(Canvas canvas, Size sz) {
    // Warm dark interior
    canvas.drawRect(Rect.fromLTWH(0,0,sz.width,sz.height),
        Paint()..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [const Color(0xFF0D0A05), const Color(0xFF1A1208), const Color(0xFF0A0800)],
        ).createShader(Rect.fromLTWH(0,0,sz.width,sz.height)));

    // Window to space (upper area)
    final winRect = Rect.fromLTWH(sz.width*0.15, sz.height*0.05, sz.width*0.7, sz.height*0.32);
    canvas.drawRRect(RRect.fromRectAndRadius(winRect, const Radius.circular(8)),
        Paint()..shader = RadialGradient(
          colors: [const Color(0xFF0A1525), const Color(0xFF050A14)],
        ).createShader(winRect));
    // Galaxy spiral in window
    _drawGalaxy(canvas, Offset(sz.width*0.65, sz.height*0.15), 45);
    // Window frame
    canvas.drawRRect(RRect.fromRectAndRadius(winRect, const Radius.circular(8)),
        Paint()..color = const Color(0xFF3A3020).withOpacity(0.8)
          ..style = PaintingStyle.stroke..strokeWidth = 3);

    // Table surface
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(sz.width*0.1, sz.height*0.48, sz.width*0.8, sz.height*0.15),
        const Radius.circular(4)),
        Paint()..color = const Color(0xFF1A1208));

    // Coffee cup silhouette
    _drawCoffeeCup(canvas, Offset(sz.width*0.35, sz.height*0.52));

    // CAFÉ ALTEA sign
    _drawNeonSign(canvas, 'CAFÉ ALTEA', Offset(sz.width*0.28, sz.height*0.42),
        const Color(0xFFFF8800));

    // Atmospheric glow at bottom (dialogue area)
    canvas.drawRect(Rect.fromLTWH(0, sz.height*0.6, sz.width, sz.height*0.4),
        Paint()..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
        ).createShader(Rect.fromLTWH(0, sz.height*0.6, sz.width, sz.height*0.4)));
  }

  void _drawHangar(Canvas canvas, Size sz) {
    // Industrial dark hangar
    canvas.drawRect(Rect.fromLTWH(0,0,sz.width,sz.height),
        Paint()..color = const Color(0xFF080C10));

    // Ceiling lights
    for (int i = 0; i < 4; i++) {
      final lx = sz.width * (0.15 + i * 0.23);
      canvas.drawRect(Rect.fromLTWH(lx-15, 0, 30, 4),
          Paint()..color = const Color(0xFFCCDDFF).withOpacity(0.7));
      canvas.drawRect(Rect.fromLTWH(lx-30, 0, 60, 60),
          Paint()..shader = RadialGradient(
            center: Alignment.topCenter,
            colors: [const Color(0xFF334466).withOpacity(0.5), Colors.transparent],
          ).createShader(Rect.fromLTWH(lx-30, 0, 60, 60)));
    }

    // Floor markings
    final fp = Paint()..color = const Color(0xFFFFCC00).withOpacity(0.4)
      ..strokeWidth = 1.5..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTWH(sz.width*0.1, sz.height*0.55, sz.width*0.8, sz.height*0.2), fp);

    // DOCK 7A text on floor
    _drawText(canvas, 'DOCK 7A', Offset(sz.width*0.5, sz.height*0.72),
        const Color(0xFFFFCC00).withOpacity(0.5), 18);
    _drawText(canvas, 'PHOENIX PROJECT', Offset(sz.width*0.5, sz.height*0.78),
        const Color(0xFFFFCC00).withOpacity(0.3), 11);

    // Phoenix ship in hangar
    _drawPhoenixShipLarge(canvas, Offset(sz.width*0.5, sz.height*0.42), sz.width*0.45);

    // Sparks
    final rng = Random(42);
    for (int i = 0; i < 8; i++) {
      final sx = sz.width*(0.3 + rng.nextDouble()*0.4);
      final sy = sz.height*(0.35 + rng.nextDouble()*0.2);
      canvas.drawCircle(Offset(sx, sy), 2+rng.nextDouble()*3,
          Paint()..color = const Color(0xFFFFAA00).withOpacity(0.8)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }

    // Space visible through open hangar door
    final doorRect = Rect.fromLTWH(sz.width*0.2, sz.height*0.02, sz.width*0.6, sz.height*0.28);
    canvas.drawRect(doorRect, Paint()..color = const Color(0xFF020810));
    _drawStarfield(canvas, doorRect, 40);
    _drawGalaxy(canvas, Offset(sz.width*0.75, sz.height*0.12), 35);
  }

  void _drawEnemySide(Canvas canvas, Size sz) {
    // Dark alien biomechanical environment
    canvas.drawRect(Rect.fromLTWH(0,0,sz.width,sz.height),
        Paint()..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [const Color(0xFF040810), const Color(0xFF000A14), const Color(0xFF000408)],
        ).createShader(Rect.fromLTWH(0,0,sz.width,sz.height)));

    // Alien tech background structures
    _drawAlienStructures(canvas, sz);

    // THE FROZEN WARLORD — central figure
    _drawFrozenWarlord(canvas,
        Offset(sz.width*0.5, sz.height*0.32), sz.height*0.28);

    // Dark energy shields around him
    for (int i = 3; i >= 1; i--) {
      canvas.drawCircle(Offset(sz.width*0.5, sz.height*0.32),
          sz.height*0.16 + i*12,
          Paint()..color = cWarlord.withOpacity(0.04*i)
            ..style = PaintingStyle.stroke..strokeWidth = 1);
    }
  }

  void _drawCockpit(Canvas canvas, Size sz) {
    // Dark cockpit interior
    canvas.drawRect(Rect.fromLTWH(0,0,sz.width,sz.height),
        Paint()..color = const Color(0xFF080A0C));

    // Cockpit frame
    _drawCockpitFrame(canvas, sz);

    // Space through windshield
    final windshield = Rect.fromLTWH(sz.width*0.08, sz.height*0.08, sz.width*0.84, sz.height*0.45);
    canvas.drawRRect(RRect.fromRectAndRadius(windshield, const Radius.circular(12)),
        Paint()..color = const Color(0xFF020810));
    _drawStarfield(canvas, windshield, 60);

    // Planet visible
    canvas.drawCircle(Offset(sz.width*0.3, sz.height*0.28), 45,
        Paint()..shader = RadialGradient(
          colors: [const Color(0xFF2244AA), const Color(0xFF112233)],
        ).createShader(Rect.fromCircle(
            center: Offset(sz.width*0.3, sz.height*0.28), radius: 45)));

    // Enemy fleet appearing
    final rng = Random(7);
    for (int i = 0; i < 5; i++) {
      final ex = sz.width*(0.45 + rng.nextDouble()*0.45);
      final ey = sz.height*(0.12 + rng.nextDouble()*0.28);
      _drawAlienShipSmall(canvas, Offset(ex, ey), 12+rng.nextDouble()*8);
    }

    // HUD overlay on cockpit glass
    _drawCockpitHUD(canvas, sz);
  }

  void _drawBattle(Canvas canvas, Size sz) {
    // Space combat scene
    canvas.drawRect(Rect.fromLTWH(0,0,sz.width,sz.height),
        Paint()..color = const Color(0xFF010508));
    _drawStarfield(canvas, Rect.fromLTWH(0,0,sz.width,sz.height), 80);

    // Nebula
    canvas.drawOval(
        Rect.fromCenter(center: Offset(sz.width*0.6, sz.height*0.3),
            width: sz.width*0.8, height: sz.height*0.4),
        Paint()..color = const Color(0xFF330A44).withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40));

    // Phoenix ship (player) at bottom
    _drawPhoenixShipLarge(canvas, Offset(sz.width*0.5, sz.height*0.6), sz.width*0.3);

    // Warlord ship at top
    _drawWarlordShipLarge(canvas, Offset(sz.width*0.5, sz.height*0.2), sz.width*0.28);

    // Energy beams between them
    final beamPaint = Paint()
      ..color = cWarlord.withOpacity(0.5)
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawLine(Offset(sz.width*0.5, sz.height*0.35),
        Offset(sz.width*0.5, sz.height*0.52), beamPaint);
  }

  // ── HELPER DRAWERS ──────────────────────────────────────
  void _drawGalaxy(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(center, radius,
        Paint()..color = Colors.white.withOpacity(0.05)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius*0.8));
    canvas.drawCircle(center, radius*0.4,
        Paint()..color = const Color(0xFFCCDDFF).withOpacity(0.15)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius*0.3));
    canvas.drawCircle(center, radius*0.1,
        Paint()..color = Colors.white.withOpacity(0.6));
  }

  void _drawStarfield(Canvas canvas, Rect rect, int count) {
    final rng = Random(rect.width.toInt());
    final p = Paint()..color = Colors.white.withOpacity(0.6);
    for (int i = 0; i < count; i++) {
      canvas.drawCircle(
          Offset(rect.left + rng.nextDouble()*rect.width,
                 rect.top  + rng.nextDouble()*rect.height),
          rng.nextDouble()*1.2, p);
    }
  }

  void _drawCoffeeCup(Canvas canvas, Offset pos) {
    final p = Paint()..color = const Color(0xFF3A2810);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: pos, width: 28, height: 32),
        const Radius.circular(4)), p);
    canvas.drawArc(Rect.fromCenter(center: Offset(pos.dx+18, pos.dy-2), width:14, height:18),
        -0.5, pi, false,
        Paint()..color = const Color(0xFF3A2810)..style=PaintingStyle.stroke..strokeWidth=2.5);
    canvas.drawOval(Rect.fromCenter(center: pos.translate(0,-16), width:28, height:8),
        Paint()..color = const Color(0xFF1A0C06));
  }

  void _drawNeonSign(Canvas canvas, String text, Offset pos, Color color) {
    canvas.drawRect(
        Rect.fromCenter(center: pos, width: 110, height: 26),
        Paint()..color = Colors.black.withOpacity(0.7));
    canvas.drawRect(
        Rect.fromCenter(center: pos, width: 110, height: 26),
        Paint()..color = color.withOpacity(0.5)..style=PaintingStyle.stroke..strokeWidth=1.5);
    _drawText(canvas, text, pos, color, 10);
  }

  void _drawPhoenixShipLarge(Canvas canvas, Offset center, double width) {
    final h = width * 1.2;
    // Engine glow
    canvas.drawCircle(Offset(center.dx, center.dy + h*0.3),
        width*0.15, Paint()..color = cFire.withOpacity(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));

    // Body gradient
    final bodyPaint = Paint()..shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [const Color(0xFF888888), const Color(0xFF444444)],
    ).createShader(Rect.fromCenter(center: center, width: width, height: h));

    final body = Path()
      ..moveTo(center.dx, center.dy - h*0.45)
      ..lineTo(center.dx + width*0.25, center.dy + h*0.1)
      ..lineTo(center.dx + width*0.15, center.dy + h*0.35)
      ..lineTo(center.dx, center.dy + h*0.25)
      ..lineTo(center.dx - width*0.15, center.dy + h*0.35)
      ..lineTo(center.dx - width*0.25, center.dy + h*0.1)
      ..close();
    canvas.drawPath(body, bodyPaint);

    // Wings
    final wingP = Paint()..color = const Color(0xFF555555);
    final lw = Path()
      ..moveTo(center.dx - width*0.2, center.dy)
      ..lineTo(center.dx - width*0.5, center.dy + h*0.15)
      ..lineTo(center.dx - width*0.4, center.dy + h*0.3)
      ..lineTo(center.dx - width*0.15, center.dy + h*0.2)
      ..close();
    final rw = Path()
      ..moveTo(center.dx + width*0.2, center.dy)
      ..lineTo(center.dx + width*0.5, center.dy + h*0.15)
      ..lineTo(center.dx + width*0.4, center.dy + h*0.3)
      ..lineTo(center.dx + width*0.15, center.dy + h*0.2)
      ..close();
    canvas.drawPath(lw, wingP);
    canvas.drawPath(rw, wingP);

    // Phoenix emblem on hull
    canvas.drawCircle(Offset(center.dx, center.dy),  width*0.12,
        Paint()..color = cFire.withOpacity(0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(Offset(center.dx, center.dy), width*0.06,
        Paint()..color = Colors.white.withOpacity(0.9));

    // G-G badge
    _drawText(canvas, 'G-G', Offset(center.dx, center.dy + h*0.05),
        cGold.withOpacity(0.7), 9);

    // Engine flames
    final flame = Paint()..shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [const Color(0xFFFFDD00), cFire, Colors.transparent],
    ).createShader(Rect.fromLTWH(center.dx-8, center.dy+h*0.25, 16, 28));
    final fp = Path()
      ..moveTo(center.dx-8, center.dy+h*0.26)
      ..lineTo(center.dx, center.dy+h*0.26+28)
      ..lineTo(center.dx+8, center.dy+h*0.26);
    canvas.drawPath(fp, flame);
  }

  void _drawFrozenWarlord(Canvas canvas, Offset center, double height) {
    final w = height * 0.55;

    // Body glow (ice aura)
    canvas.drawCircle(center, height*0.55,
        Paint()..color = cWarlord.withOpacity(0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));

    // Legs
    final legP = Paint()..color = const Color(0xFF1A3A5A);
    canvas.drawRect(Rect.fromLTWH(center.dx-w*0.22, center.dy+height*0.28, w*0.18, height*0.35), legP);
    canvas.drawRect(Rect.fromLTWH(center.dx+w*0.04, center.dy+height*0.28, w*0.18, height*0.35), legP);

    // Torso
    final torsoPath = Path()
      ..moveTo(center.dx-w*0.3, center.dy+height*0.28)
      ..lineTo(center.dx-w*0.25, center.dy-height*0.05)
      ..lineTo(center.dx, center.dy-height*0.1)
      ..lineTo(center.dx+w*0.25, center.dy-height*0.05)
      ..lineTo(center.dx+w*0.3, center.dy+height*0.28)
      ..close();
    canvas.drawPath(torsoPath,
        Paint()..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [const Color(0xFF2255AA), const Color(0xFF112244)],
        ).createShader(Rect.fromCenter(center: center, width: w, height: height)));

    // Arms
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx-w*0.5, center.dy-height*0.02, w*0.18, height*0.3),
        const Radius.circular(4)),
        Paint()..color = const Color(0xFF1A3A5A));
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx+w*0.32, center.dy-height*0.02, w*0.18, height*0.3),
        const Radius.circular(4)),
        Paint()..color = const Color(0xFF1A3A5A));

    // Head with crown spikes
    canvas.drawCircle(Offset(center.dx, center.dy-height*0.18), w*0.22,
        Paint()..color = const Color(0xFF1A3055));
    // Crown spikes
    for (int i = -2; i <= 2; i++) {
      final sx = center.dx + i*w*0.08;
      final baseY = center.dy - height*0.35;
      final tipY  = baseY - height*0.06 - i.abs()*height*0.02;
      canvas.drawLine(Offset(sx-w*0.03, baseY), Offset(sx, tipY),
          Paint()..color = cWarlord.withOpacity(0.9)..strokeWidth=2.5);
      canvas.drawLine(Offset(sx+w*0.03, baseY), Offset(sx, tipY),
          Paint()..color = cWarlord.withOpacity(0.9)..strokeWidth=2.5);
    }

    // Eyes glow
    canvas.drawCircle(Offset(center.dx-w*0.07, center.dy-height*0.19), 4,
        Paint()..color = cWarlord
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawCircle(Offset(center.dx+w*0.07, center.dy-height*0.19), 4,
        Paint()..color = cWarlord
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));

    // Ice crystal details on armor
    final cp = Paint()..color = cFrost.withOpacity(0.4)
      ..style = PaintingStyle.stroke..strokeWidth = 1;
    for (int i = 0; i < 5; i++) {
      final cx2 = center.dx + (Random(i*3).nextDouble()-0.5)*w*0.4;
      final cy2 = center.dy + Random(i*3+1).nextDouble()*height*0.2;
      canvas.drawLine(Offset(cx2-5, cy2), Offset(cx2+5, cy2), cp);
      canvas.drawLine(Offset(cx2, cy2-5), Offset(cx2, cy2+5), cp);
    }

    // Data tablet in hand
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx+w*0.1, center.dy+height*0.08, w*0.28, height*0.18),
        const Radius.circular(3)),
        Paint()..color = const Color(0xFF0A1A2A));
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx+w*0.1, center.dy+height*0.08, w*0.28, height*0.18),
        const Radius.circular(3)),
        Paint()..color = cWarlord.withOpacity(0.4)
          ..style=PaintingStyle.stroke..strokeWidth=1);
  }

  void _drawAlienStructures(Canvas canvas, Size sz) {
    // Organic alien architecture in background
    final p = Paint()..color = const Color(0xFF0A1A20).withOpacity(0.8);
    // Curved ribs
    for (int i = 0; i < 5; i++) {
      final x = sz.width*(0.1+i*0.2);
      canvas.drawPath(
          Path()
            ..moveTo(x, 0)
            ..quadraticBezierTo(x+30, sz.height*0.3, x-10, sz.height*0.65),
          Paint()..color = const Color(0xFF0D1E28)
            ..style=PaintingStyle.stroke..strokeWidth=8);
    }
    // Alien ship in background
    _drawAlienShipSmall(canvas, Offset(sz.width*0.75, sz.height*0.25), 50);
    _drawAlienShipSmall(canvas, Offset(sz.width*0.2,  sz.height*0.28), 35);
    // Floor glow
    canvas.drawRect(Rect.fromLTWH(0, sz.height*0.6, sz.width, sz.height*0.08),
        Paint()..color = cWarlord.withOpacity(0.08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
    // GGALTEA logo on floor
    _drawText(canvas, 'GGALTEA', Offset(sz.width*0.5, sz.height*0.66),
        cWarlord.withOpacity(0.3), 12);
  }

  void _drawAlienShipSmall(Canvas canvas, Offset center, double size) {
    // Organic crescent alien ship
    final p = Paint()..color = const Color(0xFF1A2A40);
    canvas.drawOval(Rect.fromCenter(center: center, width: size*1.6, height: size*0.7), p);
    canvas.drawCircle(center, size*0.28,
        Paint()..color = cWarlord.withOpacity(0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawOval(Rect.fromCenter(center: center, width: size*1.6, height: size*0.7),
        Paint()..color = cWarlord.withOpacity(0.3)
          ..style=PaintingStyle.stroke..strokeWidth=1);
    // Propulsors
    canvas.drawCircle(Offset(center.dx-size*0.55, center.dy), size*0.18,
        Paint()..color = const Color(0xFF6633AA).withOpacity(0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawCircle(Offset(center.dx+size*0.55, center.dy), size*0.18,
        Paint()..color = const Color(0xFF6633AA).withOpacity(0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
  }

  void _drawWarlordShipLarge(Canvas canvas, Offset center, double width) {
    final h = width*0.7;
    canvas.drawOval(Rect.fromCenter(center: center, width: width*1.4, height: h),
        Paint()..color = const Color(0xFF0D1A28));
    canvas.drawCircle(center, width*0.22,
        Paint()..color = cWarlord.withOpacity(0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15));
    canvas.drawOval(Rect.fromCenter(center: center, width: width*1.4, height: h),
        Paint()..color = cWarlord.withOpacity(0.35)
          ..style=PaintingStyle.stroke..strokeWidth=1.5);
    // Spike array
    for (int i = -3; i <= 3; i++) {
      canvas.drawLine(
          Offset(center.dx+i*width*0.16, center.dy-h*0.45),
          Offset(center.dx+i*width*0.12, center.dy-h*0.7),
          Paint()..color = cWarlord.withOpacity(0.5)..strokeWidth=2);
    }
  }

  void _drawCockpitFrame(Canvas canvas, Size sz) {
    final p = Paint()..color = const Color(0xFF1A1C20);
    // Left strut
    canvas.drawPath(Path()
      ..moveTo(0, 0)..lineTo(sz.width*0.12, sz.height*0.08)
      ..lineTo(sz.width*0.12, sz.height*0.55)..lineTo(0, sz.height*0.6)..close(), p);
    // Right strut
    canvas.drawPath(Path()
      ..moveTo(sz.width, 0)..lineTo(sz.width*0.88, sz.height*0.08)
      ..lineTo(sz.width*0.88, sz.height*0.55)..lineTo(sz.width, sz.height*0.6)..close(), p);
    // Dashboard
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, sz.height*0.55, sz.width, sz.height*0.2),
        const Radius.circular(0)),
        Paint()..color = const Color(0xFF141618));
    // Dashboard screens
    _drawDashScreen(canvas, Rect.fromLTWH(sz.width*0.05, sz.height*0.57, sz.width*0.28, sz.height*0.13),
        'NAV CORE', cIce);
    _drawDashScreen(canvas, Rect.fromLTWH(sz.width*0.67, sz.height*0.57, sz.width*0.28, sz.height*0.13),
        'PHOENIX', cFire);
  }

  void _drawDashScreen(Canvas canvas, Rect rect, String label, Color c) {
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = c.withOpacity(0.05));
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = c.withOpacity(0.4)..style=PaintingStyle.stroke..strokeWidth=1);
    _drawText(canvas, label, rect.center, c.withOpacity(0.7), 8);
  }

  void _drawCockpitHUD(Canvas canvas, Size sz) {
    // Mission HUD
    _drawHUDBox(canvas, Rect.fromLTWH(0, sz.height*0.08, sz.width*0.5, sz.height*0.1),
        'MISSION: DELIVER CORE\nOBJ: ORION NEBULA Q7', cIce);
    // Protocol status
    _drawHUDBox(canvas, Rect.fromLTWH(sz.width*0.55, sz.height*0.08, sz.width*0.45, sz.height*0.1),
        'PROTOCOL STATUS: ADAPTING\nENEMY ANALYSIS...', cDanger);
    // Phoenix logo HUD
    canvas.drawCircle(Offset(sz.width*0.78, sz.height*0.18), 18,
        Paint()..color = cFire.withOpacity(0.2)
          ..style=PaintingStyle.stroke..strokeWidth=1.5);
    canvas.drawCircle(Offset(sz.width*0.78, sz.height*0.18), 8,
        Paint()..color = cFire.withOpacity(0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  }

  void _drawHUDBox(Canvas canvas, Rect rect, String text, Color c) {
    canvas.drawRect(rect, Paint()..color = Colors.black.withOpacity(0.6));
    canvas.drawRect(rect, Paint()..color = c.withOpacity(0.3)
      ..style=PaintingStyle.stroke..strokeWidth=0.8);
    _drawText(canvas, text, Offset(rect.left+8, rect.center.dy),
        c.withOpacity(0.8), 8, leftAlign: true);
  }

  void _drawText(Canvas canvas, String text, Offset pos, Color color, double size,
      {bool leftAlign=false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size,
          fontFamily: 'Orbitron', fontWeight: FontWeight.bold,
          height: 1.4,
          shadows: [Shadow(color: color.withOpacity(0.4), blurRadius: 6)])),
      textAlign: leftAlign ? TextAlign.left : TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 300);
    tp.paint(canvas, Offset(
        leftAlign ? pos.dx : pos.dx - tp.width/2,
        pos.dy - tp.height/2));
  }

  @override
  bool shouldRepaint(covariant _IntroBgPainter old) =>
      old.scene.type != scene.type;
}

// ══════════════════════════════════════════════════════════
//  GAME SCREEN
// ══════════════════════════════════════════════════════════
class GameScreen extends StatefulWidget {
  final void Function(int) onGameOver;
  const GameScreen({super.key, required this.onGameOver});
  @override State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  final _rng   = Random();
  final _audio = AudioManager();

  double _sw=0, _sh=0;
  late Player _player;
  final _res   = ResourceSystem();
  final _phase = PhaseEngine();
  final _ai    = AIAdapt();

  final _enemies   = <Enemy>[];
  final _bullets   = <Bullet>[];
  final _particles = <Particle>[];
  final _floats    = <FloatingText>[];

  Enemy? _boss;
  bool   _bossAlive=false;

  int    _score=0;
  double _coreTemp=0;
  double _shootTimer=0, _spawnTimer=0;
  bool   _touching=false;
  double _touchX=0;

  bool   _showDecision=false;
  List<UpgradeOption> _options=[];

  bool   _frosting=false;
  double _frostT=0;
  bool   _quenching=false;
  double _quenchT=0;
  bool   _alarmOn=false;

  double _corePulse=0, _pulseDir=1;
  Ticker? _ticker;
  Duration _lastElapsed=Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sz = MediaQuery.of(context).size;
      _sw=sz.width; _sh=sz.height;
      _player = Player(_sw/2);
      _res.energy = _player.build.maxEnergy;
      _ticker = createTicker(_tick)..start();
    });
  }

  @override
  void dispose() { _ticker?.dispose(); _audio.dispose(); super.dispose(); }

  void _tick(Duration elapsed) {
    final dt = ((elapsed-_lastElapsed).inMicroseconds/1e6).clamp(0.0,0.05).toDouble();
    _lastElapsed = elapsed;
    if (dt==0) return;
    _update(dt);
  }

  void _update(double dt) {
    if (_frosting) {
      _frostT += dt*0.55;
      _spawnFrostParticles();
      _updateParticles(dt); _updateFloats(dt);
      if (_frostT>=1.0) {
        _frosting=false; _quenching=true;
        _audio.stopAlarm(); _audio.playQuench();
        _spawnQuenchExplosion();
      }
      setState((){ }); return;
    }
    if (_quenching) {
      _quenchT+=dt; _updateParticles(dt);
      if (_quenchT>2.5) widget.onGameOver(_score);
      setState((){}); return;
    }
    if (_showDecision) { setState((){}); return; }

    _corePulse += _pulseDir*dt*2.2;
    if (_corePulse>1) _pulseDir=-1;
    if (_corePulse<0) _pulseDir=1;

    _phase.update(dt, onDecision: _triggerDecision, onBoss: _triggerBoss);
    _res.update(dt, _player.build);
    _player.energy=_res.energy; _player.heat=_res.heat;

    // Alarm
    if (_res.heatFrac>=0.8 && !_alarmOn) { _alarmOn=true; _audio.startAlarm(); }
    else if (_res.heatFrac<0.75 && _alarmOn) { _alarmOn=false; _audio.stopAlarm(); }

    if (_player.shieldActive) {
      _player.shieldTimer-=dt;
      if (_player.shieldTimer<=0) _player.shieldActive=false;
    }

    if (_touching) {
      _player.x += (_touchX-_player.x)*14*dt;
      _player.x  = _player.x.clamp(kPhoenixSize, _sw-kPhoenixSize);
    }

    if (_touching && _res.energy>0 && !_res.overheating) {
      _shootTimer-=dt;
      if (_shootTimer<=0) { _shootTimer=0.14/_player.build.fireRate; _fireBullet(); }
    }

    for (final b in _bullets) b.y+=(b.isEnemy?380:-560)*dt;
    _bullets.removeWhere((b)=>b.y<-10||b.y>_sh+10);

    if (_phase.phase==GamePhase.combat && !_bossAlive) {
      _spawnTimer-=dt;
      if (_spawnTimer<=0) { _spawnTimer=_ai.spawnInterval; for(int i=0;i<_ai.waveSize;i++) _spawnEnemy(); }
    }

    _updateEnemies(dt);
    if (_bossAlive && _boss!=null) _updateBoss(dt);
    _resolveCollisions();

    _coreTemp=(_coreTemp-0.003*dt).clamp(0,1);
    if (_coreTemp>=1.0 && !_frosting) _beginFrost();
    if (_res.energy<=0   && !_frosting) _beginFrost();

    _updateParticles(dt); _updateFloats(dt);
    setState((){});
  }

  void _fireBullet() {
    _res.applyShoot(_player.build);
    _audio.playShoot();
    final py = _sh*0.72-kPhoenixSize;
    _bullets.add(Bullet(_player.x, py, _player.build.damage));
    if (_player.build.fireRate>1.8) {
      _bullets.add(Bullet(_player.x-16, py, _player.build.damage*0.7));
      _bullets.add(Bullet(_player.x+16, py, _player.build.damage*0.7));
    }
  }

  void _spawnEnemy() {
    final r = _rng.nextDouble();
    EnemyKind k;
    if      (r<0.40) k=EnemyKind.interceptor;
    else if (r<0.65) k=EnemyKind.frigate;
    else if (r<0.82) k=EnemyKind.parasite;
    else             k=EnemyKind.corrupter;

    final base = 15.0+_phase.cycleCount*5;
    final hp   = k==EnemyKind.parasite ? base*1.5 : k==EnemyKind.frigate ? base*0.8 : base;
    _enemies.add(Enemy(
      x: 20+_rng.nextDouble()*(_sw-40), y: -kEnemyR, hp: hp,
      vx: (_rng.nextBool()?1:-1)*(50+_rng.nextDouble()*60),
      vy: 70+_phase.cycleCount*4.0, kind: k,
    ));
  }

  void _updateEnemies(double dt) {
    for (final e in _enemies) {
      if (e.dead) continue;
      if (e.hitFlash>0) e.hitFlash-=dt*5;
      e.animT+=dt*2;

      switch (e.kind) {
        case EnemyKind.interceptor:
          e.x+=e.vx*dt; e.y+=e.vy*dt;
          if (e.x<kEnemyR||e.x>_sw-kEnemyR) e.vx*=-1;

        case EnemyKind.frigate:
          e.y=(e.y+e.vy*dt*0.4).clamp(-kEnemyR,_sh*0.25);
          e.x+=e.vx*dt;
          if (e.x<kEnemyR||e.x>_sw-kEnemyR) e.vx*=-1;
          e.actionTimer+=dt;
          if (e.actionTimer>1.8/_ai.counterFire) {
            e.actionTimer=0;
            _bullets.add(Bullet(e.x, e.y+kEnemyR, 8, isEnemy: true));
          }

        case EnemyKind.parasite:
          e.x+=(_player.x-e.x).sign*45*dt;
          e.y+=e.vy*dt*0.6;
          if ((e.x-_player.x).abs()<40&&(e.y-_sh*0.72).abs()<40) {
            _res.energy-=12*dt;
            if (_rng.nextDouble()<0.1) _particles.add(Particle(
              x:e.x,y:e.y, vx:(_player.x-e.x)*1.5, vy:(_sh*0.72-e.y)*1.5,
              life:0.4, color:cShield, size:5));
          }

        case EnemyKind.corrupter:
          e.x+=e.vx*dt; e.y+=e.vy*dt;
          if (e.x<kEnemyR||e.x>_sw-kEnemyR) e.vx*=-1;
          if (e.y>_sh*0.65) { _res.heat+=8*dt; _addFloat(e.x,e.y,'+HEAT',cDanger); }
      }

      if (e.y>_sh*0.86) {
        e.dead=true;
        _spawnBurst(e.x,e.y,cFire,10);
        _audio.playExplosion();
        if (!_player.shieldActive) {
          _coreTemp+=kCoreHeatPerEnemyPass;
          _addFloat(_sw/2,_sh*0.84,'NÚCLEO HIT',cDanger);
        }
      }
    }
    _enemies.removeWhere((e)=>e.dead&&e.hitFlash<=0);
  }

  void _updateBoss(double dt) {
    final b=_boss!;
    if (b.hitFlash>0) b.hitFlash-=dt*3;
    b.animT+=dt;
    b.x+=b.vx*dt;
    b.y=_sh*0.18+sin(b.animT)*30;
    if (b.x<kBossR||b.x>_sw-kBossR) b.vx*=-1;
    if ((b.animT*10).toInt()%8==0) {
      for (int i=-1;i<=1;i++)
        _bullets.add(Bullet(b.x+i*20, b.y+kBossR, 12, isEnemy:true));
    }
  }

  void _resolveCollisions() {
    final rem=<Bullet>{};
    for (final bul in _bullets) {
      if (bul.isEnemy) {
        final px=_player.x, py=_sh*0.72;
        if ((bul.x-px).abs()<kPhoenixSize&&(bul.y-py).abs()<kPhoenixSize) {
          rem.add(bul);
          if (_player.shieldActive) {
            _player.shieldActive=false;
            _spawnBurst(px,py,cShield,8); _addFloat(px,py-20,'ESCUDO!',cShield);
          } else {
            _res.energy-=10; _coreTemp+=kCoreHeatPerHit*0.5;
            _spawnBurst(px,py,cDanger,6); _addFloat(px,py-20,'-10',cDanger);
          }
        }
        final nx=_sw/2, ny=_sh*0.87;
        if ((bul.x-nx).abs()<kNucleusR&&(bul.y-ny).abs()<kNucleusR) {
          rem.add(bul); _coreTemp+=kCoreHeatPerHit;
          _addFloat(nx,ny-20,'NÚCLEO!',cDanger);
        }
      } else {
        for (final e in _enemies) {
          if (e.dead) continue;
          if ((bul.x-e.x).abs()<kEnemyR&&(bul.y-e.y).abs()<kEnemyR) {
            rem.add(bul); e.hp-=bul.damage; e.hitFlash=1.0;
            if (e.hp<=0) {
              e.dead=true; _score+=_eScore(e.kind);
              _spawnBurst(e.x,e.y,_eColor(e.kind),14);
              _audio.playExplosion();
              _addFloat(e.x,e.y-10,'+${_eScore(e.kind)}',cGold);
            }
            break;
          }
        }
        if (_bossAlive&&_boss!=null&&!_boss!.dead) {
          final bo=_boss!;
          if ((bul.x-bo.x).abs()<kBossR&&(bul.y-bo.y).abs()<kBossR) {
            rem.add(bul); bo.hp-=bul.damage; bo.hitFlash=1.0; _score+=5;
            if (bo.hp<=0) {
              bo.dead=true; _bossAlive=false; _score+=500;
              _spawnBurst(bo.x,bo.y,cGold,30);
              _spawnBurst(bo.x-30,bo.y+20,cFire,20);
              _audio.playExplosion();
              _addFloat(bo.x,bo.y,'+500 BOSS!',cGold);
              _phase.endBoss(); _ai.analyze(_player.build);
            }
          }
        }
      }
    }
    _bullets.removeWhere((b)=>rem.contains(b));
  }

  int   _eScore(EnemyKind k) => switch(k){
    EnemyKind.interceptor=>100, EnemyKind.frigate=>150,
    EnemyKind.parasite=>200,    EnemyKind.corrupter=>175};
  Color _eColor(EnemyKind k) => switch(k){
    EnemyKind.interceptor=>cFire, EnemyKind.frigate=>const Color(0xFF00FF88),
    EnemyKind.parasite=>cShield,  EnemyKind.corrupter=>const Color(0xFFFF8800)};

  void _triggerDecision() { _ai.analyze(_player.build); _options=_buildOptions(); _showDecision=true; }
  void _triggerBoss() {
    _enemies.clear();
    _boss=Enemy(x:_sw/2, y:_sh*0.18, hp:80+_phase.cycleCount*20.0, vx:90, kind:EnemyKind.frigate);
    _bossAlive=true;
  }
  void _beginFrost() { if(_frosting||_quenching) return; _frosting=true; _coreTemp=1.0; _audio.stopAlarm(); }

  void _spawnQuenchExplosion() {
    for (int i=0;i<80;i++) {
      final a=_rng.nextDouble()*pi*2; final s=100+_rng.nextDouble()*320;
      _particles.add(Particle(x:_sw/2,y:_sh*0.87,vx:cos(a)*s,vy:sin(a)*s,
          life:1.2+_rng.nextDouble(),color:_rng.nextBool()?cFire:cIce,size:5+_rng.nextDouble()*12));
    }
  }
  void _spawnFrostParticles() {
    if (_rng.nextDouble()>0.3) return;
    final a=_rng.nextDouble()*pi*2; final r=kNucleusR+_rng.nextDouble()*60;
    _particles.add(Particle(
      x:_sw/2+cos(a)*r, y:_sh*0.87+sin(a)*r,
      vx:cos(a+pi)*40,  vy:sin(a+pi)*40,
      life:0.8+_rng.nextDouble()*0.6, color:cFrost, size:3+_rng.nextDouble()*6, isFrost:true));
  }
  void _selectUpgrade(UpgradeOption opt) {
    opt.apply(_player.build);
    _res.energy=(_res.energy+20).clamp(0,_player.build.maxEnergy);
    _showDecision=false; _phase.endDecision();
  }

  List<UpgradeOption> _buildOptions() {
    final all=[
      UpgradeOption(title:'Plasma Overload',   description:'+40% daño',      emoji:'🔥',color:cFire,  apply:(b)=>b.damage*=1.4),
      UpgradeOption(title:'Cryo Stabilizer',   description:'Enfriamiento +50%',emoji:'❄️',color:cIce, apply:(b)=>b.cooling*=1.5),
      UpgradeOption(title:'Void Pulse',        description:'Cadencia +30%',   emoji:'⚡',color:cGold,  apply:(b)=>b.fireRate*=1.3),
      UpgradeOption(title:'Energy Core Expand',description:'Energía máx +25', emoji:'💙',color:cIce,   apply:(b)=>b.maxEnergy+=25),
      UpgradeOption(title:'Entropy Shield',    description:'Escudo activo',   emoji:'🛡️',color:cShield,apply:(b)=>b.shieldEfficiency+=0.4),
      UpgradeOption(title:'Quantum Burst',     description:'Triple shot perm.',emoji:'💥',color:cFire, apply:(b)=>b.fireRate=(b.fireRate*1.2).clamp(0,2.5)),
      UpgradeOption(title:'Core Armor',        description:'Blindaje núcleo', emoji:'🔮',color:cShield,apply:(b)=>b.modules.add('core_armor')),
      UpgradeOption(title:'Phoenix Overdrive', description:'+20% todo • -cool',emoji:'🦅',color:cGold, apply:(b){b.damage*=1.2;b.fireRate*=1.2;b.cooling*=0.9;}),
    ];
    all.shuffle(_rng); return all.take(3).toList();
  }

  void _spawnBurst(double x,double y,Color c,int n) {
    for(int i=0;i<n;i++){
      final a=_rng.nextDouble()*pi*2; final s=40+_rng.nextDouble()*180;
      _particles.add(Particle(x:x,y:y,vx:cos(a)*s,vy:sin(a)*s,
          life:0.3+_rng.nextDouble()*0.5,color:c,size:2+_rng.nextDouble()*5));
    }
  }
  void _addFloat(double x,double y,String t,Color c)=>_floats.add(FloatingText(x,y,t,c));
  void _updateParticles(double dt) {
    for(final p in _particles){p.x+=p.vx*dt;p.y+=p.vy*dt;if(!p.isFrost)p.vy+=40*dt;p.life-=dt;}
    _particles.removeWhere((p)=>p.life<=0);
  }
  void _updateFloats(double dt){for(final f in _floats){f.y-=55*dt;f.life-=dt*1.5;}_floats.removeWhere((f)=>f.life<=0);}

  void _onPanStart(DragStartDetails d){_touching=true;_touchX=d.localPosition.dx;}
  void _onPanUpdate(DragUpdateDetails d){_touchX=d.localPosition.dx;}
  void _onPanEnd(DragEndDetails _){_touching=false;}
  void _onTapDown(TapDownDetails d){_touching=true;_touchX=d.localPosition.dx;}
  void _onTapUp(TapUpDetails _){_touching=false;}

  @override
  Widget build(BuildContext context) {
    final sz=MediaQuery.of(context).size; _sw=sz.width; _sh=sz.height;
    return Scaffold(
      backgroundColor: cBg,
      body: Stack(children:[
        GestureDetector(
          onPanStart:_onPanStart,onPanUpdate:_onPanUpdate,onPanEnd:_onPanEnd,
          onTapDown:_onTapDown,onTapUp:_onTapUp,
          child: CustomPaint(
            painter: GamePainter(
              sw:_sw,sh:_sh,player:_player,enemies:_enemies,bullets:_bullets,
              boss:_bossAlive?_boss:null,particles:_particles,floats:_floats,
              score:_score,res:_res,phase:_phase,coreTemp:_coreTemp,
              corePulse:_corePulse,frosting:_frosting,frostT:_frostT,
              quenching:_quenching,quenchT:_quenchT,touching:_touching,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        if (_showDecision) _DecisionOverlay(options:_options,cycle:_phase.cycleCount,onSelect:_selectUpgrade),
        if (_phase.phase==GamePhase.boss&&_bossAlive)
          Positioned(top:8,left:0,right:0,
            child:Center(child:_GlowText('⚠ FROZEN WARLORD ⚠',color:cWarlord,size:14))),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  GAME PAINTER — LORE SPRITES
// ══════════════════════════════════════════════════════════
class GamePainter extends CustomPainter {
  final double sw,sh,coreTemp,corePulse,frostT,quenchT;
  final bool frosting,quenching,touching;
  final Player player;
  final List<Enemy> enemies;
  final List<Bullet> bullets;
  final Enemy? boss;
  final List<Particle> particles;
  final List<FloatingText> floats;
  final int score;
  final ResourceSystem res;
  final PhaseEngine phase;

  const GamePainter({
    required this.sw,required this.sh,required this.player,
    required this.enemies,required this.bullets,required this.boss,
    required this.particles,required this.floats,required this.score,
    required this.res,required this.phase,required this.coreTemp,
    required this.corePulse,required this.frosting,required this.frostT,
    required this.quenching,required this.quenchT,required this.touching,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _bg(canvas);
    _drawNucleus(canvas);
    _drawEnemies(canvas);
    if (boss!=null) _drawBoss(canvas,boss!);
    _drawBullets(canvas);
    _drawPhoenix(canvas);
    _drawParticles(canvas);
    _drawFloats(canvas);
    _drawHUD(canvas);
    if (frosting)  _drawFrost(canvas);
    if (quenching) _drawQuench(canvas);
  }

  void _bg(Canvas canvas) {
    final danger = coreTemp>0.5
        ? Color.lerp(const Color(0xFF001022),const Color(0xFF200008),(coreTemp-0.5)*2)!
        : const Color(0xFF000814);
    canvas.drawRect(Rect.fromLTWH(0,0,sw,sh),
        Paint()..shader=LinearGradient(
          begin:Alignment.topCenter,end:Alignment.bottomCenter,
          colors:[const Color(0xFF000814),const Color(0xFF001022),danger],
        ).createShader(Rect.fromLTWH(0,0,sw,sh)));
    final rng=Random(77);
    final sp=Paint()..color=Colors.white.withOpacity(0.5);
    for(int i=0;i<70;i++) canvas.drawCircle(
        Offset(rng.nextDouble()*sw,rng.nextDouble()*sh),rng.nextDouble()*1.3,sp);
    if (res.entropyFrac>0.4) canvas.drawRect(Rect.fromLTWH(0,0,sw,sh),
        Paint()..color=const Color(0xFF330044).withOpacity(res.entropyFrac*0.25)
          ..maskFilter=const MaskFilter.blur(BlurStyle.normal,60));
  }

  void _drawNucleus(Canvas canvas) {
    final cx=sw/2, cy=sh*0.87;
    final tempC=Color.lerp(cIce,cDanger,coreTemp)!;
    final pulse=kNucleusR+corePulse*5;
    for(int i=4;i>=1;i--) canvas.drawCircle(Offset(cx,cy),pulse+i*12,
        Paint()..color=tempC.withOpacity(0.06*i)..style=PaintingStyle.stroke..strokeWidth=1.5);
    canvas.drawCircle(Offset(cx,cy),pulse*1.4,
        Paint()..color=tempC.withOpacity(0.18)..maskFilter=const MaskFilter.blur(BlurStyle.normal,20));
    canvas.drawCircle(Offset(cx,cy),pulse,
        Paint()..shader=RadialGradient(colors:[
          Colors.white.withOpacity(0.95),tempC.withOpacity(0.85),tempC.withOpacity(0.2)
        ],stops:const[0.0,0.45,1.0]).createShader(Rect.fromCircle(center:Offset(cx,cy),radius:pulse)));
    // Tech ring
    canvas.drawCircle(Offset(cx,cy),pulse+4,
        Paint()..color=tempC.withOpacity(0.35)..style=PaintingStyle.stroke..strokeWidth=0.8);
    // Cross
    final lp=Paint()..color=tempC.withOpacity(0.2)..strokeWidth=0.7;
    canvas.drawLine(Offset(cx-pulse-10,cy),Offset(cx+pulse+10,cy),lp);
    canvas.drawLine(Offset(cx,cy-pulse-10),Offset(cx,cy+pulse+10),lp);
    // Lightning spokes
    final rng=Random((corePulse*20).toInt());
    final blp=Paint()..color=tempC.withOpacity(0.6)..style=PaintingStyle.stroke..strokeWidth=1.2;
    for(int i=0;i<8;i++) {
      final a=i*pi/4+corePulse*pi*0.5;
      _bolt(canvas,blp,
          Offset(cx+cos(a)*pulse*0.5,cy+sin(a)*pulse*0.5),
          Offset(cx+cos(a)*(pulse+22),cy+sin(a)*(pulse+22)),rng);
    }
    _drawArcBar(canvas,cx,cy,pulse+32,coreTemp,tempC);
    _txt(canvas,'NÚCLEO CUÁNTICO', Offset(cx,cy+pulse+22),tempC.withOpacity(0.8) 9);
  }

  void _drawArcBar(Canvas canvas,double cx,double cy,double r,double frac,Color c) {
    const st=-pi*0.75, sw2=pi*1.5;
    canvas.drawArc(Rect.fromCircle(center:Offset(cx,cy),radius:r),st,sw2,false,
        Paint()..color=Colors.white12..style=PaintingStyle.stroke..strokeWidth=4..strokeCap=StrokeCap.round);
    if(frac>0) canvas.drawArc(Rect.fromCircle(center:Offset(cx,cy),radius:r),st,sw2*frac,false,
        Paint()..color=c..style=PaintingStyle.stroke..strokeWidth=4..strokeCap=StrokeCap.round);
  }

  void _bolt(Canvas canvas,Paint p,Offset a,Offset b,Random rng) {
    final path=Path()..moveTo(a.dx,a.dy);
    for(int i=1;i<4;i++){final t=i/4;path.lineTo(
        a.dx+(b.dx-a.dx)*t+(rng.nextDouble()-0.5)*10,
        a.dy+(b.dy-a.dy)*t+(rng.nextDouble()-0.5)*10);}
    path.lineTo(b.dx,b.dy); canvas.drawPath(path,p);
  }

  // ── PHOENIX SHIP (player) ───────────────────────────────
  void _drawPhoenix(Canvas canvas) {
    final px=player.x, py=sh*0.72;
    if (player.shieldActive) {
      canvas.drawCircle(Offset(px,py),kPhoenixSize*1.7,
          Paint()..color=cShield.withOpacity(0.3)..maskFilter=const MaskFilter.blur(BlurStyle.normal,10));
      canvas.drawCircle(Offset(px,py),kPhoenixSize*1.7,
          Paint()..color=cShield.withOpacity(0.7)..style=PaintingStyle.stroke..strokeWidth=2);
    }
    // Engine glow
    canvas.drawCircle(Offset(px,py+kPhoenixSize*0.55),kPhoenixSize*0.35,
        Paint()..color=cFire.withOpacity(touching?0.85:0.3)..maskFilter=const MaskFilter.blur(BlurStyle.normal,12));
    // Fuselage
    final bodyP=Paint()..shader=LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
        colors:[const Color(0xFF999999),const Color(0xFF555555)])
        .createShader(Rect.fromCenter(center:Offset(px,py),width:kPhoenixSize*0.6,height:kPhoenixSize*1.8));
    canvas.drawPath(Path()
      ..moveTo(px,py-kPhoenixSize*0.85)
      ..lineTo(px+kPhoenixSize*0.22,py+kPhoenixSize*0.45)
      ..lineTo(px,py+kPhoenixSize*0.25)
      ..lineTo(px-kPhoenixSize*0.22,py+kPhoenixSize*0.45)
      ..close(), bodyP);
    // Wings
    final wingC=const Color(0xFF666666);
    canvas.drawPath(Path()
      ..moveTo(px-kPhoenixSize*0.18,py)
      ..lineTo(px-kPhoenixSize*1.25,py+kPhoenixSize*0.1)
      ..lineTo(px-kPhoenixSize*0.9,py+kPhoenixSize*0.5)
      ..lineTo(px-kPhoenixSize*0.2,py+kPhoenixSize*0.35)..close(),
        Paint()..color=wingC);
    canvas.drawPath(Path()
      ..moveTo(px+kPhoenixSize*0.18,py)
      ..lineTo(px+kPhoenixSize*1.25,py+kPhoenixSize*0.1)
      ..lineTo(px+kPhoenixSize*0.9,py+kPhoenixSize*0.5)
      ..lineTo(px+kPhoenixSize*0.2,py+kPhoenixSize*0.35)..close(),
        Paint()..color=wingC);
    // Cockpit
    canvas.drawCircle(Offset(px,py-kPhoenixSize*0.3),kPhoenixSize*0.18,
        Paint()..color=cIce.withOpacity(0.8)..maskFilter=const MaskFilter.blur(BlurStyle.normal,5));
    // Phoenix emblem on hull
    canvas.drawCircle(Offset(px,py+kPhoenixSize*0.05),kPhoenixSize*0.12,
        Paint()..color=cFire.withOpacity(0.6)..maskFilter=const MaskFilter.blur(BlurStyle.normal,4));
    // G-G badge
    _txt(canvas,'G·G',Offset(px,py+kPhoenixSize*0.05),cGold.withOpacity(0.8),7);
    // Wing detail lines
    final wl=Paint()..color=Colors.white.withOpacity(0.2)..strokeWidth=0.7..style=PaintingStyle.stroke;
    canvas.drawLine(Offset(px-kPhoenixSize*0.15,py+2),Offset(px-kPhoenixSize*0.95,py+kPhoenixSize*0.25),wl);
    canvas.drawLine(Offset(px+kPhoenixSize*0.15,py+2),Offset(px+kPhoenixSize*0.95,py+kPhoenixSize*0.25),wl);
    // Thrust flame
    if (touching) {
      canvas.drawPath(Path()
        ..moveTo(px-7,py+kPhoenixSize*0.42)
        ..lineTo(px,py+kPhoenixSize*0.42+30)
        ..lineTo(px+7,py+kPhoenixSize*0.42),
          Paint()..shader=LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
              colors:[const Color(0xFFFFDD00),cFire,cFire.withOpacity(0)])
              .createShader(Rect.fromLTWH(px-8,py+kPhoenixSize*0.4,16,32)));
    }
  }

  // ── ENEMY SHIPS (lore-based) ────────────────────────────
  void _drawEnemies(Canvas canvas) {
    for (final e in enemies) {
      if (e.dead) continue;
      final base=_eColor(e.kind);
      final c=e.hitFlash>0?Color.lerp(base,Colors.white,e.hitFlash)!:base;
      // Glow
      canvas.drawCircle(Offset(e.x,e.y),kEnemyR*1.5,
          Paint()..color=c.withOpacity(0.15)..maskFilter=const MaskFilter.blur(BlurStyle.normal,10));
      switch(e.kind){
        case EnemyKind.interceptor: _drawInterceptor(canvas,e,c);
        case EnemyKind.frigate:     _drawFrigate(canvas,e,c);
        case EnemyKind.parasite:    _drawParasite(canvas,e,c);
        case EnemyKind.corrupter:   _drawCorrupter(canvas,e,c);
      }
      // HP bar
      if (e.maxHp>20) {
        final bw=kEnemyR*2; final frac=(e.hp/e.maxHp).clamp(0.0,1.0);
        canvas.drawRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(e.x-bw/2,e.y-kEnemyR-8,bw,3),const Radius.circular(2)),
            Paint()..color=Colors.white24);
        canvas.drawRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(e.x-bw/2,e.y-kEnemyR-8,bw*frac,3),const Radius.circular(2)),
            Paint()..color=c);
      }
    }
  }

  // Interceptor — small crescent alien fighter (image 6 style)
  void _drawInterceptor(Canvas canvas,Enemy e,Color c) {
    final cx=e.x, cy=e.y, r=kEnemyR;
    // Organic crescent body
    canvas.drawOval(Rect.fromCenter(center:Offset(cx,cy),width:r*1.8,height:r*0.9),
        Paint()..color=c.withOpacity(0.85));
    // Core eye
    canvas.drawCircle(Offset(cx,cy),r*0.28,
        Paint()..color=Colors.white.withOpacity(0.9)..maskFilter=const MaskFilter.blur(BlurStyle.normal,4));
    // Purple propulsors
    canvas.drawCircle(Offset(cx-r*0.7,cy),r*0.2,
        Paint()..color=const Color(0xFF8833FF).withOpacity(0.9)..maskFilter=const MaskFilter.blur(BlurStyle.normal,5));
    canvas.drawCircle(Offset(cx+r*0.7,cy),r*0.2,
        Paint()..color=const Color(0xFF8833FF).withOpacity(0.9)..maskFilter=const MaskFilter.blur(BlurStyle.normal,5));
  }

  // Frigate — long sniper ship
  void _drawFrigate(Canvas canvas,Enemy e,Color c) {
    final cx=e.x, cy=e.y, r=kEnemyR;
    // Elongated diamond body
    canvas.drawPath(Path()
      ..moveTo(cx,cy-r*1.1)..lineTo(cx+r*0.5,cy)
      ..lineTo(cx,cy+r*1.1)..lineTo(cx-r*0.5,cy)..close(),
        Paint()..color=c.withOpacity(0.85));
    // Laser barrel
    canvas.drawLine(Offset(cx,cy+r*1.1),Offset(cx,cy+r*1.6),
        Paint()..color=c.withOpacity(0.8)..strokeWidth=3);
    // Pulsing scope
    canvas.drawCircle(Offset(cx,cy),r*0.22,
        Paint()..color=Colors.white.withOpacity(0.5+sin(e.animT*4)*0.4)
          ..maskFilter=const MaskFilter.blur(BlurStyle.normal,4));
  }

  // Parasite — organic biomechanical creature
  void _drawParasite(Canvas canvas,Enemy e,Color c) {
    final cx=e.x, cy=e.y, r=kEnemyR;
    // Hexagonal shell
    final p=Path();
    for(int i=0;i<6;i++){final a=i*pi/3+e.animT*0.2;
      if(i==0)p.moveTo(cx+cos(a)*r,cy+sin(a)*r);
      else p.lineTo(cx+cos(a)*r,cy+sin(a)*r);}
    p.close(); canvas.drawPath(p,Paint()..color=c.withOpacity(0.85));
    // Rotating energy tendrils
    final tp=Paint()..color=c.withOpacity(0.5)..strokeWidth=1.5..style=PaintingStyle.stroke;
    for(int i=0;i<3;i++){final a=i*pi*2/3+e.animT;
      canvas.drawLine(Offset(cx,cy),Offset(cx+cos(a)*r*1.5,cy+sin(a)*r*1.5),tp);}
    // Core
    canvas.drawCircle(Offset(cx,cy),r*0.28,
        Paint()..color=Colors.white.withOpacity(0.85)..maskFilter=const MaskFilter.blur(BlurStyle.normal,3));
  }

  // Corrupter — star-burst dark energy ship
  void _drawCorrupter(Canvas canvas,Enemy e,Color c) {
    final cx=e.x, cy=e.y, r=kEnemyR;
    final p=Path();
    for(int i=0;i<8;i++){final a=i*pi/4+e.animT*0.5;final rad=i.isEven?r:r*0.42;
      if(i==0)p.moveTo(cx+cos(a)*rad,cy+sin(a)*rad);
      else p.lineTo(cx+cos(a)*rad,cy+sin(a)*rad);}
    p.close(); canvas.drawPath(p,Paint()..color=c);
    // Dark corruption eye
    canvas.drawCircle(Offset(cx,cy),r*0.22,
        Paint()..color=const Color(0xFFFF0000).withOpacity(0.9)..maskFilter=const MaskFilter.blur(BlurStyle.normal,5));
  }

  Color _eColor(EnemyKind k) => switch(k){
    EnemyKind.interceptor=>const Color(0xFF4488FF),
    EnemyKind.frigate    =>const Color(0xFF00FF88),
    EnemyKind.parasite   =>const Color(0xFF9933FF),
    EnemyKind.corrupter  =>const Color(0xFFFF6600),
  };

  // ── FROZEN WARLORD BOSS ────────────────────────────────
  void _drawBoss(Canvas canvas,Enemy b) {
    final frac=(b.hp/b.maxHp).clamp(0.0,1.0);
    final c=b.hitFlash>0?Color.lerp(cWarlord,Colors.white,b.hitFlash)!:cWarlord;

    // Outer ice aura
    canvas.drawCircle(Offset(b.x,b.y),kBossR*1.8,
        Paint()..color=c.withOpacity(0.12)..maskFilter=const MaskFilter.blur(BlurStyle.normal,30));

    // Main body — hexagonal warlord ship
    final path=Path();
    for(int i=0;i<6;i++){final a=i*pi/3+b.animT*0.15;
      if(i==0)path.moveTo(b.x+cos(a)*kBossR,b.y+sin(a)*kBossR);
      else path.lineTo(b.x+cos(a)*kBossR,b.y+sin(a)*kBossR);}
    path.close();
    canvas.drawPath(path,Paint()..shader=RadialGradient(
        colors:[c.withOpacity(0.95),const Color(0xFF112244)],stops:const[0.3,1.0])
        .createShader(Rect.fromCircle(center:Offset(b.x,b.y),radius:kBossR)));

    // Crown spikes
    for(int i=-2;i<=2;i++){
      final sx=b.x+i*kBossR*0.28;
      canvas.drawLine(Offset(sx-5,b.y-kBossR),Offset(sx,b.y-kBossR-14-i.abs()*6),
          Paint()..color=cFrost.withOpacity(0.8)..strokeWidth=2.5);
      canvas.drawLine(Offset(sx+5,b.y-kBossR),Offset(sx,b.y-kBossR-14-i.abs()*6),
          Paint()..color=cFrost.withOpacity(0.8)..strokeWidth=2.5);
    }

    // Energy eye
    canvas.drawCircle(Offset(b.x,b.y),kBossR*0.28,
        Paint()..color=Colors.black.withOpacity(0.7));
    canvas.drawCircle(Offset(b.x,b.y),kBossR*0.18,
        Paint()..color=c..maskFilter=const MaskFilter.blur(BlurStyle.normal,12));
    canvas.drawCircle(Offset(b.x,b.y),kBossR*0.07,
        Paint()..color=Colors.white);

    // Energy spikes
    final sp=Paint()..color=c.withOpacity(0.45)..strokeWidth=1.5..style=PaintingStyle.stroke;
    for(int i=0;i<6;i++){final a=i*pi/3+b.animT*0.5;
      canvas.drawLine(Offset(b.x+cos(a)*kBossR,b.y+sin(a)*kBossR),
          Offset(b.x+cos(a)*(kBossR+18),b.y+sin(a)*(kBossR+18)),sp);}

    // Ice crystals on body
    final cp=Paint()..color=cFrost.withOpacity(0.35)..style=PaintingStyle.stroke..strokeWidth=1;
    for(int i=0;i<4;i++){
      final ang=i*pi/2+0.3; final cr=kBossR*0.55;
      canvas.drawLine(Offset(b.x+cos(ang)*cr-4,b.y+sin(ang)*cr),
          Offset(b.x+cos(ang)*cr+4,b.y+sin(ang)*cr),cp);
      canvas.drawLine(Offset(b.x+cos(ang)*cr,b.y+sin(ang)*cr-4),
          Offset(b.x+cos(ang)*cr,b.y+sin(ang)*cr+4),cp);
    }

    // HP bar
    const bw=kBossR*2;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(b.x-bw/2,b.y-kBossR-14,bw,6),const Radius.circular(3)),
        Paint()..color=Colors.white24);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(b.x-bw/2,b.y-kBossR-14,bw*frac,6),const Radius.circular(3)),
        Paint()..color=Color.lerp(cDanger,cWarlord,frac)!);
    _txt(canvas,'FROZEN WARLORD  ${(frac*100).toInt()}%',Offset(b.x,b.y-kBossR-26),cWarlord, 10);
  }

  void _drawBullets(Canvas canvas) {
    for(final b in bullets){
      if(b.isEnemy){
        canvas.drawCircle(Offset(b.x,b.y),8,Paint()..color=cWarlord..maskFilter=const MaskFilter.blur(BlurStyle.normal,6));
        canvas.drawCircle(Offset(b.x,b.y),3,Paint()..color=cFrost);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:Offset(b.x,b.y),width:5,height:18),const Radius.circular(3)),
            Paint()..color=cIce.withOpacity(0.35)..maskFilter=const MaskFilter.blur(BlurStyle.normal,4));
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:Offset(b.x,b.y),width:4,height:17),const Radius.circular(3)),
            Paint()..shader=const LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
                colors:[Colors.white,cIce]).createShader(Rect.fromCenter(center:Offset(b.x,b.y),width:4,height:17)));
      }
    }
  }

  void _drawParticles(Canvas canvas) {
    for(final p in particles){
      final a=(p.life/p.maxLife).clamp(0.0,1.0);
      if(p.isFrost){
        final fp=Paint()..color=cFrost.withOpacity(a*0.9)..style=PaintingStyle.stroke..strokeWidth=1.2;
        for(int i=0;i<3;i++){final ang=i*pi/3;
          canvas.drawLine(Offset(p.x+cos(ang)*p.size,p.y+sin(ang)*p.size),
              Offset(p.x-cos(ang)*p.size,p.y-sin(ang)*p.size),fp);}
        canvas.drawCircle(Offset(p.x,p.y),p.size*0.3*a,Paint()..color=Colors.white.withOpacity(a));
      } else {
        canvas.drawCircle(Offset(p.x,p.y),p.size*a,
            Paint()..color=p.color.withOpacity(a)..maskFilter=MaskFilter.blur(BlurStyle.normal,p.size*0.5));
      }
    }
  }

  void _drawFloats(Canvas canvas){for(final f in floats)_txt(canvas,f.text,Offset(f.x,f.y),f.color.withOpacity(f.life.clamp(0,1)),11);}

  void _drawHUD(Canvas canvas) {
    _txt(canvas,'SCORE  $score',Offset(16,56),Colors.white,15,left:true);
    final label=switch(phase.phase){
      GamePhase.combat  =>'COMBAT  ${(phase.combatProgress*100).toInt()}%',
      GamePhase.decision=>'DECISIÓN',GamePhase.boss=>'⚠ WARLORD',
    };
    _txt(canvas,label,Offset(sw/2,56),cIce,11);
    final bw=sw*0.4, bx=(sw-bw)/2;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx,66,bw,3),const Radius.circular(2)),Paint()..color=Colors.white12);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx,66,bw*phase.combatProgress,3),const Radius.circular(2)),Paint()..color=cIce);
    _vBar(canvas,14,sh*0.35,10,sh*0.32,res.energyFrac,cIce,'ENERGÍA');
    _vBar(canvas,sw-24,sh*0.35,10,sh*0.32,res.heatFrac,Color.lerp(cGold,cDanger,res.heatFrac)!,'HEAT');
    if(res.entropyFrac>0.3) _txt(canvas,'ENTROPÍA ${(res.entropyFrac*100).toInt()}%',Offset(sw/2,sh-28),cShield.withOpacity(res.entropyFrac),10);
    _txt(canvas,'DMG ${player.build.damage.toStringAsFixed(0)}  SPD ${player.build.fireRate.toStringAsFixed(1)}  COOL ${player.build.cooling.toStringAsFixed(1)}',
        Offset(sw/2,sh-14),Colors.white24,9);
    if(coreTemp>0.75) _txt(canvas,'⚠  QUENCH INMINENTE  ⚠',Offset(sw/2,sh*0.48),cDanger,15);
    if(res.overheating) _txt(canvas,'SOBRECALENTAMIENTO',Offset(sw/2,sh*0.53),cFire.withOpacity(0.85),11);
  }

  void _vBar(Canvas canvas,double x,double y,double w,double h,double frac,Color c,String label){
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x,y,w,h),const Radius.circular(4)),Paint()..color=Colors.white12);
    final f=h*frac.clamp(0.0,1.0);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x,y+h-f,w,f),const Radius.circular(4)),
        Paint()..color=c..maskFilter=MaskFilter.blur(BlurStyle.normal,frac>0.7?4:0));
    _txt(canvas,label,Offset(x+w/2,y+h+14),c.withOpacity(0.6),8);
  }

  void _drawFrost(Canvas canvas) {
    final ft=frostT.clamp(0.0,1.0);
    canvas.drawRect(Rect.fromLTWH(0,0,sw,sh),Paint()..shader=RadialGradient(
        center:Alignment.center,radius:0.7,
        colors:[Colors.transparent,cFrost.withOpacity(ft*0.35),cFrost.withOpacity(ft*0.7)],
        stops:const[0.4,0.7,1.0]).createShader(Rect.fromLTWH(0,0,sw,sh)));
    final rng=Random(42);
    final cp=Paint()..color=cFrost.withOpacity(ft*0.55)..strokeWidth=1.0..style=PaintingStyle.stroke;
    void crack(double sx,double sy,int depth){
      if(depth<=0)return;
      for(int i=0;i<3;i++){final a=rng.nextDouble()*pi*2;final l=(20+rng.nextDouble()*40)*ft;
        final ex=sx+cos(a)*l; final ey=sy+sin(a)*l;
        canvas.drawLine(Offset(sx,sy),Offset(ex,ey),cp);
        if(rng.nextDouble()<0.5)crack(ex,ey,depth-1);}}
    crack(0,0,4); crack(sw,0,4); crack(0,sh,4); crack(sw,sh,4);
    final pulse=sin(frostT*pi*8)*0.5+0.5;
    _txt(canvas,'❄  QUENCH CRÍTICO  ❄',Offset(sw/2,sh*0.38),cFrost.withOpacity(0.6+pulse*0.4),18);
  }

  void _drawQuench(Canvas canvas) {
    final a=(quenchT/2.5).clamp(0.0,0.92);
    canvas.drawRect(Rect.fromLTWH(0,0,sw,sh),Paint()..color=cFire.withOpacity(a*0.8));
    _txt(canvas,'💥  QUENCH  💥',Offset(sw/2,sh*0.38),Colors.white,38);
    _txt(canvas,'FALLO CRIOGÉNICO TOTAL',Offset(sw/2,sh*0.48),cFire,16);
  }

  void _txt(Canvas canvas,String t,Offset pos,Color c,double size,{bool left=false}){
    final tp=TextPainter(text:TextSpan(text:t,style:TextStyle(color:c,fontSize:size,
        fontFamily:'Orbitron',fontWeight:FontWeight.bold,
        shadows:[Shadow(color:c.withOpacity(0.5),blurRadius:8)])),
        textAlign:left?TextAlign.left:TextAlign.center,textDirection:TextDirection.ltr)..layout();
    tp.paint(canvas,Offset(left?pos.dx:pos.dx-tp.width/2,pos.dy-tp.height/2));
  }

  @override bool shouldRepaint(covariant CustomPainter _)=>true;
}

// ══════════════════════════════════════════════════════════
//  DECISION OVERLAY
// ══════════════════════════════════════════════════════════
class _DecisionOverlay extends StatelessWidget {
  final List<UpgradeOption> options; final int cycle;
  final void Function(UpgradeOption) onSelect;
  const _DecisionOverlay({required this.options,required this.cycle,required this.onSelect});
  @override Widget build(BuildContext context)=>Container(
    color:Colors.black.withOpacity(0.9),
    child:SafeArea(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      _GlowText('FASE DE DECISIÓN',color:cGold,size:22),const SizedBox(height:4),
      _GlowText('Ciclo $cycle — evoluciona tu Phoenix',color:Colors.white54,size:13),
      const SizedBox(height:32),
      ...options.map((opt)=>Padding(
        padding:const EdgeInsets.symmetric(horizontal:24,vertical:8),
        child:GestureDetector(onTap:()=>onSelect(opt),child:Container(
          width:double.infinity,padding:const EdgeInsets.all(18),
          decoration:BoxDecoration(border:Border.all(color:opt.color,width:1.5),
              borderRadius:BorderRadius.circular(12),color:opt.color.withOpacity(0.12),
              boxShadow:[BoxShadow(color:opt.color.withOpacity(0.25),blurRadius:16)]),
          child:Row(children:[
            Text(opt.emoji,style:const TextStyle(fontSize:28)),const SizedBox(width:16),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(opt.title,style:TextStyle(color:opt.color,fontSize:16,fontFamily:'Orbitron',fontWeight:FontWeight.bold)),
              const SizedBox(height:4),
              Text(opt.description,style:const TextStyle(color:Colors.white70,fontSize:12)),
            ])),
            Icon(Icons.arrow_forward_ios,color:opt.color,size:18),
          ]),
        )),
      )),
      const SizedBox(height:24),
      const Text('(+20 energía al elegir)',style:TextStyle(color:Colors.white30,fontSize:11)),
    ])),
  );
}

// ══════════════════════════════════════════════════════════
//  MENU SCREEN
// ══════════════════════════════════════════════════════════
class MenuScreen extends StatefulWidget {
  final int best; final VoidCallback onStart;
  const MenuScreen({super.key,required this.best,required this.onStart});
  @override State<MenuScreen> createState()=>_MenuScreenState();
}
class _MenuScreenState extends State<MenuScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;
  @override void initState(){super.initState();
    _ctrl=AnimationController(vsync:this,duration:const Duration(milliseconds:1400))..repeat(reverse:true);
    _pulse=CurvedAnimation(parent:_ctrl,curve:Curves.easeInOut);}
  @override void dispose(){_ctrl.dispose();super.dispose();}

  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:cBg,
    body:SafeArea(child:Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      _GlowText('PHOENIX CORE',color:cFire,size:38),const SizedBox(height:4),
      _GlowText('CRYO BALANCE  V4',color:cIce,size:16),const SizedBox(height:6),
      _GlowText('BEST: ${widget.best}',color:cGold,size:14),
      const SizedBox(height:40),
      _FleetLegend(),const SizedBox(height:40),
      AnimatedBuilder(animation:_pulse,builder:(_,__)=>Transform.scale(
        scale:1+_pulse.value*0.05,
        child:GestureDetector(onTap:widget.onStart,child:Container(
          padding:const EdgeInsets.symmetric(horizontal:52,vertical:18),
          decoration:BoxDecoration(border:Border.all(color:cFire,width:2),
              borderRadius:BorderRadius.circular(10),color:cFire.withOpacity(0.15),
              boxShadow:[BoxShadow(color:cFire.withOpacity(0.4),blurRadius:28)]),
          child:const _GlowText('INICIAR MISIÓN',color:Colors.white,size:22),
        )))),
      const SizedBox(height:28),
      const Padding(padding:EdgeInsets.symmetric(horizontal:32),
        child:Text('Protege el Núcleo Cuántico.\nDefiéndelo de la flota del Frozen Warlord.',
          textAlign:TextAlign.center,
          style:TextStyle(color:Colors.white38,fontSize:12,height:1.5))),
    ]))),
  );
}

class _FleetLegend extends StatelessWidget {
  @override Widget build(BuildContext context){
    final items=[
      ('◐',const Color(0xFF4488FF),'Interceptor'),
      ('◆',const Color(0xFF00FF88),'Frigate'),
      ('⬡',const Color(0xFF9933FF),'Parasite'),
      ('✦',const Color(0xFFFF6600),'Corrupter'),
    ];
    return Column(children:[
      Text('FLOTA DEL WARLORD',style:TextStyle(color:Colors.white38,fontSize:9,fontFamily:'Orbitron',letterSpacing:2)),
      const SizedBox(height:8),
      Row(mainAxisAlignment:MainAxisAlignment.center,children:items.map((e)=>Padding(
        padding:const EdgeInsets.symmetric(horizontal:10),
        child:Column(children:[
          Text(e.$1,style:TextStyle(color:e.$2,fontSize:20,shadows:[Shadow(color:e.$2,blurRadius:8)])),
          const SizedBox(height:4),
          Text(e.$3,style:const TextStyle(color:Colors.white54,fontSize:9)),
        ]))).toList()),
    ]);
  }
}

// ══════════════════════════════════════════════════════════
//  GAME OVER SCREEN
// ══════════════════════════════════════════════════════════
class GameOverScreen extends StatelessWidget {
  final int score,best; final VoidCallback onRestart,onMenu;
  const GameOverScreen({super.key,required this.score,required this.best,required this.onRestart,required this.onMenu});
  @override Widget build(BuildContext context){
    final nr=score>=best&&score>0;
    return Scaffold(backgroundColor:cBg,body:SafeArea(child:Center(child:Column(
      mainAxisAlignment:MainAxisAlignment.center,children:[
        const _GlowText('QUENCH',color:cDanger,size:52),const SizedBox(height:6),
        const _GlowText('FALLO CRIOGÉNICO',color:cFire,size:15),const SizedBox(height:36),
        _GlowText('SCORE: $score',color:cGold,size:26),
        if(nr)...[const SizedBox(height:8),const _GlowText('🏆 NUEVO RÉCORD',color:cGold,size:18)],
        _GlowText('MEJOR: $best',color:Colors.white38,size:13),const SizedBox(height:52),
        _Btn(label:'REINTENTAR',color:cFire,onTap:onRestart),const SizedBox(height:18),
        _Btn(label:'MENÚ',color:cIce,onTap:onMenu),
      ]))));
  }
}

// ══════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ══════════════════════════════════════════════════════════
class _GlowText extends StatelessWidget {
  final String text; final Color color; final double size;
  const _GlowText(this.text,{required this.color,required this.size});
  @override Widget build(BuildContext context)=>Text(text,textAlign:TextAlign.center,
      style:TextStyle(color:color,fontSize:size,fontFamily:'Orbitron',fontWeight:FontWeight.bold,
          shadows:[Shadow(color:color.withOpacity(0.8),blurRadius:14),Shadow(color:color.withOpacity(0.3),blurRadius:28)]));
}
class _Btn extends StatelessWidget {
  final String label; final Color color; final VoidCallback onTap;
  const _Btn({required this.label,required this.color,required this.onTap});
  @override Widget build(BuildContext context)=>GestureDetector(onTap:onTap,child:Container(
    padding:const EdgeInsets.symmetric(horizontal:48,vertical:15),
    decoration:BoxDecoration(border:Border.all(color:color,width:1.5),
        borderRadius:BorderRadius.circular(8),color:color.withOpacity(0.12),
        boxShadow:[BoxShadow(color:color.withOpacity(0.3),blurRadius:14)]),
    child:_GlowText(label,color:color,size:17)));
}
