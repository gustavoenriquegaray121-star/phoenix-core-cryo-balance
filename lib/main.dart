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
enum PowerUpKind { rapidFire, tripleShot, shield, coreArmor, energyBoost }

// ══════════════════════════════════════════════════════════
//  INTRO SCENES
// ══════════════════════════════════════════════════════════
class IntroScene {
  final String location;
  final String speaker;
  final String speakerColor;
  final String dialogue;
  final String imageAsset;
  const IntroScene({
    required this.location, required this.speaker,
    required this.speakerColor, required this.dialogue,
    required this.imageAsset,
  });
}

const _scenes = [
  IntroScene(
    location: 'CAFÉ ALTEA — BASE PHOENIX',
    speaker: 'GENERAL G-G', speakerColor: 'gold',
    dialogue: 'Usuario. El Núcleo Cuántico debe llegar hoy al Cuadrante 7 de la Nebulosa de Orión.\nLa colonia Elysium se está quedando sin energía.\nSin ese núcleo… perdemos tres millones de personas en menos de 72 horas.',
    imageAsset: 'assets/images/cafe1.jpg',
  ),
  IntroScene(
    location: 'CAFÉ ALTEA — BASE PHOENIX',
    speaker: 'USUARIO', speakerColor: 'ice',
    dialogue: 'Entendido.\n¿Mi nave?',
    imageAsset: 'assets/images/cafe1.jpg',
  ),
  IntroScene(
    location: 'CAFÉ ALTEA — BASE PHOENIX',
    speaker: 'GENERAL G-G', speakerColor: 'gold',
    dialogue: 'Ya casi terminan las reparaciones.\nVe al hangar.',
    imageAsset: 'assets/images/cafe1.jpg',
  ),
  IntroScene(
    location: 'DOCK 7A — PHOENIX PROJECT',
    speaker: 'USUARIO', speakerColor: 'ice',
    dialogue: 'Núcleo asegurado.\nSistemas en línea.\nPhoenix Project… listo para volar.',
    imageAsset: 'assets/images/hangar1.jpg',
  ),
  IntroScene(
    location: 'DOCK 7A — CASCO DE LA NAVE',
    speaker: '', speakerColor: 'white',
    dialogue: '[ Pones la mano en el casco. El logo del Ave Fénix brilla bajo tus dedos. ]',
    imageAsset: 'assets/images/ship_close.jpg',
  ),
  IntroScene(
    location: 'LADO ENEMIGO — UBICACIÓN DESCONOCIDA',
    speaker: 'THE FROZEN WARLORD', speakerColor: 'red',
    dialogue: 'Phoenix Protocol…\npor eso perdí.\nAhora lo conozco.\nSé cómo bloquearlo.',
    imageAsset: 'assets/images/warlord.jpg',
  ),
  IntroScene(
    location: 'LADO ENEMIGO — UBICACIÓN DESCONOCIDA',
    speaker: 'THE FROZEN WARLORD', speakerColor: 'red',
    dialogue: 'La próxima vez que nos encontremos…\nese pájaro no volverá a abrir sus alas.',
    imageAsset: 'assets/images/warlord.jpg',
  ),
  IntroScene(
    location: 'CABINA — NAVE PHOENIX',
    speaker: 'USUARIO', speakerColor: 'ice',
    dialogue: '¿Qué carajos…?\nEs él…\nThe Frozen Warlord.\nPensé que lo había destruido.\n\nTe vencí una vez…\nY te voy a vencer otra vez.',
    imageAsset: 'assets/images/battle.jpg',
  ),
];

// ══════════════════════════════════════════════════════════
//  AUDIO MANAGER
// ══════════════════════════════════════════════════════════
class AudioManager {
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _alarmPlayer = AudioPlayer();
  bool _alarmOn = false;

  Future<void> playBGM(String asset, {bool loop = true}) async {
    try {
      await _bgmPlayer.stop();
      if (loop) await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.play(AssetSource(asset), volume: 0.45);
    } catch (_) {}
  }

  Future<void> playLaser(bool triple) async {
    try {
      final source = triple ? 'sounds/laser_triple.mp3' : 'sounds/laser.mp3';
      await _sfxPlayer.play(AssetSource(source), volume: 0.3);
    } catch (_) {}
  }

  Future<void> playExplosion(bool isBoss) async {
    try {
      final source = isBoss ? 'sounds/explosion_jefe.mp3' : 'sounds/explosion.mp3';
      await _sfxPlayer.play(AssetSource(source), volume: 0.6);
    } catch (_) {}
  }

  Future<void> startAlarm() async {
    if (_alarmOn) return;
    _alarmOn = true;
    try {
      await _alarmPlayer.setReleaseMode(ReleaseMode.loop);
      await _alarmPlayer.play(AssetSource('sounds/quench.wav'), volume: 0.4);
    } catch (_) {}
  }

  Future<void> stopAlarm() async {
    _alarmOn = false;
    try { await _alarmPlayer.stop(); } catch (_) {}
  }

  Future<void> playQuenchFinal() async {
    try {
      await _sfxPlayer.play(AssetSource('sounds/quench.wav'), volume: 1.0);
    } catch (_) {}
  }

  void stopAll() {
    _bgmPlayer.stop();
    _sfxPlayer.stop();
    _alarmPlayer.stop();
  }

  void dispose() {
    _bgmPlayer.dispose();
    _sfxPlayer.dispose();
    _alarmPlayer.dispose();
  }
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
  double angle; 
  Bullet(this.x, this.y, this.damage, {this.isEnemy=false, this.angle=0});
}

class PowerUp {
  double x, y;
  PowerUpKind kind;
  bool collected=false;
  double animT=0;
  PowerUp(this.x, this.y, this.kind);
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

