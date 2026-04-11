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
  runApp(const PhoenixCoreV4App());
}

// ══════════════════════════════════════════════════════════
//  CONSTANTS
// ══════════════════════════════════════════════════════════
const double kPhoenixSize = 28.0;
const double kEnemyR      = 20.0;
const double kBossR       = 44.0;
const double kNucleusR    = 36.0;
const double kCoreHeatPerHit       = 0.06;
const double kCoreHeatPerEnemyPass = 0.10;
const double kCombatDuration       = 28.0;

const Color cFire   = Color(0xFFFF5500);
const Color cIce    = Color(0xFF00DDFF);
const Color cGold   = Color(0xFFFFCC00);
const Color cDanger = Color(0xFFFF1144);
const Color cShield = Color(0xFF8855FF);
const Color cBg     = Color(0xFF010810);
const Color cFrost  = Color(0xFFAAEEFF);

// ══════════════════════════════════════════════════════════
//  ENUMS
// ══════════════════════════════════════════════════════════
enum AppScreen   { menu, playing, gameOver }
enum GamePhase   { combat, decision, boss }
enum EnemyKind   { swarm, sniper, absorber, corrupter }

// ══════════════════════════════════════════════════════════
//  AUDIO MANAGER
// ══════════════════════════════════════════════════════════
class AudioManager {
  final _pool   = AudioPlayer();
  final _alarm  = AudioPlayer();
  final _quench = AudioPlayer();
  bool _alarmPlaying = false;

  Future<void> playShoot() async {
    try {
      await _pool.stop();
      await _pool.play(AssetSource('sounds/tap.wav'), volume: 0.35);
    } catch (_) {}
  }

  Future<void> playExplosion() async {
    try {
      final p = AudioPlayer();
      await p.play(AssetSource('sounds/tap.wav'), volume: 0.6);
      p.onPlayerComplete.listen((_) => p.dispose());
    } catch (_) {}
  }

  Future<void> startAlarm() async {
    if (_alarmPlaying) return;
    _alarmPlaying = true;
    try {
      await _alarm.setReleaseMode(ReleaseMode.loop);
      await _alarm.play(AssetSource('sounds/quench.wav'), volume: 0.5);
    } catch (_) {}
  }

  Future<void> stopAlarm() async {
    _alarmPlaying = false;
    try { await _alarm.stop(); } catch (_) {}
  }

  Future<void> playQuench() async {
    try {
      await _quench.play(AssetSource('sounds/quench.wav'), volume: 1.0);
    } catch (_) {}
  }

  void dispose() {
    _pool.dispose();
    _alarm.dispose();
    _quench.dispose();
  }
}

// ══════════════════════════════════════════════════════════
//  DATA MODELS
// ══════════════════════════════════════════════════════════
class PlayerBuild {
  double damage, fireRate, maxEnergy, cooling, shieldEfficiency;
  List<String> modules;

  PlayerBuild({
    this.damage = 10, this.fireRate = 1.0, this.maxEnergy = 100,
    this.cooling = 1.0, this.shieldEfficiency = 1.0, List<String>? modules,
  }) : modules = modules ?? [];
}

class Player {
  double x, energy = 100, heat = 0;
  bool shieldActive = false;
  double shieldTimer = 0;
  PlayerBuild build;
  Player(this.x, {PlayerBuild? build})
      : build = build ?? PlayerBuild(),
        energy = build?.maxEnergy ?? 100;
}

class Enemy {
  double x, y, hp, maxHp, vx, vy;
  EnemyKind kind;
  bool dead = false;
  double hitFlash = 0, actionTimer = 0, glowT = 0;
  Enemy({required this.x, required this.y, required this.hp,
         required this.vx, this.vy = 90, this.kind = EnemyKind.swarm})
      : maxHp = hp;
}

class Bullet {
  double x, y, damage;
  bool isEnemy;
  Bullet(this.x, this.y, this.damage, {this.isEnemy = false});
}

class FloatingText {
  double x, y, life;
  String text;
  Color color;
  FloatingText(this.x, this.y, this.text, this.color) : life = 1.0;
}

class Particle {
  double x, y, vx, vy, life, maxLife, size;
  Color color;
  bool isFrost;
  Particle({required this.x, required this.y, required this.vx,
            required this.vy, required this.life, required this.color,
            this.size = 4, this.isFrost = false})
      : maxLife = life;
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
  double timer = 0;
  int cycleCount = 0;

  void update(double dt,
      {required VoidCallback onDecision, required VoidCallback onBoss}) {
    timer += dt;
    if (phase == GamePhase.combat && timer >= kCombatDuration) {
      cycleCount++;
      timer = 0;
      if (cycleCount % 3 == 0) { phase = GamePhase.boss; onBoss(); }
      else { phase = GamePhase.decision; onDecision(); }
    }
  }

  void endDecision() { phase = GamePhase.combat; timer = 0; }
  void endBoss()     { phase = GamePhase.combat; timer = 0; }
  double get combatProgress =>
      phase == GamePhase.combat ? (timer / kCombatDuration).clamp(0, 1) : 1.0;
}

// ══════════════════════════════════════════════════════════
//  RESOURCE SYSTEM
// ══════════════════════════════════════════════════════════
class ResourceSystem {
  double energy = 100, heat = 0, entropy = 0;

  void update(double dt, PlayerBuild b) {
    heat   = (heat   - 8 * b.cooling * dt).clamp(0, 100);
    energy = (energy + 4 * dt).clamp(0, b.maxEnergy);
    entropy = (entropy + 0.3 * dt).clamp(0, 100);
    if (heat > 85) energy -= 15 * dt;
  }

  void applyShoot(PlayerBuild b) {
    energy -= 2.5;
    heat   += 4 / b.cooling;
    entropy += 0.4;
  }

  bool   get overheating  => heat > 80;
  double get heatFrac     => heat / 100;
  double get energyFrac   => (energy / 100).clamp(0, 1);
  double get entropyFrac  => entropy / 100;
}

// ══════════════════════════════════════════════════════════
//  AI ADAPT SYSTEM
// ══════════════════════════════════════════════════════════
class AIAdaptSystem {
  double aggression = 1.0, swarmDensity = 1.0, counterFire = 0.5;

  void analyze(PlayerBuild b) {
    if (b.damage    > 15)  aggression   = (aggression   + 0.15).clamp(1, 3);
    if (b.fireRate  > 1.5) swarmDensity = (swarmDensity + 0.20).clamp(1, 3);
    if (b.shieldEfficiency > 1.3)
      counterFire = (counterFire + 0.30).clamp(0.5, 2);
  }

  double get spawnInterval => (1.8 / aggression).clamp(0.4, 2.0);
  int    get waveSize      => (2 + swarmDensity).round();
}

