import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const PhoenixCoreApp());
}

void hapticLight()  => HapticFeedback.lightImpact();
void hapticMedium() => HapticFeedback.mediumImpact();
void hapticHeavy()  => HapticFeedback.heavyImpact();

const cFire    = Color(0xFFFF5500);
const cIce     = Color(0xFF00DDFF);
const cGold    = Color(0xFFFFCC00);
const cDanger  = Color(0xFFFF1144);
const cShield  = Color(0xFF8855FF);
const cFrost   = Color(0xFFAAEEFF);
const cBg      = Color(0xFF010810);
const cWarlord = Color(0xFF4488FF);
const cGreen   = Color(0xFF00FF88);
const cPurple  = Color(0xFFAA44FF);
const cRed     = Color(0xFFFF2222);

const double kPhoenixSize    = 28.0;
const double kEnemyR         = 22.0;
const double kBossR          = 52.0;
const double kNucleusR       = 38.0;
const double kCombatDuration = 32.0;
const double kBossChargeTime = 1.2;
const double kNucleusIFrame  = 0.9;
const double kCoreHeatPerHit = 0.06;
const double kCoreHeatPerPass= 0.10;
const double kHeatPerShot    = 2.5;
const double kBaseInterval   = 0.17;

// ══════════════════════════════════════════════════════════
// HEAT SYSTEM — Feedback progresivo
// ══════════════════════════════════════════════════════════
enum HeatZone { cool, warm, hot, overheat }

class HeatSystem {
  double heat = 0;
  double overheatTimer = 0;
  bool isOverheated = false;

  HeatZone get zone {
    if (isOverheated) return HeatZone.overheat;
    if (heat < 40) return HeatZone.cool;
    if (heat < 70) return HeatZone.warm;
    return HeatZone.hot;
  }

  Color get zoneColor => switch (zone) {
    HeatZone.cool    => cIce,
    HeatZone.warm    => cGold,
    HeatZone.hot     => cDanger,
    HeatZone.overheat=> cRed,
  };

  bool get canShoot => !isOverheated;

  // Multiplicador de cadencia por heat — progresivo, no de golpe
  double get fireRatePenalty {
    if (heat < 60) return 1.0;
    if (heat < 80) return 0.75; // 25% más lento
    if (heat < 95) return 0.50; // 50% más lento
    return 0.30;                // 70% más lento — casi bloqueado
  }

  void update(double dt, PlayerBuild b, DifficultyConfig diff) {
    if (isOverheated) {
      overheatTimer -= dt;
      if (overheatTimer <= 0) {
        isOverheated = false;
        overheatTimer = 0;
        heat = 55; // empieza recuperado parcialmente
      }
      return;
    }
    final coolRate = 12.0 * b.cooling * diff.heatCoolMult;
    heat = (heat - coolRate * dt).clamp(0, 100);
  }

  void applyShot(PlayerBuild b, DifficultyConfig diff) {
    if (isOverheated) return;
    final add = kHeatPerShot * b.heatGenMult * diff.heatGenMult;
    heat = (heat + add).clamp(0, 100);
    if (heat >= 100) _triggerOverheat(diff);
  }

  void _triggerOverheat(DifficultyConfig diff) {
    isOverheated = true;
    overheatTimer = diff.overheatDuration;
    heat = 100;
    hapticHeavy();
  }

  void cool(double amount) => heat = (heat - amount).clamp(0, 100);
  double get fraction => heat / 100;
}

// ══════════════════════════════════════════════════════════
// DIFFICULTY CONFIG
// ══════════════════════════════════════════════════════════
enum Difficulty { amateur, veterano, comandante }

class DifficultyConfig {
  final Difficulty level;
  const DifficultyConfig(this.level);

  String get name => switch (level) {
    Difficulty.amateur    => 'AMATEUR',
    Difficulty.veterano   => 'VETERANO',
    Difficulty.comandante => 'COMANDANTE',
  };
  String get emoji => switch (level) {
    Difficulty.amateur    => '🛡️',
    Difficulty.veterano   => '⚔️',
    Difficulty.comandante => '☠️',
  };
  String get tagline => switch (level) {
    Difficulty.amateur    => 'Domina lo básico. Siente el poder.',
    Difficulty.veterano   => 'El juego empieza a exigirte.',
    Difficulty.comandante => 'Aquí es donde fallas… o te conviertes en leyenda.',
  };
  Color get color => switch (level) {
    Difficulty.amateur    => cGreen,
    Difficulty.veterano   => cGold,
    Difficulty.comandante => cRed,
  };
  int get riskLevel => switch (level) { Difficulty.amateur => 1, Difficulty.veterano => 3, Difficulty.comandante => 5 };
  double get scoreMult => switch (level) { Difficulty.amateur => 1.0, Difficulty.veterano => 1.6, Difficulty.comandante => 2.8 };

  double get enemyHpMult     => switch (level) { Difficulty.amateur => 0.85, Difficulty.veterano => 1.3,  Difficulty.comandante => 1.8  };
  double get enemySpeedMult  => switch (level) { Difficulty.amateur => 0.85, Difficulty.veterano => 1.2,  Difficulty.comandante => 1.35 };
  double get bulletSpeedMult => switch (level) { Difficulty.amateur => 0.75, Difficulty.veterano => 1.0,  Difficulty.comandante => 1.2  };
  double get spawnRateMult   => switch (level) { Difficulty.amateur => 0.85, Difficulty.veterano => 1.35, Difficulty.comandante => 1.7  };
  int    get maxWaveSize     => switch (level) { Difficulty.amateur => 3,    Difficulty.veterano => 5,    Difficulty.comandante => 6    };
  double get enemyFireRateMult => switch (level) { Difficulty.amateur => 0.7, Difficulty.veterano => 1.0, Difficulty.comandante => 1.4 };
  double get bossHpMult      => switch (level) { Difficulty.amateur => 0.9,  Difficulty.veterano => 1.4,  Difficulty.comandante => 1.8  };
  double get bossBulletDmgMult => switch (level) { Difficulty.amateur => 0.7, Difficulty.veterano => 1.0, Difficulty.comandante => 1.4 };
  double get bossShieldDuration => switch (level) { Difficulty.amateur => 6.0, Difficulty.veterano => 10.0, Difficulty.comandante => 14.0 };
  double get bossVulnerableWindow => switch (level) { Difficulty.amateur => 4.0, Difficulty.veterano => 2.5, Difficulty.comandante => 1.8 };
  double get gravTimerSeconds => switch (level) { Difficulty.amateur => 80.0, Difficulty.veterano => 60.0, Difficulty.comandante => 45.0 };
  double get heatGenMult     => switch (level) { Difficulty.amateur => 0.6,  Difficulty.veterano => 1.0,  Difficulty.comandante => 1.5  };
  double get heatCoolMult    => switch (level) { Difficulty.amateur => 2.0,  Difficulty.veterano => 1.0,  Difficulty.comandante => 0.7  };
  double get overheatDuration => switch (level) { Difficulty.amateur => 0.8, Difficulty.veterano => 1.5,  Difficulty.comandante => 2.2  };
  bool   get tripleGuaranteed => level != Difficulty.comandante;
  bool   get hasMissile      => level != Difficulty.amateur;
  double get missileRechargeTime => switch (level) { Difficulty.amateur => 999, Difficulty.veterano => 10.0, Difficulty.comandante => 14.0 };
  double get powerUpInterval => switch (level) { Difficulty.amateur => 22.0, Difficulty.veterano => 32.0, Difficulty.comandante => 45.0 };
  bool   get boss4TripleFromStart => level == Difficulty.comandante;
  bool   get hasFinisherMode => true; // todos los niveles
  // Finisher threshold — % HP para activar huida
  double get finisherThreshold => switch (level) { Difficulty.amateur => 0.12, Difficulty.veterano => 0.10, Difficulty.comandante => 0.08 };
}

// ══════════════════════════════════════════════════════════
// FINISHER MODE STATE
// ══════════════════════════════════════════════════════════
enum FinisherPhase { none, fleeing, chasing, rematch }

class FinisherState {
  FinisherPhase phase = FinisherPhase.none;
  double timer = 0;
  double bossFleeVY = -280; // velocidad de huida
  bool rematchComplete = false;

  bool get active => phase != FinisherPhase.none;
  bool get isChasing => phase == FinisherPhase.chasing;
}

enum AppScreen  { dockIntro, intro, menu, diffSelect, playing, stageClear, cinematic, gameOver, victory }
enum GamePhase  { combat, decision, boss }
enum EnemyKind  { interceptor, frigate, parasite, corrupter }
enum PowerUpKind{ rapidFire, tripleShot, shield, coreArmor, energyBoost }
enum BossState  { moving, charging, firing, cooldown, vulnerable, fleeing }
enum StageHazard{ none, asteroids, gravityTimer, mirrorPortal }
enum MoveType   { left, right, shoot, idle }

class PlayerTracker {
  final List<MoveType> history = [];
  void add(MoveType m) { history.add(m); if (history.length > 30) history.removeAt(0); }
  MoveType get lastMove => history.isEmpty ? MoveType.idle : history.last;
  double get leftBias  { if (history.isEmpty) return 0; return history.where((m) => m == MoveType.left).length  / history.length; }
  double get rightBias { if (history.isEmpty) return 0; return history.where((m) => m == MoveType.right).length / history.length; }
}

class PlayerProfile {
  int left = 0, right = 0, shoot = 0;
  void register(MoveType m) { if (m == MoveType.left) left++; else if (m == MoveType.right) right++; else if (m == MoveType.shoot) shoot++; }
  MoveType dominantMove() { if (left > right && left > shoot) return MoveType.left; if (right > left && right > shoot) return MoveType.right; return MoveType.shoot; }
  double predictability() { final total = left + right + shoot; if (total == 0) return 0; final mx = [left, right, shoot].reduce((a, b) => a > b ? a : b); return mx / total; }
  void decay() { left = (left * 0.8).toInt(); right = (right * 0.8).toInt(); shoot = (shoot * 0.8).toInt(); }
}

class StageConfig {
  final int stageNum; final String name, bossName, bossAsset; final Color bossColor; final StageHazard hazard; final double bossHpBase, bossHpPerCycle; final List<CinematicScene> scenes;
  const StageConfig({required this.stageNum, required this.name, required this.bossName, required this.bossAsset, required this.bossColor, required this.hazard, required this.bossHpBase, required this.bossHpPerCycle, required this.scenes});
}
class CinematicScene {
  final String location, speaker, speakerColor, dialogue, imageAsset;
  const CinematicScene({required this.location, required this.speaker, required this.speakerColor, required this.dialogue, required this.imageAsset});
}

const _stages = [
  StageConfig(stageNum:1, name:'NEBULOSA DE ORIÓN', bossName:'THE FROZEN WARLORD', bossAsset:'assets/images/boss.png', bossColor:cWarlord, hazard:StageHazard.none, bossHpBase:180, bossHpPerCycle:35, scenes:[]),
  StageConfig(stageNum:2, name:'ASTEROIDES DE KHAROS', bossName:'EL SEGADOR DE ALMAS', bossAsset:'assets/images/jefe2.png', bossColor:cGreen, hazard:StageHazard.asteroids, bossHpBase:160, bossHpPerCycle:30, scenes:[
    CinematicScene(location:'DOCK 7A — BASE PHOENIX', speaker:'GENERAL G.G.', speakerColor:'gold', dialogue:'Comandante… lo consiguió.\nEl núcleo cuántico llegó intacto.\nLa colonia Elysium ya está recibiendo energía estable.', imageAsset:'assets/images/escena1jefe2.jpg'),
    CinematicScene(location:'DOCK 7A — HANGAR', speaker:'GENERAL G.G.', speakerColor:'gold', dialogue:'Recibimos señales de alerta desde los Asteroides de Kharos.\nAlgo está atacando nuestros convoyes…\nLe llamamos El Segador de Almas del Abismo.', imageAsset:'assets/images/escena2jefe2.jpg'),
    CinematicScene(location:'DOCK 7A — HANGAR', speaker:'USUARIO', speakerColor:'ice', dialogue:'¿Qué necesita que haga?', imageAsset:'assets/images/escena3jefe2.jpg'),
    CinematicScene(location:'DOCK 7A — HANGAR', speaker:'GENERAL G.G.', speakerColor:'gold', dialogue:'Vaya allí y deténgalo antes de que alcance el Núcleo Central de Elysium.\nSu nave está siendo reparada. Descanse.\nEsta entidad es mucho más antigua… y más peligrosa.', imageAsset:'assets/images/escena4jefe2.jpg'),
  ]),
  StageConfig(stageNum:3, name:'ZONA NEUTRÓNICA OMEGA', bossName:'EL DEVORADOR DE SUEÑOS', bossAsset:'assets/images/jefe3.png', bossColor:cPurple, hazard:StageHazard.gravityTimer, bossHpBase:220, bossHpPerCycle:35, scenes:[
    CinematicScene(location:'DOCK 7A — BASE PHOENIX', speaker:'GENERAL G.G.', speakerColor:'gold', dialogue:'Comandante… excelente trabajo.\nEl Segador fue neutralizado.\nPermítame presentarle a la Doctora Denise Moreau.', imageAsset:'assets/images/escena1jefe3.jpg'),
    CinematicScene(location:'SALA DE ANÁLISIS', speaker:'DRA. DENISE MOREAU', speakerColor:'ice', dialogue:'Lo que enfrentaremos no es una nave enemiga…\nes una entidad biológica altamente evolucionada.', imageAsset:'assets/images/escena2jefe3.jpg'),
    CinematicScene(location:'CAFÉ ALTEA', speaker:'DRA. DENISE MOREAU', speakerColor:'ice', dialogue:'Ataca la mente, genera alucinaciones y distorsiona la realidad.\nSi logra establecer una cabeza de playa, la infestación será imposible de detener.', imageAsset:'assets/images/escena3jefe3.jpg'),
    CinematicScene(location:'DOCK 7A — HANGAR', speaker:'GENERAL G.G.', speakerColor:'gold', dialogue:'¡ADVERTENCIA: campo gravitacional activo!\nNeutralice al jefe antes de ser absorbido.\nTiene 75 segundos desde que aparezca.', imageAsset:'assets/images/escena4jefe3.jpg'),
  ]),
  StageConfig(stageNum:4, name:'SECTOR OMEGA-9 — REALIDAD ESPEJO', bossName:'ANTI-PHOENIX UNIT 01', bossAsset:'assets/images/jefe4.png', bossColor:cRed, hazard:StageHazard.mirrorPortal, bossHpBase:999, bossHpPerCycle:0, scenes:[
    CinematicScene(location:'PUENTE DE MANDO', speaker:'GENERAL G.G.', speakerColor:'gold', dialogue:'¡Comandante! Los sensores detectaron una anomalía masiva en el sector Omega-9.\nEs un portal dimensional que se está abriendo.', imageAsset:'assets/images/escena1jefe4.jpg'),
    CinematicScene(location:'SALA DE ANÁLISIS', speaker:'DRA. DENISE MOREAU', speakerColor:'ice', dialogue:'La firma energética es completamente desconocida.\nSea lo que sea que intenta cruzar, viene con poder enorme.', imageAsset:'assets/images/escena2jefe4.jpg'),
    CinematicScene(location:'SECTOR OMEGA-9', speaker:'USUARIO', speakerColor:'ice', dialogue:'Del portal emerge una nave casi idéntica a la Phoenix… oscura y roja.\nEl emblema está invertido.\n"ANTI-PHOENIX" pintado en el casco con plasma.', imageAsset:'assets/images/escena3jefe4.jpg'),
    CinematicScene(location:'CANAL DE COMUNICACIÓN', speaker:'ANTI-PHOENIX', speakerColor:'red', dialogue:'Por fin nos encontramos… "yo".\nEn mi universo ya conquisté todo lo que se movía.\nAhora vengo por el tuyo.', imageAsset:'assets/images/escena4jefe4.jpg'),
    CinematicScene(location:'CANAL DE COMUNICACIÓN', speaker:'DRA. DENISE MOREAU', speakerColor:'ice', dialogue:'¡Phoenix! ¡Escúchame!\n¡No puedes dañarlo!\n¡Dispara los 4 NODOS del portal!\n¡Es la única salida!', imageAsset:'assets/images/escena5jefe4.jpg'),
  ]),
];

const _introScenes = [
  CinematicScene(location:'CAFÉ ALTEA — BASE PHOENIX', speaker:'GENERAL G.G.', speakerColor:'gold', dialogue:'Usuario. El Núcleo Cuántico debe llegar hoy al Cuadrante 7 de la Nebulosa de Orión.\nLa colonia Elysium se está quedando sin energía.\nSin ese núcleo… perdemos tres millones de personas.', imageAsset:'assets/images/cafe1.jpg'),
  CinematicScene(location:'CAFÉ ALTEA — BASE PHOENIX', speaker:'USUARIO', speakerColor:'ice', dialogue:'Entendido.\n¿Mi nave?', imageAsset:'assets/images/cafe1.jpg'),
  CinematicScene(location:'DOCK 7A — PHOENIX PROJECT', speaker:'USUARIO', speakerColor:'ice', dialogue:'Núcleo asegurado. Sistemas en línea.\nPhoenix Project… listo para volar.', imageAsset:'assets/images/hangar1.jpg'),
  CinematicScene(location:'DOCK 7A — CASCO DE LA NAVE', speaker:'USUARIO', speakerColor:'ice', dialogue:'El casco está dañado. Tres cicatrices de plasma.\nEl emblema del Ave Fénix sigue intacto.\nSiempre sobrevive al fuego.\nYo también.', imageAsset:'assets/images/ship_close.jpg'),
  CinematicScene(location:'LADO ENEMIGO — UBICACIÓN DESCONOCIDA', speaker:'THE FROZEN WARLORD', speakerColor:'red', dialogue:'Phoenix Protocol…\npor eso perdí. Ahora lo conozco.\nSé cómo bloquearlo.', imageAsset:'assets/images/warlord.jpg'),
  CinematicScene(location:'NEBULOSA DE ORIÓN — CUADRANTE 7', speaker:'USUARIO', speakerColor:'ice', dialogue:'¿Qué carajos…?\nEs él… The Frozen Warlord.\n\nTe vencí una vez…\nY te voy a vencer otra vez.', imageAsset:'assets/images/battle.jpg'),
];

// ── AUDIO ────────────────────────────────────────────────
class AudioManager {
  final List<AudioPlayer> _pool = List.generate(6, (_) => AudioPlayer()); int _li = 0;
  final _bg = AudioPlayer(), _bm = AudioPlayer(), _eb = AudioPlayer(), _qs = AudioPlayer(), _al = AudioPlayer(), _sfx = AudioPlayer();
  bool _bossOn = false, _bgOn = false, _alOn = false;
  Future<void> startAmbient() async { if (_bgOn) return; _bgOn = true; try { await _bg.setReleaseMode(ReleaseMode.loop); await _bg.play(AssetSource('sounds/musica_ambiente.mp3'), volume: 0.5); } catch (_) {} }
  Future<void> switchToBoss() async { if (_bossOn) return; _bossOn = true; try { await _bg.stop(); await _bm.setReleaseMode(ReleaseMode.loop); await _bm.play(AssetSource('sounds/musica_jefe.mp3'), volume: 0.7); } catch (_) {} }
  Future<void> switchToAmbient() async { _bossOn = false; try { await _bm.stop(); await _bg.setReleaseMode(ReleaseMode.loop); await _bg.play(AssetSource('sounds/musica_ambiente.mp3'), volume: 0.5); } catch (_) {} }
  Future<void> playLaser({bool triple = false}) async { try { final p = _pool[_li % _pool.length]; _li++; await p.stop(); await p.play(AssetSource(triple ? 'sounds/laser_triple.mp3' : 'sounds/laser.mp3'), volume: triple ? 0.5 : 0.3); } catch (_) {} }
  Future<void> playExplosion({bool isBoss = false, bool isAsteroid = false}) async { try { if (isAsteroid) { final p = AudioPlayer(); await p.play(AssetSource('sounds/explosion_meteorito.mp3'), volume: 0.55); p.onPlayerComplete.listen((_) => p.dispose()); } else if (isBoss) { await _eb.stop(); await _eb.play(AssetSource('sounds/explosion_jefe.mp3'), volume: 1.0); } else { final p = AudioPlayer(); await p.play(AssetSource('sounds/explosion.mp3'), volume: 0.5); p.onPlayerComplete.listen((_) => p.dispose()); } } catch (_) {} }
  Future<void> playShieldHit() async { try { await _sfx.stop(); await _sfx.play(AssetSource('sounds/shiel_guarda.mp3'), volume: 0.7); } catch (_) {} }
  Future<void> playShieldCharge() async { try { await _sfx.stop(); await _sfx.play(AssetSource('sounds/cargando_shield.mp3'), volume: 0.6); } catch (_) {} }
  Future<void> playMissionStart() async { try { await _sfx.stop(); await _sfx.play(AssetSource('sounds/intro_iniciando_mision.mp3'), volume: 0.8); } catch (_) {} }
  Future<void> startAlarm() async { if (_alOn) return; _alOn = true; try { await _al.setReleaseMode(ReleaseMode.loop); await _al.play(AssetSource('sounds/quench.wav'), volume: 0.45); } catch (_) {} }
  Future<void> stopAlarm() async { _alOn = false; try { await _al.stop(); } catch (_) {} }
  Future<void> playQuench() async { try { await _qs.play(AssetSource('sounds/explosion_jefe.mp3'), volume: 1.0); } catch (_) {} }
  Future<void> stopAll() async { try { await _bg.stop(); } catch (_) {} try { await _bm.stop(); } catch (_) {} try { await _eb.stop(); } catch (_) {} try { await _qs.stop(); } catch (_) {} try { await _al.stop(); } catch (_) {} try { await _sfx.stop(); } catch (_) {} for (final p in _pool) { try { await p.stop(); } catch (_) {} } _bossOn = false; _bgOn = false; _alOn = false; }
  void dispose() { for (final p in _pool) p.dispose(); _bg.dispose(); _bm.dispose(); _eb.dispose(); _qs.dispose(); _al.dispose(); _sfx.dispose(); }
}