  void update(double dt,
      {required VoidCallback onDecision, required VoidCallback onBoss}) {
    timer += dt;
    if (phase==GamePhase.combat && timer>=kCombatDuration) {
      cycleCount++; timer=0;
      if (cycleCount%3==0) { phase=GamePhase.boss; onBoss(); }
      else { phase=GamePhase.decision; onDecision(); }
    }
  }
  void endDecision() { phase=GamePhase.combat; timer=0; }
  void endBoss()     { phase=GamePhase.combat; timer=0; }
  double get combatProgress =>
      phase==GamePhase.combat ? (timer/kCombatDuration).clamp(0,1) : 1.0;
}

// ══════════════════════════════════════════════════════════
//  RESOURCE SYSTEM (CORREGIDO: CALENTAMIENTO POR MOVIMIENTO)
// ══════════════════════════════════════════════════════════
class ResourceSystem {
  double energy=100, heat=0, entropy=0;

  void update(double dt, PlayerBuild b, bool isMoving) {
    // El enfriamiento base se ve afectado por la eficiencia criogénica
    double coolingRate = 8 * b.cooling;
    
    // Penalización térmica por movimiento (esfuerzo de motores)
    if (isMoving) {
      heat += 6.5 * dt; 
    }

    heat = (heat - coolingRate * dt).clamp(0,100);
    energy = (energy + 4*dt).clamp(0,b.maxEnergy);
    entropy = (entropy + 0.3*dt).clamp(0,100);
    
    if (heat>85) energy -= 15*dt;
  }