// ══════════════════════════════════════════════════════════
//  APP ROOT
// ══════════════════════════════════════════════════════════
class PhoenixCoreV4App extends StatelessWidget {
  const PhoenixCoreV4App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: const AppRoot(),
      );
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});
  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  AppScreen _screen = AppScreen.menu;
  int _score = 0, _best = 0;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance()
        .then((p) => setState(() => _best = p.getInt('best_v4') ?? 0));
  }

  void _start() => setState(() { _score = 0; _screen = AppScreen.playing; });

  void _gameOver(int score) async {
    if (score > _best) {
      _best = score;
      final p = await SharedPreferences.getInstance();
      await p.setInt('best_v4', _best);
    }
    setState(() { _score = score; _screen = AppScreen.gameOver; });
  }

  @override
  Widget build(BuildContext context) => switch (_screen) {
        AppScreen.menu    => MenuScreen(best: _best, onStart: _start),
        AppScreen.playing => GameScreen(key: const ValueKey('g'), onGameOver: _gameOver),
        AppScreen.gameOver => GameOverScreen(
            score: _score, best: _best,
            onRestart: _start,
            onMenu: () => setState(() => _screen = AppScreen.menu)),
      };
}

// ══════════════════════════════════════════════════════════
//  GAME SCREEN
// ══════════════════════════════════════════════════════════
class GameScreen extends StatefulWidget {
  final void Function(int) onGameOver;
  const GameScreen({super.key, required this.onGameOver});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  final _rng   = Random();
  final _audio = AudioManager();

  double _sw = 0, _sh = 0;

  late Player _player;
  final _res   = ResourceSystem();
  final _phase = PhaseEngine();
  final _ai    = AIAdaptSystem();

  final _enemies   = <Enemy>[];
  final _bullets   = <Bullet>[];
  final _particles = <Particle>[];
  final _floats    = <FloatingText>[];

  Enemy? _boss;
  bool   _bossAlive = false;

  int    _score = 0;
  double _coreTemp = 0;
  double _shootTimer = 0, _spawnTimer = 0;
  bool   _touching = false;
  double _touchX = 0;

  bool   _showDecision = false;
  List<UpgradeOption> _options = [];

  // Quench stages
  bool   _quenching  = false;
  bool   _frosting   = false;   // frost phase before explosion
  double _frostT     = 0;       // 0→1 frost build-up
  double _quenchT    = 0;       // after frost completes
  bool   _alarmOn    = false;

  double _corePulse = 0, _pulseDir = 1;