// ── MODELOS ──────────────────────────────────────────────
class PlayerBuild {
  double damage, fireRate, maxEnergy, cooling, shieldEfficiency, heatGenMult;
  bool hasTripleShot; List<String> modules;
  PlayerBuild({this.damage = 10, this.fireRate = 1.0, this.maxEnergy = 100, this.cooling = 1.0, this.shieldEfficiency = 1.0, this.hasTripleShot = false, this.heatGenMult = 1.0, List<String>? modules}) : modules = modules ?? [];
}
class Player {
  double x, y, energy = 100, heat = 0; bool shieldActive = false; double shieldTimer = 0; PlayerBuild build;
  // y es para Finisher Mode (movimiento libre)
  Player(this.x, {PlayerBuild? b, double? startY}) : build = b ?? PlayerBuild(), energy = b?.maxEnergy ?? 100, y = startY ?? 0;
}
class Enemy {
  double x, y, hp, maxHp, vx, vy; EnemyKind kind; bool dead = false; double hitFlash = 0, actionTimer = 0, animT = 0;
  Enemy({required this.x, required this.y, required this.hp, required this.vx, this.vy = 90, this.kind = EnemyKind.interceptor}) : maxHp = hp;
}
class Asteroid {
  double x, y, vx, vy, r, angle, spin; bool dead = false; int level;
  Asteroid({required this.x, required this.y, required this.vx, required this.vy, required this.r, this.level = 2}) : angle = 0, spin = (Random().nextDouble() - 0.5) * (level == 0 ? 5 : level == 1 ? 3 : 2);
}
class Boss {
  double x, y, hp, maxHp, vx, vy; bool dead = false;
  double hitFlash = 0, animT = 0, stateTimer = 0, chargeGlow = 0, burstTimer = 0;
  int burstCount = 0; BossState state = BossState.moving;
  double repelMeter = 0;
  bool phaseShieldActive = false; double phaseShieldTimer = 0, vulnerableTimer = 0; bool phaseTriggered = false;
  // Finisher
  bool finisherTriggered = false;
  static const double moveTime = 3.0, chargeTime = kBossChargeTime, cooldownTime = 2.8;
  Boss({required this.x, required this.y, required this.hp, this.vx = 75}) : maxHp = hp, vy = 0;
}
class Bullet {
  double x, y, damage, angle, speed; bool isEnemy, fromBoss, isMissile;
  Bullet(this.x, this.y, this.damage, {this.isEnemy = false, this.angle = 0, this.fromBoss = false, this.isMissile = false, this.speed = 560});
}
class PowerUp {
  double x, y, animT; PowerUpKind kind; bool collected;
  PowerUp(this.x, this.y, this.kind) : animT = 0, collected = false;
}
class FloatingText { double x, y, life; String text; Color color; FloatingText(this.x, this.y, this.text, this.color) : life = 1.0; }
class Particle {
  double x, y, vx, vy, life, maxLife, size; Color color; bool isFrost, isSmoke;
  Particle({required this.x, required this.y, required this.vx, required this.vy, required this.life, required this.color, this.size = 4, this.isFrost = false, this.isSmoke = false}) : maxLife = life;
}
class UpgradeOption {
  final String title, description, tradeoff, emoji; final Color color; final void Function(PlayerBuild) apply; final bool hasTradeoff;
  const UpgradeOption({required this.title, required this.description, this.tradeoff = '', required this.emoji, required this.color, required this.apply, this.hasTradeoff = false});
}
class PortalNode {
  double x, y, hp; bool broken;
  PortalNode({required this.x, required this.y, this.hp = 100, this.broken = false});
  Color get color { if (broken) return const Color(0xFF00FF88); if (hp > 60) return const Color(0xFFFF2222); if (hp > 30) return const Color(0xFFFF8800); return const Color(0xFFFFFF00); }
}

// ── MISSILE SYSTEM ───────────────────────────────────────
class MissileSystem {
  double charge = 0; bool ready = false; final double rechargeTime;
  MissileSystem(this.rechargeTime);
  void update(double dt) { if (ready) return; charge = (charge + dt).clamp(0, rechargeTime); if (charge >= rechargeTime) ready = true; }
  bool consume() { if (!ready) return false; ready = false; charge = 0; return true; }
  double get fraction => ready ? 1.0 : charge / rechargeTime;
}

// ── PHASE ENGINE ─────────────────────────────────────────
class PhaseEngine {
  GamePhase phase = GamePhase.combat; double timer = 0; int cycleCount = 0;
  void update(double dt, {required VoidCallback onDecision, required VoidCallback onBoss}) {
    timer += dt;
    if (phase == GamePhase.combat && timer >= kCombatDuration) { cycleCount++; timer = 0; if (cycleCount % 3 == 0) { phase = GamePhase.boss; onBoss(); } else { phase = GamePhase.decision; onDecision(); } }
  }
  void endDecision() { phase = GamePhase.combat; timer = 0; }
  void endBoss() { phase = GamePhase.combat; timer = 0; }
  double get combatProgress => phase == GamePhase.combat ? (timer / kCombatDuration).clamp(0, 1) : 1.0;
}

// ── RESOURCE SYSTEM ──────────────────────────────────────
class ResourceSystem {
  double energy = 100, entropy = 0;
  void update(double dt, PlayerBuild b) { energy = (energy + 5 * dt).clamp(0, b.maxEnergy); entropy = (entropy + 0.3 * dt).clamp(0, 100); }
  void applyShoot(PlayerBuild b) { energy -= 1.2; entropy += 0.12; }
  double get energyFrac => (energy / 100).clamp(0, 1);
  double get entropyFrac => entropy / 100;
}

// ── AI ADAPT ─────────────────────────────────────────────
class AIAdapt {
  double aggression = 1.0, swarmDensity = 1.0, counterFire = 0.5;
  double _spikeMult = 1.0; double _spikeTimer = 0;
  void resetForStage(int s) { aggression = 1.0 + (s - 1) * 0.12; swarmDensity = 1.0 + (s - 1) * 0.10; counterFire = 0.5 + (s - 1) * 0.06; }
  void analyze(PlayerBuild b, int s) { final maxAgg = 1.0 + (s - 1) * 0.3; final maxSwarm = 1.0 + (s - 1) * 0.25; if (b.damage > 15) aggression = (aggression + 0.08).clamp(1, maxAgg); if (b.fireRate > 1.3) swarmDensity = (swarmDensity + 0.10).clamp(1, maxSwarm); counterFire = (counterFire + 0.05 * s).clamp(0.5, 1.8); }
  void updateSpike(double dt, DifficultyConfig diff) { if (diff.level != Difficulty.comandante) { _spikeMult = 1.0; return; } _spikeTimer -= dt; if (_spikeTimer <= 0) { _spikeMult = _spikeMult > 1.0 ? 1.0 : 1.8; _spikeTimer = 15 + Random().nextDouble() * 10; } }
  double get currentSpike => _spikeMult;
  double spawnInterval(int c, int s, DifficultyConfig diff) { final base = 2.4 - (c * 0.06) - (s - 1) * 0.06; return (base.clamp(0.85, 2.4) / aggression / diff.spawnRateMult) / _spikeMult; }
  int waveSize(int c, int s, DifficultyConfig diff) => (1 + (c * 0.22 + swarmDensity * 0.18 + (s - 1) * 0.20)).floor().clamp(1, diff.maxWaveSize);
}

// ── CHARGE INDICATOR ─────────────────────────────────────
class ChargeIndicator {
  final String icon; final Color color; double chargeTime, current = 0; bool ready = false, active = false; double activeTimer = 0; final double activeDuration;
  ChargeIndicator({required this.icon, required this.color, required this.chargeTime, required this.activeDuration});
  void update(double dt) { if (active) { activeTimer -= dt; if (activeTimer <= 0) { active = false; activeTimer = 0; current = 0; ready = false; } } else if (!ready) { current = (current + dt).clamp(0, chargeTime); if (current >= chargeTime) ready = true; } }
  void consume() { if (ready && !active) { active = true; activeTimer = activeDuration; } }
  double get fraction => ready ? 1.0 : current / chargeTime;
}

// ── SPRITE CACHE ──────────────────────────────────────────
class SpriteCache {
  ui.Image? player, boss, boss2, boss3, boss4, enemy1, enemy2, enemy3, enemy4; bool loaded = false;
  Future<void> load() async { try { player = await _lc('assets/images/player.png'); boss = await _lc('assets/images/boss.png'); enemy1 = await _lc('assets/images/enemy1.png'); enemy2 = await _lc('assets/images/enemy2.png'); enemy3 = await _lc('assets/images/enemy3.png'); enemy4 = await _lc('assets/images/enemy4.png'); try { boss2 = await _lc('assets/images/jefe2.png'); } catch (_) {} try { boss3 = await _lc('assets/images/jefe3.png'); } catch (_) {} try { boss4 = await _lc('assets/images/jefe4.png'); } catch (_) {} loaded = true; } catch (_) { loaded = false; } }
  Future<ui.Image> _lc(String path) async { final data = await rootBundle.load(path); final codec = await ui.instantiateImageCodec(data.buffer.asUint8List()); final frame = await codec.getNextFrame(); final raw = frame.image; final bd = await raw.toByteData(format: ui.ImageByteFormat.rawRgba); if (bd == null) return raw; final w = raw.width, h = raw.height; final pixels = bd.buffer.asUint8List(); final result = Uint8List.fromList(pixels); for (int i = 0; i < result.length; i += 4) { final r = result[i], g = result[i + 1], b = result[i + 2], a = result[i + 3]; if (a == 0) continue; final mx = max(r, max(g, b)); final mn = min(r, min(g, b)); final sat = mx == 0 ? 0 : (mx - mn) * 255 ~/ mx; if (sat < 55 && mx > 60 && mx < 230) { result[i + 3] = 0; continue; } if (r > 215 && g > 215 && b > 215 && a > 150) { result[i + 3] = 0; continue; } if ((r - g).abs() < 12 && (g - b).abs() < 12 && (r - b).abs() < 12 && mx > 90 && mx < 200) { result[i + 3] = 0; continue; } } final comp = Completer<ui.Image>(); ui.decodeImageFromPixels(result, w, h, ui.PixelFormat.rgba8888, comp.complete); return comp.future; }
  ui.Image? enemyImg(EnemyKind k) => switch (k) { EnemyKind.interceptor => enemy1, EnemyKind.frigate => enemy2, EnemyKind.parasite => enemy3, EnemyKind.corrupter => enemy4 };
  ui.Image? bossImg(int s) => switch (s) { 1 => boss, 2 => boss2, 3 => boss3, 4 => boss4, _ => boss };
}

void drawSprite(Canvas canvas, ui.Image img, Offset center, double size, {double flash = 0}) {
  final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
  final dst = Rect.fromCenter(center: center, width: size, height: size);
  canvas.drawImageRect(img, src, dst, Paint()..filterQuality = FilterQuality.high..isAntiAlias = true..blendMode = BlendMode.srcOver);
  if (flash > 0) { canvas.drawImageRect(img, src, dst, Paint()..filterQuality = FilterQuality.high..blendMode = BlendMode.srcATop..colorFilter = ColorFilter.mode(Colors.white.withOpacity(flash.clamp(0, 1) * 0.65), BlendMode.srcATop)); }
}

// ══════════════════════════════════════════════════════════
// DOCK SCENE
// ══════════════════════════════════════════════════════════
class DockScene extends StatefulWidget {
  final VoidCallback onFinish; const DockScene({super.key, required this.onFinish}); @override State<DockScene> createState() => _DockSceneState();
}
class _DockSceneState extends State<DockScene> {
  late VideoPlayerController _ctrl; bool _initialized = false;
  @override void initState() { super.initState(); _ctrl = VideoPlayerController.asset('assets/videos/intro_dock.mp4')..initialize().then((_) { if (!mounted) return; setState(() => _initialized = true); _ctrl.play(); _ctrl.addListener(_onVideoEnd); }); }
  void _onVideoEnd() { if (_ctrl.value.position >= _ctrl.value.duration && _ctrl.value.duration.inMilliseconds > 0) { _ctrl.removeListener(_onVideoEnd); if (mounted) widget.onFinish(); } }
  @override void dispose() { _ctrl.removeListener(_onVideoEnd); _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext ctx) => Scaffold(backgroundColor: Colors.black, body: GestureDetector(onTap: widget.onFinish, child: Stack(children: [if (_initialized) SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _ctrl.value.size.width, height: _ctrl.value.size.height, child: VideoPlayer(_ctrl)))) else const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(color: cIce), SizedBox(height: 16), Text('PHOENIX PROJECT', style: TextStyle(color: cGold, fontSize: 14, fontFamily: 'Orbitron', letterSpacing: 2))])), if (_initialized) Positioned(bottom: 24, right: 20, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white24)), child: const Text('toca para saltar', style: TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'Orbitron'))))])));
}

class _CinDust { double x, y, speed, size; _CinDust({required this.x, required this.y, required this.speed, required this.size}); }

// ══════════════════════════════════════════════════════════
// CINEMATIC SCREEN
// ══════════════════════════════════════════════════════════
class CinematicScreen extends StatefulWidget {
  final List<CinematicScene> scenes; final VoidCallback onDone;
  const CinematicScreen({super.key, required this.scenes, required this.onDone}); @override State<CinematicScreen> createState() => _CinState();
}
class _CinState extends State<CinematicScreen> with TickerProviderStateMixin {
  int _idx = 0, _ci = 0; String _disp = ''; bool _full = false;
  late AnimationController _tc, _zoom, _dustCtrl; late Animation<double> _zoomAnim;
  final _tts = FlutterTts(); bool _ttsReady = false; double _flashAlpha = 0.0;
  final List<_CinDust> _dust = []; final _rng = Random();
  @override void initState() { super.initState(); _tc = AnimationController(vsync: this, duration: const Duration(milliseconds: 32))..addListener(_tick); _zoom = AnimationController(vsync: this, duration: const Duration(seconds: 8))..forward(); _zoomAnim = Tween(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _zoom, curve: Curves.easeInOut)); _dustCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 16))..addListener(_updateDust)..repeat(); for (int i = 0; i < 18; i++) _dust.add(_CinDust(x: _rng.nextDouble(), y: _rng.nextDouble(), speed: 0.00008 + _rng.nextDouble() * 0.00015, size: 1 + _rng.nextDouble() * 2.5)); _initTts(); _startScene(); }
  void _updateDust() { for (final d in _dust) { d.y -= d.speed; if (d.y < 0) d.y = 1.0; } if (mounted) setState(() {}); }
  Future<void> _initTts() async { try { await _tts.setLanguage('es-MX'); await _tts.setSpeechRate(0.42); await _tts.setPitch(0.95); _ttsReady = true; } catch (_) {} }
  void _startScene() { _ci = 0; _disp = ''; _full = false; _zoom.reset(); _zoom.forward(); _tc.repeat(); if (_ttsReady) _tts.speak(widget.scenes[_idx].dialogue.replaceAll('\n', ' ')); }
  void _tick() { final f = widget.scenes[_idx].dialogue; if (_ci < f.length) { setState(() { _ci++; _disp = f.substring(0, _ci); }); } else { _tc.stop(); setState(() => _full = true); } if (_flashAlpha > 0) setState(() => _flashAlpha = (_flashAlpha - 0.05).clamp(0, 1)); }
  void _next() { if (!_full) { _tc.stop(); setState(() { _disp = widget.scenes[_idx].dialogue; _full = true; }); _tts.stop(); return; } _tts.stop(); if (_idx < widget.scenes.length - 1) { setState(() { _flashAlpha = 1.0; _idx++; }); _startScene(); } else widget.onDone(); }
  @override void dispose() { _tc.dispose(); _zoom.dispose(); _dustCtrl.dispose(); _tts.stop(); super.dispose(); }
  Color _sc(String s) => switch (s) { 'gold' => cGold, 'ice' => cIce, 'red' => cDanger, _ => Colors.white };
  @override Widget build(BuildContext ctx) {
    final s = widget.scenes[_idx]; final sc = _sc(s.speakerColor); final sz = MediaQuery.of(ctx).size;
    return Scaffold(backgroundColor: Colors.black, body: GestureDetector(onTapDown: (_) => _next(), child: Column(children: [
      Expanded(flex: 55, child: Stack(children: [
        Positioned.fill(child: AnimatedBuilder(animation: _zoomAnim, builder: (_, __) => Transform.scale(scale: _zoomAnim.value, child: Image.asset(s.imageAsset, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, __, ___) => Container(color: const Color(0xFF050A14), child: const Center(child: Icon(Icons.image_not_supported, color: Colors.white24, size: 48))))))),
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.28))),
        Positioned.fill(child: CustomPaint(painter: _VignettePainter())),
        Positioned.fill(child: CustomPaint(painter: _DustPainter(dust: _dust, sw: sz.width, sh: sz.height * 0.55))),
        Positioned(bottom: 0, left: 0, right: 0, height: 110, child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.97)])))),
        Positioned(top: 0, left: 0, right: 0, height: MediaQuery.of(ctx).padding.top + 6, child: Container(color: Colors.black)),
        Positioned(top: MediaQuery.of(ctx).padding.top + 10, left: 12, right: 80, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), border: Border.all(color: cGold.withOpacity(0.6)), borderRadius: BorderRadius.circular(3)), child: Text(s.location, style: const TextStyle(color: cGold, fontSize: 9, fontFamily: 'Orbitron', letterSpacing: 1.5)))),
        Positioned(top: MediaQuery.of(ctx).padding.top + 10, right: 12, child: Text('${_idx + 1}/${widget.scenes.length}', style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'Orbitron'))),
        if (_flashAlpha > 0) Positioned.fill(child: Container(color: Colors.white.withOpacity(_flashAlpha * 0.7))),
      ])),
      Container(constraints: BoxConstraints(minHeight: sz.height * 0.32), padding: const EdgeInsets.fromLTRB(20, 14, 20, 28), decoration: BoxDecoration(color: Colors.black, border: Border(top: BorderSide(color: sc.withOpacity(0.5), width: 1.5))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (s.speaker.isNotEmpty) ...[Row(children: [Container(width: 3, height: 14, decoration: BoxDecoration(color: sc, boxShadow: [BoxShadow(color: sc, blurRadius: 5)])), const SizedBox(width: 8), Expanded(child: Text(s.speaker, style: TextStyle(color: sc, fontSize: 11, fontFamily: 'Orbitron', fontWeight: FontWeight.bold)))]), const SizedBox(height: 10)],
        Text(_disp, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.55, fontFamily: 'Orbitron')), const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [if (_full) Row(children: [Text(_idx == widget.scenes.length - 1 ? 'CONTINUAR' : 'SIGUIENTE', style: TextStyle(color: sc, fontSize: 10, fontFamily: 'Orbitron', letterSpacing: 1.5)), const SizedBox(width: 6), Icon(Icons.arrow_forward_ios, color: sc, size: 14)]) else const Text('toca para continuar', style: TextStyle(color: Colors.white24, fontSize: 9, fontFamily: 'Orbitron'))]),
      ])),
    ])));
  }
}
class _VignettePainter extends CustomPainter { @override void paint(Canvas canvas, Size size) { canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..shader = RadialGradient(center: Alignment.center, radius: 0.85, colors: [Colors.transparent, Colors.black.withOpacity(0.65)], stops: const [0.55, 1.0]).createShader(Rect.fromLTWH(0, 0, size.width, size.height))); } @override bool shouldRepaint(covariant CustomPainter _) => false; }
class _DustPainter extends CustomPainter { final List<_CinDust> dust; final double sw, sh; _DustPainter({required this.dust, required this.sw, required this.sh}); @override void paint(Canvas canvas, Size size) { final p = Paint()..color = Colors.white.withOpacity(0.35); for (final d in dust) canvas.drawCircle(Offset(d.x * sw, d.y * sh), d.size, p); } @override bool shouldRepaint(covariant CustomPainter _) => true; }

// ══════════════════════════════════════════════════════════
// APP ROOT
// ══════════════════════════════════════════════════════════
class PhoenixCoreApp extends StatelessWidget { const PhoenixCoreApp({super.key}); @override Widget build(BuildContext ctx) => MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData.dark(), home: const AppRoot()); }

class AppRoot extends StatefulWidget { const AppRoot({super.key}); @override State<AppRoot> createState() => _AppRootState(); }
class _AppRootState extends State<AppRoot> {
  AppScreen _screen = AppScreen.dockIntro;
  int _score = 0, _currentStage = 1;
  int _bestAmateur = 0, _bestVeterano = 0, _bestComandante = 0, _totalRuns = 0;
  final _audio = AudioManager(); final _sprites = SpriteCache();
  PlayerBuild? _carry;
  DifficultyConfig _diff = const DifficultyConfig(Difficulty.amateur);
  DateTime? _runStart; int _stagesReached = 1;
  // Stats para loop retención
  int _totalDamageDealt = 0;

  @override void initState() { super.initState(); _loadBests(); _sprites.load().then((_) { if (mounted) setState(() {}); }); }
  @override void dispose() { _audio.dispose(); super.dispose(); }

  void _loadBests() async { final p = await SharedPreferences.getInstance(); setState(() { _bestAmateur = p.getInt('best_amateur') ?? 0; _bestVeterano = p.getInt('best_veterano') ?? 0; _bestComandante = p.getInt('best_comandante') ?? 0; _totalRuns = p.getInt('total_runs') ?? 0; }); }
  int get _currentBest => switch (_diff.level) { Difficulty.amateur => _bestAmateur, Difficulty.veterano => _bestVeterano, Difficulty.comandante => _bestComandante };