  void applyShoot(PlayerBuild b) {
    energy -= 2.5; 
    // Disparar genera calor inversamente proporcional al cooling
    heat += 4.5 / b.cooling; 
    entropy += 0.4;
  }

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
    if (b.damage>15)  aggression    = (aggression+0.15).clamp(1,3);
    if (b.fireRate>1.5) swarmDensity = (swarmDensity+0.20).clamp(1,3);
    if (b.shieldEfficiency>1.3) counterFire=(counterFire+0.30).clamp(0.5,2);
  }
  double spawnInterval(int cycle) => (2.5 - cycle*0.2).clamp(0.5, 2.5) / aggression;
  int waveSize(int cycle) => (1 + (cycle * 0.4 + swarmDensity * 0.5)).floor().clamp(1,5);
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
  int _idx = 0;
  int _charIdx = 0;
  String _displayed = '';
  bool _full = false;
  late AnimationController _typeCtrl;

  @override
  void initState() {
    super.initState();
    _typeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 35));
    _typeCtrl.addListener(_onTick);
    _startScene();
  }

  void _startScene() {
    _charIdx = 0; _displayed = ''; _full = false;
    _typeCtrl.repeat();
  }

  void _onTick() {
    final full = _scenes[_idx].dialogue;
    if (_charIdx < full.length) {
      setState(() { _charIdx++; _displayed = full.substring(0, _charIdx); });
    } else {
      _typeCtrl.stop();
      setState(() => _full = true);
    }
  }

  void _next() {
    if (!_full) {
      _typeCtrl.stop();
      setState(() { _displayed = _scenes[_idx].dialogue; _full = true; });
      return;
    }
    if (_idx < _scenes.length-1) {
      setState(() => _idx++);
      _startScene();
    } else {
      widget.onDone();
    }
  }

  @override
  void dispose() { _typeCtrl.dispose(); super.dispose(); }

  Color _spColor(String s) => switch(s) {
    'gold' => cGold, 'ice' => cIce, 'red' => cDanger, _ => Colors.white,
  };

  @override
  Widget build(BuildContext context) {
    final scene = _scenes[_idx];
    final sc = _spColor(scene.speakerColor);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (_) => _next(),
        child: Column(children: [
          Expanded(
            flex: 55,
            child: Stack(children: [
              Positioned.fill(
                child: Image.asset(
                  scene.imageAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF050A14),
                    child: const Center(
                        child: Icon(Icons.image_not_supported,
                            color: Colors.white24, size: 48)),
                  ),
                ),
              ),
              Positioned(
                bottom: 0, left: 0, right: 0, height: 80,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 12, right: 80,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    border: Border.all(color: cGold.withOpacity(0.6)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(scene.location,
                      style: const TextStyle(color: cGold, fontSize: 9,
                          fontFamily: 'Orbitron', letterSpacing: 1.5)),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 12,
                child: Text('${_idx+1}/${_scenes.length}',
                    style: const TextStyle(color: Colors.white38, fontSize: 10,
                        fontFamily: 'Orbitron')),
              ),
            ]),
          ),
          Container(
            constraints: BoxConstraints(minHeight: size.height * 0.32),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border(top: BorderSide(color: sc.withOpacity(0.5), width: 1.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (scene.speaker.isNotEmpty) ...[
                  Row(children: [
                    Container(width: 3, height: 14,
                        decoration: BoxDecoration(color: sc,
                            boxShadow: [BoxShadow(color: sc, blurRadius: 5)])),
                    const SizedBox(width: 8),
                    Text(scene.speaker, style: TextStyle(color: sc, fontSize: 11,
                        fontFamily: 'Orbitron', fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: sc.withOpacity(0.6), blurRadius: 6)])),
                  ]),
                  const SizedBox(height: 10),
                ],
                Text(_displayed,
                    style: const TextStyle(color: Colors.white, fontSize: 13,
                        height: 1.55, fontFamily: 'Orbitron')),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (_full)
                    Row(children: [
                      Text(_idx==_scenes.length-1 ? 'INICIAR MISIÓN' : 'SIGUIENTE',
                          style: TextStyle(color: sc, fontSize: 10,
                              fontFamily: 'Orbitron', letterSpacing: 1.5)),
                      const SizedBox(width: 6),
                      Icon(_idx==_scenes.length-1
                          ? Icons.rocket_launch : Icons.arrow_forward_ios,
                          color: sc, size: 14),
                    ])
                  else
                    Text('toca para continuar',
                        style: const TextStyle(color: Colors.white24,
                            fontSize: 9, fontFamily: 'Orbitron')),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
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
  final _powerUps  = <PowerUp>[];
  final _particles = <Particle>[];
  final _floats    = <FloatingText>[];

  Enemy? _boss;
  bool   _bossAlive=false;

  int    _score=0;
  double _coreTemp=0;
  double _shootTimer=0, _spawnTimer=0;
  double _powerUpTimer=15.0; 
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
      _audio.playBGM('sounds/musica_ambiente.mp3');
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
        _audio.stopAlarm(); 
        _audio.playQuenchFinal();
        _spawnQuenchExplosion();
      }
      setState((){}); return;
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
    
    // CORREGIDO: Pasar _touching para penalización de calor por movimiento
    _res.update(dt, _player.build, _touching);
    _player.energy=_res.energy; _player.heat=_res.heat;

    if (_res.heatFrac>=0.8 && !_alarmOn) { 
      _alarmOn=true; 
      _audio.startAlarm();
    } else if (_res.heatFrac<0.75 && _alarmOn) { 
      _alarmOn=false; 
      _audio.stopAlarm(); 
    }

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
      if (_shootTimer<=0) {
        _shootTimer=0.14/_player.build.fireRate;
        _fireLaser();
      }
    }

    for (final b in _bullets) {
      if (b.isEnemy) {
        b.y += 380*dt;
      } else {
        b.x += sin(b.angle)*560*dt;
        b.y -= cos(b.angle)*560*dt;
      }
    }
    _bullets.removeWhere((b) => b.y<-20 || b.y>_sh+20 || b.x<-20 || b.x>_sw+20);

    _powerUpTimer-=dt;
    if (_powerUpTimer<=0) {
      _powerUpTimer = 18.0 + _rng.nextDouble()*8;
      _spawnPowerUp();
    }
    _updatePowerUps(dt);

    if (_phase.phase==GamePhase.combat && !_bossAlive) {
      _spawnTimer-=dt;
      if (_spawnTimer<=0) {
        _spawnTimer = _ai.spawnInterval(_phase.cycleCount);
        final count = _ai.waveSize(_phase.cycleCount);
        for (int i=0; i<count; i++) _spawnEnemy();
      }
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

  void _fireLaser() {
    _res.applyShoot(_player.build);
    bool isTriple = _player.build.fireRate > 1.8;
    _audio.playLaser(isTriple);

    final py = _sh*0.72 - kPhoenixSize;
    _bullets.add(Bullet(_player.x, py, _player.build.damage, angle: 0));

    if (isTriple) {
      _bullets.add(Bullet(_player.x, py, _player.build.damage*0.7, angle: -0.12));
      _bullets.add(Bullet(_player.x, py, _player.build.damage*0.7, angle:  0.12));
    }
  }

  void _spawnEnemy() {
    final cycle = _phase.cycleCount;
    EnemyKind k;
    final r = _rng.nextDouble();
    if (cycle == 0) {
      k = EnemyKind.interceptor;
    } else if (cycle == 1) {
      k = r < 0.6 ? EnemyKind.interceptor : EnemyKind.frigate;
    } else if (cycle == 2) {
      if      (r < 0.45) k = EnemyKind.interceptor;
      else if (r < 0.75) k = EnemyKind.frigate;
      else               k = EnemyKind.parasite;
    } else {
      if      (r < 0.35) k = EnemyKind.interceptor;
      else if (r < 0.60) k = EnemyKind.frigate;
      else if (r < 0.80) k = EnemyKind.parasite;
      else               k = EnemyKind.corrupter;
    }

    final base = 15.0 + cycle*5;
    final hp   = k==EnemyKind.parasite ? base*1.5 : k==EnemyKind.frigate ? base*0.8 : base;
    _enemies.add(Enemy(
      x: 20+_rng.nextDouble()*(_sw-40), y: -kEnemyR, hp: hp,
      vx: (_rng.nextBool()?1:-1)*(50+_rng.nextDouble()*60),
      vy: 65 + cycle*4.0 + _rng.nextDouble()*15,
      kind: k,
    ));
  }

  void _spawnPowerUp() {
    final cycle = _phase.cycleCount;
    final available = <PowerUpKind>[PowerUpKind.energyBoost];
    if (cycle >= 1) available.add(PowerUpKind.rapidFire);
    if (cycle >= 1) available.add(PowerUpKind.shield);
    if (cycle >= 2) available.add(PowerUpKind.tripleShot);
    if (cycle >= 3) available.add(PowerUpKind.coreArmor);

    final kind = available[_rng.nextInt(available.length)];
    _powerUps.add(PowerUp(
      20 + _rng.nextDouble()*(_sw-40),
      -30,
      kind,
    ));
  }

  void _updatePowerUps(double dt) {
    for (final p in _powerUps) {
      p.y += 70*dt;
      p.animT += dt*3;
      if (!p.collected) {
        final px = _player.x, py = _sh*0.72;
        if ((p.x-px).abs()<35 && (p.y-py).abs()<35) {
          p.collected = true;
          _applyPowerUp(p.kind);
          _spawnBurst(p.x, p.y, _powerUpColor(p.kind), 16);
          _addFloat(p.x, p.y-10, _powerUpLabel(p.kind), _powerUpColor(p.kind));
        }
      }
    }
    _powerUps.removeWhere((p) => p.y > _sh+40 || p.collected);
  }

  void _applyPowerUp(PowerUpKind k) {
    switch (k) {
      case PowerUpKind.rapidFire:
        _player.build.fireRate = (_player.build.fireRate * 1.4).clamp(1.0, 3.0);
      case PowerUpKind.tripleShot:
        _player.build.fireRate = (_player.build.fireRate * 1.2).clamp(1.0, 3.0);
        _player.build.damage  *= 1.1;
      case PowerUpKind.shield:
        _player.shieldActive = true;
        _player.shieldTimer = 12.0;
      case PowerUpKind.coreArmor:
        _coreTemp = (_coreTemp - 0.2).clamp(0, 1);
        _player.build.modules.add('core_armor');
      case PowerUpKind.energyBoost:
        _res.energy = (_res.energy + 35).clamp(0, _player.build.maxEnergy);
        _res.heat   = (_res.heat - 20).clamp(0, 100);
    }
  }

  Color  _powerUpColor(PowerUpKind k) => switch(k) {
    PowerUpKind.rapidFire   => cFire,
    PowerUpKind.tripleShot  => cGold,
    PowerUpKind.shield      => cShield,
    PowerUpKind.coreArmor   => cIce,
    PowerUpKind.energyBoost => const Color(0xFF00FF88),
  };

  String _powerUpLabel(PowerUpKind k) => switch(k) {
    PowerUpKind.rapidFire   => '⚡ RAPID FIRE',
    PowerUpKind.tripleShot  => '💥 TRIPLE SHOT',
    PowerUpKind.shield      => '🛡 ESCUDO',
    PowerUpKind.coreArmor   => '❄ CORE ARMOR',
    PowerUpKind.energyBoost => '💚 ENERGÍA +35',
  };

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
            _bullets.add(Bullet(e.x, e.y+kEnemyR, 8, isEnemy:true));
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
        _audio.playExplosion(false);
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
            _audio.playExplosion(false);
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
              _spawnBurst(e.x,e.y,_eColor(e.kind),16);
              _audio.playExplosion(false);
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
              _audio.playExplosion(true);
              _addFloat(bo.x,bo.y,'+500 BOSS!',cGold);
              _phase.endBoss(); 
              _audio.playBGM('sounds/musica_ambiente.mp3');
              _ai.analyze(_player.build);
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
    EnemyKind.interceptor=>cWarlord, EnemyKind.frigate=>const Color(0xFF00FF88),
    EnemyKind.parasite=>cShield,     EnemyKind.corrupter=>const Color(0xFFFF6600)};

  void _triggerDecision() {
    _ai.analyze(_player.build); _options=_buildOptions(); _showDecision=true;
  }
  void _triggerBoss() {
    _enemies.clear();
    _boss=Enemy(x:_sw/2, y:_sh*0.18,
        hp:80+_phase.cycleCount*20.0, vx:90, kind:EnemyKind.frigate);
    _bossAlive=true;
    _audio.playBGM('sounds/musica_jefe.mp3');
  }
  void _beginFrost() {
    if (_frosting||_quenching) return;
    _frosting=true; _coreTemp=1.0; _audio.stopAlarm();
  }
  void _spawnQuenchExplosion() {
    for (int i=0;i<80;i++) {
      final a=_rng.nextDouble()*pi*2; final s=100+_rng.nextDouble()*320;
      _particles.add(Particle(x:_sw/2,y:_sh*0.87,vx:cos(a)*s,vy:sin(a)*s,
          life:1.2+_rng.nextDouble(),color:_rng.nextBool()?cFire:cIce,
          size:5+_rng.nextDouble()*12));
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
      UpgradeOption(title:'Plasma Overload',   description:'+40% daño de disparo', emoji:'🔥',color:cFire,  apply:(b)=>b.damage*=1.4),
      UpgradeOption(title:'Cryo Stabilizer',   description:'Enfriamiento +50%',    emoji:'❄️',color:cIce,   apply:(b)=>b.cooling*=1.5),
      UpgradeOption(title:'Void Pulse',        description:'Cadencia +30%',        emoji:'⚡',color:cGold,  apply:(b)=>b.fireRate*=1.3),
      UpgradeOption(title:'Energy Core Expand',description:'Energía máxima +25',   emoji:'💙',color:cIce,   apply:(b)=>b.maxEnergy+=25),
      UpgradeOption(title:'Entropy Shield',    description:'Escudo 12 segundos',   emoji:'🛡️',color:cShield,apply:(b){b.shieldEfficiency+=0.4;}),
      UpgradeOption(title:'Quantum Burst',     description:'Triple shot permanente',emoji:'💥',color:cFire, apply:(b)=>b.fireRate=(b.fireRate*1.2).clamp(0,2.5)),
      UpgradeOption(title:'Core Armor',        description:'Blindaje del núcleo',  emoji:'🔮',color:cShield,apply:(b)=>b.modules.add('core_armor')),
      UpgradeOption(title:'Phoenix Overdrive', description:'+20% todo · -10% cool',emoji:'🦅',color:cGold, apply:(b){b.damage*=1.2;b.fireRate*=1.2;b.cooling*=0.9;}),
    ];
    all.shuffle(_rng); return all.take(3).toList();
  }

  void _spawnBurst(double x,double y,Color c,int n) {
    for(int i=0;i<n;i++){
      final a=_rng.nextDouble()*pi*2; final s=40+_rng.nextDouble()*200;
      _particles.add(Particle(x:x,y:y,vx:cos(a)*s,vy:sin(a)*s,
          life:0.3+_rng.nextDouble()*0.55,color:c,size:2+_rng.nextDouble()*6));
    }
  }
  void _addFloat(double x,double y,String t,Color c)=>
      _floats.add(FloatingText(x,y,t,c));
  void _updateParticles(double dt){
    for(final p in _particles){p.x+=p.vx*dt;p.y+=p.vy*dt;if(!p.isFrost)p.vy+=40*dt;p.life-=dt;}
    _particles.removeWhere((p)=>p.life<=0);
  }
  void _updateFloats(double dt){
    for(final f in _floats){f.y-=55*dt;f.life-=dt*1.5;}
    _floats.removeWhere((f)=>f.life<=0);
  }

  void _onPanStart(DragStartDetails d){_touching=true;_touchX=d.localPosition.dx;}
  void _onPanUpdate(DragUpdateDetails d){_touchX=d.localPosition.dx;}
  void _onPanEnd(DragEndDetails _){_touching=false;}
  void _onTapDown(TapDownDetails d){_touching=true;_touchX=d.localPosition.dx;}
  void _onTapUp(TapUpDetails _){_touching=false;}

  @override
  Widget build(BuildContext context) {
    final sz=MediaQuery.of(context).size; _sw=sz.width; _sh=sz.height;
    final laserColor = Color.lerp(cIce, cDanger, _res.heatFrac)!;

    return Scaffold(
      backgroundColor: cBg,
      body: Stack(children:[
        GestureDetector(
          onPanStart:_onPanStart,onPanUpdate:_onPanUpdate,onPanEnd:_onPanEnd,
          onTapDown:_onTapDown,onTapUp:_onTapUp,
          child: CustomPaint(
            painter: GamePainter(
              sw:_sw,sh:_sh,player:_player,
              enemies:_enemies,bullets:_bullets,powerUps:_powerUps,
              boss:_bossAlive?_boss:null,
              particles:_particles,floats:_floats,
              score:_score,res:_res,phase:_phase,
              coreTemp:_coreTemp,corePulse:_corePulse,
              laserColor:laserColor,
              frosting:_frosting,frostT:_frostT,
              quenching:_quenching,quenchT:_quenchT,
              touching:_touching,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        if (_showDecision)
          _DecisionOverlay(options:_options,cycle:_phase.cycleCount,onSelect:_selectUpgrade),
        if (_phase.phase==GamePhase.boss&&_bossAlive)
          Positioned(top:8,left:0,right:0,
            child:Center(child:_GlowText('⚠ FROZEN WARLORD ⚠',color:cWarlord,size:14))),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  GAME PAINTER
// ══════════════════════════════════════════════════════════
class GamePainter extends CustomPainter {
  final double sw,sh,coreTemp,corePulse,frostT,quenchT;
  final bool frosting,quenching,touching;
  final Color laserColor;
  final Player player;
  final List<Enemy> enemies;
  final List<Bullet> bullets;
  final List<PowerUp> powerUps;
  final Enemy? boss;
  final List<Particle> particles;
  final List<FloatingText> floats;
  final int score;
  final ResourceSystem res;
  final PhaseEngine phase;

  const GamePainter({
    required this.sw,required this.sh,required this.player,
    required this.enemies,required this.bullets,required this.powerUps,
    required this.boss,required this.particles,required this.floats,
    required this.score,required this.res,required this.phase,
    required this.coreTemp,required this.corePulse,required this.laserColor,
    required this.frosting,required this.frostT,
    required this.quenching,required this.quenchT,required this.touching,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _bg(canvas);
    _drawNucleus(canvas);
    _drawPowerUps(canvas);
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
    canvas.drawCircle(Offset(cx,cy),pulse+4,
        Paint()..color=tempC.withOpacity(0.35)..style=PaintingStyle.stroke..strokeWidth=0.8);
    final lp=Paint()..color=tempC.withOpacity(0.2)..strokeWidth=0.7;
    canvas.drawLine(Offset(cx-pulse-10,cy),Offset(cx+pulse+10,cy),lp);
    canvas.drawLine(Offset(cx,cy-pulse-10),Offset(cx,cy+pulse+10),lp);
    final rng=Random((corePulse*20).toInt());
    final blp=Paint()..color=tempC.withOpacity(0.6)..style=PaintingStyle.stroke..strokeWidth=1.2;
    for(int i=0;i<8;i++){
      final a=i*pi/4+corePulse*pi*0.5;
      _bolt(canvas,blp,
          Offset(cx+cos(a)*pulse*0.5,cy+sin(a)*pulse*0.5),
          Offset(cx+cos(a)*(pulse+22),cy+sin(a)*(pulse+22)),rng);
    }
    _drawArcBar(canvas,cx,cy,pulse+32,coreTemp,tempC);
    _txt(canvas,'NÚCLEO CUÁNTICO',Offset(cx,cy+pulse+22),tempC.withOpacity(0.8),9);
  }

  void _drawArcBar(Canvas canvas,double cx,double cy,double r,double frac,Color c){
    const st=-pi*0.75, sw2=pi*1.5;
    canvas.drawArc(Rect.fromCircle(center:Offset(cx,cy),radius:r),st,sw2,false,
        Paint()..color=Colors.white12..style=PaintingStyle.stroke..strokeWidth=4..strokeCap=StrokeCap.round);
    if(frac>0) canvas.drawArc(Rect.fromCircle(center:Offset(cx,cy),radius:r),st,sw2*frac,false,
        Paint()..color=c..style=PaintingStyle.stroke..strokeWidth=4..strokeCap=StrokeCap.round);
  }

  void _bolt(Canvas canvas,Paint p,Offset a,Offset b,Random rng){
    final path=Path()..moveTo(a.dx,a.dy);
    for(int i=1;i<4;i++){final t=i/4;path.lineTo(
        a.dx+(b.dx-a.dx)*t+(rng.nextDouble()-0.5)*10,
        a.dy+(b.dy-a.dy)*t+(rng.nextDouble()-0.5)*10);}
    path.lineTo(b.dx,b.dy); canvas.drawPath(path,p);
  }

  void _drawPowerUps(Canvas canvas) {
    for (final p in powerUps) {
      if (p.collected) continue;
      final c   = _puColor(p.kind);
      final lbl = _puIcon(p.kind);
      final pulse = sin(p.animT)*0.15 + 1.0;
      canvas.drawCircle(Offset(p.x, p.y), 22*pulse,
          Paint()..color=c.withOpacity(0.25)..maskFilter=const MaskFilter.blur(BlurStyle.normal,10));
      canvas.drawCircle(Offset(p.x, p.y), 18*pulse,
          Paint()..color=c.withOpacity(0.7)..style=PaintingStyle.stroke..strokeWidth=2);
      _txt(canvas, lbl, Offset(p.x, p.y), c, 16);
    }
  }

  Color  _puColor(PowerUpKind k) => switch(k){
    PowerUpKind.rapidFire=>cFire, PowerUpKind.tripleShot=>cGold,
    PowerUpKind.shield=>cShield,  PowerUpKind.coreArmor=>cIce,
    PowerUpKind.energyBoost=>const Color(0xFF00FF88)};
  String _puIcon(PowerUpKind k) => switch(k){
    PowerUpKind.rapidFire=>'⚡', PowerUpKind.tripleShot=>'💥',
    PowerUpKind.shield=>'🛡',    PowerUpKind.coreArmor=>'❄',
    PowerUpKind.energyBoost=>'💚'};

  void _drawPhoenix(Canvas canvas) {
    final px=player.x, py=sh*0.72;
    if (player.shieldActive) {
      canvas.drawCircle(Offset(px,py),kPhoenixSize*1.7,
          Paint()..color=cShield.withOpacity(0.3)..maskFilter=const MaskFilter.blur(BlurStyle.normal,10));
      canvas.drawCircle(Offset(px,py),kPhoenixSize*1.7,
          Paint()..color=cShield.withOpacity(0.7)..style=PaintingStyle.stroke..strokeWidth=2);
    }
    canvas.drawCircle(Offset(px,py+kPhoenixSize*0.55),kPhoenixSize*0.35,
        Paint()..color=cFire.withOpacity(touching?0.85:0.3)
          ..maskFilter=const MaskFilter.blur(BlurStyle.normal,12));
    final bodyP=Paint()..shader=LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
        colors:[const Color(0xFF999999),const Color(0xFF555555)])
        .createShader(Rect.fromCenter(center:Offset(px,py),width:kPhoenixSize*0.6,height:kPhoenixSize*1.8));
    canvas.drawPath(Path()
      ..moveTo(px,py-kPhoenixSize*0.85)
      ..lineTo(px+kPhoenixSize*0.22,py+kPhoenixSize*0.45)
      ..lineTo(px,py+kPhoenixSize*0.25)
      ..lineTo(px-kPhoenixSize*0.22,py+kPhoenixSize*0.45)..close(), bodyP);
    final wc=const Color(0xFF666666);
    canvas.drawPath(Path()
      ..moveTo(px-kPhoenixSize*0.18,py)
      ..lineTo(px-kPhoenixSize*1.25,py+kPhoenixSize*0.1)
      ..lineTo(px-kPhoenixSize*0.9,py+kPhoenixSize*0.5)
      ..lineTo(px-kPhoenixSize*0.2,py+kPhoenixSize*0.35)..close(),
        Paint()..color=wc);
    canvas.drawPath(Path()
      ..moveTo(px+kPhoenixSize*0.18,py)
      ..lineTo(px+kPhoenixSize*1.25,py+kPhoenixSize*0.1)
      ..lineTo(px+kPhoenixSize*0.9,py+kPhoenixSize*0.5)
      ..lineTo(px+kPhoenixSize*0.2,py+kPhoenixSize*0.35)..close(),
        Paint()..color=wc);
    canvas.drawCircle(Offset(px,py-kPhoenixSize*0.3),kPhoenixSize*0.18,
        Paint()..color=cIce.withOpacity(0.8)..maskFilter=const MaskFilter.blur(BlurStyle.normal,5));
    canvas.drawCircle(Offset(px,py+kPhoenixSize*0.05),kPhoenixSize*0.12,
        Paint()..color=cFire.withOpacity(0.6)..maskFilter=const MaskFilter.blur(BlurStyle.normal,4));
    _txt(canvas,'G·G',Offset(px,py+kPhoenixSize*0.05),cGold.withOpacity(0.8),7);
    final wl=Paint()..color=Colors.white.withOpacity(0.2)..strokeWidth=0.7..style=PaintingStyle.stroke;
    canvas.drawLine(Offset(px-kPhoenixSize*0.15,py+2),Offset(px-kPhoenixSize*0.95,py+kPhoenixSize*0.25),wl);
    canvas.drawLine(Offset(px+kPhoenixSize*0.15,py+2),Offset(px+kPhoenixSize*0.95,py+kPhoenixSize*0.25),wl);
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

  void _drawEnemies(Canvas canvas) {
    for (final e in enemies) {
      if (e.dead) continue;
      final base=_eColor(e.kind);
      final c=e.hitFlash>0?Color.lerp(base,Colors.white,e.hitFlash)!:base;
      canvas.drawCircle(Offset(e.x,e.y),kEnemyR*1.5,
          Paint()..color=c.withOpacity(0.15)..maskFilter=const MaskFilter.blur(BlurStyle.normal,10));
      switch(e.kind){
        case EnemyKind.interceptor: _drawInterceptor(canvas,e,c);
        case EnemyKind.frigate:     _drawFrigate(canvas,e,c);
        case EnemyKind.parasite:    _drawParasite(canvas,e,c);
        case EnemyKind.corrupter:   _drawCorrupter(canvas,e,c);
      }
      if (e.maxHp>20){
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

  void _drawInterceptor(Canvas canvas,Enemy e,Color c){
    canvas.drawOval(Rect.fromCenter(center:Offset(e.x,e.y),width:kEnemyR*1.8,height:kEnemyR*0.9),
        Paint()..color=c.withOpacity(0.85));
    canvas.drawCircle(Offset(e.x,e.y),kEnemyR*0.28,
        Paint()..color=Colors.white.withOpacity(0.9)..maskFilter=const MaskFilter.blur(BlurStyle.normal,4));
    for(final dx in [-kEnemyR*0.7,kEnemyR*0.7])
      canvas.drawCircle(Offset(e.x+dx,e.y),kEnemyR*0.2,
          Paint()..color=const Color(0xFF8833FF).withOpacity(0.9)..maskFilter=const MaskFilter.blur(BlurStyle.normal,5));
  }

  void _drawFrigate(Canvas canvas,Enemy e,Color c){
    canvas.drawPath(Path()
      ..moveTo(e.x,e.y-kEnemyR*1.1)..lineTo(e.x+kEnemyR*0.5,e.y)
      ..lineTo(e.x,e.y+kEnemyR*1.1)..lineTo(e.x-kEnemyR*0.5,e.y)..close(),
        Paint()..color=c.withOpacity(0.85));
    canvas.drawLine(Offset(e.x,e.y+kEnemyR*1.1),Offset(e.x,e.y+kEnemyR*1.6),
        Paint()..color=c.withOpacity(0.8)..strokeWidth=3);
    canvas.drawCircle(Offset(e.x,e.y),kEnemyR*0.22,
        Paint()..color=Colors.white.withOpacity(0.5+sin(e.animT*4)*0.4)
          ..maskFilter=const MaskFilter.blur(BlurStyle.normal,4));
  }

  void _drawParasite(Canvas canvas,Enemy e,Color c){
    final p=Path();
    for(int i=0;i<6;i++){final a=i*pi/3+e.animT*0.2;
      if(i==0)p.moveTo(e.x+cos(a)*kEnemyR,e.y+sin(a)*kEnemyR);
      else p.lineTo(e.x+cos(a)*kEnemyR,e.y+sin(a)*kEnemyR);}
    p.close(); canvas.drawPath(p,Paint()..color=c.withOpacity(0.85));
    final tp=Paint()..color=c.withOpacity(0.5)..strokeWidth=1.5..style=PaintingStyle.stroke;
    for(int i=0;i<3;i++){final a=i*pi*2/3+e.animT;
      canvas.drawLine(Offset(e.x,e.y),Offset(e.x+cos(a)*kEnemyR*1.5,e.y+sin(a)*kEnemyR*1.5),tp);}
    canvas.drawCircle(Offset(e.x,e.y),kEnemyR*0.28,
        Paint()..color=Colors.white.withOpacity(0.85)..maskFilter=const MaskFilter.blur(BlurStyle.normal,3));
  }

  void _drawCorrupter(Canvas canvas,Enemy e,Color c){
    final p=Path();
    for(int i=0;i<8;i++){final a=i*pi/4+e.animT*0.5;final r=i.isEven?kEnemyR:kEnemyR*0.42;
      if(i==0)p.moveTo(e.x+cos(a)*r,e.y+sin(a)*r);
      else p.lineTo(e.x+cos(a)*r,e.y+sin(a)*r);}
    p.close(); canvas.drawPath(p,Paint()..color=c);
    canvas.drawCircle(Offset(e.x,e.y),kEnemyR*0.22,
        Paint()..color=const Color(0xFFFF0000).withOpacity(0.9)..maskFilter=const MaskFilter.blur(BlurStyle.normal,5));
  }

  Color _eColor(EnemyKind k) => switch(k){
    EnemyKind.interceptor=>cWarlord, EnemyKind.frigate=>const Color(0xFF00FF88),
    EnemyKind.parasite=>cShield,     EnemyKind.corrupter=>const Color(0xFFFF6600)};

  void _drawBoss(Canvas canvas,Enemy b){
    final frac=(b.hp/b.maxHp).clamp(0.0,1.0);
    final c=b.hitFlash>0?Color.lerp(cWarlord,Colors.white,b.hitFlash)!:cWarlord;
    canvas.drawCircle(Offset(b.x,b.y),kBossR*1.8,
        Paint()..color=c.withOpacity(0.12)..maskFilter=const MaskFilter.blur(BlurStyle.normal,30));
    final path=Path();
    for(int i=0;i<6;i++){final a=i*pi/3+b.animT*0.15;
      if(i==0)path.moveTo(b.x+cos(a)*kBossR,b.y+sin(a)*kBossR);
      else path.lineTo(b.x+cos(a)*kBossR,b.y+sin(a)*kBossR);}
    path.close();
    canvas.drawPath(path,Paint()..shader=RadialGradient(
        colors:[c.withOpacity(0.95),const Color(0xFF112244)],stops:const[0.3,1.0])
        .createShader(Rect.fromCircle(center:Offset(b.x,b.y),radius:kBossR)));
    for(int i=-2;i<=2;i++){final sx=b.x+i*kBossR*0.28;
      canvas.drawLine(Offset(sx-5,b.y-kBossR),Offset(sx,b.y-kBossR-14-i.abs()*6),
          Paint()..color=cFrost.withOpacity(0.8)..strokeWidth=2.5);
      canvas.drawLine(Offset(sx+5,b.y-kBossR),Offset(sx,b.y-kBossR-14-i.abs()*6),
          Paint()..color=cFrost.withOpacity(0.8)..strokeWidth=2.5);}
    canvas.drawCircle(Offset(b.x,b.y),kBossR*0.28,Paint()..color=Colors.black.withOpacity(0.7));
    canvas.drawCircle(Offset(b.x,b.y),kBossR*0.18,
        Paint()..color=c..maskFilter=const MaskFilter.blur(BlurStyle.normal,12));
    canvas.drawCircle(Offset(b.x,b.y),kBossR*0.07,Paint()..color=Colors.white);
    final sp=Paint()..color=c.withOpacity(0.45)..strokeWidth=1.5..style=PaintingStyle.stroke;
    for(int i=0;i<6;i++){final a=i*pi/3+b.animT*0.5;
      canvas.drawLine(Offset(b.x+cos(a)*kBossR,b.y+sin(a)*kBossR),
          Offset(b.x+cos(a)*(kBossR+18),b.y+sin(a)*(kBossR+18)),sp);}
    const bw=kBossR*2;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(b.x-bw/2,b.y-kBossR-14,bw,6),const Radius.circular(3)),Paint()..color=Colors.white24);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(b.x-bw/2,b.y-kBossR-14,bw*frac,6),const Radius.circular(3)),
        Paint()..color=Color.lerp(cDanger,cWarlord,frac)!);
    _txt(canvas,'FROZEN WARLORD  ${(frac*100).toInt()}%',Offset(b.x,b.y-kBossR-26),cWarlord,10);
  }

  void _drawBullets(Canvas canvas) {
    for (final b in bullets) {
      if (b.isEnemy) {
        canvas.drawCircle(Offset(b.x,b.y),8,
            Paint()..color=cWarlord..maskFilter=const MaskFilter.blur(BlurStyle.normal,6));
        canvas.drawCircle(Offset(b.x,b.y),3,Paint()..color=cFrost);
      } else {
        final lc = laserColor;
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center:Offset(b.x,b.y),width:9,height:22),
                const Radius.circular(4)),
            Paint()..color=lc.withOpacity(0.25)..maskFilter=const MaskFilter.blur(BlurStyle.normal,6));
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center:Offset(b.x,b.y),width:3,height:20),
                const Radius.circular(2)),
            Paint()..shader=LinearGradient(
              begin:Alignment.topCenter,end:Alignment.bottomCenter,
              colors:[Colors.white,lc,lc.withOpacity(0.5)],
            ).createShader(Rect.fromCenter(center:Offset(b.x,b.y),width:3,height:20)));
        canvas.drawCircle(Offset(b.x,b.y-9),2.5,
            Paint()..color=Colors.white.withOpacity(0.95));
      }
    }
  }

  void _drawParticles(Canvas canvas){
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

  void _drawFloats(Canvas canvas){
    for(final f in floats)
      _txt(canvas,f.text,Offset(f.x,f.y),f.color.withOpacity(f.life.clamp(0,1)),11);
  }

  void _drawHUD(Canvas canvas){
    _txt(canvas,'SCORE  $score',Offset(16,56),Colors.white,15,left:true);
    final label=switch(phase.phase){
      GamePhase.combat  =>'COMBAT  ${(phase.combatProgress*100).toInt()}%',
      GamePhase.decision=>'DECISIÓN',GamePhase.boss=>'⚠ WARLORD',
    };
    _txt(canvas,label,Offset(sw/2,56),cIce,11);
    final bw=sw*0.4,bx=(sw-bw)/2;
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

  void _drawFrost(Canvas canvas){
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
        final ex=sx+cos(a)*l;final ey=sy+sin(a)*l;
        canvas.drawLine(Offset(sx,sy),Offset(ex,ey),cp);
        if(rng.nextDouble()<0.5)crack(ex,ey,depth-1);}}
    crack(0,0,4);crack(sw,0,4);crack(0,sh,4);crack(sw,sh,4);
    final pulse=sin(frostT*pi*8)*0.5+0.5;
    _txt(canvas,'❄  QUENCH CRÍTICO  ❄',Offset(sw/2,sh*0.38),cFrost.withOpacity(0.6+pulse*0.4),18);
  }

  void _drawQuench(Canvas canvas){
    final a=(quenchT/2.5).clamp(0.0,0.92);
    canvas.drawRect(Rect.fromLTWH(0,0,sw,sh),Paint()..color=cFire.withOpacity(a*0.8));
    _txt(canvas,'💥  QUENCH  💥',Offset(sw/2,sh*0.38),Colors.white,38);
    _txt(canvas,'FALLO CRIOGÉNICO TOTAL',Offset(sw/2,sh*0.48),cFire,16);
  }

  void _txt(Canvas canvas,String t,Offset pos,Color c,double sz,{bool left=false}){
    final tp=TextPainter(
      text:TextSpan(text:t,style:TextStyle(color:c,fontSize:sz,fontFamily:'Orbitron',
          fontWeight:FontWeight.bold,shadows:[Shadow(color:c.withOpacity(0.5),blurRadius:8)])),
      textAlign:left?TextAlign.left:TextAlign.center,
      textDirection:TextDirection.ltr)..layout();
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
      ('◐',cWarlord,'Interceptor'),
      ('◆',const Color(0xFF00FF88),'Frigate'),
      ('⬡',cShield,'Parasite'),
      ('✦',const Color(0xFFFF6600),'Corrupter'),
    ];
    return Column(children:[
      const Text('FLOTA DEL WARLORD',style:TextStyle(color:Colors.white38,fontSize:9,
          fontFamily:'Orbitron',letterSpacing:2)),
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
  const GameOverScreen({super.key,required this.score,required this.best,
      required this.onRestart,required this.onMenu});
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
          shadows:[Shadow(color:color.withOpacity(0.8),blurRadius:14),
                   Shadow(color:color.withOpacity(0.3),blurRadius:28)]));
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