  Ticker?  _ticker;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sz = MediaQuery.of(context).size;
      _sw = sz.width; _sh = sz.height;
      _player = Player(_sw / 2);
      _res.energy = _player.build.maxEnergy;
      _ticker = createTicker(_tick)..start();
    });
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _audio.dispose();
    super.dispose();
  }

  // ── TICK ─────────────────────────────────────────────────
  void _tick(Duration elapsed) {
    final dt = ((elapsed - _lastElapsed).inMicroseconds / 1e6)
        .clamp(0.0, 0.05).toDouble();
    _lastElapsed = elapsed;
    if (dt == 0) return;
    _update(dt);
  }

  void _update(double dt) {
    // ── FROST phase (escarcha antes del quench) ──
    if (_frosting) {
      _frostT += dt * 0.55;          // ~1.8s to fill
      _spawnFrostParticles();
      _updateParticles(dt);
      _updateFloats(dt);
      if (_frostT >= 1.0) {
        _frosting  = false;
        _quenching = true;
        _audio.stopAlarm();
        _audio.playQuench();
        _spawnQuenchExplosion();
      }
      setState(() {});
      return;
    }

    // ── QUENCH explosion phase ──
    if (_quenching) {
      _quenchT += dt;
      _updateParticles(dt);
      if (_quenchT > 2.5) widget.onGameOver(_score);
      setState(() {});
      return;
    }

    if (_showDecision) { setState(() {}); return; }

    // ── Core pulse ──
    _corePulse += _pulseDir * dt * 2.2;
    if (_corePulse > 1) _pulseDir = -1;
    if (_corePulse < 0) _pulseDir =  1;

    // ── Phase ──
    _phase.update(dt, onDecision: _triggerDecision, onBoss: _triggerBoss);

    // ── Resources ──
    _res.update(dt, _player.build);
    _player.energy = _res.energy;
    _player.heat   = _res.heat;

    // ── Alarm at 80% heat ──
    if (_res.heatFrac >= 0.80 && !_alarmOn) {
      _alarmOn = true;
      _audio.startAlarm();
    } else if (_res.heatFrac < 0.75 && _alarmOn) {
      _alarmOn = false;
      _audio.stopAlarm();
    }

    // ── Shield ──
    if (_player.shieldActive) {
      _player.shieldTimer -= dt;
      if (_player.shieldTimer <= 0) _player.shieldActive = false;
    }

    // ── Move phoenix ──
    if (_touching) {
      _player.x += (_touchX - _player.x) * 14 * dt;
      _player.x  = _player.x.clamp(kPhoenixSize, _sw - kPhoenixSize);
    }

    // ── Shoot ──
    if (_touching && _res.energy > 0 && !_res.overheating) {
      _shootTimer -= dt;
      if (_shootTimer <= 0) {
        _shootTimer = 0.14 / _player.build.fireRate;
        _fireBullet();
      }
    }

    // ── Move bullets ──
    for (final b in _bullets) b.y += (b.isEnemy ? 380 : -560) * dt;
    _bullets.removeWhere((b) => b.y < -10 || b.y > _sh + 10);

    // ── Spawn enemies ──
    if (_phase.phase == GamePhase.combat && !_bossAlive) {
      _spawnTimer -= dt;
      if (_spawnTimer <= 0) {
        _spawnTimer = _ai.spawnInterval;
        for (int i = 0; i < _ai.waveSize; i++) _spawnEnemy();
      }
    }

    _updateEnemies(dt);
    if (_bossAlive && _boss != null) _updateBoss(dt);
    _resolveCollisions();

    // ── Core temp decay ──
    _coreTemp = (_coreTemp - 0.003 * dt).clamp(0, 1);
    if (_coreTemp >= 1.0 && !_frosting) _beginFrost();
    if (_res.energy <= 0  && !_frosting) _beginFrost();

    _updateParticles(dt);
    _updateFloats(dt);
    setState(() {});
  }

  // ── FIRE ─────────────────────────────────────────────────
  void _fireBullet() {
    _res.applyShoot(_player.build);
    _audio.playShoot();
    final py = _sh * 0.72 - kPhoenixSize;
    _bullets.add(Bullet(_player.x, py, _player.build.damage));
    if (_player.build.fireRate > 1.8) {
      _bullets.add(Bullet(_player.x - 16, py, _player.build.damage * 0.7));
      _bullets.add(Bullet(_player.x + 16, py, _player.build.damage * 0.7));
    }
  }

  // ── SPAWN ENEMY ──────────────────────────────────────────
  void _spawnEnemy() {
    final r = _rng.nextDouble();
    EnemyKind k;
    if      (r < 0.40) k = EnemyKind.swarm;
    else if (r < 0.65) k = EnemyKind.sniper;
    else if (r < 0.82) k = EnemyKind.absorber;
    else               k = EnemyKind.corrupter;

    final baseHp = 15.0 + _phase.cycleCount * 5;
    final hp = k == EnemyKind.absorber  ? baseHp * 1.5 :
               k == EnemyKind.sniper    ? baseHp * 0.8 : baseHp;

    _enemies.add(Enemy(
      x: 20 + _rng.nextDouble() * (_sw - 40),
      y: -kEnemyR,
      hp: hp,
      vx: (_rng.nextBool() ? 1 : -1) * (50 + _rng.nextDouble() * 60),
      vy: 70 + _phase.cycleCount * 4.0,
      kind: k,
    ));
  }

  // ── UPDATE ENEMIES ───────────────────────────────────────
  void _updateEnemies(double dt) {
    for (final e in _enemies) {
      if (e.dead) continue;
      if (e.hitFlash > 0) e.hitFlash -= dt * 5;
      e.glowT += dt * 2;

      switch (e.kind) {
        case EnemyKind.swarm:
          e.x += e.vx * dt; e.y += e.vy * dt;
          if (e.x < kEnemyR || e.x > _sw - kEnemyR) e.vx *= -1;

        case EnemyKind.sniper:
          e.y = (e.y + e.vy * dt * 0.4).clamp(-kEnemyR, _sh * 0.25);
          e.x += e.vx * dt;
          if (e.x < kEnemyR || e.x > _sw - kEnemyR) e.vx *= -1;
          e.actionTimer += dt;
          if (e.actionTimer > 1.8 / _ai.counterFire) {
            e.actionTimer = 0;
            _bullets.add(Bullet(e.x, e.y + kEnemyR, 8, isEnemy: true));
          }

        case EnemyKind.absorber:
          e.x += (_player.x - e.x).sign * 45 * dt;
          e.y += e.vy * dt * 0.6;
          if ((e.x - _player.x).abs() < 40 && (e.y - _sh * 0.72).abs() < 40) {
            _res.energy -= 12 * dt;
            if (_rng.nextDouble() < 0.1) _particles.add(Particle(
              x: e.x, y: e.y,
              vx: (_player.x - e.x) * 1.5, vy: (_sh * 0.72 - e.y) * 1.5,
              life: 0.4, color: cShield, size: 5,
            ));
          }

        case EnemyKind.corrupter:
          e.x += e.vx * dt; e.y += e.vy * dt;
          if (e.x < kEnemyR || e.x > _sw - kEnemyR) e.vx *= -1;
          if (e.y > _sh * 0.65) {
            _res.heat += 8 * dt;
            _addFloat(e.x, e.y, '+HEAT', cDanger);
          }
      }

      if (e.y > _sh * 0.86) {
        e.dead = true;
        _spawnBurst(e.x, e.y, cFire, 10);
        _audio.playExplosion();
        if (!_player.shieldActive) {
          _coreTemp += kCoreHeatPerEnemyPass;
          _addFloat(_sw / 2, _sh * 0.84, 'NÚCLEO HIT', cDanger);
        }
      }
    }
    _enemies.removeWhere((e) => e.dead && e.hitFlash <= 0);
  }

  // ── UPDATE BOSS ──────────────────────────────────────────
  void _updateBoss(double dt) {
    final b = _boss!;
    if (b.hitFlash > 0) b.hitFlash -= dt * 3;
    b.glowT += dt;
    b.x += b.vx * dt;
    b.y  = _sh * 0.18 + sin(b.actionTimer) * 30;
    b.actionTimer += dt * 0.8;
    if (b.x < kBossR || b.x > _sw - kBossR) b.vx *= -1;
    if ((b.actionTimer * 10).toInt() % 8 == 0) {
      for (int i = -1; i <= 1; i++)
        _bullets.add(Bullet(b.x + i * 20, b.y + kBossR, 12, isEnemy: true));
    }
  }

  // ── COLLISIONS ───────────────────────────────────────────
  void _resolveCollisions() {
    final rem = <Bullet>{};
    for (final bul in _bullets) {
      if (bul.isEnemy) {
        final px = _player.x, py = _sh * 0.72;
        if ((bul.x - px).abs() < kPhoenixSize && (bul.y - py).abs() < kPhoenixSize) {
          rem.add(bul);
          if (_player.shieldActive) {
            _player.shieldActive = false;
            _spawnBurst(px, py, cShield, 8);
            _addFloat(px, py - 20, 'ESCUDO!', cShield);
          } else {
            _res.energy -= 10;
            _coreTemp   += kCoreHeatPerHit * 0.5;
            _spawnBurst(px, py, cDanger, 6);
            _addFloat(px, py - 20, '-10', cDanger);
          }
        }
        final nx = _sw / 2, ny = _sh * 0.87;
        if ((bul.x - nx).abs() < kNucleusR && (bul.y - ny).abs() < kNucleusR) {
          rem.add(bul);
          _coreTemp += kCoreHeatPerHit;
          _addFloat(nx, ny - 20, 'NÚCLEO!', cDanger);
        }
      } else {
        for (final e in _enemies) {
          if (e.dead) continue;
          if ((bul.x - e.x).abs() < kEnemyR && (bul.y - e.y).abs() < kEnemyR) {
            rem.add(bul);
            e.hp -= bul.damage; e.hitFlash = 1.0;
            if (e.hp <= 0) {
              e.dead = true;
              _score += _enemyScore(e.kind);
              _spawnBurst(e.x, e.y, _enemyColor(e.kind), 14);
              _audio.playExplosion();
              _addFloat(e.x, e.y - 10, '+${_enemyScore(e.kind)}', cGold);
            }
            break;
          }
        }
        if (_bossAlive && _boss != null && !_boss!.dead) {
          final bo = _boss!;
          if ((bul.x - bo.x).abs() < kBossR && (bul.y - bo.y).abs() < kBossR) {
            rem.add(bul);
            bo.hp -= bul.damage; bo.hitFlash = 1.0; _score += 5;
            if (bo.hp <= 0) {
              bo.dead = true; _bossAlive = false; _score += 500;
              _spawnBurst(bo.x, bo.y, cGold, 30);
              _spawnBurst(bo.x - 30, bo.y + 20, cFire, 20);
              _audio.playExplosion();
              _addFloat(bo.x, bo.y, '+500 BOSS!', cGold);
              _phase.endBoss();
              _ai.analyze(_player.build);
            }
          }
        }
      }
    }
    _bullets.removeWhere((b) => rem.contains(b));
  }

  // ── HELPERS ──────────────────────────────────────────────
  int   _enemyScore(EnemyKind k) => switch (k) {
        EnemyKind.swarm     => 100,
        EnemyKind.sniper    => 150,
        EnemyKind.absorber  => 200,
        EnemyKind.corrupter => 175,
      };

  Color _enemyColor(EnemyKind k) => switch (k) {
        EnemyKind.swarm     => cFire,
        EnemyKind.sniper    => const Color(0xFF00FF88),
        EnemyKind.absorber  => cShield,
        EnemyKind.corrupter => const Color(0xFFFF8800),
      };

  void _triggerDecision() {
    _ai.analyze(_player.build);
    _options = _buildOptions();
    _showDecision = true;
  }

  void _triggerBoss() {
    _enemies.clear();
    _boss = Enemy(x: _sw / 2, y: _sh * 0.18,
        hp: 80 + _phase.cycleCount * 20.0, vx: 90, kind: EnemyKind.sniper);
    _bossAlive = true;
  }

  void _beginFrost() {
    if (_frosting || _quenching) return;
    _frosting = true;
    _coreTemp = 1.0;
    _audio.stopAlarm();
  }

  void _spawnQuenchExplosion() {
    for (int i = 0; i < 80; i++) {
      final angle = _rng.nextDouble() * pi * 2;
      final speed = 100 + _rng.nextDouble() * 320;
      _particles.add(Particle(
        x: _sw / 2, y: _sh * 0.87,
        vx: cos(angle) * speed, vy: sin(angle) * speed,
        life: 1.2 + _rng.nextDouble(),
        color: _rng.nextBool() ? cFire : cIce,
        size: 5 + _rng.nextDouble() * 12,
      ));
    }
  }

  void _spawnFrostParticles() {
    if (_rng.nextDouble() > 0.3) return;
    final angle = _rng.nextDouble() * pi * 2;
    final r = kNucleusR + _rng.nextDouble() * 60;
    _particles.add(Particle(
      x: _sw / 2 + cos(angle) * r,
      y: _sh * 0.87 + sin(angle) * r,
      vx: (cos(angle + pi) * 40),
      vy: (sin(angle + pi) * 40),
      life: 0.8 + _rng.nextDouble() * 0.6,
      color: cFrost,
      size: 3 + _rng.nextDouble() * 6,
      isFrost: true,
    ));
  }

  void _selectUpgrade(UpgradeOption opt) {
    opt.apply(_player.build);
    _res.energy = (_res.energy + 20).clamp(0, _player.build.maxEnergy);
    _showDecision = false;
    _phase.endDecision();
  }

  List<UpgradeOption> _buildOptions() {
    final all = [
      UpgradeOption(title: 'Plasma Overload',   description: '+40% daño',
          emoji: '🔥', color: cFire,   apply: (b) => b.damage   *= 1.4),
      UpgradeOption(title: 'Cryo Stabilizer',   description: 'Enfriamiento +50%',
          emoji: '❄️', color: cIce,    apply: (b) => b.cooling  *= 1.5),
      UpgradeOption(title: 'Void Pulse',        description: 'Cadencia +30%',
          emoji: '⚡', color: cGold,   apply: (b) => b.fireRate *= 1.3),
      UpgradeOption(title: 'Energy Core Expand',description: 'Energía máx +25',
          emoji: '💙', color: cIce,    apply: (b) => b.maxEnergy += 25),
      UpgradeOption(title: 'Entropy Shield',    description: 'Escudo activo',
          emoji: '🛡️', color: cShield, apply: (b) => b.shieldEfficiency += 0.4),
      UpgradeOption(title: 'Quantum Burst',     description: 'Disparo triple perm.',
          emoji: '💥', color: cFire,   apply: (b) => b.fireRate = (b.fireRate * 1.2).clamp(0, 2.5)),
      UpgradeOption(title: 'Core Armor',        description: 'Módulo blindaje núcleo',
          emoji: '🔮', color: cShield, apply: (b) => b.modules.add('core_armor')),
      UpgradeOption(title: 'Phoenix Overdrive', description: '+20% todo  •  cooling-10%',
          emoji: '🦅', color: cGold,   apply: (b) { b.damage *= 1.2; b.fireRate *= 1.2; b.cooling *= 0.9; }),
    ];
    all.shuffle(_rng);
    return all.take(3).toList();
  }

  void _spawnBurst(double x, double y, Color c, int n) {
    for (int i = 0; i < n; i++) {
      final a = _rng.nextDouble() * pi * 2;
      final s = 40 + _rng.nextDouble() * 180;
      _particles.add(Particle(x: x, y: y, vx: cos(a)*s, vy: sin(a)*s,
          life: 0.3 + _rng.nextDouble() * 0.5, color: c,
          size: 2 + _rng.nextDouble() * 5));
    }
  }

  void _addFloat(double x, double y, String t, Color c) =>
      _floats.add(FloatingText(x, y, t, c));

  void _updateParticles(double dt) {
    for (final p in _particles) {
      p.x += p.vx * dt; p.y += p.vy * dt;
      if (!p.isFrost) p.vy += 40 * dt;
      p.life -= dt;
    }
    _particles.removeWhere((p) => p.life <= 0);
  }

  void _updateFloats(double dt) {
    for (final f in _floats) { f.y -= 55 * dt; f.life -= dt * 1.5; }
    _floats.removeWhere((f) => f.life <= 0);
  }

  // ── INPUT ────────────────────────────────────────────────
  void _onPanStart(DragStartDetails d)  { _touching = true;  _touchX = d.localPosition.dx; }
  void _onPanUpdate(DragUpdateDetails d){ _touchX = d.localPosition.dx; }
  void _onPanEnd(DragEndDetails _)      { _touching = false; }
  void _onTapDown(TapDownDetails d)     { _touching = true;  _touchX = d.localPosition.dx; }
  void _onTapUp(TapUpDetails _)         { _touching = false; }

  // ── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    _sw = sz.width; _sh = sz.height;

    return Scaffold(
      backgroundColor: cBg,
      body: Stack(children: [
        GestureDetector(
          onPanStart: _onPanStart, onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd, onTapDown: _onTapDown, onTapUp: _onTapUp,
          child: CustomPaint(
            painter: GamePainter(
              sw: _sw, sh: _sh, player: _player,
              enemies: _enemies, bullets: _bullets,
              boss: _bossAlive ? _boss : null,
              particles: _particles, floats: _floats,
              score: _score, res: _res, phase: _phase,
              coreTemp: _coreTemp, corePulse: _corePulse,
              frosting: _frosting, frostT: _frostT,
              quenching: _quenching, quenchT: _quenchT,
              touching: _touching,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        if (_showDecision)
          _DecisionOverlay(options: _options,
              cycleCount: _phase.cycleCount, onSelect: _selectUpgrade),
        if (_phase.phase == GamePhase.boss && _bossAlive)
          Positioned(top: 8, left: 0, right: 0,
            child: Center(child: _GlowText('⚠ BOSS ⚠', color: cDanger, size: 14))),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  GAME PAINTER
// ══════════════════════════════════════════════════════════
class GamePainter extends CustomPainter {
  final double sw, sh, coreTemp, corePulse, frostT, quenchT;
  final bool frosting, quenching, touching;
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
    required this.sw, required this.sh, required this.player,
    required this.enemies, required this.bullets, required this.boss,
    required this.particles, required this.floats, required this.score,
    required this.res, required this.phase,
    required this.coreTemp, required this.corePulse,
    required this.frosting, required this.frostT,
    required this.quenching, required this.quenchT,
    required this.touching,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBg(canvas);
    _drawNucleus(canvas);
    _drawEnemies(canvas);
    if (boss != null) _drawBoss(canvas, boss!);
    _drawBullets(canvas);
    _drawPhoenix(canvas);
    _drawParticles(canvas);
    _drawFloats(canvas);
    _drawHUD(canvas);
    if (frosting)  _drawFrost(canvas);
    if (quenching) _drawQuench(canvas);
  }

  // ── BACKGROUND ───────────────────────────────────────────
  void _drawBg(Canvas canvas) {
    final danger = coreTemp > 0.5
        ? Color.lerp(const Color(0xFF001022), const Color(0xFF200008),
            (coreTemp - 0.5) * 2)!
        : const Color(0xFF000814);

    canvas.drawRect(Rect.fromLTWH(0, 0, sw, sh),
        Paint()..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [const Color(0xFF000814), const Color(0xFF001022), danger],
        ).createShader(Rect.fromLTWH(0, 0, sw, sh)));

    final rng = Random(77);
    final sp  = Paint()..color = Colors.white.withOpacity(0.5);
    for (int i = 0; i < 70; i++) {
      canvas.drawCircle(
          Offset(rng.nextDouble() * sw, rng.nextDouble() * sh),
          rng.nextDouble() * 1.3, sp);
    }

    if (res.entropyFrac > 0.4) {
      canvas.drawRect(Rect.fromLTWH(0, 0, sw, sh),
          Paint()
            ..color = const Color(0xFF330044).withOpacity(res.entropyFrac * 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60));
    }
  }

  // ── NUCLEUS ───────────────────────────────────────────────
  void _drawNucleus(Canvas canvas) {
    final cx = sw / 2, cy = sh * 0.87;
    final tempC = Color.lerp(cIce, cDanger, coreTemp)!;
    final pulse = kNucleusR + corePulse * 5;

    // rings
    for (int i = 4; i >= 1; i--) {
      canvas.drawCircle(Offset(cx, cy), pulse + i * 12,
          Paint()
            ..color = tempC.withOpacity(0.06 * i)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
    // glow
    canvas.drawCircle(Offset(cx, cy), pulse * 1.4,
        Paint()
          ..color = tempC.withOpacity(0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
    // core
    canvas.drawCircle(Offset(cx, cy), pulse,
        Paint()..shader = RadialGradient(colors: [
          Colors.white.withOpacity(0.95),
          tempC.withOpacity(0.85),
          tempC.withOpacity(0.2),
        ], stops: const [0.0, 0.45, 1.0]).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: pulse)));

    // tech ring detail
    canvas.drawCircle(Offset(cx, cy), pulse + 4,
        Paint()
          ..color = tempC.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8);

    // cross hair lines
    final lp = Paint()..color = tempC.withOpacity(0.25)..strokeWidth = 0.8;
    canvas.drawLine(Offset(cx - pulse - 10, cy), Offset(cx + pulse + 10, cy), lp);
    canvas.drawLine(Offset(cx, cy - pulse - 10), Offset(cx, cy + pulse + 10), lp);

    // lightning spokes
    final rng = Random((corePulse * 20).toInt());
    final bltp = Paint()..color = tempC.withOpacity(0.65)
      ..style = PaintingStyle.stroke..strokeWidth = 1.2;
    for (int i = 0; i < 8; i++) {
      final angle = i * pi / 4 + corePulse * pi * 0.5;
      _bolt(canvas, bltp,
          Offset(cx + cos(angle) * pulse * 0.5, cy + sin(angle) * pulse * 0.5),
          Offset(cx + cos(angle) * (pulse + 22), cy + sin(angle) * (pulse + 22)),
          rng);
    }

    _drawArcBar(canvas, cx, cy, pulse + 32, coreTemp, tempC);
    _txt(canvas, 'NÚCLEO CUÁNTICO', cx, cy + pulse + 22, tempC.withOpacity(0.8), 9);
  }

  void _drawArcBar(Canvas canvas, double cx, double cy, double r, double frac, Color c) {
    const start = -pi * 0.75, sweep = pi * 1.5;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        start, sweep, false,
        Paint()..color = Colors.white12..style = PaintingStyle.stroke
          ..strokeWidth = 4..strokeCap = StrokeCap.round);
    if (frac > 0)
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
          start, sweep * frac, false,
          Paint()..color = c..style = PaintingStyle.stroke
            ..strokeWidth = 4..strokeCap = StrokeCap.round);
  }

  void _bolt(Canvas canvas, Paint p, Offset a, Offset b, Random rng) {
    final path = Path()..moveTo(a.dx, a.dy);
    for (int i = 1; i < 4; i++) {
      final t = i / 4;
      path.lineTo(a.dx + (b.dx - a.dx) * t + (rng.nextDouble() - 0.5) * 10,
                  a.dy + (b.dy - a.dy) * t + (rng.nextDouble() - 0.5) * 10);
    }
    path.lineTo(b.dx, b.dy);
    canvas.drawPath(path, p);
  }

  // ── PHOENIX ───────────────────────────────────────────────
  void _drawPhoenix(Canvas canvas) {
    final px = player.x, py = sh * 0.72;

    // shield bubble
    if (player.shieldActive) {
      canvas.drawCircle(Offset(px, py), kPhoenixSize * 1.7,
          Paint()..color = cShield.withOpacity(0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      canvas.drawCircle(Offset(px, py), kPhoenixSize * 1.7,
          Paint()..color = cShield.withOpacity(0.7)
            ..style = PaintingStyle.stroke..strokeWidth = 2);
    }

    // --- ENGINE GLOW (bottom) ---
    canvas.drawCircle(Offset(px, py + kPhoenixSize * 0.55),
        kPhoenixSize * 0.35,
        Paint()..color = cFire.withOpacity(touching ? 0.85 : 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

    // --- BODY ---
    final bodyP = Paint()..shader = RadialGradient(
      colors: [Colors.white, const Color(0xFFFFAA00), cFire],
      stops: const [0.0, 0.4, 1.0],
    ).createShader(Rect.fromCircle(center: Offset(px, py), radius: kPhoenixSize));

    // fuselage
    final body = Path();
    body.moveTo(px, py - kPhoenixSize * 0.85);   // nose
    body.lineTo(px + kPhoenixSize * 0.22, py + kPhoenixSize * 0.45);
    body.lineTo(px, py + kPhoenixSize * 0.25);
    body.lineTo(px - kPhoenixSize * 0.22, py + kPhoenixSize * 0.45);
    body.close();
    canvas.drawPath(body, bodyP);

    // left wing
    final lw = Paint()..color = const Color(0xFFFF6600).withOpacity(0.85);
    final lwPath = Path();
    lwPath.moveTo(px - kPhoenixSize * 0.18, py);
    lwPath.lineTo(px - kPhoenixSize * 1.25, py + kPhoenixSize * 0.1);
    lwPath.lineTo(px - kPhoenixSize * 0.9,  py + kPhoenixSize * 0.5);
    lwPath.lineTo(px - kPhoenixSize * 0.2,  py + kPhoenixSize * 0.35);
    lwPath.close();
    canvas.drawPath(lwPath, lw);

    // right wing (mirrored)
    final rw = Paint()..color = const Color(0xFFFF6600).withOpacity(0.85);
    final rwPath = Path();
    rwPath.moveTo(px + kPhoenixSize * 0.18, py);
    rwPath.lineTo(px + kPhoenixSize * 1.25, py + kPhoenixSize * 0.1);
    rwPath.lineTo(px + kPhoenixSize * 0.9,  py + kPhoenixSize * 0.5);
    rwPath.lineTo(px + kPhoenixSize * 0.2,  py + kPhoenixSize * 0.35);
    rwPath.close();
    canvas.drawPath(rwPath, rw);

    // cockpit glow
    canvas.drawCircle(Offset(px, py - kPhoenixSize * 0.3), kPhoenixSize * 0.18,
        Paint()..color = cIce.withOpacity(0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));

    // thrust flame
    if (touching) {
      final tf = Paint()..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [const Color(0xFFFFDD00), cFire, cFire.withOpacity(0)],
      ).createShader(Rect.fromLTWH(px - 8, py + kPhoenixSize * 0.4, 16, 32));
      final flame = Path();
      flame.moveTo(px - 7, py + kPhoenixSize * 0.42);
      flame.lineTo(px, py + kPhoenixSize * 0.42 + 30);
      flame.lineTo(px + 7, py + kPhoenixSize * 0.42);
      canvas.drawPath(flame, tf);
    }

    // wing detail lines
    final wdp = Paint()..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 0.8..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(px - kPhoenixSize * 0.15, py + 2),
        Offset(px - kPhoenixSize * 0.95, py + kPhoenixSize * 0.25), wdp);
    canvas.drawLine(Offset(px + kPhoenixSize * 0.15, py + 2),
        Offset(px + kPhoenixSize * 0.95, py + kPhoenixSize * 0.25), wdp);
  }

  // ── ENEMIES ───────────────────────────────────────────────
  void _drawEnemies(Canvas canvas) {
    for (final e in enemies) {
      if (e.dead) continue;
      final base = _enemyColor(e.kind);
      final c = e.hitFlash > 0 ? Color.lerp(base, Colors.white, e.hitFlash)! : base;
      _drawEnemy(canvas, e, c);
    }
  }

  void _drawEnemy(Canvas canvas, Enemy e, Color c) {
    final cx = e.x, cy = e.y;
    // glow
    canvas.drawCircle(Offset(cx, cy), kEnemyR * 1.5,
        Paint()..color = c.withOpacity(0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

    switch (e.kind) {
      case EnemyKind.swarm:
        // Triangular fighter
        _drawSwarm(canvas, cx, cy, c);

      case EnemyKind.sniper:
        // Diamond with laser eye
        _drawSniper(canvas, cx, cy, c, e.glowT);

      case EnemyKind.absorber:
        // Hexagonal with energy tendrils
        _drawAbsorber(canvas, cx, cy, c, e.glowT);

      case EnemyKind.corrupter:
        // Star-burst rotating shape
        _drawCorrupter(canvas, cx, cy, c, e.glowT);
    }

    // HP bar
    if (e.maxHp > 20) {
      final bw = kEnemyR * 2;
      final frac = (e.hp / e.maxHp).clamp(0.0, 1.0);
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - bw/2, cy - kEnemyR - 8, bw, 3),
          const Radius.circular(2)),
          Paint()..color = Colors.white24);
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - bw/2, cy - kEnemyR - 8, bw * frac, 3),
          const Radius.circular(2)),
          Paint()..color = c);
    }
  }

  void _drawSwarm(Canvas canvas, double cx, double cy, Color c) {
    // Main triangle body
    final p = Paint()..color = c;
    final path = Path()
      ..moveTo(cx, cy - kEnemyR * 0.9)
      ..lineTo(cx + kEnemyR * 0.8, cy + kEnemyR * 0.6)
      ..lineTo(cx - kEnemyR * 0.8, cy + kEnemyR * 0.6)
      ..close();
    canvas.drawPath(path, p);
    // cockpit
    canvas.drawCircle(Offset(cx, cy - kEnemyR * 0.2), kEnemyR * 0.2,
        Paint()..color = Colors.white.withOpacity(0.7));
    // wing lines
    final lp = Paint()..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 0.8..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - kEnemyR * 0.5, cy + kEnemyR * 0.2),
        Offset(cx - kEnemyR * 0.7, cy + kEnemyR * 0.55), lp);
    canvas.drawLine(Offset(cx + kEnemyR * 0.5, cy + kEnemyR * 0.2),
        Offset(cx + kEnemyR * 0.7, cy + kEnemyR * 0.55), lp);
  }

  void _drawSniper(Canvas canvas, double cx, double cy, Color c, double t) {
    // Diamond body
    final p = Paint()..color = c;
    final path = Path()
      ..moveTo(cx, cy - kEnemyR)
      ..lineTo(cx + kEnemyR * 0.55, cy)
      ..lineTo(cx, cy + kEnemyR * 1.1)
      ..lineTo(cx - kEnemyR * 0.55, cy)
      ..close();
    canvas.drawPath(path, p);
    // pulsing laser eye
    canvas.drawCircle(Offset(cx, cy), kEnemyR * 0.25,
        Paint()..color = Colors.white.withOpacity(0.5 + sin(t * 4) * 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    // laser barrel
    canvas.drawLine(Offset(cx, cy + kEnemyR * 1.1), Offset(cx, cy + kEnemyR * 1.5),
        Paint()..color = c.withOpacity(0.7)..strokeWidth = 2);
  }

  void _drawAbsorber(Canvas canvas, double cx, double cy, Color c, double t) {
    // Hexagon
    final p = Paint()..color = c.withOpacity(0.85);
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = i * pi / 3 - pi / 6;
      if (i == 0) path.moveTo(cx + cos(a) * kEnemyR, cy + sin(a) * kEnemyR);
      else         path.lineTo(cx + cos(a) * kEnemyR, cy + sin(a) * kEnemyR);
    }
    path.close();
    canvas.drawPath(path, p);
    // energy tendrils
    final tp = Paint()..color = c.withOpacity(0.5)
      ..strokeWidth = 1.2..style = PaintingStyle.stroke;
    for (int i = 0; i < 3; i++) {
      final a = i * pi * 2 / 3 + t;
      canvas.drawLine(Offset(cx, cy),
          Offset(cx + cos(a) * kEnemyR * 1.4, cy + sin(a) * kEnemyR * 1.4), tp);
    }
    // core
    canvas.drawCircle(Offset(cx, cy), kEnemyR * 0.28,
        Paint()..color = Colors.white.withOpacity(0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  }

  void _drawCorrupter(Canvas canvas, double cx, double cy, Color c, double t) {
    // Rotating star
    final p = Paint()..color = c;
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final a = i * pi / 4 + t * 0.5;
      final r = i.isEven ? kEnemyR : kEnemyR * 0.42;
      if (i == 0) path.moveTo(cx + cos(a) * r, cy + sin(a) * r);
      else         path.lineTo(cx + cos(a) * r, cy + sin(a) * r);
    }
    path.close();
    canvas.drawPath(path, p);
    // corruption eye
    canvas.drawCircle(Offset(cx, cy), kEnemyR * 0.22,
        Paint()..color = const Color(0xFFFF0000).withOpacity(0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  }

  Color _enemyColor(EnemyKind k) => switch (k) {
    EnemyKind.swarm     => const Color(0xFFFF2200),
    EnemyKind.sniper    => const Color(0xFF00FF88),
    EnemyKind.absorber  => const Color(0xFF9933FF),
    EnemyKind.corrupter => const Color(0xFFFF8800),
  };

  // ── BOSS ──────────────────────────────────────────────────
  void _drawBoss(Canvas canvas, Enemy b) {
    final frac = (b.hp / b.maxHp).clamp(0.0, 1.0);
    final c = b.hitFlash > 0 ? Color.lerp(cDanger, Colors.white, b.hitFlash)! : cDanger;

    // outer glow
    canvas.drawCircle(Offset(b.x, b.y), kBossR * 1.6,
        Paint()..color = c.withOpacity(0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24));

    // hexagonal boss body
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = i * pi / 3 + b.glowT * 0.2;
      if (i == 0) path.moveTo(b.x + cos(a) * kBossR, b.y + sin(a) * kBossR);
      else         path.lineTo(b.x + cos(a) * kBossR, b.y + sin(a) * kBossR);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = c.withOpacity(0.9));

    // inner ring
    canvas.drawCircle(Offset(b.x, b.y), kBossR * 0.6,
        Paint()..color = Colors.black.withOpacity(0.5));

    // core eye
    canvas.drawCircle(Offset(b.x, b.y), kBossR * 0.28,
        Paint()..color = Colors.red
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawCircle(Offset(b.x, b.y), kBossR * 0.12,
        Paint()..color = Colors.white);

    // energy spikes
    final sp = Paint()..color = c.withOpacity(0.5)
      ..strokeWidth = 1.5..style = PaintingStyle.stroke;
    for (int i = 0; i < 6; i++) {
      final a = i * pi / 3 + b.glowT * 0.5;
      canvas.drawLine(
          Offset(b.x + cos(a) * kBossR, b.y + sin(a) * kBossR),
          Offset(b.x + cos(a) * (kBossR + 16), b.y + sin(a) * (kBossR + 16)), sp);
    }

    // HP bar
    const bw = kBossR * 2;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(b.x - bw/2, b.y - kBossR - 14, bw, 6),
        const Radius.circular(3)), Paint()..color = Colors.white24);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(b.x - bw/2, b.y - kBossR - 14, bw * frac, 6),
        const Radius.circular(3)),
        Paint()..color = Color.lerp(cDanger, cGold, frac)!);

    _txt(canvas, 'BOSS  ${(frac * 100).toInt()}%',
        b.x, b.y - kBossR - 24, cDanger, 10);
  }

  // ── BULLETS ───────────────────────────────────────────────
  void _drawBullets(Canvas canvas) {
    for (final b in bullets) {
      if (b.isEnemy) {
        // plasma ball
        canvas.drawCircle(Offset(b.x, b.y), 8,
            Paint()..color = cFire
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        canvas.drawCircle(Offset(b.x, b.y), 3.5,
            Paint()..color = Colors.yellow);
      } else {
        // energy bolt
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset(b.x, b.y), width: 5, height: 18),
                const Radius.circular(3)),
            Paint()..color = cIce.withOpacity(0.35)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset(b.x, b.y), width: 4, height: 17),
                const Radius.circular(3)),
            Paint()..shader = const LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.white, cIce],
            ).createShader(Rect.fromCenter(
                center: Offset(b.x, b.y), width: 4, height: 17)));
      }
    }
  }

  // ── PARTICLES ─────────────────────────────────────────────
  void _drawParticles(Canvas canvas) {
    for (final p in particles) {
      final a = (p.life / p.maxLife).clamp(0.0, 1.0);
      if (p.isFrost) {
        // frost crystal — draw a small star/snowflake
        final fp = Paint()
          ..color = cFrost.withOpacity(a * 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        for (int i = 0; i < 3; i++) {
          final ang = i * pi / 3;
          canvas.drawLine(
              Offset(p.x + cos(ang) * p.size, p.y + sin(ang) * p.size),
              Offset(p.x - cos(ang) * p.size, p.y - sin(ang) * p.size),
              fp);
        }
        canvas.drawCircle(Offset(p.x, p.y), p.size * 0.3 * a,
            Paint()..color = Colors.white.withOpacity(a));
      } else {
        canvas.drawCircle(Offset(p.x, p.y), p.size * a,
            Paint()
              ..color = p.color.withOpacity(a)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.5));
      }
    }
  }

  // ── FLOATS ────────────────────────────────────────────────
  void _drawFloats(Canvas canvas) {
    for (final f in floats) {
      _txt(canvas, f.text, f.x, f.y, f.color.withOpacity(f.life.clamp(0, 1)), 11);
    }
  }

  // ── HUD ───────────────────────────────────────────────────
  void _drawHUD(Canvas canvas) {
    _txt(canvas, 'SCORE  $score', 16, 56, Colors.white, 15, left: true);

    final phaseLabel = switch (phase.phase) {
      GamePhase.combat   => 'COMBAT  ${(phase.combatProgress * 100).toInt()}%',
      GamePhase.decision => 'DECISIÓN',
      GamePhase.boss     => '⚠ BOSS',
    };
    _txt(canvas, phaseLabel, sw / 2, 56, cIce, 11);

    // phase progress bar
    final barW = sw * 0.4, barX = (sw - barW) / 2;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, 66, barW, 3), const Radius.circular(2)),
        Paint()..color = Colors.white12);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, 66, barW * phase.combatProgress, 3),
        const Radius.circular(2)),
        Paint()..color = cIce);

    // vertical bars
    _vertBar(canvas, 14,      sh * 0.35, 10, sh * 0.32, res.energyFrac, cIce,    'ENERGÍA');
    _vertBar(canvas, sw - 24, sh * 0.35, 10, sh * 0.32, res.heatFrac,
        Color.lerp(cGold, cDanger, res.heatFrac)!, 'HEAT');

    if (res.entropyFrac > 0.3)
      _txt(canvas, 'ENTROPÍA ${(res.entropyFrac * 100).toInt()}%',
          sw / 2, sh - 28, cShield.withOpacity(res.entropyFrac), 10);

    _txt(canvas,
        'DMG ${player.build.damage.toStringAsFixed(0)}  '
        'SPD ${player.build.fireRate.toStringAsFixed(1)}  '
        'COOL ${player.build.cooling.toStringAsFixed(1)}',
        sw / 2, sh - 14, Colors.white24, 9);

    if (coreTemp > 0.75)
      _txt(canvas, '⚠  QUENCH INMINENTE  ⚠', sw / 2, sh * 0.48, cDanger, 15);
    if (res.overheating)
      _txt(canvas, 'SOBRECALENTAMIENTO', sw / 2, sh * 0.53,
          cFire.withOpacity(0.85), 11);
  }

  void _vertBar(Canvas canvas, double x, double y, double w, double h,
      double frac, Color c, String label) {
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h), const Radius.circular(4)),
        Paint()..color = Colors.white12);
    final filled = h * frac.clamp(0.0, 1.0);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y + h - filled, w, filled),
        const Radius.circular(4)),
        Paint()..color = c
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, frac > 0.7 ? 4 : 0));
    _txt(canvas, label, x + w / 2, y + h + 14, c.withOpacity(0.6), 8);
  }

  // ── FROST EFFECT ──────────────────────────────────────────
  void _drawFrost(Canvas canvas) {
    // Creeping ice overlay from edges
    final ft = frostT.clamp(0.0, 1.0);

    // Blue-white vignette growing inward
    final frostPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.7,
        colors: [
          Colors.transparent,
          cFrost.withOpacity(ft * 0.35),
          cFrost.withOpacity(ft * 0.7),
        ],
        stops: const [0.4, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, sw, sh));
    canvas.drawRect(Rect.fromLTWH(0, 0, sw, sh), frostPaint);

    // Frost cracks spreading from corners
    final rng = Random(42);
    final crackP = Paint()
      ..color = cFrost.withOpacity(ft * 0.6)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    void crack(double startX, double startY, int depth) {
      if (depth <= 0) return;
      for (int i = 0; i < 3; i++) {
        final angle = rng.nextDouble() * pi * 2;
        final len   = (20 + rng.nextDouble() * 40) * ft;
        final ex = startX + cos(angle) * len;
        final ey = startY + sin(angle) * len;
        canvas.drawLine(Offset(startX, startY), Offset(ex, ey), crackP);
        if (rng.nextDouble() < 0.5) crack(ex, ey, depth - 1);
      }
    }

    // Corner cracks
    rng..nextInt(1000); // reset seed walk
    crack(0,  0,  4);
    crack(sw, 0,  4);
    crack(0,  sh, 4);
    crack(sw, sh, 4);

    // WARNING text
    final pulse = sin(frostT * pi * 8) * 0.5 + 0.5;
    _txt(canvas, '❄  QUENCH CRÍTICO  ❄', sw / 2, sh * 0.38,
        cFrost.withOpacity(0.6 + pulse * 0.4), 18);
  }

  // ── QUENCH EXPLOSION ──────────────────────────────────────
  void _drawQuench(Canvas canvas) {
    final a = (quenchT / 2.5).clamp(0.0, 0.92);
    canvas.drawRect(Rect.fromLTWH(0, 0, sw, sh),
        Paint()..color = cFire.withOpacity(a * 0.8));
    _txt(canvas, '💥  QUENCH  💥', sw / 2, sh * 0.38, Colors.white, 38);
    _txt(canvas, 'FALLO CRIOGÉNICO TOTAL', sw / 2, sh * 0.48, cFire, 16);
  }

  // ── TEXT HELPER ───────────────────────────────────────────
  void _txt(Canvas canvas, String t, double x, double y, Color c, double sz,
      {bool left = false}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(
          color: c, fontSize: sz, fontFamily: 'Orbitron',
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: c.withOpacity(0.5), blurRadius: 8)])),
      textAlign: left ? TextAlign.left : TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(left ? x : x - tp.width / 2, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => true;
}