  void _onDockDone() { _audio.startAmbient(); setState(() => _screen = AppScreen.intro); }
  void _onIntroDone() => setState(() => _screen = AppScreen.menu);

  void _startWithDiff(DifficultyConfig diff) {
    _diff = diff; _currentStage = 1; _carry = null; _score = 0; _stagesReached = 1; _totalDamageDealt = 0; _runStart = DateTime.now();
    _audio.stopAll().then((_) { _audio.playMissionStart(); _audio.startAmbient(); });
    setState(() => _screen = AppScreen.playing);
  }

  void _onStageClear(int score, PlayerBuild build, int dmg) {
    _score = score; _carry = build; _stagesReached = _currentStage; _totalDamageDealt += dmg;
    if (_currentStage >= 4) { _save(_score); setState(() => _screen = AppScreen.victory); }
    else setState(() => _screen = AppScreen.stageClear);
  }
  void _onCinematicDone() { _currentStage++; setState(() => _screen = AppScreen.playing); }
  void _gameOver(int score, int dmg) { _audio.switchToAmbient(); _stagesReached = _currentStage; _totalDamageDealt += dmg; _save(score); setState(() { _score = score; _screen = AppScreen.gameOver; }); }
  void _save(int s) async { final key = switch (_diff.level) { Difficulty.amateur => 'best_amateur', Difficulty.veterano => 'best_veterano', Difficulty.comandante => 'best_comandante' }; final p = await SharedPreferences.getInstance(); final current = p.getInt(key) ?? 0; if (s > current) await p.setInt(key, s); _totalRuns++; await p.setInt('total_runs', _totalRuns); _loadBests(); }

  Duration get _runDuration => _runStart != null ? DateTime.now().difference(_runStart!) : Duration.zero;

  @override Widget build(BuildContext ctx) => switch (_screen) {
    AppScreen.dockIntro  => DockScene(onFinish: _onDockDone),
    AppScreen.intro      => CinematicScreen(scenes: _introScenes, onDone: _onIntroDone),
    AppScreen.menu       => MenuScreen(bestAmateur: _bestAmateur, bestVeterano: _bestVeterano, bestComandante: _bestComandante, totalRuns: _totalRuns, onStart: () => setState(() => _screen = AppScreen.diffSelect), sprites: _sprites),
    AppScreen.diffSelect => DiffSelectScreen(onSelect: _startWithDiff, bestAmateur: _bestAmateur, bestVeterano: _bestVeterano, bestComandante: _bestComandante),
    AppScreen.playing    => GameScreen(key: ValueKey('s${_currentStage}_${_diff.level.name}'), stageConfig: _stages[_currentStage - 1], initialBuild: _carry, initialScore: _score, onStageClear: _onStageClear, onGameOver: _gameOver, audio: _audio, sprites: _sprites, diff: _diff),
    AppScreen.stageClear => StageClearScreen(stageNum: _currentStage, diff: _diff, onContinue: () => setState(() => _screen = AppScreen.cinematic)),
    AppScreen.cinematic  => CinematicScreen(scenes: _stages[_currentStage].scenes, onDone: _onCinematicDone),
    AppScreen.gameOver   => GameOverScreen(score: _score, best: _currentBest, diff: _diff, stagesReached: _stagesReached, runDuration: _runDuration, totalDmg: _totalDamageDealt, onRetry: () => _startWithDiff(_diff), onChangeDiff: () => setState(() => _screen = AppScreen.diffSelect), onMenu: () => setState(() => _screen = AppScreen.menu)),
    AppScreen.victory    => VictoryScreen(score: _score, best: _currentBest, diff: _diff, runDuration: _runDuration, totalDmg: _totalDamageDealt, onTryNextDiff: () { final next = switch (_diff.level) { Difficulty.amateur => const DifficultyConfig(Difficulty.veterano), Difficulty.veterano => const DifficultyConfig(Difficulty.comandante), Difficulty.comandante => null }; if (next != null) _startWithDiff(next); else setState(() => _screen = AppScreen.menu); }, onMenu: () => setState(() => _screen = AppScreen.menu)),
  };
}

// ══════════════════════════════════════════════════════════
// DIFF SELECT — Paneles tácticos animados
// ══════════════════════════════════════════════════════════
class DiffSelectScreen extends StatefulWidget {
  final void Function(DifficultyConfig) onSelect;
  final int bestAmateur, bestVeterano, bestComandante;
  const DiffSelectScreen({super.key, required this.onSelect, required this.bestAmateur, required this.bestVeterano, required this.bestComandante});
  @override State<DiffSelectScreen> createState() => _DiffSelectScreenState();
}
class _DiffSelectScreenState extends State<DiffSelectScreen> with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _entryCtrl;
  late List<Animation<Offset>> _slideAnims;
  int _pressedIndex = -1;

  @override void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _slideAnims = List.generate(3, (i) => Tween<Offset>(begin: const Offset(0, -1.5), end: Offset.zero).animate(CurvedAnimation(parent: _entryCtrl, curve: Interval(i * 0.15, 0.7 + i * 0.1, curve: Curves.elasticOut))));
  }
  @override void dispose() { _pulseCtrl.dispose(); _entryCtrl.dispose(); super.dispose(); }

  static const _feats = [
    ['Proyectiles lentos', 'PowerUps frecuentes', 'Triple cañón garantizado', 'Heat sin penalización real'],
    ['Leading básico de IA', 'Heat importa — gestión real', 'Misil Phoenix (10s recarga)', 'Jefe 1: ventana de vulnerabilidad'],
    ['Picos de presión dinámicos', 'Trade-offs en upgrades', 'Misil Phoenix (14s recarga)', 'Heat domina el gameplay', 'Triple cañón + costo de heat'],
  ];
  static const _icons = ['🛡️', '⚔️', '☠️'];
  static const _bests = [0, 0, 0]; // placeholder

  @override Widget build(BuildContext ctx) {
    final diffs = [const DifficultyConfig(Difficulty.amateur), const DifficultyConfig(Difficulty.veterano), const DifficultyConfig(Difficulty.comandante)];
    final bests = [widget.bestAmateur, widget.bestVeterano, widget.bestComandante];
    return Scaffold(backgroundColor: cBg, body: SafeArea(child: Column(children: [
      const SizedBox(height: 20),
      const _GlowText('SELECCIONA DIFICULTAD', color: cIce, size: 16),
      const SizedBox(height: 4),
      const Text('Cada dificultad es una experiencia distinta', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'Orbitron')),
      const SizedBox(height: 16),
      Expanded(child: AnimatedBuilder(animation: _pulseCtrl, builder: (ctx, _) {
        return ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 18), itemCount: 3, itemBuilder: (ctx, i) {
          final d = diffs[i]; final best = bests[i]; final feats = _feats[i];
          return SlideTransition(position: _slideAnims[i], child: Padding(padding: const EdgeInsets.only(bottom: 14), child: GestureDetector(
            onTapDown: (_) => setState(() => _pressedIndex = i),
            onTapUp: (_) { setState(() => _pressedIndex = -1); widget.onSelect(d); },
            onTapCancel: () => setState(() => _pressedIndex = -1),
            child: AnimatedScale(scale: _pressedIndex == i ? 1.03 : 1.0, duration: const Duration(milliseconds: 120), child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                border: Border.all(color: _pressedIndex == i ? d.color : d.color.withOpacity(0.5 + _pulseCtrl.value * 0.3), width: _pressedIndex == i ? 3 : 2),
                borderRadius: BorderRadius.circular(16),
                color: _pressedIndex == i ? d.color.withOpacity(0.18) : d.color.withOpacity(0.07),
                boxShadow: [BoxShadow(color: d.color.withOpacity(0.15 + _pulseCtrl.value * 0.12), blurRadius: 20, spreadRadius: 2)],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(_icons[i], style: const TextStyle(fontSize: 30)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.name, style: TextStyle(color: d.color, fontSize: 17, fontFamily: 'Orbitron', fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(d.tagline, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
                  ])),
                ]),
                const SizedBox(height: 12),
                // Barra de riesgo
                Row(children: [
                  Text('RIESGO ', style: TextStyle(color: d.color.withOpacity(0.7), fontSize: 9, fontFamily: 'Orbitron')),
                  ...List.generate(5, (j) => Padding(padding: const EdgeInsets.only(right: 3), child: Container(width: 14, height: 8, decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: j < d.riskLevel ? d.color : d.color.withOpacity(0.2))))),
                ]),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 5, children: feats.map((f) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: d.color.withOpacity(0.12), borderRadius: BorderRadius.circular(4), border: Border.all(color: d.color.withOpacity(0.4))), child: Text(f, style: TextStyle(color: d.color, fontSize: 9, fontFamily: 'Orbitron')))).toList()),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [Icon(Icons.stars, color: d.color, size: 14), const SizedBox(width: 4), Text('x${d.scoreMult.toStringAsFixed(1)} score', style: TextStyle(color: d.color, fontSize: 11, fontFamily: 'Orbitron'))]),
                  if (best > 0) Row(children: [const Icon(Icons.emoji_events, color: Colors.white38, size: 12), const SizedBox(width: 4), Text('MEJOR: $best', style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'Orbitron'))]),
                  Icon(Icons.arrow_forward_ios, color: d.color, size: 16),
                ]),
              ]),
            )))));
        });
      })),
    ])));
  }
}

// ══════════════════════════════════════════════════════════
// STAGE CLEAR
// ══════════════════════════════════════════════════════════
class StageClearScreen extends StatefulWidget {
  final int stageNum; final DifficultyConfig diff; final VoidCallback onContinue;
  const StageClearScreen({super.key, required this.stageNum, required this.diff, required this.onContinue}); @override State<StageClearScreen> createState() => _SCState();
}
class _SCState extends State<StageClearScreen> with SingleTickerProviderStateMixin {
  late AnimationController _c; late Animation<double> _a;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward(); _a = CurvedAnimation(parent: _c, curve: Curves.elasticOut); hapticHeavy(); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext ctx) => Scaffold(backgroundColor: cBg, body: SafeArea(child: Center(child: ScaleTransition(scale: _a, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Text('✦', style: TextStyle(color: cGold, fontSize: 64, shadows: [Shadow(color: cGold, blurRadius: 30)])), const SizedBox(height: 16),
    _GlowText('STAGE ${widget.stageNum}', color: cIce, size: 22), const SizedBox(height: 8), _GlowText('COMPLETADO', color: cGold, size: 38), const SizedBox(height: 8),
    _GlowText(_stages[widget.stageNum - 1].name, color: Colors.white54, size: 13), const SizedBox(height: 14),
    Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(color: widget.diff.color.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: widget.diff.color)), child: Text('${widget.diff.emoji} ${widget.diff.name}  ·  x${widget.diff.scoreMult.toStringAsFixed(1)} SCORE', style: TextStyle(color: widget.diff.color, fontSize: 11, fontFamily: 'Orbitron'))),
    const SizedBox(height: 36), _GlowText('PREPARANDO STAGE ${widget.stageNum + 1}', color: cIce, size: 14), const SizedBox(height: 8), _GlowText(_stages[widget.stageNum].name, color: cFire, size: 16), const SizedBox(height: 48),
    _Btn(label: 'VER BRIEFING', color: cGold, onTap: widget.onContinue),
  ])))));
}

// ══════════════════════════════════════════════════════════
// VICTORY — Con loop retención
// ══════════════════════════════════════════════════════════
class VictoryScreen extends StatelessWidget {
  final int score, best, totalDmg; final DifficultyConfig diff; final Duration runDuration;
  final VoidCallback onTryNextDiff, onMenu;
  const VictoryScreen({super.key, required this.score, required this.best, required this.diff, required this.runDuration, required this.totalDmg, required this.onTryNextDiff, required this.onMenu});
  String get _nextDiffName => switch (diff.level) { Difficulty.amateur => 'VETERANO', Difficulty.veterano => 'COMANDANTE', Difficulty.comandante => 'MENÚ' };
  Color get _nextDiffColor => switch (diff.level) { Difficulty.amateur => cGold, Difficulty.veterano => cRed, Difficulty.comandante => cIce };
  String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  @override Widget build(BuildContext ctx) => Scaffold(backgroundColor: cBg, body: SafeArea(child: Center(child: SingleChildScrollView(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const SizedBox(height: 20), const Text('🏆', style: TextStyle(fontSize: 72)), const SizedBox(height: 12),
    _GlowText('VICTORIA GALÁCTICA', color: cGold, size: 24), const SizedBox(height: 6),
    _GlowText('La puerta dimensional fue cerrada…', color: Colors.white70, size: 12), _GlowText('por ahora.', color: cIce, size: 15), const SizedBox(height: 16),
    Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), decoration: BoxDecoration(color: diff.color.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: diff.color, width: 2)), child: Text('${diff.emoji} ${diff.name}', style: TextStyle(color: diff.color, fontSize: 15, fontFamily: 'Orbitron', fontWeight: FontWeight.bold))),
    const SizedBox(height: 20),
    Container(margin: const EdgeInsets.symmetric(horizontal: 32), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)), child: Column(children: [
      _StatRow('SCORE FINAL', '$score', cGold), const SizedBox(height: 4),
      if (score >= best && score > 0) _StatRow('NUEVO RÉCORD', '🏆', cGold),
      _StatRow('MEJOR ANTERIOR', '$best', Colors.white38), const SizedBox(height: 4),
      _StatRow('TIEMPO TOTAL', _fmt(runDuration), cIce),
      _StatRow('DAÑO TOTAL', '${(totalDmg / 1000).toStringAsFixed(1)}K', cFire),
      _StatRow('STAGES', '4 / 4', cGreen),
    ])),
    const SizedBox(height: 24),
    // Botón principal — siguiente dificultad
    GestureDetector(onTap: onTryNextDiff, child: Container(margin: const EdgeInsets.symmetric(horizontal: 32), padding: const EdgeInsets.all(18), decoration: BoxDecoration(border: Border.all(color: _nextDiffColor, width: 2), borderRadius: BorderRadius.circular(14), color: _nextDiffColor.withOpacity(0.15), boxShadow: [BoxShadow(color: _nextDiffColor.withOpacity(0.4), blurRadius: 20)]), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.rocket_launch, color: _nextDiffColor, size: 22), const SizedBox(width: 10), Text(diff.level == Difficulty.comandante ? 'MENÚ PRINCIPAL' : '🔥 INTENTAR EN $_nextDiffName', style: TextStyle(color: _nextDiffColor, fontSize: 14, fontFamily: 'Orbitron', fontWeight: FontWeight.bold))]))),
    const SizedBox(height: 12), _Btn(label: 'MENÚ PRINCIPAL', color: Colors.white38, onTap: onMenu), const SizedBox(height: 20),
  ])))));
}

// ══════════════════════════════════════════════════════════
// GAME OVER — Loop retención directo
// ══════════════════════════════════════════════════════════
class GameOverScreen extends StatelessWidget {
  final int score, best, stagesReached, totalDmg; final DifficultyConfig diff; final Duration runDuration;
  final VoidCallback onRetry, onChangeDiff, onMenu;
  const GameOverScreen({super.key, required this.score, required this.best, required this.diff, required this.stagesReached, required this.runDuration, required this.totalDmg, required this.onRetry, required this.onChangeDiff, required this.onMenu});
  String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  @override Widget build(BuildContext ctx) {
    final nr = score >= best && score > 0;
    return Scaffold(backgroundColor: cBg, body: SafeArea(child: Center(child: SingleChildScrollView(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const SizedBox(height: 20), const _GlowText('QUENCH', color: cDanger, size: 48), const SizedBox(height: 4), const _GlowText('FALLO CRIOGÉNICO', color: cFire, size: 14), const SizedBox(height: 14),
      Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(color: diff.color.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: diff.color)), child: Text('${diff.emoji} ${diff.name}', style: TextStyle(color: diff.color, fontSize: 12, fontFamily: 'Orbitron'))),
      const SizedBox(height: 18),
      Container(margin: const EdgeInsets.symmetric(horizontal: 32), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)), child: Column(children: [
        _StatRow('SCORE', '$score', cGold), const SizedBox(height: 4),
        if (nr) _StatRow('NUEVO RÉCORD', '🏆', cGold),
        _StatRow('MEJOR ANTERIOR', '$best', Colors.white38), const SizedBox(height: 4),
        _StatRow('STAGE ALCANZADO', '$stagesReached / 4', cIce),
        _StatRow('TIEMPO', _fmt(runDuration), Colors.white54),
        _StatRow('DAÑO TOTAL', '${(totalDmg / 1000).toStringAsFixed(1)}K', cFire),
      ])),
      const SizedBox(height: 22),
      // Retención — reintentar PRIMERO, sin fricción
      _Btn(label: '⟳  REINTENTAR', color: diff.color, onTap: onRetry), const SizedBox(height: 10),
      _Btn(label: 'CAMBIAR DIFICULTAD', color: cIce, onTap: onChangeDiff), const SizedBox(height: 10),
      _Btn(label: 'MENÚ', color: Colors.white38, onTap: onMenu), const SizedBox(height: 20),
    ])))));
  }
}

class _StatRow extends StatelessWidget {
  final String label, value; final Color color;
  const _StatRow(this.label, this.value, this.color);
  @override Widget build(BuildContext ctx) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'Orbitron')), Text(value, style: TextStyle(color: color, fontSize: 11, fontFamily: 'Orbitron', fontWeight: FontWeight.bold))]);
}

// ══════════════════════════════════════════════════════════
// MENU
// ══════════════════════════════════════════════════════════
class MenuScreen extends StatefulWidget {
  final int bestAmateur, bestVeterano, bestComandante, totalRuns; final VoidCallback onStart; final SpriteCache sprites;
  const MenuScreen({super.key, required this.bestAmateur, required this.bestVeterano, required this.bestComandante, required this.totalRuns, required this.onStart, required this.sprites}); @override State<MenuScreen> createState() => _MState();
}
class _MState extends State<MenuScreen> with SingleTickerProviderStateMixin {
  late AnimationController _c; late Animation<double> _p;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true); _p = CurvedAnimation(parent: _c, curve: Curves.easeInOut); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext ctx) => Scaffold(backgroundColor: cBg, body: SafeArea(child: Center(child: SingleChildScrollView(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const SizedBox(height: 20), _GlowText('PHOENIX CORE', color: cFire, size: 36), const SizedBox(height: 4), _GlowText('CRYO BALANCE  V6', color: cIce, size: 15), const SizedBox(height: 4),
    if (widget.totalRuns > 0) Text('PARTIDAS JUGADAS: ${widget.totalRuns}', style: const TextStyle(color: Colors.white24, fontSize: 9, fontFamily: 'Orbitron')),
    const SizedBox(height: 14),
    Container(margin: const EdgeInsets.symmetric(horizontal: 24), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)), child: Column(children: [
      const Text('RÉCORDS', style: TextStyle(color: Colors.white38, fontSize: 9, fontFamily: 'Orbitron', letterSpacing: 2)), const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_RecordChip(emoji: '🛡️', name: 'AMATEUR', score: widget.bestAmateur, color: cGreen), _RecordChip(emoji: '⚔️', name: 'VETERANO', score: widget.bestVeterano, color: cGold), _RecordChip(emoji: '☠️', name: 'CMDTE', score: widget.bestComandante, color: cRed)]),
    ])),
    const SizedBox(height: 16), _FleetLegend(sprites: widget.sprites), const SizedBox(height: 22),
    AnimatedBuilder(animation: _p, builder: (_, __) => Transform.scale(scale: 1 + _p.value * 0.05, child: GestureDetector(onTap: widget.onStart, child: Container(padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18), decoration: BoxDecoration(border: Border.all(color: cFire, width: 2), borderRadius: BorderRadius.circular(10), color: cFire.withOpacity(0.15), boxShadow: [BoxShadow(color: cFire.withOpacity(0.4), blurRadius: 28)]), child: const _GlowText('INICIAR MISIÓN', color: Colors.white, size: 22))))),
    const SizedBox(height: 12), const Text('4 Stages · 4 Jefes · 3 Dificultades\nFinisher Mode · Misil Phoenix · Heat System', textAlign: TextAlign.center, style: TextStyle(color: Colors.white30, fontSize: 10, height: 1.5)), const SizedBox(height: 20),
  ])))));
}
class _RecordChip extends StatelessWidget {
  final String emoji, name; final int score; final Color color;
  const _RecordChip({required this.emoji, required this.name, required this.score, required this.color});
  @override Widget build(BuildContext ctx) => Column(children: [Text(emoji, style: const TextStyle(fontSize: 20)), const SizedBox(height: 2), Text(name, style: TextStyle(color: color, fontSize: 8, fontFamily: 'Orbitron')), Text(score > 0 ? '$score' : '---', style: TextStyle(color: color, fontSize: 10, fontFamily: 'Orbitron', fontWeight: FontWeight.bold))]);
}
class _FleetLegend extends StatelessWidget {
  final SpriteCache sprites; const _FleetLegend({required this.sprites});
  @override Widget build(BuildContext ctx) { final items = [(sprites.enemy1, cWarlord, 'Interceptor'), (sprites.enemy2, cGreen, 'Frigate'), (sprites.enemy3, cShield, 'Parasite'), (sprites.enemy4, const Color(0xFFFF6600), 'Corrupter')]; return Column(children: [const Text('FLOTA DEL WARLORD', style: TextStyle(color: Colors.white38, fontSize: 9, fontFamily: 'Orbitron', letterSpacing: 2)), const SizedBox(height: 8), Row(mainAxisAlignment: MainAxisAlignment.center, children: items.map((e) => Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Column(children: [SizedBox(width: 40, height: 40, child: e.$1 != null ? RawImage(image: e.$1, width: 40, height: 40, filterQuality: FilterQuality.high, fit: BoxFit.contain) : Container(decoration: BoxDecoration(shape: BoxShape.circle, color: e.$2.withOpacity(0.3), border: Border.all(color: e.$2, width: 1.5)))), const SizedBox(height: 4), Text(e.$3, style: const TextStyle(color: Colors.white54, fontSize: 8, fontFamily: 'Orbitron'))]))).toList())]); }
}

// ══════════════════════════════════════════════════════════
// GAME SCREEN — Con Finisher Mode
// ══════════════════════════════════════════════════════════
class GameScreen extends StatefulWidget {
  final StageConfig stageConfig; final PlayerBuild? initialBuild; final int initialScore;
  final void Function(int, PlayerBuild, int) onStageClear;
  final void Function(int, int) onGameOver;
  final AudioManager audio; final SpriteCache sprites; final DifficultyConfig diff;
  const GameScreen({super.key, required this.stageConfig, required this.initialBuild, required this.initialScore, required this.onStageClear, required this.onGameOver, required this.audio, required this.sprites, required this.diff});
  @override State<GameScreen> createState() => _GState();
}
class _GState extends State<GameScreen> with SingleTickerProviderStateMixin {
  final _rng = Random();
  AudioManager get _audio => widget.audio; SpriteCache get _spr => widget.sprites; StageConfig get _stage => widget.stageConfig; DifficultyConfig get _diff => widget.diff;
  double _sw = 0, _sh = 0; late Player _player;
  final _res = ResourceSystem(); final _phase = PhaseEngine(); late AIAdapt _ai;
  late HeatSystem _heat;
  MissileSystem? _missile;
  final _enemies = <Enemy>[]; final _bullets = <Bullet>[]; final _powerUps = <PowerUp>[];
  final _particles = <Particle>[]; final _floats = <FloatingText>[]; final _asteroids = <Asteroid>[];
  Boss? _boss; bool _bossAlive = false;
  // ── Finisher Mode ──
  final _finisher = FinisherState();
  bool _finisherTriggered = false;
  double _finisherCamZoom = 1.0; // zoom out durante chase
  // ── Boss death épica ──
  bool _bossDying = false; double _bossDeathTimer = 0; double _timeScale = 1.0;
  double _bossShakeX = 0, _bossShakeY = 0, _bossShakeIntensity = 0;
  int _score = 0, _totalDmg = 0; double _coreTemp = 0, _niFrame = 0;
  double _shootTimer = 0, _spawnTimer = 0, _puTimer = 0;
  bool _touching = false, _alarmOn = false; double _touchX = 0;
  bool _showDec = false; List<UpgradeOption> _opts = [];
  bool _frosting = false, _quenching = false;
  double _frostT = 0, _quenchT = 0, _pulse = 0, _pDir = 1;
  double _gravTimer = 75.0; bool _gravActive = false, _gravWarn = false;
  double _portal = 0.0; bool _mirrorWin = false; double _mirrorT = 0;
  double _asteroidTimer = 0; bool _paused = false;
  final _tracker = PlayerTracker(); final _profile = PlayerProfile();
  bool _antiPatternTriggered = false, _antiFinalTriggered = false;
  double _diffMult = 1.0, _decayTimer = 15.0;
  double _tripleTimer = 0.0; bool _triplePermanent = false;
  double _glitchT = 0; bool _glitchActive = false;
  final List<PortalNode> _portalNodes = [];
  bool _nodesInitialized = false, _deniseMsgShown = false; double _deniseMsgTimer = 0; bool _showDeniseWarning = false;
  final List<String> _dopEnojado = ['¡Imposible!', '¡Eso no cambia nada!', '¡Sigues siendo predecible!', '¡Tecnología de museo!'];
  bool _tripleGuaranteedUsed = false;
  double _upgradeFlash = 0; Color _upgradeFlashColor = Colors.white;
  bool _disposed = false;
  // Finisher joystick virtual
  Offset? _joystickOrigin; Offset _joystickDelta = Offset.zero;
  bool _finisherComplete = false;
  final _mg = ChargeIndicator(icon: '⚡', color: cGold, chargeTime: 28.0, activeDuration: 8.0);
  final _fr = ChargeIndicator(icon: '❄', color: cIce, chargeTime: 38.0, activeDuration: 6.0);
  Ticker? _ticker; Duration _last = Duration.zero;