// ══════════════════════════════════════════════════════════
//  DECISION OVERLAY
// ══════════════════════════════════════════════════════════
class _DecisionOverlay extends StatelessWidget {
  final List<UpgradeOption> options;
  final int cycleCount;
  final void Function(UpgradeOption) onSelect;
  const _DecisionOverlay(
      {required this.options, required this.cycleCount, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.88),
      child: SafeArea(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          _GlowText('FASE DE DECISIÓN', color: cGold, size: 22),
          const SizedBox(height: 4),
          _GlowText('Ciclo $cycleCount — elige tu evolución',
              color: Colors.white54, size: 13),
          const SizedBox(height: 32),
          ...options.map((opt) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: GestureDetector(
                  onTap: () => onSelect(opt),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      border: Border.all(color: opt.color, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                      color: opt.color.withOpacity(0.12),
                      boxShadow: [BoxShadow(
                          color: opt.color.withOpacity(0.25), blurRadius: 16)],
                    ),
                    child: Row(children: [
                      Text(opt.emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 16),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(opt.title, style: TextStyle(color: opt.color,
                              fontSize: 16, fontFamily: 'Orbitron',
                              fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(opt.description, style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                        ],
                      )),
                      Icon(Icons.arrow_forward_ios, color: opt.color, size: 18),
                    ]),
                  ),
                ),
              )),
          const SizedBox(height: 24),
          const Text('(+20 energía al elegir)',
              style: TextStyle(color: Colors.white30, fontSize: 11)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  MENU SCREEN
// ══════════════════════════════════════════════════════════
class MenuScreen extends StatefulWidget {
  final int best;
  final VoidCallback onStart;
  const MenuScreen({super.key, required this.best, required this.onStart});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GlowText('PHOENIX CORE', color: cFire, size: 38),
            const SizedBox(height: 4),
            _GlowText('CRYO BALANCE  V4', color: cIce, size: 16),
            const SizedBox(height: 6),
            _GlowText('BEST: ${widget.best}', color: cGold, size: 14),
            const SizedBox(height: 40),
            _EnemyLegend(),
            const SizedBox(height: 40),
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Transform.scale(
                scale: 1 + _pulse.value * 0.05,
                child: GestureDetector(
                  onTap: widget.onStart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 18),
                    decoration: BoxDecoration(
                      border: Border.all(color: cFire, width: 2),
                      borderRadius: BorderRadius.circular(10),
                      color: cFire.withOpacity(0.15),
                      boxShadow: [BoxShadow(color: cFire.withOpacity(0.4), blurRadius: 28)],
                    ),
                    child: const _GlowText('INICIAR', color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Mantén presionado para mover y disparar.\n'
                'Cada 28s — Fase de Decisión: evoluciona tu Phoenix.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
              ),
            ),
          ],
        )),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ENEMY LEGEND (menu)