  @override void initState() {
    super.initState(); _score = widget.initialScore; _ai = AIAdapt();
    _heat = HeatSystem(); _puTimer = _diff.powerUpInterval; _gravTimer = _diff.gravTimerSeconds;
    if (_diff.hasMissile) _missile = MissileSystem(_diff.missileRechargeTime);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sz = MediaQuery.of(context).size; _sw = sz.width; _sh = sz.height;
      final b = widget.initialBuild ?? PlayerBuild();
      _player = Player(_sw / 2, b: b, startY: _sh * 0.72); _res.energy = _player.build.maxEnergy;
      _ai.resetForStage(_stage.stageNum);
      _ticker = createTicker(_tick)..start();
    });
  }
  @override void dispose() { _disposed = true; _ticker?.dispose(); super.dispose(); }

  void _tick(Duration elapsed) {
    if (_disposed) return;
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05).toDouble();
    _last = elapsed; if (dt == 0 || !mounted) return; _update(dt);
  }

  // ── FINISHER MODE ─────────────────────────────────────
  void _triggerFinisher() {
    if (_finisherTriggered || _stage.stageNum == 4) return;
    _finisherTriggered = true;
    _finisher.phase = FinisherPhase.fleeing;
    _finisher.timer = 0;
    if (_boss != null) {
      _boss!.state = BossState.fleeing;
      _boss!.vy = _finisher.bossFleeVY;
    }
    _addFloat(_sw / 2, _sh * 0.35, '⚡ ¡HUYE — PERSÍGUELO!', cGold);
    hapticHeavy();
  }

  void _updateFinisher(double dt) {
    if (!_finisher.active || _boss == null) return;
    _finisher.timer += dt;

    switch (_finisher.phase) {
      case FinisherPhase.fleeing:
        // El boss huye hacia arriba con aceleración
        _boss!.y += _boss!.vy * dt;
        _boss!.vy = (_boss!.vy - 80 * dt).clamp(-600, -50); // acelera
        _boss!.x += _boss!.vx * dt * 0.5;
        if (_boss!.x < kBossR || _boss!.x > _sw - kBossR) _boss!.vx *= -1;
        // Después de 1.5s empieza el chase
        if (_finisher.timer > 1.5) {
          _finisher.phase = FinisherPhase.chasing;
          _finisher.timer = 0;
          _finisherCamZoom = 0.85; // zoom out
          _addFloat(_sw / 2, _sh * 0.4, '🎯 FINISHER MODE', cFire);
          // Reset boss position para que entre desde arriba
          _boss!.y = -kBossR * 2;
          _boss!.vy = 0;
          _boss!.hp = _boss!.maxHp * 0.08; // solo 8% de vida
        }

      case FinisherPhase.chasing:
        // Boss zigzaguea intentando escapar
        _boss!.y += 120 * dt; // baja lentamente
        _boss!.x += _boss!.vx * dt * 1.4;
        if (_boss!.x < kBossR * 1.5 || _boss!.x > _sw - kBossR * 1.5) _boss!.vx *= -1;
        // Dispara desesperadamente
        _boss!.burstTimer += dt;
        if (_boss!.burstTimer >= 0.6) { _boss!.burstTimer = 0; _fireFinisherBoss(); }
        // Finisher zoom
        _finisherCamZoom = (_finisherCamZoom + (0.85 - _finisherCamZoom) * dt * 3).clamp(0.8, 1.0);
        if (_boss!.y > _sh + kBossR * 2) {
          // Escapó — lo matamos narrativamente
          _boss!.hp = 0;
          _triggerBossDeath();
        }

      case FinisherPhase.rematch:
        break;
      case FinisherPhase.none:
        break;
    }

    // Movimiento libre del jugador en Finisher (joystick)
    if (_finisher.phase == FinisherPhase.chasing) {
      if (_joystickOrigin != null && _joystickDelta != Offset.zero) {
        final spd = 280.0;
        _player.x = (_player.x + _joystickDelta.dx * spd * dt).clamp(kPhoenixSize, _sw - kPhoenixSize);
        _player.y = (_player.y + _joystickDelta.dy * spd * dt).clamp(_sh * 0.2, _sh - kPhoenixSize * 2);
      }
    }
  }

  void _fireFinisherBoss() {
    if (_boss == null) return;
    final ba = atan2(_player.x - _boss!.x, _player.y - _boss!.y) * 0.5;
    _bullets.add(Bullet(_boss!.x, _boss!.y + kBossR, 8 * _diff.bossBulletDmgMult, isEnemy: true, fromBoss: true, angle: ba));
    _bullets.add(Bullet(_boss!.x, _boss!.y + kBossR, 6 * _diff.bossBulletDmgMult, isEnemy: true, fromBoss: true, angle: ba - 0.3));
    _bullets.add(Bullet(_boss!.x, _boss!.y + kBossR, 6 * _diff.bossBulletDmgMult, isEnemy: true, fromBoss: true, angle: ba + 0.3));
  }

  void _triggerBossDeath() {
    if (_bossDying || _boss == null) return;
    _bossDying = true; _bossDeathTimer = 0; _bossShakeIntensity = 22; _timeScale = 0.25;
    final bossScore = (500 + (_stage.stageNum - 1) * 200) * _diff.scoreMult;
    if (_finisher.active) {
      // Finisher bonus
      _score += (bossScore * 1.5).toInt();
      _addFloat(_boss!.x, _boss!.y, '+${(bossScore * 1.5).toInt()} FINISHER!', Colors.orange);
      _addFloat(_boss!.x, _boss!.y - 50, '★ FINISHER KILL ★', cGold);
    } else {
      _score += bossScore.toInt();
      _addFloat(_boss!.x, _boss!.y, '+${bossScore.toInt()} BOSS!', cGold);
      _addFloat(_boss!.x, _boss!.y - 50, '★ ELIMINADO ★', _stage.bossColor);
    }
    _totalDmg += (_boss!.maxHp * 1000).toInt(); // aproximación
    for (int i = 0; i < 80; i++) {
      final a = _rng.nextDouble() * pi * 2; final s = 80 + _rng.nextDouble() * 400;
      _particles.add(Particle(x: _boss!.x + (_rng.nextDouble() - 0.5) * 50, y: _boss!.y + (_rng.nextDouble() - 0.5) * 50, vx: cos(a) * s, vy: sin(a) * s, life: 1.0 + _rng.nextDouble() * 1.2, color: _rng.nextBool() ? cGold : (_rng.nextBool() ? cFire : Colors.orange), size: 4 + _rng.nextDouble() * 10));
    }
    _audio.playExplosion(isBoss: true); hapticHeavy();
    _ai.analyze(_player.build, _stage.stageNum); _audio.switchToAmbient();
    _finisherCamZoom = 1.0;
  }

  // ── PORTAL NODES ──────────────────────────────────────
  void _initPortalNodes() {
    if (_nodesInitialized) return; _nodesInitialized = true;
    final cx = _sw / 2, cy = _sh * 0.22, halfW = _sw * 0.18, halfH = _sh * 0.09;
    _portalNodes.clear();
    _portalNodes.addAll([PortalNode(x: cx - halfW, y: cy - halfH), PortalNode(x: cx + halfW, y: cy - halfH), PortalNode(x: cx - halfW, y: cy + halfH), PortalNode(x: cx + halfW, y: cy + halfH)]);
  }

  void _checkBulletsVsNodes() {
    if (_portalNodes.isEmpty) return;
    final rem = <Bullet>{};
    for (final bul in _bullets) {
      if (bul.isEnemy) continue;
      for (int i = 0; i < _portalNodes.length; i++) {
        final node = _portalNodes[i]; if (node.broken) continue;
        final dx = bul.x - node.x, dy = bul.y - node.y;
        if (dx * dx + dy * dy < (bul.isMissile ? 40 * 40 : 24 * 24)) { rem.add(bul); node.hp -= bul.isMissile ? 45 : 8; _spawnBurst(node.x, node.y, bul.isMissile ? Colors.orange : Colors.cyanAccent, bul.isMissile ? 20 : 5); if (node.hp <= 0) { node.hp = 0; node.broken = true; _onNodeBroken(i); } break; }
      }
    }
    _bullets.removeWhere((b) => rem.contains(b));
    if (_bossAlive && _boss != null) { final remB = <Bullet>{}; for (final bul in _bullets) { if (bul.isEnemy) continue; final bo = _boss!; if ((bul.x - bo.x).abs() < kBossR && (bul.y - bo.y).abs() < kBossR) { remB.add(bul); _glitchActive = true; _glitchT = 0.2; _spawnBurst(bo.x, bo.y, Colors.purpleAccent, 3); } } _bullets.removeWhere((b) => remB.contains(b)); }
    if (_portalNodes.every((n) => n.broken) && !_mirrorWin) { _mirrorWin = true; hapticHeavy(); _spawnBurst(_sw / 2, _sh * 0.22, Colors.cyanAccent, 60); _spawnBurst(_sw / 2, _sh * 0.22, Colors.white, 30); _addFloat(_sw / 2, _sh * 0.4, '★ PORTAL CERRADO ★', cGold); _audio.playExplosion(isBoss: true); _audio.switchToAmbient(); }
  }

  void _onNodeBroken(int index) {
    _timeScale = 0.3; Future.delayed(const Duration(milliseconds: 700), () { if (mounted && !_disposed) setState(() => _timeScale = 1.0); });
    _bossShakeIntensity = 12;
    if (index < _dopEnojado.length && _boss != null) { _addFloat(_boss!.x, _boss!.y - kBossR - 28, _dopEnojado[index], cRed); _glitchActive = true; _glitchT = 0.5; }
    if (_boss != null) _boss!.vx *= 1.2;
    final node = _portalNodes[index]; _spawnBurst(node.x, node.y, Colors.greenAccent, 25); _spawnBurst(node.x, node.y, Colors.white, 10);
    hapticHeavy(); _score += (_diff.scoreMult * 200).toInt();
  }

  void _fireMissile() {
    if (_missile == null || !_missile!.consume()) return;
    final py = _player.y - kPhoenixSize;
    _bullets.add(Bullet(_player.x, py, 90, angle: 0, isMissile: true, speed: 650));
    _spawnBurst(_player.x, py, Colors.orange, 10);
    _addFloat(_player.x, py - 30, '🚀 MISIL', Colors.orange);
    hapticHeavy();
  }

  void _update(double dt) {
    if (_disposed || !mounted) return;
    if (_paused) { setState(() {}); return; }

    // Boss dying épico
    if (_bossDying) {
      _bossDeathTimer += dt; _bossShakeIntensity *= 0.92;
      _bossShakeX = (_rng.nextDouble() - 0.5) * _bossShakeIntensity; _bossShakeY = (_rng.nextDouble() - 0.5) * _bossShakeIntensity;
      if (_rng.nextDouble() < 0.4 && _boss != null) { _particles.add(Particle(x: _boss!.x + (_rng.nextDouble() - 0.5) * 90, y: _boss!.y + (_rng.nextDouble() - 0.5) * 90, vx: (_rng.nextDouble() - 0.5) * 240, vy: (_rng.nextDouble() - 0.5) * 240, life: 0.6 + _rng.nextDouble() * 0.5, color: _rng.nextBool() ? Colors.orange : cFire, size: 3 + _rng.nextDouble() * 6)); }
      if (_bossDeathTimer > 0.3 && _timeScale < 1.0) _timeScale = (_timeScale + dt * 2.5).clamp(0, 1);
      _updateParticles(dt); _updateFloats(dt);
      if (_bossDeathTimer > 3.0) { _bossDying = false; _timeScale = 1.0; _bossShakeIntensity = 0; _resetPlayerForStage(); _stageClear(); }
      if (mounted) setState(() {}); return;
    }

    if (_mirrorWin) { _mirrorT += dt; _updateParticles(dt); _updateFloats(dt); if (_mirrorT > 3.5 && !_disposed) widget.onStageClear(_score, _player.build, _totalDmg); if (mounted) setState(() {}); return; }
    if (_quenching) { _quenchT += dt; _updateParticles(dt); if (_quenchT > 2.5 && !_disposed) widget.onGameOver(_score, _totalDmg); if (mounted) setState(() {}); return; }
    if (_frosting) { _frostT += dt * 0.55; _spawnFrost(); _updateParticles(dt); _updateFloats(dt); if (_frostT >= 1.0) { _frosting = false; _quenching = true; _audio.stopAlarm(); _audio.playQuench(); _quenchExp(); } if (mounted) setState(() {}); return; }
    if (_showDec) { if (mounted) setState(() {}); return; }

    // Finisher update
    if (_finisher.active) _updateFinisher(dt);

    // Stage 4 nodes
    if (_stage.stageNum == 4 && _bossAlive && !_nodesInitialized) { _initPortalNodes(); if (!_deniseMsgShown) { _deniseMsgShown = true; _showDeniseWarning = true; _deniseMsgTimer = 5.0; } }
    if (_showDeniseWarning) { _deniseMsgTimer -= dt; if (_deniseMsgTimer <= 0) _showDeniseWarning = false; }

    if (_upgradeFlash > 0) _upgradeFlash = (_upgradeFlash - dt * 2).clamp(0, 1);
    if (_tripleTimer > 0) { _tripleTimer -= dt; if (_tripleTimer <= 0) { _tripleTimer = 0; if (!_triplePermanent) { _player.build.hasTripleShot = false; _addFloat(_player.x, _sh * 0.72 - 40, 'TRIPLE EXPIRÓ', cGold); } } }

    _pulse += _pDir * dt * 2.2; if (_pulse > 1) _pDir = -1; if (_pulse < 0) _pDir = 1;
    _phase.update(dt, onDecision: _triggerDec, onBoss: _triggerBoss);
    _res.update(dt, _player.build); _player.energy = _res.energy;
    _heat.update(dt, _player.build, _diff);
    _missile?.update(dt);
    _ai.updateSpike(dt, _diff);
    if (_niFrame > 0) _niFrame = (_niFrame - dt).clamp(0, kNucleusIFrame);
    _mg.update(dt); _fr.update(dt);

    final mv = _touching ? (_touchX < _player.x ? MoveType.left : MoveType.right) : MoveType.idle;
    _tracker.add(mv); _profile.register(mv);
    _decayTimer -= dt; if (_decayTimer <= 0) { _decayTimer = 15.0; _profile.decay(); }

    if (_stage.stageNum == 4 && !_bossAlive && _phase.cycleCount >= 2) { if (_rng.nextDouble() < 0.003) { _glitchActive = true; _glitchT = 0.4; } }
    if (_glitchActive) { _glitchT -= dt; if (_glitchT <= 0) _glitchActive = false; }
    if (_stage.stageNum == 4 && _bossAlive && !_antiFinalTriggered && _profile.predictability() > 0.8) { _antiFinalTriggered = true; _glitchActive = true; _glitchT = 0.8; hapticHeavy(); if (_boss != null) _addFloat(_boss!.x, _boss!.y - kBossR - 30, 'Eres yo… pero sin evolución.', cRed); }

    if (_stage.hazard == StageHazard.gravityTimer && _gravActive) { _gravTimer -= dt; _gravWarn = _gravTimer < 30; if (_gravTimer <= 0) _beginFrost(); }
    if (_stage.hazard == StageHazard.mirrorPortal) { if (_bossAlive && !_mirrorWin) _portal = (_portal + dt * 0.003).clamp(0, 0.95); }
    if (_stage.hazard == StageHazard.asteroids) { _asteroidTimer -= dt; if (_asteroidTimer <= 0) { _asteroidTimer = 4 + _rng.nextDouble() * 4; _spawnAsteroid(2); } _updateAsteroids(dt); }

    // Alarma por heat
    if (_heat.zone == HeatZone.hot && !_alarmOn) { _alarmOn = true; _audio.startAlarm(); }
    else if (_heat.zone != HeatZone.hot && _alarmOn) { _alarmOn = false; _audio.stopAlarm(); }

    if (_player.shieldActive) { _player.shieldTimer -= dt; if (_player.shieldTimer <= 0) _player.shieldActive = false; }

    // Movimiento normal (fuera de Finisher)
    if (!_finisher.isChasing) {
      if (_touching) { _player.x += (_touchX - _player.x) * 14 * dt; _player.x = _player.x.clamp(kPhoenixSize, _sw - kPhoenixSize); }
    }

    // Disparo — con penalización progresiva de heat
    if (_touching && _res.energy > 0 && _heat.canShoot) {
      _shootTimer -= dt;
      if (_shootTimer <= 0) {
        final rate = (_mg.active ? _player.build.fireRate * 1.7 : _player.build.fireRate) * _heat.fireRatePenalty;
        final base = kBaseInterval / rate.clamp(0.3, 2.0);
        _shootTimer = base;
        _fireLaser();
      }
    }

    // Mover balas
    for (final b in _bullets) {
      if (b.isEnemy) { b.y += 360 * _diff.bulletSpeedMult * dt; }
      else if (b.isMissile) {
        if (_boss != null && _bossAlive) { final dx = _boss!.x - b.x; b.x += dx.sign * b.speed * dt * 0.4; b.y -= b.speed * dt; }
        else { b.y -= b.speed * dt; }
      } else {
        b.x += sin(b.angle) * b.speed * dt; b.y -= cos(b.angle) * b.speed * dt;
      }
    }
    _bullets.removeWhere((b) => b.y < -30 || b.y > _sh + 30 || b.x < -30 || b.x > _sw + 30);

    _puTimer -= dt; if (_puTimer <= 0) { _puTimer = _diff.powerUpInterval + _rng.nextDouble() * 10; _spawnPowerUp(); }
    _updatePowerUps(dt);

    if (_phase.phase == GamePhase.combat && !_bossAlive && !_finisher.active) { _spawnTimer -= dt; if (_spawnTimer <= 0) { _spawnTimer = _ai.spawnInterval(_phase.cycleCount, _stage.stageNum, _diff); for (int i = 0; i < _ai.waveSize(_phase.cycleCount, _stage.stageNum, _diff); i++) _spawnEnemy(); } }

    _updateEnemies(dt);
    if (_bossAlive && _boss != null && !_finisher.active) _updateBoss(dt);

    _bossShakeIntensity *= 0.88; _bossShakeX = (_rng.nextDouble() - 0.5) * _bossShakeIntensity; _bossShakeY = (_rng.nextDouble() - 0.5) * _bossShakeIntensity;

    _resolveCollisions();
    if (_stage.stageNum == 4 && _bossAlive && _nodesInitialized) _checkBulletsVsNodes();
    _coreTemp = (_coreTemp - 0.004 * dt).clamp(0, 1); if (_coreTemp >= 1.0 && !_frosting && !_quenching) _beginFrost();
    _updateParticles(dt); _updateFloats(dt); if (mounted) setState(() {});
  }

  void _fireLaser() {
    _res.applyShoot(_player.build);
    final isTriple = _player.build.hasTripleShot || _player.build.fireRate >= 1.8;
    // Triple en Comandante genera más heat
    _heat.applyShot(_player.build, _diff);
    if (isTriple && _diff.level == Difficulty.comandante) _heat.applyShot(_player.build, _diff);
    _audio.playLaser(triple: isTriple);
    final py = _player.y - kPhoenixSize;
    final heatAffectsAccuracy = _diff.level != Difficulty.amateur;
    final penalty = _heat.zone == HeatZone.hot && heatAffectsAccuracy ? (_rng.nextDouble() - 0.5) * 0.06 : 0.0;

    if (isTriple) {
      _bullets.add(Bullet(_player.x, py, _player.build.damage, angle: penalty));
      _bullets.add(Bullet(_player.x, py, _player.build.damage * 0.7, angle: -0.13 + penalty));
      _bullets.add(Bullet(_player.x, py, _player.build.damage * 0.7, angle: 0.13 + penalty));
    } else {
      _bullets.add(Bullet(_player.x, py, _player.build.damage, angle: penalty));
    }
  }

  void _spawnAsteroid(int level, {double? ox, double? oy, double? ovx, double? ovy}) { final r = level == 2 ? 18 + _rng.nextDouble() * 20 : level == 1 ? 10 + _rng.nextDouble() * 8 : 5 + _rng.nextDouble() * 5; _asteroids.add(Asteroid(x: ox ?? 20 + _rng.nextDouble() * (_sw - 40), y: oy ?? -r, vx: ovx ?? (_rng.nextBool() ? 1 : -1) * (20 + _rng.nextDouble() * 40) * _diff.enemySpeedMult, vy: ovy ?? (60 + _rng.nextDouble() * 50) * _diff.enemySpeedMult, r: r, level: level)); }
  void _splitAsteroid(Asteroid a) { if (a.level <= 0) return; final nextLevel = a.level - 1; final count = nextLevel == 1 ? 4 : 3; for (int i = 0; i < count; i++) { final ang = (pi * 2 / count) * i; final spd = nextLevel == 1 ? 55 + _rng.nextDouble() * 35 : 70 + _rng.nextDouble() * 40; _spawnAsteroid(nextLevel, ox: a.x, oy: a.y, ovx: cos(ang) * spd, ovy: sin(ang) * spd - 10); } }

  void _updateAsteroids(double dt) {
    for (final a in _asteroids) { if (a.dead) continue; a.x += a.vx * dt; a.y += a.vy * dt; a.angle += a.spin * dt; if (a.x < a.r || a.x > _sw - a.r) a.vx *= -1; final px = _player.x, py = _player.y; if ((a.x - px).abs() < a.r + kPhoenixSize * 0.8 && (a.y - py).abs() < a.r + kPhoenixSize * 0.8) { a.dead = true; if (!_player.shieldActive) { _res.energy -= 8; _coreTemp += 0.05; hapticMedium(); _spawnBurst(px, py, cFire, 10); _addFloat(px, py - 20, 'ASTEROIDE!', cFire); } else { hapticLight(); _audio.playShieldHit(); _spawnBurst(px, py, cShield, 6); } } final nx = _sw / 2, ny = _sh * 0.87; if ((a.x - nx).abs() < a.r + kNucleusR && (a.y - ny).abs() < a.r + kNucleusR) { a.dead = true; if (_niFrame <= 0) { _niFrame = kNucleusIFrame; _coreTemp += kCoreHeatPerHit * 1.5; hapticHeavy(); _addFloat(nx, ny - 20, 'NÚCLEO HIT!', cDanger); _spawnBurst(nx, ny, cDanger, 8); } } if (!a.dead) { for (final e in _enemies) { if (e.dead) continue; if ((a.x - e.x).abs() < a.r + kEnemyR * 0.7 && (a.y - e.y).abs() < a.r + kEnemyR * 0.7) { a.dead = true; e.hp -= 15; e.hitFlash = 0.8; _spawnBurst(a.x, a.y, Colors.grey, 6); _audio.playExplosion(isAsteroid: true); if (e.hp <= 0) { e.dead = true; _score += (_eScore(e.kind) ~/ 2 * _diff.scoreMult).toInt(); _spawnBurst(e.x, e.y, _eColor(e.kind), 10); _audio.playExplosion(); } break; } } } if (a.y > _sh + a.r) a.dead = true; }
    final remB = <Bullet>{}; for (final b in _bullets) { if (b.isEnemy) continue; for (final a in _asteroids) { if (a.dead) continue; if ((b.x - a.x).abs() < a.r && (b.y - a.y).abs() < a.r) { remB.add(b); _splitAsteroid(a); a.dead = true; final pts = a.level == 2 ? 30 : a.level == 1 ? 15 : 8; _score += (pts * _diff.scoreMult).toInt(); _spawnBurst(a.x, a.y, Colors.grey.shade400, a.level == 2 ? 12 : a.level == 1 ? 7 : 4); _addFloat(a.x, a.y - 10, '+$pts', Colors.grey.shade300); _audio.playExplosion(isAsteroid: true); break; } } }
    final remE = <Bullet>{}; for (final b in _bullets) { if (!b.isEnemy) continue; for (final a in _asteroids) { if (a.dead) continue; if ((b.x - a.x).abs() < a.r && (b.y - a.y).abs() < a.r) { remE.add(b); break; } } }
    _bullets.removeWhere((b) => remB.contains(b) || remE.contains(b)); _asteroids.removeWhere((a) => a.dead);
  }

  void _spawnPowerUp() { final av = [PowerUpKind.energyBoost]; final c = _phase.cycleCount; if (c >= 1) av.add(PowerUpKind.shield); if (c >= 2) av.add(PowerUpKind.rapidFire); if (c >= 3) av.add(PowerUpKind.coreArmor); if (c >= 4) av.add(PowerUpKind.tripleShot); _powerUps.add(PowerUp(20 + _rng.nextDouble() * (_sw - 40), -30, av[_rng.nextInt(av.length)])); }
  void _updatePowerUps(double dt) { for (final p in _powerUps) { p.y += 65 * dt; p.animT += dt * 3; if (!p.collected && (p.x - _player.x).abs() < 40 && (p.y - _player.y).abs() < 40) { p.collected = true; _applyPU(p.kind); hapticLight(); _spawnBurst(p.x, p.y, _puC(p.kind), 18); _addFloat(p.x, p.y - 10, _puL(p.kind), _puC(p.kind)); } } _powerUps.removeWhere((p) => p.y > _sh + 40 || p.collected); }
  void _applyPU(PowerUpKind k) { switch (k) { case PowerUpKind.rapidFire: _player.build.fireRate = (_player.build.fireRate * 1.3).clamp(1.0, 2.0); case PowerUpKind.tripleShot: _player.build.hasTripleShot = true; _tripleTimer = 12.0; _player.build.fireRate = (_player.build.fireRate * 1.1).clamp(1.0, 2.0); case PowerUpKind.shield: _player.shieldActive = true; _player.shieldTimer = 10.0; _audio.playShieldCharge(); case PowerUpKind.coreArmor: _coreTemp = (_coreTemp - 0.22).clamp(0, 1); _heat.cool(30); case PowerUpKind.energyBoost: _res.energy = (_res.energy + 35).clamp(0, _player.build.maxEnergy); _heat.cool(20); } }
  Color _puC(PowerUpKind k) => switch (k) { PowerUpKind.rapidFire => cFire, PowerUpKind.tripleShot => cGold, PowerUpKind.shield => cShield, PowerUpKind.coreArmor => cIce, PowerUpKind.energyBoost => cGreen };
  String _puL(PowerUpKind k) => switch (k) { PowerUpKind.rapidFire => '⚡ RAPID FIRE', PowerUpKind.tripleShot => '💥 TRIPLE SHOT', PowerUpKind.shield => '🛡 ESCUDO', PowerUpKind.coreArmor => '❄ CORE ARMOR', PowerUpKind.energyBoost => '💚 ENERGÍA' };

  void _spawnEnemy() {
    final c = _phase.cycleCount; final s = _stage.stageNum; final r = _rng.nextDouble(); EnemyKind k;
    if (c == 0 && s == 1) k = EnemyKind.interceptor; else if (c <= 1 && s <= 2) k = r < 0.55 ? EnemyKind.interceptor : EnemyKind.frigate; else if (c <= 2) k = r < 0.35 ? EnemyKind.interceptor : r < 0.65 ? EnemyKind.frigate : EnemyKind.parasite; else k = r < 0.28 ? EnemyKind.interceptor : r < 0.52 ? EnemyKind.frigate : r < 0.76 ? EnemyKind.parasite : EnemyKind.corrupter;
    final base = (18.0 + c * 5 + (s - 1) * 6) * _diff.enemyHpMult; final hp = k == EnemyKind.parasite ? base * 1.4 : k == EnemyKind.frigate ? base * 0.8 : base;
    final spd = _diff.enemySpeedMult;
    _enemies.add(Enemy(x: 20 + _rng.nextDouble() * (_sw - 40), y: -kEnemyR, hp: hp, vx: (_rng.nextBool() ? 1 : -1) * (50 + _rng.nextDouble() * 55 + (s - 1) * 8) * spd, vy: (65 + c * 4 + _rng.nextDouble() * 16 + (s - 1) * 5) * spd, kind: k));
  }

  void _updateEnemies(double dt) {
    for (final e in _enemies) {
      if (e.dead) continue; if (e.hitFlash > 0) e.hitFlash -= dt * 5; e.animT += dt * 2;
      switch (e.kind) {
        case EnemyKind.interceptor: e.x += e.vx * dt; e.y += e.vy * dt; if (e.x < kEnemyR || e.x > _sw - kEnemyR) e.vx *= -1;
          if (_diff.level != Difficulty.amateur && e.y > _sh * 0.3) { final leadX = _player.x - e.x; e.x += leadX.sign * 18 * _diff.enemySpeedMult * dt; }
        case EnemyKind.frigate: e.y = (e.y + e.vy * dt * 0.4).clamp(-kEnemyR, _sh * 0.25); e.x += e.vx * dt; if (e.x < kEnemyR || e.x > _sw - kEnemyR) e.vx *= -1; e.actionTimer += dt; if (e.actionTimer > 1.5 / _ai.counterFire / _diff.enemyFireRateMult) { e.actionTimer = 0; _bullets.add(Bullet(e.x, e.y + kEnemyR, 9 * _diff.bossBulletDmgMult, isEnemy: true)); }
        case EnemyKind.parasite: e.x += (_player.x - e.x).sign * 48 * _diff.enemySpeedMult * dt; e.y += e.vy * dt * 0.6; if ((e.x - _player.x).abs() < 40 && (e.y - _player.y).abs() < 40) { _res.energy -= 11 * dt; if (_rng.nextDouble() < 0.08) _particles.add(Particle(x: e.x, y: e.y, vx: (_player.x - e.x) * 1.5, vy: (_player.y - e.y) * 1.5, life: 0.4, color: cShield, size: 5)); }
        case EnemyKind.corrupter: e.x += e.vx * dt; e.y += e.vy * dt; if (e.x < kEnemyR || e.x > _sw - kEnemyR) e.vx *= -1; if (e.y > _sh * 0.65) { _heat.applyShot(_player.build, _diff); _addFloat(e.x, e.y, '+HEAT', cDanger); }
      }
      if (e.y > _sh * 0.87) { e.dead = true; _spawnBurst(e.x, e.y, cFire, 10); _audio.playExplosion(); if (!_player.shieldActive) { _coreTemp += kCoreHeatPerPass; hapticMedium(); _addFloat(_sw / 2, _sh * 0.84, 'NÚCLEO HIT', cDanger); } }
    }
    _enemies.removeWhere((e) => e.dead && e.hitFlash <= 0);
  }

  void _updateBoss(double dt) {
    final b = _boss!; if (b.dead) return; if (b.hitFlash > 0) b.hitFlash -= dt * 3; b.animT += dt;

    // CHECK FINISHER THRESHOLD
    if (!_finisherTriggered && _diff.hasFinisherMode && _stage.stageNum != 4 && b.hp / b.maxHp <= _diff.finisherThreshold && b.hp > 0) {
      _triggerFinisher();
      return;
    }

    if (b.phaseShieldActive) {
      b.phaseShieldTimer -= dt;
      if (b.phaseShieldTimer <= 0) { b.phaseShieldActive = false; b.state = BossState.vulnerable; b.vulnerableTimer = _diff.bossVulnerableWindow; _addFloat(b.x, b.y - kBossR - 20, '⚡ VULNERABLE — ¡ATACA!', cGold); _spawnBurst(b.x, b.y, Colors.yellow, 20); hapticHeavy(); }
    }
    if (b.state == BossState.vulnerable) {
      b.vulnerableTimer -= dt; b.y = _sh * 0.16 + sin(b.animT * 1.5) * 16; b.x += b.vx * dt * 0.5; if (b.x < kBossR || b.x > _sw - kBossR) b.vx *= -1;
      if (b.vulnerableTimer <= 0) { b.state = BossState.moving; b.stateTimer = 0; } return;
    }

    if (_stage.stageNum == 4) {
      b.x += b.vx * dt; b.y = _sh * 0.16 + sin(b.animT * 0.8) * 22; if (b.x < kBossR || b.x > _sw - kBossR) b.vx *= -1;
      b.burstTimer += dt; final brokenCount = _portalNodes.isEmpty ? 0 : _portalNodes.where((n) => n.broken).length; final interval = (1.8 - (brokenCount * 0.32)).clamp(0.45, 1.8); if (b.burstTimer >= interval) { b.burstTimer = 0; _fireBoss(b); } return;
    }

    final effectiveMoveTime = b.phaseShieldActive ? 1.5 : Boss.moveTime; final effectiveBurstLimit = b.phaseShieldActive ? 4 : 3;
    switch (b.state) {
      case BossState.moving: b.x += b.vx * dt; b.y = _sh * 0.16 + sin(b.animT * 0.8) * 24; if (b.x < kBossR || b.x > _sw - kBossR) b.vx *= -1; b.stateTimer += dt; if (b.stateTimer >= effectiveMoveTime) { b.state = BossState.charging; b.stateTimer = 0; b.chargeGlow = 0; }
      case BossState.charging: b.stateTimer += dt; b.chargeGlow = (b.stateTimer / Boss.chargeTime).clamp(0, 1); b.y = _sh * 0.16 + sin(b.animT * 12) * 3 * b.chargeGlow; if (b.stateTimer >= Boss.chargeTime) { b.state = BossState.firing; b.stateTimer = 0; b.burstCount = 0; b.burstTimer = 0; }
      case BossState.firing: b.burstTimer += dt; if (b.burstTimer >= 0.45 && b.burstCount < effectiveBurstLimit) { b.burstTimer = 0; b.burstCount++; _fireBoss(b); } if (b.burstCount >= effectiveBurstLimit) { b.state = BossState.cooldown; b.stateTimer = 0; }
      case BossState.cooldown: b.x += b.vx * dt; b.y = _sh * 0.16; if (b.x < kBossR || b.x > _sw - kBossR) b.vx *= -1; b.stateTimer += dt; b.chargeGlow = 0; if (b.stateTimer >= Boss.cooldownTime) { b.state = BossState.moving; b.stateTimer = 0; }
      case BossState.vulnerable: break;
      case BossState.fleeing: break; // handled by finisher
    }
  }

  void _fireBoss(Boss b) {
    final ba = atan2(_player.x - b.x, _sh * 0.5) * 0.35; const sp = 0.31;
    final dmg = (14 + (_stage.stageNum - 1) * 3) * _diff.bossBulletDmgMult;
    final bspd = 360 * _diff.bulletSpeedMult;

    if (_stage.stageNum == 4) {
      final predict = _profile.predictability(); double targetX = _player.x;
      if (_diff.level != Difficulty.amateur && predict > 0.5) { final dom = _profile.dominantMove(); final lead = _diff.level == Difficulty.comandante ? 70.0 : 45.0; if (dom == MoveType.right) targetX = (_player.x + lead * _diffMult).clamp(0, _sw); else if (dom == MoveType.left) targetX = (_player.x - lead * _diffMult).clamp(0, _sw); }
      final predAngle = atan2(targetX - b.x, _sh * 0.5) * 0.45;
      _bullets.add(Bullet(b.x, b.y + kBossR, 7 * _diff.bossBulletDmgMult, isEnemy: true, fromBoss: true, angle: predAngle, speed: bspd));
      final brokenCount = _portalNodes.isEmpty ? 0 : _portalNodes.where((n) => n.broken).length;
      if (brokenCount >= 2 || _diff.boss4TripleFromStart) { _bullets.add(Bullet(b.x, b.y + kBossR, 5 * _diff.bossBulletDmgMult, isEnemy: true, fromBoss: true, angle: predAngle - 0.22, speed: bspd)); _bullets.add(Bullet(b.x, b.y + kBossR, 5 * _diff.bossBulletDmgMult, isEnemy: true, fromBoss: true, angle: predAngle + 0.22, speed: bspd)); }
      if (!_antiPatternTriggered && _rng.nextDouble() < 0.25) { _antiPatternTriggered = true; final msg = predict > 0.75 ? 'Eres completamente predecible…' : predict > 0.5 ? 'Empiezo a entenderte…' : 'Con tecnología de museo…'; _addFloat(b.x, b.y - kBossR - 24, msg, cRed); _glitchActive = true; _glitchT = 0.5; Future.delayed(const Duration(seconds: 4), () { if (!_disposed) _antiPatternTriggered = false; }); }
      _diffMult = (_diffMult + 0.03).clamp(1.0, 2.0); return;
    }
    final offsets = _stage.stageNum >= 3 ? [0.0, -sp, sp, -sp * 0.5] : [0.0, -sp, sp];
    for (final off in offsets) _bullets.add(Bullet(b.x, b.y + kBossR, dmg, isEnemy: true, fromBoss: true, angle: ba + off, speed: bspd));
  }

  void _resolveCollisions() {
    final rem = <Bullet>{};
    for (final bul in _bullets) {
      if (bul.isEnemy) {
        final px = _player.x, py = _player.y;
        if ((bul.x - px).abs() < kPhoenixSize && (bul.y - py).abs() < kPhoenixSize) {
          rem.add(bul);
          if (_player.shieldActive) { _player.shieldActive = false; hapticLight(); _audio.playShieldHit(); _spawnBurst(px, py, cShield, 8); _addFloat(px, py - 20, 'ESCUDO!', cShield); }
          else { _res.energy -= bul.fromBoss ? 11 : 13; _heat.applyShot(_player.build, _diff); _coreTemp += bul.fromBoss ? 0.032 : 0.042; hapticMedium(); _spawnBurst(px, py, cDanger, 8); _addFloat(px, py - 20, '-E', cDanger); }
        }
        final nx = _sw / 2, ny = _sh * 0.87;
        if (_niFrame <= 0 && (bul.x - nx).abs() < kNucleusR && (bul.y - ny).abs() < kNucleusR) { rem.add(bul); _niFrame = kNucleusIFrame; _coreTemp += bul.fromBoss ? 0.055 : kCoreHeatPerHit; hapticHeavy(); _addFloat(nx, ny - 20, 'NÚCLEO!', cDanger); _spawnBurst(nx, ny, cDanger, 6); }
        else if (_niFrame > 0 && (bul.x - nx).abs() < kNucleusR && (bul.y - ny).abs() < kNucleusR) { rem.add(bul); _spawnBurst(bul.x, bul.y, cShield.withOpacity(0.5), 4); }
      } else {
        if (_stage.stageNum == 4 && _bossAlive) continue;
        if (_finisher.active && _boss != null) {
          // En Finisher — balas van al boss directamente
          final bo = _boss!;
          if ((bul.x - bo.x).abs() < kBossR && (bul.y - bo.y).abs() < kBossR) {
            rem.add(bul); final dmg = _fr.active ? bul.damage * 1.5 : bul.damage; bo.hp -= dmg; bo.hitFlash = 1.0; _score += 8; _totalDmg += dmg.toInt();
            if (bo.hp <= 0) { _triggerBossDeath(); }
          }
          continue;
        }
        bool hit = false;
        for (final e in _enemies) { if (e.dead || hit) continue; if ((bul.x - e.x).abs() < kEnemyR && (bul.y - e.y).abs() < kEnemyR) { rem.add(bul); hit = true; final dmg = _fr.active ? bul.damage * 1.6 : bul.damage; e.hp -= dmg; e.hitFlash = 1.0; _totalDmg += dmg.toInt(); if (e.hp <= 0) { e.dead = true; _score += (_eScore(e.kind) * _diff.scoreMult).toInt(); _spawnBurst(e.x, e.y, _eColor(e.kind), 16); _audio.playExplosion(); _addFloat(e.x, e.y - 10, '+${(_eScore(e.kind) * _diff.scoreMult).toInt()}', cGold); } } }
        if (!hit && _bossAlive && _boss != null && !_boss!.dead) {
          final bo = _boss!;
          if ((bul.x - bo.x).abs() < kBossR && (bul.y - bo.y).abs() < kBossR) {
            rem.add(bul);
            final inShield = bo.phaseShieldActive; final inVulnerable = bo.state == BossState.vulnerable;
            final dmgMult = inShield ? 0.25 : inVulnerable ? 2.0 : 1.0;
            final actualDmg = (_fr.active ? bul.damage * 1.5 : bul.damage) * dmgMult;
            bo.hp -= actualDmg; bo.hitFlash = 1.0; _score += inVulnerable ? 12 : (_fr.active ? 7 : 5); _totalDmg += actualDmg.toInt();
            if (inShield) _spawnBurst(bo.x, bo.y, cShield.withOpacity(0.4), 4);
            if (inVulnerable) _spawnBurst(bo.x, bo.y, cGold.withOpacity(0.6), 6);
            // Misil rompe escudo
            if (inShield && bul.isMissile) { bo.phaseShieldActive = false; bo.state = BossState.vulnerable; bo.vulnerableTimer = _diff.bossVulnerableWindow; _addFloat(bo.x, bo.y - kBossR - 20, '💥 MISIL ROMPE ESCUDO', Colors.orange); }
            // FIX CRASH: verificar que no esté muerto antes de activar fase
            if (_stage.stageNum == 1 && !bo.phaseTriggered && bo.hp / bo.maxHp <= 0.5 && bo.hp > 0) {
              bo.phaseTriggered = true; bo.phaseShieldActive = true; bo.phaseShieldTimer = _diff.bossShieldDuration;
              _addFloat(bo.x, bo.y - kBossR - 20, '⚡ ESCUDO ACTIVO', cShield); _spawnBurst(bo.x, bo.y, cShield, 30); hapticHeavy();
            }
            // Finisher threshold check
            if (!_finisherTriggered && bo.hp / bo.maxHp <= _diff.finisherThreshold && bo.hp > 0 && _stage.stageNum != 4) {
              _triggerFinisher();
            } else if (bo.hp <= 0 && !_bossDying && !_finisher.active) {
              _triggerBossDeath();
            }
          }
        }
      }
    }
    _bullets.removeWhere((b) => rem.contains(b));
  }

  int _eScore(EnemyKind k) => switch (k) { EnemyKind.interceptor => 100, EnemyKind.frigate => 150, EnemyKind.parasite => 200, EnemyKind.corrupter => 175 };
  Color _eColor(EnemyKind k) => switch (k) { EnemyKind.interceptor => cWarlord, EnemyKind.frigate => cGreen, EnemyKind.parasite => cShield, EnemyKind.corrupter => const Color(0xFFFF6600) };
  void _triggerDec() { _ai.analyze(_player.build, _stage.stageNum); _opts = _buildOpts(); _showDec = true; }
  void _triggerBoss() {
    _enemies.clear();
    // FIX CRASH: HP nunca 0 al crear boss
    final hp = ((_stage.bossHpBase + _phase.cycleCount * _stage.bossHpPerCycle) * _diff.bossHpMult).clamp(50.0, 99999.0);
    _boss = Boss(x: _sw / 2, y: _sh * 0.16, hp: hp);
    _bossAlive = true; _audio.switchToBoss();
    if (_stage.hazard == StageHazard.gravityTimer) { _gravActive = true; _gravTimer = _diff.gravTimerSeconds; }
    _addFloat(_sw / 2, _sh * 0.3, '⚠ ${_stage.bossName}', _stage.bossColor);
  }
  void _stageClear() { _audio.stopAlarm(); _phase.endBoss(); if (mounted && !_disposed) widget.onStageClear(_score, _player.build, _totalDmg); }
  void _resetPlayerForStage() {
    _player.build.hasTripleShot = false; _triplePermanent = false; _player.build.fireRate = _player.build.fireRate.clamp(1.0, 1.4); _tripleTimer = 0;
    _boss = null; _bossAlive = false; _bossDying = false; _bossDeathTimer = 0;
    _bullets.clear(); _asteroids.clear(); _enemies.clear(); _portalNodes.clear(); _nodesInitialized = false;
    _tripleGuaranteedUsed = false; _gravTimer = _diff.gravTimerSeconds; _heat.heat = 0; _heat.isOverheated = false;
    _finisher.phase = FinisherPhase.none; _finisherTriggered = false; _finisherCamZoom = 1.0;
    _player.y = _sh * 0.72; // reset Y al modo normal
  }
  void _beginFrost() { if (_frosting || _quenching) return; _frosting = true; _coreTemp = 1.0; _audio.stopAlarm(); }
  void _quenchExp() { for (int i = 0; i < 80; i++) { final a = _rng.nextDouble() * pi * 2; final s = 100 + _rng.nextDouble() * 320; _particles.add(Particle(x: _sw / 2, y: _sh * 0.87, vx: cos(a) * s, vy: sin(a) * s, life: 1.2 + _rng.nextDouble(), color: _rng.nextBool() ? cFire : cIce, size: 5 + _rng.nextDouble() * 12)); } }
  void _spawnFrost() { if (_rng.nextDouble() > 0.3) return; final a = _rng.nextDouble() * pi * 2; final r = kNucleusR + _rng.nextDouble() * 60; _particles.add(Particle(x: _sw / 2 + cos(a) * r, y: _sh * 0.87 + sin(a) * r, vx: cos(a + pi) * 40, vy: sin(a + pi) * 40, life: 0.8 + _rng.nextDouble() * 0.6, color: cFrost, size: 3 + _rng.nextDouble() * 6, isFrost: true)); }

  void _selectUpg(UpgradeOption o) { o.apply(_player.build); _res.energy = (_res.energy + 20).clamp(0, _player.build.maxEnergy); _heat.cool(12); _upgradeFlash = 1.0; _upgradeFlashColor = o.color; _showDec = false; _phase.endDecision(); if (!_bossAlive && _phase.cycleCount >= 3) _stageClear(); }

  List<UpgradeOption> _buildOpts() {
    final forceTriple = _diff.tripleGuaranteed && _stage.stageNum >= 3 && !_player.build.hasTripleShot && !_tripleGuaranteedUsed;
    final isComandante = _diff.level == Difficulty.comandante;
    final standard = [
      UpgradeOption(title: 'Plasma Overload', description: '+40% daño — balas más destructivas', emoji: '🔥', color: cFire, apply: (b) => b.damage *= 1.4),
      UpgradeOption(title: 'Cryo Stabilizer', description: 'Enfriamiento +80% — heat baja rápido', emoji: '❄️', color: cIce, apply: (b) { b.cooling *= 1.8; _heat.cool(35); }),
      UpgradeOption(title: 'Void Pulse', description: 'Cadencia +25%', emoji: '⚡', color: cGold, apply: (b) => b.fireRate = (b.fireRate * 1.25).clamp(1, 2.0)),
      UpgradeOption(title: 'Energy Core', description: 'Energía máxima +30', emoji: '💙', color: cIce, apply: (b) { b.maxEnergy += 30; _res.energy = (_res.energy + 30).clamp(0, b.maxEnergy); }),
      UpgradeOption(title: 'Phoenix Shield', description: 'Escudo activo 12 segundos', emoji: '🛡️', color: cShield, apply: (b) { _player.shieldActive = true; _player.shieldTimer = 12.0; _audio.playShieldCharge(); }),
      UpgradeOption(title: 'Triple Cannon', description: 'Disparo TRIPLE permanente', emoji: '💥', color: cFire, apply: (b) { b.hasTripleShot = true; _triplePermanent = true; _tripleTimer = 0; b.fireRate = (b.fireRate * 1.1).clamp(1, 2.0); _tripleGuaranteedUsed = true; }),
      UpgradeOption(title: 'Core Armor', description: 'Enfría el núcleo 35%', emoji: '🔮', color: cShield, apply: (b) { _coreTemp = (_coreTemp - 0.35).clamp(0, 1); _heat.cool(30); }),
      UpgradeOption(title: 'Phoenix Overdrive', description: '+25% daño y +15% cadencia', emoji: '🦅', color: cGold, apply: (b) { b.damage *= 1.25; b.fireRate = (b.fireRate * 1.15).clamp(1, 2.0); }),
    ];
    final tradeoffs = [
      UpgradeOption(title: 'Plasma Burst', description: '+60% daño', tradeoff: '⚠ +40% generación de heat', emoji: '🔥', color: cFire, hasTradeoff: true, apply: (b) { b.damage *= 1.6; b.heatGenMult *= 1.4; }),
      UpgradeOption(title: 'Cryo Overdrive', description: 'Enfriamiento +120%', tradeoff: '⚠ -15% daño', emoji: '❄️', color: cIce, hasTradeoff: true, apply: (b) { b.cooling *= 2.2; b.damage *= 0.85; _heat.cool(40); }),
      UpgradeOption(title: 'Rapid Instability', description: 'Cadencia +35%', tradeoff: '⚠ +20% heat por disparo', emoji: '⚡', color: cGold, hasTradeoff: true, apply: (b) { b.fireRate = (b.fireRate * 1.35).clamp(1, 2.0); b.heatGenMult *= 1.2; }),
      UpgradeOption(title: 'Berserker Mode', description: '+50% daño y cadencia', tradeoff: '⚠ +80% heat por disparo', emoji: '🔴', color: cRed, hasTradeoff: true, apply: (b) { b.damage *= 1.5; b.fireRate = (b.fireRate * 1.2).clamp(1, 2.0); b.heatGenMult *= 1.8; }),
      UpgradeOption(title: 'Thermal Shield', description: 'Escudo 15s + -50% heat', tradeoff: '⚠ -20% daño durante el escudo', emoji: '🛡️', color: cShield, hasTradeoff: true, apply: (b) { _player.shieldActive = true; _player.shieldTimer = 15.0; _heat.cool(50); b.damage *= 0.8; _audio.playShieldCharge(); }),
      UpgradeOption(title: 'Triple Cannon+', description: 'Triple PERMANENTE', tradeoff: '⚠ +30% heat por disparo', emoji: '💥', color: cFire, hasTradeoff: true, apply: (b) { b.hasTripleShot = true; _triplePermanent = true; _tripleTimer = 0; b.heatGenMult *= 1.3; _tripleGuaranteedUsed = true; }),
      UpgradeOption(title: 'Core Armor+', description: 'Enfría núcleo 50%', tradeoff: '⚠ -10% daño permanente', emoji: '🔮', color: cShield, hasTradeoff: true, apply: (b) { _coreTemp = (_coreTemp - 0.5).clamp(0, 1); _heat.cool(40); b.damage *= 0.9; }),
      UpgradeOption(title: 'Overdrive+', description: '+30% daño y cadencia', tradeoff: '⚠ +25% heat por disparo', emoji: '🦅', color: cGold, hasTradeoff: true, apply: (b) { b.damage *= 1.3; b.fireRate = (b.fireRate * 1.2).clamp(1, 2.0); b.heatGenMult *= 1.25; }),
    ];
    final pool = isComandante ? tradeoffs : standard;
    if (forceTriple && !isComandante) { final t = standard.firstWhere((o) => o.title == 'Triple Cannon'); final rest = standard.where((o) => o.title != 'Triple Cannon').toList()..shuffle(_rng); return [t, ...rest.take(2)]; }
    if (forceTriple && isComandante) { final t = tradeoffs.firstWhere((o) => o.title == 'Triple Cannon+'); final rest = tradeoffs.where((o) => o.title != 'Triple Cannon+').toList()..shuffle(_rng); return [t, ...rest.take(2)]; }
    pool.shuffle(_rng); return pool.take(3).toList();
  }

  void _spawnBurst(double x, double y, Color c, int n) { for (int i = 0; i < n; i++) { final a = _rng.nextDouble() * pi * 2; final s = 40 + _rng.nextDouble() * 200; _particles.add(Particle(x: x, y: y, vx: cos(a) * s, vy: sin(a) * s, life: 0.3 + _rng.nextDouble() * 0.6, color: c, size: 2 + _rng.nextDouble() * 6)); } }
  void _addFloat(double x, double y, String t, Color c) => _floats.add(FloatingText(x, y, t, c));
  void _updateParticles(double dt) { for (final p in _particles) { p.x += p.vx * dt; p.y += p.vy * dt; if (!p.isFrost) p.vy += 40 * dt; p.life -= dt; } _particles.removeWhere((p) => p.life <= 0); }
  void _updateFloats(double dt) { for (final f in _floats) { f.y -= 55 * dt; f.life -= dt * 1.5; } _floats.removeWhere((f) => f.life <= 0); }

  // Gestos — normales o joystick Finisher
  void _onPS(DragStartDetails d) {
    if (_finisher.isChasing) { _joystickOrigin = d.localPosition; _joystickDelta = Offset.zero; }
    else { _touching = true; _touchX = d.localPosition.dx; }
  }
  void _onPU(DragUpdateDetails d) {
    if (_finisher.isChasing && _joystickOrigin != null) {
      final delta = d.localPosition - _joystickOrigin!;
      final mag = delta.distance.clamp(0, 60);
      _joystickDelta = mag > 5 ? delta / delta.distance : Offset.zero;
    } else { _touchX = d.localPosition.dx; }
  }
  void _onPE(DragEndDetails _) { _touching = false; _joystickOrigin = null; _joystickDelta = Offset.zero; }
  void _onTD(TapDownDetails d) { if (!_finisher.isChasing) { _touching = true; _touchX = d.localPosition.dx; } }
  void _onTU(TapUpDetails _) { _touching = false; }
  void _onTap(bool mg) { if (mg && _mg.ready) _mg.consume(); else if (!mg && _fr.ready) _fr.consume(); }

  @override Widget build(BuildContext ctx) {
    final sz = MediaQuery.of(ctx).size; _sw = sz.width; _sh = sz.height;
    final lc = Color.lerp(cIce, cGold, (_player.build.fireRate - 1.0).clamp(0, 1))!;
    final isTriple = _player.build.hasTripleShot || _player.build.fireRate >= 1.8;
    final brokenCount = _portalNodes.isEmpty ? 0 : _portalNodes.where((n) => n.broken).length;
    final playerY = _finisher.isChasing ? _player.y : _sh * 0.72;

    return Scaffold(backgroundColor: cBg, body: Stack(children: [
      GestureDetector(onPanStart: _onPS, onPanUpdate: _onPU, onPanEnd: _onPE, onTapDown: _onTD, onTapUp: _onTU,
        child: CustomPaint(painter: GamePainter(sw: _sw, sh: _sh, player: _player, playerY: playerY, enemies: _enemies, bullets: _bullets, powerUps: _powerUps, boss: (_bossAlive || _bossDying || _finisher.active) ? _boss : null, particles: _particles, floats: _floats, score: _score, res: _res, heat: _heat, phase: _phase, coreTemp: _coreTemp, corePulse: _pulse, laserColor: lc, isTriple: isTriple, frosting: _frosting, frostT: _frostT, quenching: _quenching, quenchT: _quenchT, touching: _touching, sprites: _spr, nucleusIFrame: _niFrame, freezeActive: _fr.active, machineGunActive: _mg.active, stageNum: _stage.stageNum, bossColor: _stage.bossColor, asteroids: _asteroids, gravityTimer: _gravActive ? _gravTimer : -1, portalGrow: _stage.hazard == StageHazard.mirrorPortal ? _portal : -1, mirrorVictory: _mirrorWin, mirrorVictoryT: _mirrorT, stageName: _stage.name, glitchActive: _glitchActive || _bossDying, paused: _paused, bossShakeX: _bossShakeX, bossShakeY: _bossShakeY, bossDying: _bossDying, portalNodes: _portalNodes, upgradeFlash: _upgradeFlash, upgradeFlashColor: _upgradeFlashColor, diff: _diff, finisher: _finisher, camZoom: _finisherCamZoom), child: const SizedBox.expand())),

      // Badge dificultad
      Positioned(top: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _diff.color.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: _diff.color.withOpacity(0.6))), child: Text('${_diff.emoji} ${_diff.name}', style: TextStyle(color: _diff.color, fontSize: 9, fontFamily: 'Orbitron', fontWeight: FontWeight.bold)))),

      // Pausa
      Positioned(top: 8, right: 8, child: GestureDetector(onTap: () { setState(() => _paused = !_paused); hapticLight(); }, child: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle, border: Border.all(color: Colors.white24)), child: Icon(_paused ? Icons.play_arrow : Icons.pause, color: Colors.white60, size: 22)))),

      // Misil
      if (_diff.hasMissile && _missile != null)
        Positioned(right: 8, top: _sh * 0.28, child: GestureDetector(onTap: _fireMissile, child: Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8), border: Border.all(color: _missile!.ready ? Colors.orange : Colors.white24, width: _missile!.ready ? 2 : 1)), child: CustomPaint(painter: _MissilePainter(fraction: _missile!.fraction, ready: _missile!.ready))))),

      // Charge rings
      Positioned(right: 8, top: _sh * 0.42, child: Column(children: [_ChargeRing(indicator: _mg, onTap: () => _onTap(true)), const SizedBox(height: 12), _ChargeRing(indicator: _fr, onTap: () => _onTap(false))])),

      // Finisher Mode UI
      if (_finisher.phase == FinisherPhase.chasing) ...[
        // Joystick visual
        if (_joystickOrigin != null) Positioned(left: _joystickOrigin!.dx - 40, top: _joystickOrigin!.dy - 40, child: Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08), border: Border.all(color: Colors.orange.withOpacity(0.5), width: 2)))),
        // Label Finisher
        Positioned(top: _sh * 0.12, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange, width: 2)), child: const Text('🎯 FINISHER MODE — ¡PERSÍGUELO!', style: TextStyle(color: Colors.orange, fontSize: 12, fontFamily: 'Orbitron', fontWeight: FontWeight.bold))))),
      ],
      if (_finisher.phase == FinisherPhase.fleeing)
        Positioned(top: _sh * 0.35, left: 0, right: 0, child: Center(child: _GlowText('⚡ ¡HUYE — PREPÁRATE!', color: cGold, size: 16))),

      // Overheat overlay
      if (_heat.isOverheated) Positioned.fill(child: IgnorePointer(child: Container(color: cRed.withOpacity(0.08)))),
      if (_heat.isOverheated) Positioned(top: _sh * 0.28, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(8), border: Border.all(color: cRed, width: 2)), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('🔥 SOBRECALENTAMIENTO 🔥', style: TextStyle(color: cRed, fontSize: 12, fontFamily: 'Orbitron', fontWeight: FontWeight.bold)), Text('BLOQUEADO ${_heat.overheatTimer.toStringAsFixed(1)}s', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Orbitron'))])))),

      if (_paused) Container(color: Colors.black.withOpacity(0.75), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [_GlowText('PAUSA', color: cGold, size: 38), const SizedBox(height: 8), Text('${_diff.emoji} ${_diff.name}', style: TextStyle(color: _diff.color, fontSize: 12, fontFamily: 'Orbitron')), const SizedBox(height: 32), _Btn(label: 'REANUDAR', color: cIce, onTap: () { setState(() => _paused = false); }), const SizedBox(height: 16)]))),
      if (_showDec) _DecisionOverlay(options: _opts, cycle: _phase.cycleCount, stageNum: _stage.stageNum, diff: _diff, onSelect: _selectUpg),
      if (_phase.phase == GamePhase.boss && _bossAlive && !_finisher.active) Positioned(top: 52, left: 0, right: 0, child: Center(child: _GlowText('⚠ ${_stage.bossName} ⚠', color: _stage.bossColor, size: 13))),
      if (_boss != null && _boss!.state == BossState.vulnerable && _bossAlive && !_finisher.active) Positioned(top: 70, left: 0, right: 0, child: Center(child: _GlowText('⚡ VULNERABLE — ¡ATACA AHORA!', color: cGold, size: 12))),
      if (isTriple) Positioned(bottom: _sh * 0.14, right: 60, child: _GlowText(_tripleTimer > 0 ? '💥 TRIPLE ${_tripleTimer.toStringAsFixed(0)}s' : '💥 TRIPLE PERM', color: cGold, size: 11)),
      if (_bossDying) Positioned.fill(child: Container(color: Colors.black.withOpacity(0.25))),
      if (_mg.active) Positioned(bottom: _sh * 0.16, left: 20, child: _GlowText('⚡ RÁFAGA ${_mg.activeTimer.toStringAsFixed(1)}s', color: cGold, size: 11)),
      if (_fr.active) Positioned(bottom: _sh * 0.18, left: 20, child: _GlowText('❄ FREEZE ${_fr.activeTimer.toStringAsFixed(1)}s', color: cIce, size: 11)),
      if (_gravWarn) Positioned(top: _sh * 0.3, left: 0, right: 0, child: Center(child: _GlowText('⚠ GRAVEDAD: ${_gravTimer.toInt()}s', color: cDanger, size: 16))),
      if (_stage.stageNum == 4 && _bossAlive) Positioned(bottom: _sh * 0.22, left: 20, right: 20, child: Column(children: [_GlowText('NODOS: $brokenCount/4', color: brokenCount == 4 ? Colors.greenAccent : cRed, size: 13), const SizedBox(height: 4), Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(4, (i) { final broken = _portalNodes.isEmpty ? false : _portalNodes[i].broken; return Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Icon(broken ? Icons.circle : Icons.circle_outlined, color: broken ? Colors.greenAccent : Colors.white38, size: 14)); }))])),
      if (_showDeniseWarning) Positioned(bottom: _sh * 0.30, left: 16, right: 16, child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.black.withOpacity(0.88), borderRadius: BorderRadius.circular(10), border: Border.all(color: cIce, width: 1.5), boxShadow: [BoxShadow(color: cIce.withOpacity(0.3), blurRadius: 18)]), child: Row(children: [Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: cIce, width: 2), color: Colors.blue.shade900), child: const Center(child: Text('D', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))), const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Dra. Denise Moreau', style: TextStyle(color: cIce, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')), SizedBox(height: 4), Text('¡Phoenix!\n¡No puedes dañarlo!\n¡Dispara los 4 NODOS!', style: TextStyle(color: Colors.white, fontSize: 11, height: 1.4))]))]))),
    ]));
  }
}