// ══════════════════════════════════════════════════════════
class _EnemyLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      ('▲', const Color(0xFFFF2200), 'Swarm'),
      ('◆', const Color(0xFF00FF88), 'Sniper'),
      ('⬡', const Color(0xFF9933FF), 'Absorber'),
      ('✦', const Color(0xFFFF8800), 'Corrupter'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items.map((e) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(children: [
          Text(e.$1, style: TextStyle(color: e.$2, fontSize: 20,
              shadows: [Shadow(color: e.$2, blurRadius: 8)])),
          const SizedBox(height: 4),
          Text(e.$3, style: const TextStyle(color: Colors.white54, fontSize: 9)),
        ]),
      )).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  GAME OVER SCREEN
// ══════════════════════════════════════════════════════════
class GameOverScreen extends StatelessWidget {
  final int score, best;
  final VoidCallback onRestart, onMenu;
  const GameOverScreen({super.key, required this.score, required this.best,
      required this.onRestart, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final newRecord = score >= best && score > 0;
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(child: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _GlowText('QUENCH', color: cDanger, size: 52),
          const SizedBox(height: 6),
          const _GlowText('FALLO CRIOGÉNICO', color: cFire, size: 15),
          const SizedBox(height: 36),
          _GlowText('SCORE: $score', color: cGold, size: 26),
          if (newRecord) ...[
            const SizedBox(height: 8),
            const _GlowText('🏆 NUEVO RÉCORD', color: cGold, size: 18),
          ],
          _GlowText('MEJOR: $best', color: Colors.white38, size: 13),
          const SizedBox(height: 52),
          _Btn(label: 'REINTENTAR', color: cFire, onTap: onRestart),
          const SizedBox(height: 18),
          _Btn(label: 'MENÚ', color: cIce, onTap: onMenu),
        ],
      ))),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ══════════════════════════════════════════════════════════
class _GlowText extends StatelessWidget {
  final String text;
  final Color color;
  final double size;
  const _GlowText(this.text, {required this.color, required this.size});
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: TextAlign.center,
      style: TextStyle(color: color, fontSize: size,
          fontFamily: 'Orbitron', fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: color.withOpacity(0.8), blurRadius: 14),
            Shadow(color: color.withOpacity(0.3), blurRadius: 28),
          ]));
}

class _Btn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Btn({required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 15),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(8),
            color: color.withOpacity(0.12),
            boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 14)],
          ),
          child: _GlowText(label, color: color, size: 17),
        ),
      );
}