// ── MISSILE PAINTER ──────────────────────────────────────
class _MissilePainter extends CustomPainter {
  final double fraction; final bool ready;
  const _MissilePainter({required this.fraction, required this.ready});
  @override void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2, r = size.width / 2 - 4;
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = Colors.white12..style = PaintingStyle.stroke..strokeWidth = 2);
    if (fraction > 0) canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), -pi / 2, pi * 2 * fraction, false, Paint()..color = ready ? Colors.orange : Colors.orange.withOpacity(0.6)..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round);
    if (ready) canvas.drawCircle(Offset(cx, cy), r * 0.65, Paint()..color = Colors.orange.withOpacity(0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    final tp = TextPainter(text: TextSpan(text: '🚀', style: TextStyle(fontSize: 20, color: ready ? Colors.orange : Colors.white38)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }
  @override bool shouldRepaint(_MissilePainter old) => old.fraction != fraction || old.ready != ready;
}

// ══════════════════════════════════════════════════════════
// GAME PAINTER
// ══════════════════════════════════════════════════════════
class GamePainter extends CustomPainter {
  final double sw, sh, coreTemp, corePulse, frostT, quenchT, nucleusIFrame, gravityTimer, portalGrow, mirrorVictoryT, upgradeFlash, playerY, camZoom;
  final bool frosting, quenching, touching, isTriple, freezeActive, machineGunActive, mirrorVictory, glitchActive, paused, bossDying;
  final double bossShakeX, bossShakeY; final Color laserColor, bossColor, upgradeFlashColor; final int stageNum; final String stageName;
  final Player player; final List<Enemy> enemies; final List<Bullet> bullets; final List<PowerUp> powerUps;
  final List<Asteroid> asteroids; final Boss? boss; final List<Particle> particles; final List<FloatingText> floats;
  final int score; final ResourceSystem res; final HeatSystem heat; final PhaseEngine phase; final SpriteCache sprites; final List<PortalNode> portalNodes; final DifficultyConfig diff; final FinisherState finisher;
  const GamePainter({required this.sw, required this.sh, required this.player, required this.playerY, required this.enemies, required this.bullets, required this.powerUps, required this.boss, required this.particles, required this.floats, required this.score, required this.res, required this.heat, required this.phase, required this.coreTemp, required this.corePulse, required this.laserColor, required this.isTriple, required this.frosting, required this.frostT, required this.quenching, required this.quenchT, required this.touching, required this.sprites, required this.nucleusIFrame, required this.freezeActive, required this.machineGunActive, required this.stageNum, required this.bossColor, required this.asteroids, required this.gravityTimer, required this.portalGrow, required this.mirrorVictory, required this.mirrorVictoryT, required this.stageName, required this.glitchActive, required this.paused, required this.bossShakeX, required this.bossShakeY, required this.bossDying, required this.portalNodes, required this.upgradeFlash, required this.upgradeFlashColor, required this.diff, required this.finisher, required this.camZoom});

  @override void paint(Canvas canvas, Size size) {
    canvas.save();
    // Camera zoom para Finisher Mode
    if (camZoom != 1.0) { canvas.translate(sw / 2, sh / 2); canvas.scale(camZoom); canvas.translate(-sw / 2, -sh / 2); }
    canvas.translate(bossShakeX, bossShakeY);
    if (glitchActive) { canvas.save(); canvas.translate((Random().nextDouble() - 0.5) * 8, 0); }
    _bg(canvas); if (portalGrow > 0) _portal(canvas);
    _drawNucleus(canvas); _drawPowerUps(canvas); _drawAsteroids(canvas); _drawEnemies(canvas);
    if (boss != null) _drawBoss(canvas, boss!);
    if (stageNum == 4 && portalNodes.isNotEmpty) _drawPortalNodes(canvas);
    _drawBullets(canvas); _drawPhoenix(canvas, playerY); _drawParticles(canvas); _drawFloats(canvas); _drawHUD(canvas);
    if (frosting) _drawFrost(canvas); if (quenching) _drawQuench(canvas); if (mirrorVictory) _drawMirrorWin(canvas); if (bossDying) _drawBossDeathOverlay(canvas);
    // Finisher flash naranja
    if (finisher.phase == FinisherPhase.chasing) canvas.drawRect(Rect.fromLTWH(0, 0, sw, sh), Paint()..color = Colors.orange.withOpacity(0.04));
    if (upgradeFlash > 0) canvas.drawRect(Rect.fromLTWH(0, 0, sw, sh), Paint()..color = upgradeFlashColor.withOpacity(upgradeFlash * 0.28));
    if (glitchActive) { canvas.restore(); for (int i = 0; i < sh.toInt(); i += 6) { canvas.drawRect(Rect.fromLTWH(0, i.toDouble(), sw, 2), Paint()..color = cRed.withOpacity(0.06)); } canvas.drawRect(Rect.fromLTWH(0, 0, sw, sh), Paint()..color = cRed.withOpacity(0.08)); }
    canvas.restore();
  }

  void _drawPortalNodes(Canvas canvas) {
    if (portalNodes.length == 4) { final lp = Paint()..color = Colors.purpleAccent.withOpacity(0.2)..strokeWidth = 1..style = PaintingStyle.stroke; final corners = [Offset(portalNodes[0].x, portalNodes[0].y), Offset(portalNodes[1].x, portalNodes[1].y), Offset(portalNodes[3].x, portalNodes[3].y), Offset(portalNodes[2].x, portalNodes[2].y)]; for (int i = 0; i < 4; i++) canvas.drawLine(corners[i], corners[(i + 1) % 4], lp); }
    for (final node in portalNodes) { final c = node.color; canvas.drawCircle(Offset(node.x, node.y), 28, Paint()..color = c.withOpacity(0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)); canvas.drawCircle(Offset(node.x, node.y), 22, Paint()..color = c.withOpacity(0.15)); canvas.drawCircle(Offset(node.x, node.y), 22, Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = node.broken ? 3 : 2); if (node.broken) { final tp = TextPainter(text: const TextSpan(text: '✓', style: TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout(); tp.paint(canvas, Offset(node.x - tp.width / 2, node.y - tp.height / 2)); } else { final barW = 44.0, barH = 5.0, barX = node.x - 22, barY = node.y + 26; canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(barX, barY, barW, barH), const Radius.circular(3)), Paint()..color = Colors.white12); final frac = (node.hp / 100).clamp(0.0, 1.0); canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(barX, barY, barW * frac, barH), const Radius.circular(3)), Paint()..color = c); } }
  }

  void _drawBossDeathOverlay(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, sw, sh), Paint()..shader = RadialGradient(center: Alignment.center, radius: 0.7, colors: [Colors.transparent, Colors.orange.withOpacity(0.22)], stops: const [0.5, 1.0]).createShader(Rect.fromLTWH(0, 0, sw, sh)));
    final label = finisher.active ? '★ FINISHER KILL ★' : '★  ELIMINADO  ★';
    final c = finisher.active ? Colors.orange : cGold;
    _txt(canvas, label, Offset(sw / 2, sh * 0.35), c, 22);
  }

  void _bg(Canvas canvas) { final sa = switch (stageNum) { 2 => const Color(0xFF001A00), 3 => const Color(0xFF0A001A), 4 => const Color(0xFF1A0000), _ => const Color(0xFF001022) }; final finisherTint = finisher.isChasing ? Color.lerp(sa, Colors.orange.withOpacity(0.1), 0.3)! : sa; final danger = coreTemp > 0.5 ? Color.lerp(finisherTint, const Color(0xFF200008), (coreTemp - 0.5) * 2)! : finisherTint; canvas.drawRect(Rect.fromLTWH(0, 0, sw, sh), Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFF000814), finisherTint, danger]).createShader(Rect.fromLTWH(0, 0, sw, sh))); final rng = Random(77 + stageNum); final sp = Paint()..color = Colors.white.withOpacity(0.5); for (int i = 0; i < 70; i++) canvas.drawCircle(Offset(rng.nextDouble() * sw, rng.nextDouble() * sh), rng.nextDouble() * 1.3, sp); if (res.entropyFrac > 0.4) canvas.drawRect(Rect.fromLTWH(0, 0, sw, sh), Paint()..color = const Color(0xFF330044).withOpacity(res.entropyFrac * 0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60)); _txt(canvas, 'STAGE $stageNum', Offset(sw - 12, 72), Colors.white24, 9, right: true); }
  void _portal(Canvas canvas) { final cx = sw / 2, cy = sh * 0.22; final pg = portalGrow.clamp(0.0, 1.0); final r = 55 + pg * 100; for (int i = 8; i >= 1; i--) canvas.drawCircle(Offset(cx, cy), r * i * 0.12, Paint()..color = cRed.withOpacity(pg * 0.06 * i)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20)); canvas.drawCircle(Offset(cx, cy), r, Paint()..color = const Color(0xFF1A0000).withOpacity(pg * 0.7)); canvas.drawCircle(Offset(cx, cy), r, Paint()..color = cRed.withOpacity(pg * 0.5)..style = PaintingStyle.stroke..strokeWidth = 3); if (pg > 0.4) _txt(canvas, 'PORTAL DIMENSIONAL', Offset(cx, cy), cRed.withOpacity(pg), 11); }
  void _drawAsteroids(Canvas canvas) { for (final a in asteroids) { if (a.dead) continue; canvas.save(); canvas.translate(a.x, a.y); canvas.rotate(a.angle); final col = a.level == 2 ? const Color(0xFF665544) : a.level == 1 ? const Color(0xFF887755) : const Color(0xFFAA9966); final colB = a.level == 2 ? const Color(0xFF887766) : a.level == 1 ? const Color(0xFFAA9977) : const Color(0xFFCCBB88); final path = Path(); for (int i = 0; i < 8; i++) { final ang = i * pi / 4; final r2 = a.r * (0.7 + 0.3 * (i % 2 == 0 ? 1 : 0.6)); if (i == 0) path.moveTo(cos(ang) * r2, sin(ang) * r2); else path.lineTo(cos(ang) * r2, sin(ang) * r2); } path.close(); canvas.drawPath(path, Paint()..color = col); canvas.drawPath(path, Paint()..color = colB..style = PaintingStyle.stroke..strokeWidth = 1.5); canvas.restore(); } }
  void _drawNucleus(Canvas canvas) { final cx = sw / 2, cy = sh * 0.87; final tc = Color.lerp(cIce, cDanger, coreTemp)!; final pulse = kNucleusR + corePulse * 5; if (nucleusIFrame > 0) canvas.drawCircle(Offset(cx, cy), pulse + 10, Paint()..color = cShield.withOpacity(0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15)); for (int i = 4; i >= 1; i--) canvas.drawCircle(Offset(cx, cy), pulse + i * 12, Paint()..color = tc.withOpacity(0.06 * i)..style = PaintingStyle.stroke..strokeWidth = 1.5); canvas.drawCircle(Offset(cx, cy), pulse * 1.4, Paint()..color = tc.withOpacity(0.18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20)); canvas.drawCircle(Offset(cx, cy), pulse, Paint()..shader = RadialGradient(colors: [Colors.white.withOpacity(0.95), tc.withOpacity(0.85), tc.withOpacity(0.2)], stops: const [0.0, 0.45, 1.0]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: pulse))); canvas.drawCircle(Offset(cx, cy), pulse + 4, Paint()..color = tc.withOpacity(0.35)..style = PaintingStyle.stroke..strokeWidth = 0.8); final lp = Paint()..color = tc.withOpacity(0.2)..strokeWidth = 0.7; canvas.drawLine(Offset(cx - pulse - 10, cy), Offset(cx + pulse + 10, cy), lp); canvas.drawLine(Offset(cx, cy - pulse - 10), Offset(cx, cy + pulse + 10), lp); final rng = Random((corePulse * 20).toInt()); final blp = Paint()..color = tc.withOpacity(0.6)..style = PaintingStyle.stroke..strokeWidth = 1.2; for (int i = 0; i < 8; i++) { final a = i * pi / 4 + corePulse * pi * 0.5; _bolt(canvas, blp, Offset(cx + cos(a) * pulse * 0.5, cy + sin(a) * pulse * 0.5), Offset(cx + cos(a) * (pulse + 22), cy + sin(a) * (pulse + 22)), rng); } _arcBar(canvas, cx, cy, pulse + 32, coreTemp, tc); _txt(canvas, 'NÚCLEO CUÁNTICO', Offset(cx, cy + pulse + 22), tc.withOpacity(0.8), 9); }
  void _arcBar(Canvas canvas, double cx, double cy, double r, double frac, Color c) { const st = -pi * 0.75, sw2 = pi * 1.5; canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), st, sw2, false, Paint()..color = Colors.white12..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round); if (frac > 0) canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), st, sw2 * frac, false, Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round); }
  void _bolt(Canvas canvas, Paint p, Offset a, Offset b, Random rng) { final path = Path()..moveTo(a.dx, a.dy); for (int i = 1; i < 4; i++) { final t = i / 4; path.lineTo(a.dx + (b.dx - a.dx) * t + (rng.nextDouble() - 0.5) * 10, a.dy + (b.dy - a.dy) * t + (rng.nextDouble() - 0.5) * 10); } path.lineTo(b.dx, b.dy); canvas.drawPath(path, p); }
  void _drawPowerUps(Canvas canvas) { for (final p in powerUps) { if (p.collected) continue; final c = _puC(p.kind); final pulse = sin(p.animT) * 0.15 + 1.0; canvas.drawCircle(Offset(p.x, p.y), 22 * pulse, Paint()..color = c.withOpacity(0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)); canvas.drawCircle(Offset(p.x, p.y), 18 * pulse, Paint()..color = c.withOpacity(0.7)..style = PaintingStyle.stroke..strokeWidth = 2); _txt(canvas, _puI(p.kind), Offset(p.x, p.y), c, 16); } }
  Color _puC(PowerUpKind k) => switch (k) { PowerUpKind.rapidFire => cFire, PowerUpKind.tripleShot => cGold, PowerUpKind.shield => cShield, PowerUpKind.coreArmor => cIce, PowerUpKind.energyBoost => cGreen };
  String _puI(PowerUpKind k) => switch (k) { PowerUpKind.rapidFire => '⚡', PowerUpKind.tripleShot => '💥', PowerUpKind.shield => '🛡', PowerUpKind.coreArmor => '❄', PowerUpKind.energyBoost => '💚' };
  void _drawPhoenix(Canvas canvas, double py) {
    final px = player.x;
    if (heat.zone != HeatZone.cool) { final hc = heat.zoneColor; canvas.drawCircle(Offset(px, py), kPhoenixSize * 1.3, Paint()..color = hc.withOpacity(0.15 + heat.fraction * 0.15)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)); }
    if (player.shieldActive) { canvas.drawCircle(Offset(px, py), kPhoenixSize * 1.7, Paint()..color = cShield.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)); canvas.drawCircle(Offset(px, py), kPhoenixSize * 1.7, Paint()..color = cShield.withOpacity(0.7)..style = PaintingStyle.stroke..strokeWidth = 2); }
    if (isTriple) canvas.drawCircle(Offset(px, py), kPhoenixSize * 0.9, Paint()..color = cGold.withOpacity(0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    if (machineGunActive) canvas.drawCircle(Offset(px, py), kPhoenixSize * 1.1, Paint()..color = cGold.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    if (sprites.loaded && sprites.player != null) { drawSprite(canvas, sprites.player!, Offset(px, py), kPhoenixSize * 2.4); return; }
    canvas.drawCircle(Offset(px, py + kPhoenixSize * 0.55), kPhoenixSize * 0.35, Paint()..color = cFire.withOpacity(touching ? 0.85 : 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    final bp = Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFF999999), const Color(0xFF555555)]).createShader(Rect.fromCenter(center: Offset(px, py), width: kPhoenixSize * 0.6, height: kPhoenixSize * 1.8));
    canvas.drawPath(Path()..moveTo(px, py - kPhoenixSize * 0.85)..lineTo(px + kPhoenixSize * 0.22, py + kPhoenixSize * 0.45)..lineTo(px, py + kPhoenixSize * 0.25)..lineTo(px - kPhoenixSize * 0.22, py + kPhoenixSize * 0.45)..close(), bp);
    const wc = Color(0xFF666666);
    canvas.drawPath(Path()..moveTo(px - kPhoenixSize * 0.18, py)..lineTo(px - kPhoenixSize * 1.25, py + kPhoenixSize * 0.1)..lineTo(px - kPhoenixSize * 0.9, py + kPhoenixSize * 0.5)..lineTo(px - kPhoenixSize * 0.2, py + kPhoenixSize * 0.35)..close(), Paint()..color = wc);
    canvas.drawPath(Path()..moveTo(px + kPhoenixSize * 0.18, py)..lineTo(px + kPhoenixSize * 1.25, py + kPhoenixSize * 0.1)..lineTo(px + kPhoenixSize * 0.9, py + kPhoenixSize * 0.5)..lineTo(px + kPhoenixSize * 0.2, py + kPhoenixSize * 0.35)..close(), Paint()..color = wc);
    canvas.drawCircle(Offset(px, py - kPhoenixSize * 0.3), kPhoenixSize * 0.18, Paint()..color = cIce.withOpacity(0.8)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    _txt(canvas, 'G·G', Offset(px, py + kPhoenixSize * 0.05), cGold.withOpacity(0.8), 7);
    if (touching) canvas.drawPath(Path()..moveTo(px - 7, py + kPhoenixSize * 0.42)..lineTo(px, py + kPhoenixSize * 0.42 + 30)..lineTo(px + 7, py + kPhoenixSize * 0.42), Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFFFFDD00), cFire, cFire.withOpacity(0)]).createShader(Rect.fromLTWH(px - 8, py + kPhoenixSize * 0.4, 16, 32)));
  }
  void _drawEnemies(Canvas canvas) { for (final e in enemies) { if (e.dead) continue; final base = _eColor(e.kind); final c = e.hitFlash > 0 ? Color.lerp(base, Colors.white, e.hitFlash)! : base; canvas.drawCircle(Offset(e.x, e.y), kEnemyR * 1.45, Paint()..color = c.withOpacity(0.18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)); final img = sprites.enemyImg(e.kind); if (sprites.loaded && img != null) { drawSprite(canvas, img, Offset(e.x, e.y), kEnemyR * 2.4, flash: e.hitFlash); } else { _eFallback(canvas, e, c); } if (e.maxHp > 20) { final bw = kEnemyR * 2; final frac = (e.hp / e.maxHp).clamp(0.0, 1.0); canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(e.x - bw / 2, e.y - kEnemyR - 8, bw, 3), const Radius.circular(2)), Paint()..color = Colors.white24); canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(e.x - bw / 2, e.y - kEnemyR - 8, bw * frac, 3), const Radius.circular(2)), Paint()..color = c); } } }
  void _eFallback(Canvas canvas, Enemy e, Color c) { switch (e.kind) { case EnemyKind.interceptor: canvas.drawOval(Rect.fromCenter(center: Offset(e.x, e.y), width: kEnemyR * 1.8, height: kEnemyR * 0.9), Paint()..color = c.withOpacity(0.85)); canvas.drawCircle(Offset(e.x, e.y), kEnemyR * 0.28, Paint()..color = Colors.white.withOpacity(0.9)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)); case EnemyKind.frigate: canvas.drawPath(Path()..moveTo(e.x, e.y - kEnemyR * 1.1)..lineTo(e.x + kEnemyR * 0.5, e.y)..lineTo(e.x, e.y + kEnemyR * 1.1)..lineTo(e.x - kEnemyR * 0.5, e.y)..close(), Paint()..color = c.withOpacity(0.85)); canvas.drawCircle(Offset(e.x, e.y), kEnemyR * 0.22, Paint()..color = Colors.white.withOpacity(0.7)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)); case EnemyKind.parasite: final p = Path(); for (int i = 0; i < 6; i++) { final a = i * pi / 3 + e.animT * 0.2; if (i == 0) p.moveTo(e.x + cos(a) * kEnemyR, e.y + sin(a) * kEnemyR); else p.lineTo(e.x + cos(a) * kEnemyR, e.y + sin(a) * kEnemyR); } p.close(); canvas.drawPath(p, Paint()..color = c.withOpacity(0.85)); canvas.drawCircle(Offset(e.x, e.y), kEnemyR * 0.28, Paint()..color = Colors.white.withOpacity(0.85)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)); case EnemyKind.corrupter: final p = Path(); for (int i = 0; i < 8; i++) { final a = i * pi / 4 + e.animT * 0.5; final r = i.isEven ? kEnemyR : kEnemyR * 0.42; if (i == 0) p.moveTo(e.x + cos(a) * r, e.y + sin(a) * r); else p.lineTo(e.x + cos(a) * r, e.y + sin(a) * r); } p.close(); canvas.drawPath(p, Paint()..color = c); canvas.drawCircle(Offset(e.x, e.y), kEnemyR * 0.22, Paint()..color = const Color(0xFFFF0000).withOpacity(0.9)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)); } }
  Color _eColor(EnemyKind k) => switch (k) { EnemyKind.interceptor => cWarlord, EnemyKind.frigate => cGreen, EnemyKind.parasite => cShield, EnemyKind.corrupter => const Color(0xFFFF6600) };
  void _drawBoss(Canvas canvas, Boss b) {
    final isVulnerable = b.state == BossState.vulnerable;
    final isCharging = b.state == BossState.charging && stageNum != 4;
    final isFleeing = b.state == BossState.fleeing || finisher.phase == FinisherPhase.fleeing;
    // Aura de huida
    if (isFleeing) { canvas.drawCircle(Offset(b.x, b.y), kBossR * 2.5, Paint()..color = cDanger.withOpacity(0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30)); }
    if (isVulnerable) { canvas.drawCircle(Offset(b.x, b.y), kBossR * 2.0, Paint()..color = cGold.withOpacity(0.3 + sin(b.animT * 6) * 0.15)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20)); canvas.drawCircle(Offset(b.x, b.y), kBossR * 1.5, Paint()..color = cGold.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 3); }
    if (b.phaseShieldActive) { final pulse = 0.7 + sin(b.animT * 8) * 0.3; canvas.drawCircle(Offset(b.x, b.y), kBossR * 1.6, Paint()..color = cShield.withOpacity(0.35 * pulse)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)); canvas.drawCircle(Offset(b.x, b.y), kBossR * 1.6, Paint()..color = cShield.withOpacity(0.8 * pulse)..style = PaintingStyle.stroke..strokeWidth = 3); final shieldFrac = (b.phaseShieldTimer / diff.bossShieldDuration).clamp(0.0, 1.0); canvas.drawArc(Rect.fromCircle(center: Offset(b.x, b.y), radius: kBossR * 1.7), -pi / 2, pi * 2 * shieldFrac, false, Paint()..color = cShield..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round); }
    if (isCharging) { canvas.drawCircle(Offset(b.x, b.y), kBossR * 2.2, Paint()..color = bossColor.withOpacity(b.chargeGlow * 0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30)); for (int i = 1; i <= 3; i++) canvas.drawCircle(Offset(b.x, b.y), kBossR * (1.0 + i * 0.4 * b.chargeGlow), Paint()..color = bossColor.withOpacity((1 - b.chargeGlow) * 0.3 / (i * 0.8))..style = PaintingStyle.stroke..strokeWidth = 1.5); }
    final img = sprites.bossImg(stageNum); if (sprites.loaded && img != null) { drawSprite(canvas, img, Offset(b.x, b.y), kBossR * 2.4, flash: b.hitFlash); } else { final c = b.hitFlash > 0 ? Color.lerp(bossColor, Colors.white, b.hitFlash)! : bossColor; canvas.drawCircle(Offset(b.x, b.y), kBossR * 1.8, Paint()..color = c.withOpacity(0.12)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30)); final path = Path(); for (int i = 0; i < 6; i++) { final a = i * pi / 3 + b.animT * 0.15; if (i == 0) path.moveTo(b.x + cos(a) * kBossR, b.y + sin(a) * kBossR); else path.lineTo(b.x + cos(a) * kBossR, b.y + sin(a) * kBossR); } path.close(); canvas.drawPath(path, Paint()..shader = RadialGradient(colors: [bossColor.withOpacity(0.95), const Color(0xFF112244)], stops: const [0.3, 1.0]).createShader(Rect.fromCircle(center: Offset(b.x, b.y), radius: kBossR))); canvas.drawCircle(Offset(b.x, b.y), kBossR * 0.18, Paint()..color = bossColor..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)); canvas.drawCircle(Offset(b.x, b.y), kBossR * 0.07, Paint()..color = Colors.white); }
    // HP bar
    if (stageNum != 4 && b.hp > 0) { const bw = kBossR * 2; canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(b.x - bw / 2, b.y - kBossR * 1.3, bw, 6), const Radius.circular(3)), Paint()..color = Colors.white24); final frac = (b.hp / b.maxHp).clamp(0.0, 1.0); final barC = isVulnerable ? cGold : isFleeing ? Colors.orange : Color.lerp(cDanger, bossColor, frac)!; canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(b.x - bw / 2, b.y - kBossR * 1.3, bw * frac, 6), const Radius.circular(3)), Paint()..color = barC); _txt(canvas, isVulnerable ? '💥 VULNERABLE' : isFleeing ? '⚡ HUYENDO' : '${(frac * 100).toInt()}%', Offset(b.x, b.y - kBossR * 1.45), barC, 10); } else if (stageNum == 4) { _txt(canvas, '⚠ INVENCIBLE', Offset(b.x, b.y - kBossR * 1.45), cRed, 10); }
    if (isVulnerable) _txt(canvas, '¡VULNERABLE!', Offset(b.x, b.y + kBossR + 18), cGold, 12);
    else if (isFleeing) _txt(canvas, '⚡ ¡HUYE!', Offset(b.x, b.y + kBossR + 18), Colors.orange, 12);
    else if (isCharging) _txt(canvas, '⚠ CARGANDO…', Offset(b.x, b.y + kBossR + 18), cDanger, 11);
  }
  void _drawBullets(Canvas canvas) { for (final b in bullets) { if (b.isEnemy) { final c = b.fromBoss ? bossColor : cWarlord; final r = b.fromBoss ? 9.0 : 7.0; canvas.drawCircle(Offset(b.x, b.y), r, Paint()..color = c..maskFilter = MaskFilter.blur(BlurStyle.normal, b.fromBoss ? 8 : 5)); canvas.drawCircle(Offset(b.x, b.y), r * 0.38, Paint()..color = b.fromBoss ? Colors.orange : cFrost); } else if (b.isMissile) { canvas.drawCircle(Offset(b.x, b.y), 12, Paint()..color = Colors.orange.withOpacity(0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)); canvas.drawCircle(Offset(b.x, b.y), 6, Paint()..color = Colors.orange); canvas.drawOval(Rect.fromCenter(center: Offset(b.x, b.y + 12), width: 6, height: 16), Paint()..color = cFire.withOpacity(0.7)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)); } else { final lc = freezeActive ? cIce : laserColor; canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(b.x, b.y), width: 10, height: 24), const Radius.circular(5)), Paint()..color = lc.withOpacity(0.22)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)); canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(b.x, b.y), width: 3.5, height: 22), const Radius.circular(2)), Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, lc, lc.withOpacity(0.5)]).createShader(Rect.fromCenter(center: Offset(b.x, b.y), width: 3.5, height: 22))); canvas.drawCircle(Offset(b.x, b.y - 10), 3, Paint()..color = Colors.white.withOpacity(0.95)); } } }
  void _drawParticles(Canvas canvas) { for (final p in particles) { final a = (p.life / p.maxLife).clamp(0.0, 1.0); if (p.isFrost) { final fp = Paint()..color = cFrost.withOpacity(a * 0.9)..style = PaintingStyle.stroke..strokeWidth = 1.2; for (int i = 0; i < 3; i++) { final ang = i * pi / 3; canvas.drawLine(Offset(p.x + cos(ang) * p.size, p.y + sin(ang) * p.size), Offset(p.x - cos(ang) * p.size, p.y - sin(ang) * p.size), fp); } canvas.drawCircle(Offset(p.x, p.y), p.size * 0.3 * a, Paint()..color = Colors.white.withOpacity(a)); } else { canvas.drawCircle(Offset(p.x, p.y), p.size * a, Paint()..color = p.color.withOpacity(a)..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.5)); } } }
  void _drawFloats(Canvas canvas) { for (final f in floats) _txt(canvas, f.text, Offset(f.x, f.y), f.color.withOpacity(f.life.clamp(0, 1)), 11); }
  void _drawHUD(Canvas canvas) {
    _txt(canvas, 'SCORE  $score', Offset(16, 56), Colors.white, 15, left: true);
    final label = switch (phase.phase) { GamePhase.combat => 'COMBAT  \${(phase.combatProgress * 100).toInt()}%', GamePhase.decision => 'DECISIÓN', GamePhase.boss => '⚠ BOSS' };
    _txt(canvas, label, Offset(sw / 2, 56), cIce, 11);
    final bw = sw * 0.4, bx = (sw - bw) / 2;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, 66, bw, 3), const Radius.circular(2)), Paint()..color = Colors.white12);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, 66, bw * phase.combatProgress, 3), const Radius.circular(2)), Paint()..color = cIce);
    final enePulse = 0.5 + sin(corePulse * pi * 3) * 0.15;
    _vBarPulse(canvas, 14, sh * 0.35, 10, sh * 0.28, res.energyFrac, cIce, 'ENE', enePulse);
    _drawHeatBar(canvas);
    if (gravityTimer > 0) _txt(canvas, '⏱ \${gravityTimer.toInt()}s', Offset(sw - 12, 84), cDanger, 11, right: true);
    if (res.entropyFrac > 0.3) {
      final entropyPct = (res.entropyFrac * 100).toInt();
      final isCritical = res.entropyFrac > 0.9;
      final entColor = isCritical ? Color.lerp(cDanger, Colors.white, (sin(corePulse * pi * 8) * 0.5 + 0.5))! : cShield.withOpacity(res.entropyFrac);
      _txt(canvas, isCritical ? '⚠ ENTROPÍA \$entropyPct%' : 'ENTROPÍA \$entropyPct%', Offset(sw / 2, sh - 28), entColor, isCritical ? 11.0 : 10.0);
    }
    _txt(canvas, 'DMG \${player.build.damage.toStringAsFixed(0)}  SPD \${player.build.fireRate.toStringAsFixed(1)}', Offset(sw / 2, sh - 14), Colors.white24, 9);
    if (coreTemp > 0.75) _txt(canvas, '⚠  QUENCH INMINENTE  ⚠', Offset(sw / 2, sh * 0.48), cDanger, 15);
    if (heat.zone == HeatZone.hot && !heat.isOverheated) _txt(canvas, '🔥 CADENCIA REDUCIDA', Offset(sw / 2, sh * 0.53), cDanger.withOpacity(0.85), 10);
    if (heat.zone == HeatZone.cool) _drawColdAura(canvas);
  }

  void _drawColdAura(Canvas canvas) {
    final px = player.x, py = playerY;
    final rng = Random((corePulse * 60).toInt());
    final frostPaint = Paint()..color = cIce.withOpacity(0.12)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    for (int i = 0; i < 4; i++) {
      final angle = corePulse * pi * 2 + i * pi / 2;
      final r = kPhoenixSize * 1.6 + rng.nextDouble() * 10;
      canvas.drawCircle(Offset(px + cos(angle) * r, py + sin(angle) * r), 3 + rng.nextDouble() * 2, frostPaint);
    }
    canvas.drawCircle(Offset(px, py), kPhoenixSize * 2.0, Paint()..color = cIce.withOpacity(0.06 + sin(corePulse * pi * 4) * 0.03)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(px + (rng.nextDouble() - 0.5) * 18, py + kPhoenixSize + i * 8.0), 2, Paint()..color = cFrost.withOpacity(0.25 - i * 0.07)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
  }

  void _drawHeatBar(Canvas canvas) {
    final x = sw - 60.0, y = sh * 0.35, w = 10.0, h = sh * 0.28;
    if (heat.fraction > 0.4) {
      final glowAlpha = (heat.fraction - 0.4) / 0.6 * 0.3;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 3, y - 3, w + 6, h + 6), const Radius.circular(7)), Paint()..color = heat.zoneColor.withOpacity(glowAlpha * (0.5 + sin(corePulse * pi * 4) * 0.5))..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(4)), Paint()..color = Colors.white12);
    final frac = heat.fraction.clamp(0.0, 1.0);
    if (frac > 0) {
      final barH = h * frac;
      final barColor = heat.isOverheated ? cRed : switch (heat.zone) { HeatZone.cool => cIce, HeatZone.warm => cGold, HeatZone.hot => cDanger, HeatZone.overheat => cRed };
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y + h - barH, w, barH), const Radius.circular(4)), Paint()..color = barColor..maskFilter = frac > 0.7 ? MaskFilter.blur(BlurStyle.normal, frac > 0.85 ? 6 : 3) : null);
    }
    final cool40Y = y + h * (1 - 0.40); final warn70Y = y + h * (1 - 0.70);
    canvas.drawLine(Offset(x - 3, cool40Y), Offset(x + w + 3, cool40Y), Paint()..color = cGold.withOpacity(0.4)..strokeWidth = 1);
    canvas.drawLine(Offset(x - 3, warn70Y), Offset(x + w + 3, warn70Y), Paint()..color = cDanger.withOpacity(0.5)..strokeWidth = 1);
    _txt(canvas, 'HEAT', Offset(x + w / 2, y + h + 14), heat.zoneColor.withOpacity(0.7), 8);
    if (heat.isOverheated) _txt(canvas, '🔥', Offset(x + w / 2, y - 14), cRed, 14);
  }

  void _vBarPulse(Canvas canvas, double x, double y, double w, double h, double frac, Color c, String label, double pulse) {
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(4)), Paint()..color = Colors.white12);
    final f = h * frac.clamp(0.0, 1.0);
    if (frac > 0.2) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 2, y + h - f - 2, w + 4, f + 4), const Radius.circular(6)), Paint()..color = c.withOpacity(0.08 + pulse * 0.08)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    }
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y + h - f, w, f), const Radius.circular(4)), Paint()..color = c..maskFilter = MaskFilter.blur(BlurStyle.normal, frac > 0.7 ? 4 : 0));
    _txt(canvas, label, Offset(x + w / 2, y + h + 14), c.withOpacity(0.6 + pulse * 0.2), 8);
  }

  void _vBar(Canvas canvas, double x, double y, double w, double h, double frac, Color c, String label) {
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(4)), Paint()..color = Colors.white12);
    final f = h * frac.clamp(0.0, 1.0);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y + h - f, w, f), const Radius.circular(4)), Paint()..color = c..maskFilter = MaskFilter.blur(BlurStyle.normal, frac > 0.7 ? 4 : 0));
    _txt(canvas, label, Offset(x + w / 2, y + h + 14), c.withOpacity(0.6), 8);
  }
  void _drawFrost(Canvas canvas) { final ft = frostT.clamp(0.0, 1.0); canvas.drawRect(Rect.fromLTWH(0, 0, sw, sh), Paint()..shader = RadialGradient(center: Alignment.center, radius: 0.7, colors: [Colors.transparent, cFrost.withOpacity(ft * 0.35), cFrost.withOpacity(ft * 0.7)], stops: const [0.4, 0.7, 1.0]).createShader(Rect.fromLTWH(0, 0, sw, sh))); final rng = Random(42); final cp = Paint()..color = cFrost.withOpacity(ft * 0.55)..strokeWidth = 1.0..style = PaintingStyle.stroke; void crack(double sx, double sy, int d) { if (d <= 0) return; for (int i = 0; i < 3; i++) { final a = rng.nextDouble() * pi * 2; final l = (20 + rng.nextDouble() * 40) * ft; final ex = sx + cos(a) * l; final ey = sy + sin(a) * l; canvas.drawLine(Offset(sx, sy), Offset(ex, ey), cp); if (rng.nextDouble() < 0.5) crack(ex, ey, d - 1); } } crack(0, 0, 4); crack(sw, 0, 4); crack(0, sh, 4); crack(sw, sh, 4); _txt(canvas, '❄  QUENCH CRÍTICO  ❄', Offset(sw / 2, sh * 0.38), cFrost.withOpacity(0.6 + sin(frostT * pi * 8) * 0.4), 18); }
  void _drawQuench(Canvas canvas) { final a = (quenchT / 2.5).clamp(0.0, 0.92); canvas.drawRect(Rect.fromLTWH(0, 0, sw, sh), Paint()..color = cFire.withOpacity(a * 0.8)); _txt(canvas, '💥  QUENCH  💥', Offset(sw / 2, sh * 0.38), Colors.white, 38); _txt(canvas, 'FALLO CRIOGÉNICO TOTAL', Offset(sw / 2, sh * 0.48), cFire, 16); }
  void _drawMirrorWin(Canvas canvas) { final t = (mirrorVictoryT / 3.5).clamp(0.0, 1.0); canvas.drawRect(Rect.fromLTWH(0, 0, sw, sh), Paint()..color = const Color(0xFF000033).withOpacity(t * 0.88)); _txt(canvas, '★ PORTAL CERRADO ★', Offset(sw / 2, sh * 0.35), cGold.withOpacity(t), 22); _txt(canvas, 'La puerta fue cerrada…', Offset(sw / 2, sh * 0.45), Colors.white.withOpacity(t), 14); _txt(canvas, 'por ahora.', Offset(sw / 2, sh * 0.52), cIce.withOpacity(t), 20); _txt(canvas, 'PHOENIX CORE II — COMING SOON', Offset(sw / 2, sh * 0.62), cRed.withOpacity(t * 0.9), 12); }
  void _txt(Canvas canvas, String t, Offset pos, Color c, double sz, {bool left = false, bool right = false}) { final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(color: c, fontSize: sz, fontFamily: 'Orbitron', fontWeight: FontWeight.bold, shadows: [Shadow(color: c.withOpacity(0.5), blurRadius: 8)])), textAlign: left ? TextAlign.left : TextAlign.center, textDirection: TextDirection.ltr)..layout(); final dx = right ? pos.dx - tp.width : left ? pos.dx : pos.dx - tp.width / 2; tp.paint(canvas, Offset(dx, pos.dy - tp.height / 2)); }
  @override bool shouldRepaint(covariant CustomPainter _) => true;
}

// ── CHARGE RING ──────────────────────────────────────────
class _ChargeRing extends StatelessWidget {
  final ChargeIndicator indicator; final VoidCallback onTap;
  const _ChargeRing({required this.indicator, required this.onTap});
  @override Widget build(BuildContext ctx) { final c = indicator.color; final ready = indicator.ready && !indicator.active; final active = indicator.active; return GestureDetector(onTap: onTap, child: SizedBox(width: 48, height: 48, child: CustomPaint(painter: _RingPainter(fraction: indicator.fraction, color: c, ready: ready, active: active, icon: indicator.icon)))); }
}
class _RingPainter extends CustomPainter {
  final double fraction; final Color color; final bool ready, active; final String icon;
  const _RingPainter({required this.fraction, required this.color, required this.ready, required this.active, required this.icon});
  @override void paint(Canvas canvas, Size size) { final cx = size.width / 2, cy = size.height / 2, r = size.width / 2 - 4; canvas.drawCircle(Offset(cx, cy), r, Paint()..color = Colors.white12..style = PaintingStyle.stroke..strokeWidth = 3); if (fraction > 0) canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), -pi / 2, pi * 2 * fraction, false, Paint()..color = active ? color.withOpacity(0.5) : color..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round); if (ready) canvas.drawCircle(Offset(cx, cy), r * 0.7, Paint()..color = color.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)); final tp = TextPainter(text: TextSpan(text: icon, style: TextStyle(fontSize: 18, color: active ? color.withOpacity(0.5) : ready ? color : Colors.white38)), textDirection: TextDirection.ltr)..layout(); tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2)); }
  @override bool shouldRepaint(covariant CustomPainter _) => true;
}

// ── DECISION OVERLAY ─────────────────────────────────────
class _DecisionOverlay extends StatelessWidget {
  final List<UpgradeOption> options; final int cycle, stageNum; final DifficultyConfig diff; final void Function(UpgradeOption) onSelect;
  const _DecisionOverlay({required this.options, required this.cycle, required this.stageNum, required this.diff, required this.onSelect});
  @override Widget build(BuildContext ctx) {
    Widget buildOpt(UpgradeOption opt) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: GestureDetector(onTap: () => onSelect(opt), child: Container(
        width: double.infinity, padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(border: Border.all(color: opt.color, width: 2), borderRadius: BorderRadius.circular(14), color: opt.color.withOpacity(0.12), boxShadow: [BoxShadow(color: opt.color.withOpacity(0.28), blurRadius: 18)]),
        child: Row(children: [
          Text(opt.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(opt.title, style: TextStyle(color: opt.color, fontSize: 13, fontFamily: 'Orbitron', fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text(opt.description, style: const TextStyle(color: Colors.white, fontSize: 11)),
            if (opt.hasTradeoff) ...[const SizedBox(height: 3), Text(opt.tradeoff, style: const TextStyle(color: Colors.orange, fontSize: 10))],
          ])),
          Icon(Icons.arrow_forward_ios, color: opt.color, size: 16),
        ]),
      )),
    );
    return Container(
      color: Colors.black.withOpacity(0.93),
      child: SafeArea(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        _GlowText('⚡ FASE DE DECISIÓN', color: cGold, size: 19),
        const SizedBox(height: 4),
        _GlowText('Stage $stageNum — Ciclo $cycle', color: Colors.white54, size: 11),
        const SizedBox(height: 6),
        Container(margin: const EdgeInsets.symmetric(horizontal: 24), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: diff.color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: diff.color.withOpacity(0.4))), child: Text('${diff.emoji} ${diff.name}  ·  Efecto INMEDIATO', textAlign: TextAlign.center, style: TextStyle(color: diff.color, fontSize: 10, fontFamily: 'Orbitron'))),
        const SizedBox(height: 12),
        ...options.map(buildOpt),
      ])),
    );
  }
}

class _GlowText extends StatelessWidget {
  final String text; final Color color; final double size;
  const _GlowText(this.text, {required this.color, required this.size});
  @override Widget build(BuildContext ctx) => Text(text, textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: size, fontFamily: 'Orbitron', fontWeight: FontWeight.bold, shadows: [Shadow(color: color.withOpacity(0.8), blurRadius: 14), Shadow(color: color.withOpacity(0.3), blurRadius: 28)]));
}
class _Btn extends StatelessWidget {
  final String label; final Color color; final VoidCallback onTap;
  const _Btn({required this.label, required this.color, required this.onTap});
  @override Widget build(BuildContext ctx) => GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 14), decoration: BoxDecoration(border: Border.all(color: color, width: 1.5), borderRadius: BorderRadius.circular(8), color: color.withOpacity(0.12), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 14)]), child: _GlowText(label, color: color, size: 15)));
}

// Extension para DifficultyConfig
extension DiffExt on DifficultyConfig {
  bool get heatAffectsAccuracy => level != Difficulty.amateur;
}
