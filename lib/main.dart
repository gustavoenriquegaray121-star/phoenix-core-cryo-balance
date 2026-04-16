import 'dart:math';
import 'dart:ui' as ui;
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

// ── HAPTIC ───────────────────────────────────────────────
void hapticLight()  => HapticFeedback.lightImpact();
void hapticMedium() => HapticFeedback.mediumImpact();
void hapticHeavy()  => HapticFeedback.heavyImpact();

// ── COLORS ───────────────────────────────────────────────
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

// ── CONSTANTS ────────────────────────────────────────────
const double kPhoenixSize    = 28.0;
const double kEnemyR         = 22.0;
const double kBossR          = 52.0;
const double kNucleusR       = 38.0;
const double kCombatDuration = 32.0;
const double kBossChargeTime = 1.2;
const double kNucleusIFrame  = 0.9;
const double kBossBulletDmg  = 0.055;
const double kCoreHeatPerHit = 0.06;
const double kCoreHeatPerPass= 0.10;

// ── ENUMS ────────────────────────────────────────────────
enum AppScreen  { intro, menu, playing, stageClear, cinematic, gameOver, victory }
enum GamePhase  { combat, decision, boss }
enum EnemyKind  { interceptor, frigate, parasite, corrupter }
enum PowerUpKind{ rapidFire, tripleShot, shield, coreArmor, energyBoost }
enum BossState  { moving, charging, firing, cooldown }
enum StageHazard{ none, asteroids, gravityTimer, mirrorPortal }

// ── STAGE DEFINITIONS ────────────────────────────────────
class StageConfig {
  final int    stageNum;
  final String name;
  final String bossName;
  final String bossAsset;
  final Color  bossColor;
  final StageHazard hazard;
  final double bossHpBase;
  final double bossHpPerCycle;
  final List<CinematicScene> scenes;
  const StageConfig({
    required this.stageNum, required this.name,
    required this.bossName, required this.bossAsset, required this.bossColor,
    required this.hazard,   required this.bossHpBase, required this.bossHpPerCycle,
    required this.scenes,
  });
}

const _stages = [
  // STAGE 1 — Nebulosa de Orión
  StageConfig(
    stageNum:1, name:'NEBULOSA DE ORIÓN',
    bossName:'THE FROZEN WARLORD', bossAsset:'assets/images/boss.png',
    bossColor:cWarlord, hazard:StageHazard.none,
    bossHpBase:110, bossHpPerCycle:25,
    scenes:[],
  ),
  // STAGE 2 — Campo de Asteroides de Kharos
  StageConfig(
    stageNum:2, name:'ASTEROIDES DE KHAROS',
    bossName:'EL SEGADOR DE ALMAS', bossAsset:'assets/images/jefe2.png',
    bossColor:cGreen, hazard:StageHazard.asteroids,
    bossHpBase:160, bossHpPerCycle:30,
    scenes:[
      CinematicScene(location:'DOCK 7A — BASE PHOENIX', speaker:'GENERAL G-G', speakerColor:'gold',
          dialogue:'Comandante… lo consiguió.\nEl núcleo cuántico llegó intacto.\nLa colonia Elysium ya está recibiendo energía estable.',
          imageAsset:'assets/images/escena1jefe2.jpg'),
      CinematicScene(location:'DOCK 7A — HANGAR', speaker:'GENERAL G-G', speakerColor:'gold',
          dialogue:'Recibimos señales de alerta desde el sector de los Asteroides de Kharos.\nAlgo está atacando nuestros convoyes… y no es una nave común.\nLe llamamos El Segador de Almas del Abismo.',
          imageAsset:'assets/images/escena2jefe2.jpg'),
      CinematicScene(location:'DOCK 7A — HANGAR', speaker:'USUARIO', speakerColor:'ice',
          dialogue:'¿Qué necesita que haga?',
          imageAsset:'assets/images/escena3jefe2.jpg'),
      CinematicScene(location:'DOCK 7A — HANGAR', speaker:'GENERAL G-G', speakerColor:'gold',
          dialogue:'Vaya allí y deténgalo antes de que alcance el Núcleo Central de Elysium.\nSu nave está siendo reparada. Descanse en el Café Altea.\nEsta entidad es mucho más antigua… y mucho más peligrosa.',
          imageAsset:'assets/images/escena4jefe2.jpg'),
    ],
  ),
  // STAGE 3 — Zona de Estrella de Neutrones
  StageConfig(
    stageNum:3, name:'ZONA NEUTRÓNICA OMEGA',
    bossName:'EL DEVORADOR DE SUEÑOS', bossAsset:'assets/images/jefe3.png',
    bossColor:cPurple, hazard:StageHazard.gravityTimer,
    bossHpBase:220, bossHpPerCycle:35,
    scenes:[
      CinematicScene(location:'DOCK 7A — BASE PHOENIX', speaker:'GENERAL G-G', speakerColor:'gold',
          dialogue:'Comandante… excelente trabajo.\nEl Segador fue neutralizado.\nPermítame presentarle a la Doctora Denise Moreau.',
          imageAsset:'assets/images/escena1jefe3.jpg'),
      CinematicScene(location:'SALA DE ANÁLISIS', speaker:'DRA. DENISE MOREAU', speakerColor:'ice',
          dialogue:'Lo que enfrentaremos no es una nave enemiga…\nes una entidad biológica altamente evolucionada.\nUna vanguardia de enjambre insectoide.',
          imageAsset:'assets/images/escena2jefe3.jpg'),
      CinematicScene(location:'CAFÉ ALTEA', speaker:'DRA. DENISE MOREAU', speakerColor:'ice',
          dialogue:'Ataca la mente, genera alucinaciones y distorsiona la realidad.\nSi logra establecer una cabeza de playa, será casi imposible detener la infestación completa.',
          imageAsset:'assets/images/escena3jefe3.jpg'),
      CinematicScene(location:'DOCK 7A — HANGAR', speaker:'GENERAL G-G', speakerColor:'gold',
          dialogue:'Diríjase al punto de intercepción antes de que la nave nodriza cruce el vacío intergaláctico.\n¡ADVERTENCIA: campo gravitacional activo — neutralice al jefe antes de ser absorbido!',
          imageAsset:'assets/images/escena4jefe3.jpg'),
    ],
  ),
  // STAGE 4 — Realidad Espejo
  StageConfig(
    stageNum:4, name:'SECTOR OMEGA-9 — REALIDAD ESPEJO',
    bossName:'ANTI-PHOENIX UNIT 01', bossAsset:'assets/images/jefe4.png',
    bossColor:cRed, hazard:StageHazard.mirrorPortal,
    bossHpBase:999, bossHpPerCycle:0,
    scenes:[
      CinematicScene(location:'PUENTE DE MANDO', speaker:'GENERAL G-G', speakerColor:'gold',
          dialogue:'¡Comandante! Los sensores detectaron una anomalía masiva en el sector Omega-9.\nNo es una nave enemiga… es un portal dimensional que se está abriendo desde otro universo.',
          imageAsset:'assets/images/escena1jefe4.jpg'),
      CinematicScene(location:'SALA DE ANÁLISIS', speaker:'DRA. DENISE MOREAU', speakerColor:'ice',
          dialogue:'La firma energética es completamente desconocida.\nSea lo que sea que intenta cruzar, viene con una cantidad de poder enorme.',
          imageAsset:'assets/images/escena2jefe4.jpg'),
      CinematicScene(location:'SECTOR OMEGA-9', speaker:'USUARIO', speakerColor:'ice',
          dialogue:'[ El jugador derrota las naves invasoras. Entonces emerge una última nave del portal… casi idéntica a la Phoenix, pero oscura y roja. ]\n\n"ANTI-PHOENIX" se lee en el casco.',
          imageAsset:'assets/images/escena3jefe4.jpg'),
      CinematicScene(location:'CANAL DE COMUNICACIÓN', speaker:'ANTI-PHOENIX', speakerColor:'red',
          dialogue:'Por fin nos encontramos… "yo".\nEn mi universo ya conquisté todo lo que se movía.\nAhora vengo por el tuyo.',
          imageAsset:'assets/images/escena4jefe4.jpg'),
      CinematicScene(location:'CANAL DE COMUNICACIÓN', speaker:'GENERAL G-G', speakerColor:'gold',
          dialogue:'¡Comandante! ¡No intente destruirla!\n¡Su objetivo es CERRAR ESE PORTAL antes de que se estabilice!\n¡Repélalo de regreso a su realidad!',
          imageAsset:'assets/images/escena5jefe4.jpg'),
    ],
  ),
];

// ── CINEMATIC SCENE ──────────────────────────────────────
class CinematicScene {
  final String location, speaker, speakerColor, dialogue, imageAsset;
  const CinematicScene({required this.location, required this.speaker,
      required this.speakerColor, required this.dialogue, required this.imageAsset});
}

// ── INTRO SCENES (before Stage 1) ────────────────────────
const _introScenes = [
  CinematicScene(location:'CAFÉ ALTEA — BASE PHOENIX', speaker:'GENERAL G-G', speakerColor:'gold',
      dialogue:'Usuario. El Núcleo Cuántico debe llegar hoy al Cuadrante 7 de la Nebulosa de Orión.\nLa colonia Elysium se está quedando sin energía.\nSin ese núcleo… perdemos tres millones de personas en menos de 72 horas.',
      imageAsset:'assets/images/cafe1.jpg'),
  CinematicScene(location:'CAFÉ ALTEA — BASE PHOENIX', speaker:'USUARIO', speakerColor:'ice',
      dialogue:'Entendido.\n¿Mi nave?', imageAsset:'assets/images/cafe1.jpg'),
  CinematicScene(location:'DOCK 7A — PHOENIX PROJECT', speaker:'USUARIO', speakerColor:'ice',
      dialogue:'Núcleo asegurado. Sistemas en línea.\nPhoenix Project… listo para volar.',
      imageAsset:'assets/images/hangar1.jpg'),
  CinematicScene(location:'DOCK 7A — CASCO DE LA NAVE', speaker:'', speakerColor:'white',
      dialogue:'[ Pones la mano en el casco. El logo del Ave Fénix brilla bajo tus dedos. ]',
      imageAsset:'assets/images/ship_close.jpg'),
  CinematicScene(location:'LADO ENEMIGO — UBICACIÓN DESCONOCIDA',
      speaker:'THE FROZEN WARLORD', speakerColor:'red',
      dialogue:'Phoenix Protocol…\npor eso perdí. Ahora lo conozco.\nSé cómo bloquearlo.',
      imageAsset:'assets/images/warlord.jpg'),
  CinematicScene(location:'NEBULOSA DE ORIÓN — CUADRANTE 7',
      speaker:'USUARIO', speakerColor:'ice',
      dialogue:'¿Qué carajos…?\nEs él… The Frozen Warlord.\n\nTe vencí una vez…\nY te voy a vencer otra vez.',
      imageAsset:'assets/images/battle.jpg'),
];

// ── AUDIO MANAGER ────────────────────────────────────────
class AudioManager {
  final List<AudioPlayer> _laserPool = List.generate(6, (_) => AudioPlayer());
  int _li = 0;
  final _bg = AudioPlayer(), _bossMusic = AudioPlayer(),
        _explBoss = AudioPlayer(), _quenchSfx = AudioPlayer(),
        _alarm = AudioPlayer();
  bool _bossOn=false, _bgOn=false, _alarmOn=false;

  Future<void> startAmbient() async {
    if (_bgOn) return; _bgOn=true;
    try { await _bg.setReleaseMode(ReleaseMode.loop);
      await _bg.play(AssetSource('sounds/musica_ambiente.mp3'),volume:0.5); }catch(_){}
  }
  Future<void> switchToBoss() async {
    if (_bossOn) return; _bossOn=true;
    try { await _bg.stop(); await _bossMusic.setReleaseMode(ReleaseMode.loop);
      await _bossMusic.play(AssetSource('sounds/musica_jefe.mp3'),volume:0.7); }catch(_){}
  }
  Future<void> switchToAmbient() async {
    _bossOn=false;
    try { await _bossMusic.stop(); await _bg.setReleaseMode(ReleaseMode.loop);
      await _bg.play(AssetSource('sounds/musica_ambiente.mp3'),volume:0.5); }catch(_){}
  }
  Future<void> playLaser({bool triple=false}) async {
    try { final p=_laserPool[_li%_laserPool.length]; _li++;
      await p.stop();
      await p.play(AssetSource(triple?'sounds/laser_triple.mp3':'sounds/laser.mp3'),
          volume:triple?0.5:0.3); }catch(_){}
  }
  Future<void> playExplosion({bool isBoss=false}) async {
    try {
      if(isBoss){await _explBoss.stop();
        await _explBoss.play(AssetSource('sounds/explosion_jefe.mp3'),volume:1.0);}
      else{final p=AudioPlayer();
        await p.play(AssetSource('sounds/explosion.mp3'),volume:0.5);
        p.onPlayerComplete.listen((_)=>p.dispose());}
    }catch(_){}
  }
  Future<void> startAlarm() async {
    if(_alarmOn)return; _alarmOn=true;
    try{await _alarm.setReleaseMode(ReleaseMode.loop);
      await _alarm.play(AssetSource('sounds/quench.wav'),volume:0.45);}catch(_){}
  }
  Future<void> stopAlarm() async {
    _alarmOn=false; try{await _alarm.stop();}catch(_){}
  }
  Future<void> playQuench() async {
    try{await _quenchSfx.play(AssetSource('sounds/explosion_jefe.mp3'),volume:1.0);}catch(_){}
  }
  void dispose(){
    for(final p in _laserPool)p.dispose();
    _bg.dispose();_bossMusic.dispose();_explBoss.dispose();_quenchSfx.dispose();_alarm.dispose();
  }
}

// ── DATA MODELS ──────────────────────────────────────────
class PlayerBuild {
  double damage,fireRate,maxEnergy,cooling,shieldEfficiency;
  bool hasTripleShot; List<String> modules;
  PlayerBuild({this.damage=10,this.fireRate=1.0,this.maxEnergy=100,
               this.cooling=1.0,this.shieldEfficiency=1.0,this.hasTripleShot=false,
               List<String>? modules}):modules=modules??[];
}
class Player {
  double x,energy=100,heat=0; bool shieldActive=false; double shieldTimer=0;
  PlayerBuild build;
  Player(this.x,{PlayerBuild? build}):build=build??PlayerBuild(),energy=build?.maxEnergy??100;
}
class Enemy {
  double x,y,hp,maxHp,vx,vy; EnemyKind kind; bool dead=false;
  double hitFlash=0,actionTimer=0,animT=0;
  Enemy({required this.x,required this.y,required this.hp,
         required this.vx,this.vy=90,this.kind=EnemyKind.interceptor}):maxHp=hp;
}
class Asteroid {
  double x,y,vx,vy,r,angle,spin; bool dead=false;
  Asteroid({required this.x,required this.y,required this.vx,required this.vy,
            required this.r}):angle=0,spin=(math_random.nextDouble()-0.5)*2;
  static final math_random=Random();
}
class Boss {
  double x,y,hp,maxHp,vx; bool dead=false;
  double hitFlash=0,animT=0,stateTimer=0,chargeGlow=0,burstTimer=0;
  int burstCount=0; BossState state=BossState.moving;
  // Stage 4 special: repel meter
  double repelMeter=0; // 0→1, when 1 → victory
  static const double moveTime=3.0,chargeTime=kBossChargeTime,cooldownTime=2.8;
  Boss({required this.x,required this.y,required this.hp,this.vx=75}):maxHp=hp;
}
class Bullet {
  double x,y,damage,angle; bool isEnemy,fromBoss;
  Bullet(this.x,this.y,this.damage,{this.isEnemy=false,this.angle=0,this.fromBoss=false});
}
class PowerUp {
  double x,y,animT; PowerUpKind kind; bool collected;
  PowerUp(this.x,this.y,this.kind):animT=0,collected=false;
}
class FloatingText {
  double x,y,life; String text; Color color;
  FloatingText(this.x,this.y,this.text,this.color):life=1.0;
}
class Particle {
  double x,y,vx,vy,life,maxLife,size; Color color; bool isFrost;
  Particle({required this.x,required this.y,required this.vx,required this.vy,
            required this.life,required this.color,this.size=4,this.isFrost=false}):maxLife=life;
}
class UpgradeOption {
  final String title,description,emoji; final Color color;
  final void Function(PlayerBuild) apply;
  const UpgradeOption({required this.title,required this.description,
      required this.emoji,required this.color,required this.apply});
}

// ── PHASE ENGINE ─────────────────────────────────────────
class PhaseEngine {
  GamePhase phase=GamePhase.combat; double timer=0; int cycleCount=0;
  void update(double dt,{required VoidCallback onDecision,required VoidCallback onBoss}){
    timer+=dt;
    if(phase==GamePhase.combat&&timer>=kCombatDuration){
      cycleCount++;timer=0;
      if(cycleCount%3==0){phase=GamePhase.boss;onBoss();}
      else{phase=GamePhase.decision;onDecision();}
    }
  }
  void endDecision(){phase=GamePhase.combat;timer=0;}
  void endBoss(){phase=GamePhase.combat;timer=0;}
  double get combatProgress=>phase==GamePhase.combat?(timer/kCombatDuration).clamp(0,1):1.0;
}

// ── RESOURCE SYSTEM ──────────────────────────────────────
class ResourceSystem {
  double energy=100,heat=0,entropy=0;
  void update(double dt,PlayerBuild b){
    heat=(heat-10*b.cooling*dt).clamp(0,100);
    energy=(energy+4*dt).clamp(0,b.maxEnergy);
    entropy=(entropy+0.3*dt).clamp(0,100);
    if(heat>97)energy-=4*dt;
  }
  void applyShoot(PlayerBuild b){energy-=1.5;entropy+=0.15;}
  void applyDamageHeat(double f){heat=(heat+f*100).clamp(0,100);}
  bool   get overheating=>heat>92;
  double get heatFrac   =>heat/100;
  double get energyFrac =>(energy/100).clamp(0,1);
  double get entropyFrac=>entropy/100;
}

// ── AI ADAPT ─────────────────────────────────────────────
class AIAdapt {
  double aggression=1.0,swarmDensity=1.0,counterFire=0.5;
  void analyze(PlayerBuild b,int stageNum){
    final sBonus=(stageNum-1)*0.15;
    if(b.damage>15)    aggression   =(aggression+0.18+sBonus).clamp(1,4);
    if(b.fireRate>1.5) swarmDensity =(swarmDensity+0.22+sBonus).clamp(1,4);
    counterFire=(counterFire+0.1*stageNum).clamp(0.5,3);
  }
  double spawnInterval(int c,int s)=>(2.0-c*0.12-(s-1)*0.1).clamp(0.4,2.0)/aggression;
  int    waveSize(int c,int s)=>(1+(c*0.45+swarmDensity*0.4+(s-1)*0.5)).floor().clamp(1,7);
}

// ── CHARGE INDICATOR ─────────────────────────────────────
class ChargeIndicator {
  final String icon; final Color color;
  double chargeTime,current=0; bool ready=false,active=false; double activeTimer=0;
  final double activeDuration;
  ChargeIndicator({required this.icon,required this.color,required this.chargeTime,required this.activeDuration});
  void update(double dt){
    if(active){activeTimer-=dt;if(activeTimer<=0){active=false;activeTimer=0;current=0;ready=false;}}
    else if(!ready){current=(current+dt).clamp(0,chargeTime);if(current>=chargeTime)ready=true;}
  }
  void consume(){if(ready&&!active){active=true;activeTimer=activeDuration;}}
  double get fraction=>ready?1.0:current/chargeTime;
}

// ── SPRITE CACHE ─────────────────────────────────────────
class SpriteCache {
  ui.Image? player,boss,boss2,boss3,boss4,enemy1,enemy2,enemy3,enemy4;
  bool loaded=false;

  Future<void> load() async {
    try {
      player = await _load('assets/images/player.png');
      boss   = await _load('assets/images/boss.png');
      enemy1 = await _load('assets/images/enemy1.png');
      enemy2 = await _load('assets/images/enemy2.png');
      enemy3 = await _load('assets/images/enemy3.png');
      enemy4 = await _load('assets/images/enemy4.png');
      // Load new bosses — optional, fallback to shapes if missing
      try { boss2 = await _load('assets/images/jefe2.png'); } catch(_){}
      try { boss3 = await _load('assets/images/jefe3.png'); } catch(_){}
      try { boss4 = await _load('assets/images/jefe4.png'); } catch(_){}
      loaded=true;
    } catch(_){loaded=false;}
  }

  Future<ui.Image> _load(String path) async {
    final data=await rootBundle.load(path);
    final codec=await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  ui.Image? enemyImg(EnemyKind k)=>switch(k){
    EnemyKind.interceptor=>enemy1,EnemyKind.frigate=>enemy2,
    EnemyKind.parasite=>enemy3,EnemyKind.corrupter=>enemy4};

  ui.Image? bossImg(int stageNum)=>switch(stageNum){
    1=>boss, 2=>boss2, 3=>boss3, 4=>boss4, _=>boss};
}

// ── SPRITE DRAW (no checkered background) ────────────────
void drawSprite(Canvas canvas, ui.Image img, Offset center, double size,
    {double flash=0}) {
  final src=Rect.fromLTWH(0,0,img.width.toDouble(),img.height.toDouble());
  final dst=Rect.fromCenter(center:center,width:size,height:size);
  canvas.drawImageRect(img,src,dst,
      Paint()..filterQuality=FilterQuality.high..isAntiAlias=true);
  if(flash>0){
    canvas.drawImageRect(img,src,dst,
        Paint()..filterQuality=FilterQuality.high
          ..colorFilter=ColorFilter.mode(Colors.white.withOpacity(flash*0.65),BlendMode.srcATop));
  }
}

// ── APP ROOT ─────────────────────────────────────────────
class PhoenixCoreApp extends StatelessWidget {
  const PhoenixCoreApp({super.key});
  @override Widget build(BuildContext ctx)=>MaterialApp(
      debugShowCheckedModeBanner:false,theme:ThemeData.dark(),home:const AppRoot());
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});
  @override State<AppRoot> createState()=>_AppRootState();
}

class _AppRootState extends State<AppRoot> {
  AppScreen _screen=AppScreen.intro;
  int _score=0,_best=0,_currentStage=1;
  final _audio  =AudioManager();
  final _sprites=SpriteCache();
  PlayerBuild? _carryBuild; // carry build between stages

  @override void initState(){
    super.initState();
    SharedPreferences.getInstance().then((p)=>setState(()=>_best=p.getInt('best_v4')??0));
    _sprites.load().then((_){if(mounted)setState((){});});
    WidgetsBinding.instance.addPostFrameCallback((_)=>_audio.startAmbient());
  }
  @override void dispose(){_audio.dispose();super.dispose();}

  void _onIntroDone()=>setState(()=>_screen=AppScreen.menu);
  void _start(){
    _currentStage=1; _carryBuild=null; _score=0;
    setState(()=>_screen=AppScreen.playing);
  }
  void _onStageClear(int score,PlayerBuild build){
    _score=score; _carryBuild=build;
    if(_currentStage>=4){
      _saveScore(_score);
      setState(()=>_screen=AppScreen.victory);
    } else {
      setState(()=>_screen=AppScreen.stageClear);
    }
  }
  void _onCinematicDone(){
    _currentStage++;
    setState(()=>_screen=AppScreen.playing);
  }
  void _gameOver(int score){
    _audio.switchToAmbient();
    _saveScore(score);
    setState((){_score=score;_screen=AppScreen.gameOver;});
  }
  void _saveScore(int score) async {
    if(score>_best){_best=score;final p=await SharedPreferences.getInstance();await p.setInt('best_v4',_best);}
  }

  @override Widget build(BuildContext ctx)=>switch(_screen){
    AppScreen.intro      => CinematicScreen(scenes:_introScenes,onDone:_onIntroDone),
    AppScreen.menu       => MenuScreen(best:_best,onStart:_start,sprites:_sprites),
    AppScreen.playing    => GameScreen(
        key:ValueKey('stage$_currentStage'),
        stageConfig:_stages[_currentStage-1],
        initialBuild:_carryBuild,
        initialScore:_score,
        onStageClear:_onStageClear,
        onGameOver:_gameOver,
        audio:_audio,sprites:_sprites),
    AppScreen.stageClear => StageClearScreen(
        stageNum:_currentStage,
        nextStageScenes:_stages[_currentStage].scenes,
        onContinue:()=>setState(()=>_screen=AppScreen.cinematic)),
    AppScreen.cinematic  => CinematicScreen(
        scenes:_stages[_currentStage].scenes,
        onDone:_onCinematicDone),
    AppScreen.gameOver   => GameOverScreen(score:_score,best:_best,
        onRestart:_start,
        onMenu:()=>setState(()=>_screen=AppScreen.menu)),
    AppScreen.victory    => VictoryScreen(score:_score,best:_best,
        onMenu:()=>setState(()=>_screen=AppScreen.menu)),
  };
}

// ── CINEMATIC SCREEN (reusable) ──────────────────────────
class CinematicScreen extends StatefulWidget {
  final List<CinematicScene> scenes;
  final VoidCallback onDone;
  const CinematicScreen({super.key,required this.scenes,required this.onDone});
  @override State<CinematicScreen> createState()=>_CinematicScreenState();
}
class _CinematicScreenState extends State<CinematicScreen> with SingleTickerProviderStateMixin {
  int _idx=0,_ci=0; String _disp=''; bool _full=false;
  late AnimationController _tc;

  @override void initState(){super.initState();
    _tc=AnimationController(vsync:this,duration:const Duration(milliseconds:32));
    _tc.addListener(_tick);_startScene();}
  void _startScene(){_ci=0;_disp='';_full=false;_tc.repeat();}
  void _tick(){final f=widget.scenes[_idx].dialogue;
    if(_ci<f.length){setState((){_ci++;_disp=f.substring(0,_ci);});}
    else{_tc.stop();setState(()=>_full=true);}}
  void _next(){
    if(!_full){_tc.stop();setState((){_disp=widget.scenes[_idx].dialogue;_full=true;});return;}
    if(_idx<widget.scenes.length-1){setState(()=>_idx++);_startScene();}
    else widget.onDone();}
  @override void dispose(){_tc.dispose();super.dispose();}
  Color _sc(String s)=>switch(s){'gold'=>cGold,'ice'=>cIce,'red'=>cDanger,_=>Colors.white};

  @override Widget build(BuildContext ctx){
    final s=widget.scenes[_idx];final sc=_sc(s.speakerColor);
    final size=MediaQuery.of(ctx).size;
    return Scaffold(backgroundColor:Colors.black,
      body:GestureDetector(onTapDown:(_)=>_next(),
        child:Column(children:[
          Expanded(flex:55,child:Stack(children:[
            Positioned.fill(child:Image.asset(s.imageAsset,fit:BoxFit.cover,
                errorBuilder:(_,__,___)=>Container(color:const Color(0xFF050A14),
                    child:const Center(child:Icon(Icons.image_not_supported,color:Colors.white24,size:48))))),
            Positioned(bottom:0,left:0,right:0,height:80,child:Container(
                decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,
                    end:Alignment.bottomCenter,colors:[Colors.transparent,Colors.black.withOpacity(0.9)])))),
            Positioned(top:MediaQuery.of(ctx).padding.top+10,left:12,right:80,
              child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:5),
                decoration:BoxDecoration(color:Colors.black.withOpacity(0.75),
                    border:Border.all(color:cGold.withOpacity(0.6)),borderRadius:BorderRadius.circular(3)),
                child:Text(s.location,style:const TextStyle(color:cGold,fontSize:9,fontFamily:'Orbitron',letterSpacing:1.5)))),
            Positioned(top:MediaQuery.of(ctx).padding.top+10,right:12,
              child:Text('${_idx+1}/${widget.scenes.length}',
                  style:const TextStyle(color:Colors.white38,fontSize:10,fontFamily:'Orbitron'))),
          ])),
          Container(constraints:BoxConstraints(minHeight:size.height*0.32),
            padding:const EdgeInsets.fromLTRB(20,14,20,28),
            decoration:BoxDecoration(color:Colors.black,
                border:Border(top:BorderSide(color:sc.withOpacity(0.5),width:1.5))),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
              if(s.speaker.isNotEmpty)...[
                Row(children:[
                  Container(width:3,height:14,decoration:BoxDecoration(color:sc,boxShadow:[BoxShadow(color:sc,blurRadius:5)])),
                  const SizedBox(width:8),
                  Expanded(child:Text(s.speaker,style:TextStyle(color:sc,fontSize:11,fontFamily:'Orbitron',fontWeight:FontWeight.bold))),
                ]),const SizedBox(height:10),
              ],
              Text(_disp,style:const TextStyle(color:Colors.white,fontSize:13,height:1.55,fontFamily:'Orbitron')),
              const SizedBox(height:14),
              Row(mainAxisAlignment:MainAxisAlignment.end,children:[
                if(_full)Row(children:[
                  Text(_idx==widget.scenes.length-1?'CONTINUAR':'SIGUIENTE',
                      style:TextStyle(color:sc,fontSize:10,fontFamily:'Orbitron',letterSpacing:1.5)),
                  const SizedBox(width:6),
                  Icon(Icons.arrow_forward_ios,color:sc,size:14),
                ])else Text('toca para continuar',
                    style:const TextStyle(color:Colors.white24,fontSize:9,fontFamily:'Orbitron')),
              ]),
            ])),
        ])));
  }
}

// ── STAGE CLEAR SCREEN ───────────────────────────────────
class StageClearScreen extends StatefulWidget {
  final int stageNum;
  final List<CinematicScene> nextStageScenes;
  final VoidCallback onContinue;
  const StageClearScreen({super.key,required this.stageNum,required this.nextStageScenes,required this.onContinue});
  @override State<StageClearScreen> createState()=>_StageClearScreenState();
}
class _StageClearScreenState extends State<StageClearScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl; late Animation<double> _anim;
  @override void initState(){super.initState();
    _ctrl=AnimationController(vsync:this,duration:const Duration(milliseconds:800))..forward();
    _anim=CurvedAnimation(parent:_ctrl,curve:Curves.elasticOut);
    hapticHeavy();}
  @override void dispose(){_ctrl.dispose();super.dispose();}

  @override Widget build(BuildContext ctx)=>Scaffold(backgroundColor:cBg,
    body:SafeArea(child:Center(child:ScaleTransition(scale:_anim,child:Column(
      mainAxisAlignment:MainAxisAlignment.center,children:[
        const Text('✦',style:TextStyle(color:cGold,fontSize:64,shadows:[Shadow(color:cGold,blurRadius:30)])),
        const SizedBox(height:16),
        _GlowText('STAGE ${widget.stageNum}',color:cIce,size:22),
        const SizedBox(height:8),
        _GlowText('COMPLETADO',color:cGold,size:38),
        const SizedBox(height:8),
        _GlowText(_stages[widget.stageNum-1].name,color:Colors.white54,size:13),
        const SizedBox(height:48),
        _GlowText('PREPARANDO STAGE ${widget.stageNum+1}',color:cIce,size:14),
        const SizedBox(height:8),
        _GlowText(_stages[widget.stageNum].name,color:cFire,size:16),
        const SizedBox(height:48),
        _Btn(label:'VER BRIEFING',color:cGold,onTap:widget.onContinue),
      ])))));
}

// ── VICTORY SCREEN ───────────────────────────────────────
class VictoryScreen extends StatelessWidget {
  final int score,best; final VoidCallback onMenu;
  const VictoryScreen({super.key,required this.score,required this.best,required this.onMenu});
  @override Widget build(BuildContext ctx)=>Scaffold(backgroundColor:cBg,
    body:SafeArea(child:Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      const Text('🏆',style:TextStyle(fontSize:80)),const SizedBox(height:16),
      _GlowText('VICTORIA GALÁCTICA',color:cGold,size:26),const SizedBox(height:8),
      _GlowText('La puerta dimensional fue cerrada…',color:Colors.white70,size:13),
      _GlowText('por ahora.',color:cIce,size:16),const SizedBox(height:8),
      _GlowText('COMANDANTE DE LAS FUERZAS GALÁCTICAS',color:cGold,size:11),
      const SizedBox(height:32),
      _GlowText('SCORE FINAL: $score',color:cGold,size:24),
      _GlowText('MEJOR: $best',color:Colors.white38,size:13),
      const SizedBox(height:48),
      _Btn(label:'MENÚ PRINCIPAL',color:cIce,onTap:onMenu),
    ]))));
}

// ── GAME SCREEN ──────────────────────────────────────────
class GameScreen extends StatefulWidget {
  final StageConfig stageConfig;
  final PlayerBuild? initialBuild;
  final int initialScore;
  final void Function(int,PlayerBuild) onStageClear;
  final void Function(int) onGameOver;
  final AudioManager audio;
  final SpriteCache sprites;
  const GameScreen({super.key,required this.stageConfig,required this.initialBuild,
      required this.initialScore,required this.onStageClear,required this.onGameOver,
      required this.audio,required this.sprites});
  @override State<GameScreen> createState()=>_GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  final _rng=Random();
  AudioManager  get _audio  =>widget.audio;
  SpriteCache   get _sprites=>widget.sprites;
  StageConfig   get _stage  =>widget.stageConfig;

  double _sw=0,_sh=0;
  late Player _player;
  final _res  =ResourceSystem();
  final _phase=PhaseEngine();
  late AIAdapt _ai;

  final _enemies   =<Enemy>[];
  final _bullets   =<Bullet>[];
  final _powerUps  =<PowerUp>[];
  final _particles =<Particle>[];
  final _floats    =<FloatingText>[];
  final _asteroids =<Asteroid>[];

  Boss?  _boss; bool _bossAlive=false;
  int    _score=0;
  double _coreTemp=0,_nucleusIFrame=0;
  double _shootTimer=0,_spawnTimer=0,_powerUpTimer=25.0;
  bool   _touching=false,_alarmOn=false; double _touchX=0;
  bool   _showDecision=false; List<UpgradeOption> _options=[];
  bool   _frosting=false,_quenching=false;
  double _frostT=0,_quenchT=0,_corePulse=0,_pulseDir=1;

  // Stage 3 — gravity timer
  double _gravityTimer=90.0;
  bool   _gravityWarning=false;

  // Stage 4 — portal & repel
  double _portalGrow=0.0; // 0→1
  bool   _mirrorVictory=false;
  double _mirrorVictoryT=0;

  // Asteroid spawn timer
  double _asteroidTimer=0;

  final _machineGun=ChargeIndicator(icon:'⚡',color:cGold,chargeTime:28.0,activeDuration:8.0);
  final _freeze    =ChargeIndicator(icon:'❄',color:cIce, chargeTime:38.0,activeDuration:6.0);

  Ticker?  _ticker; Duration _lastElapsed=Duration.zero;

  @override void initState(){
    super.initState();
    _score=widget.initialScore;
    _ai=AIAdapt();
    WidgetsBinding.instance.addPostFrameCallback((_){
      final sz=MediaQuery.of(context).size; _sw=sz.width; _sh=sz.height;
      // Carry build from previous stage
      final b=widget.initialBuild ?? PlayerBuild();
      _player=Player(_sw/2,build:b);
      _res.energy=_player.build.maxEnergy;
      _ticker=createTicker(_tick)..start();
    });
  }
  @override void dispose(){_ticker?.dispose();super.dispose();}

  void _tick(Duration elapsed){
    final dt=((elapsed-_lastElapsed).inMicroseconds/1e6).clamp(0.0,0.05).toDouble();
    _lastElapsed=elapsed;
    if(dt==0||!mounted)return;
    _update(dt);
  }

  void _update(double dt){
    if(_mirrorVictory){
      _mirrorVictoryT+=dt;_updateParticles(dt);
      if(_mirrorVictoryT>3.0) widget.onStageClear(_score,_player.build);
      if(mounted)setState((){});return;
    }
    if(_quenching){
      _quenchT+=dt;_updateParticles(dt);
      if(_quenchT>2.5)widget.onGameOver(_score);
      if(mounted)setState((){});return;
    }
    if(_frosting){
      _frostT+=dt*0.55;_spawnFrostParticles();
      _updateParticles(dt);_updateFloats(dt);
      if(_frostT>=1.0){_frosting=false;_quenching=true;
        _audio.stopAlarm();_audio.playQuench();_spawnQuenchExplosion();}
      if(mounted)setState((){});return;
    }
    if(_showDecision){if(mounted)setState((){});return;}

    _corePulse+=_pulseDir*dt*2.2;
    if(_corePulse>1)_pulseDir=-1;if(_corePulse<0)_pulseDir=1;

    _phase.update(dt,onDecision:_triggerDecision,onBoss:_triggerBoss);
    _res.update(dt,_player.build);
    _player.energy=_res.energy;_player.heat=_res.heat;

    if(_nucleusIFrame>0)_nucleusIFrame=(_nucleusIFrame-dt).clamp(0,kNucleusIFrame);
    _machineGun.update(dt);_freeze.update(dt);

    // Stage 3: gravity timer
    if(_stage.hazard==StageHazard.gravityTimer&&!_bossAlive){
      _gravityTimer-=dt;
      _gravityWarning=_gravityTimer<30;
      if(_gravityTimer<=0)_beginFrost();
    }

    // Stage 4: portal grows — force-game-over if reaches 1
    if(_stage.hazard==StageHazard.mirrorPortal){
      if(_bossAlive){_portalGrow+=dt*0.004;}
      if(_portalGrow>=1.0)_beginFrost();
    }

    // Stage 2: spawn asteroids
    if(_stage.hazard==StageHazard.asteroids){
      _asteroidTimer-=dt;
      if(_asteroidTimer<=0){_asteroidTimer=4+_rng.nextDouble()*4;_spawnAsteroid();}
      _updateAsteroids(dt);
    }

    if(_res.heatFrac>=0.8&&!_alarmOn){_alarmOn=true;_audio.startAlarm();}
    else if(_res.heatFrac<0.75&&_alarmOn){_alarmOn=false;_audio.stopAlarm();}

    if(_player.shieldActive){_player.shieldTimer-=dt;if(_player.shieldTimer<=0)_player.shieldActive=false;}

    if(_touching){
      _player.x+=(_touchX-_player.x)*14*dt;
      _player.x=_player.x.clamp(kPhoenixSize,_sw-kPhoenixSize);
    }

    final effRate=_machineGun.active?_player.build.fireRate*2.2:_player.build.fireRate;
    if(_touching&&_res.energy>0){
      _shootTimer-=dt;
      if(_shootTimer<=0){_shootTimer=0.14/effRate;_fireLaser();}
    }

    for(final b in _bullets){
      if(b.isEnemy){b.y+=360*dt;}
      else{b.x+=sin(b.angle)*560*dt;b.y-=cos(b.angle)*560*dt;}
    }
    _bullets.removeWhere((b)=>b.y<-30||b.y>_sh+30||b.x<-30||b.x>_sw+30);

    _powerUpTimer-=dt;
    if(_powerUpTimer<=0){_powerUpTimer=22+_rng.nextDouble()*14;_spawnPowerUp();}
    _updatePowerUps(dt);

    if(_phase.phase==GamePhase.combat&&!_bossAlive){
      _spawnTimer-=dt;
      if(_spawnTimer<=0){
        _spawnTimer=_ai.spawnInterval(_phase.cycleCount,_stage.stageNum);
        final n=_ai.waveSize(_phase.cycleCount,_stage.stageNum);
        for(int i=0;i<n;i++)_spawnEnemy();
      }
    }

    _updateEnemies(dt);
    if(_bossAlive&&_boss!=null)_updateBoss(dt);
    _resolveCollisions();

    _coreTemp=(_coreTemp-0.004*dt).clamp(0,1);
    if(_coreTemp>=1.0&&!_frosting&&!_quenching)_beginFrost();

    _updateParticles(dt);_updateFloats(dt);
    if(mounted)setState((){});
  }

  void _fireLaser(){
    _res.applyShoot(_player.build);
    final isTriple=_player.build.hasTripleShot||_player.build.fireRate>1.8;
    _audio.playLaser(triple:isTriple);
    final py=_sh*0.72-kPhoenixSize;
    if(isTriple){
      _bullets.add(Bullet(_player.x,py,_player.build.damage,angle:0));
      _bullets.add(Bullet(_player.x,py,_player.build.damage*0.7,angle:-0.13));
      _bullets.add(Bullet(_player.x,py,_player.build.damage*0.7,angle:0.13));
    } else {
      _bullets.add(Bullet(_player.x,py,_player.build.damage));
    }
  }

  void _spawnAsteroid(){
    final r=18+_rng.nextDouble()*22;
    _asteroids.add(Asteroid(
      x:20+_rng.nextDouble()*(_sw-40),y:-r,
      vx:(_rng.nextBool()?1:-1)*(20+_rng.nextDouble()*40),
      vy:60+_rng.nextDouble()*50,r:r));
  }

  void _updateAsteroids(double dt){
    for(final a in _asteroids){
      if(a.dead)continue;
      a.x+=a.vx*dt;a.y+=a.vy*dt;a.angle+=a.spin*dt;
      if(a.x<a.r||a.x>_sw-a.r){a.vx*=-1;}
      // Hit player
      final px=_player.x,py=_sh*0.72;
      if((a.x-px).abs()<a.r+kPhoenixSize*0.8&&(a.y-py).abs()<a.r+kPhoenixSize*0.8){
        a.dead=true;
        if(!_player.shieldActive){
          _res.applyDamageHeat(0.08);_coreTemp+=0.05;
          hapticMedium();
          _spawnBurst(px,py,cFire,10);_addFloat(px,py-20,'ASTEROIDE!',cFire);
        }
      }
      // Hit nucleus
      final nx=_sw/2,ny=_sh*0.87;
      if((a.x-nx).abs()<a.r+kNucleusR&&(a.y-ny).abs()<a.r+kNucleusR){
        a.dead=true;
        if(_nucleusIFrame<=0){
          _nucleusIFrame=kNucleusIFrame;
          _res.applyDamageHeat(kCoreHeatPerHit*1.5);_coreTemp+=kCoreHeatPerHit*1.5;
          hapticHeavy();
          _addFloat(nx,ny-20,'NÚCLEO HIT!',cDanger);_spawnBurst(nx,ny,cDanger,8);
        }
      }
      if(a.y>_sh+a.r)a.dead=true;
    }
    _asteroids.removeWhere((a)=>a.dead);
    // Player bullets can destroy asteroids
    final rem=<Bullet>{};
    for(final b in _bullets){
      if(b.isEnemy)continue;
      for(final a in _asteroids){
        if(a.dead)continue;
        if((b.x-a.x).abs()<a.r&&(b.y-a.y).abs()<a.r){
          rem.add(b);a.dead=true;_score+=25;
          _spawnBurst(a.x,a.y,Colors.grey,8);
          _addFloat(a.x,a.y-10,'+25',Colors.grey.shade300);
          break;
        }
      }
    }
    _bullets.removeWhere((b)=>rem.contains(b));
  }

  void _spawnPowerUp(){
    final c=_phase.cycleCount;
    final av=[PowerUpKind.energyBoost];
    if(c>=1){av.add(PowerUpKind.rapidFire);av.add(PowerUpKind.shield);}
    if(c>=2)av.add(PowerUpKind.tripleShot);
    if(c>=3)av.add(PowerUpKind.coreArmor);
    _powerUps.add(PowerUp(20+_rng.nextDouble()*(_sw-40),-30,av[_rng.nextInt(av.length)]));
  }

  void _updatePowerUps(double dt){
    for(final p in _powerUps){
      p.y+=65*dt;p.animT+=dt*3;
      if(!p.collected&&(p.x-_player.x).abs()<40&&(p.y-_sh*0.72).abs()<40){
        p.collected=true;_applyPowerUp(p.kind);
        hapticLight();
        _spawnBurst(p.x,p.y,_puColor(p.kind),18);
        _addFloat(p.x,p.y-10,_puLabel(p.kind),_puColor(p.kind));
      }
    }
    _powerUps.removeWhere((p)=>p.y>_sh+40||p.collected);
  }

  void _applyPowerUp(PowerUpKind k){
    switch(k){
      case PowerUpKind.rapidFire:
        _player.build.fireRate=(_player.build.fireRate*1.35).clamp(1.0,2.8);
      case PowerUpKind.tripleShot:
        _player.build.hasTripleShot=true;
        _player.build.fireRate=(_player.build.fireRate*1.1).clamp(1.0,2.8);
      case PowerUpKind.shield:
        _player.shieldActive=true;_player.shieldTimer=10.0;
      case PowerUpKind.coreArmor:
        _coreTemp=(_coreTemp-0.22).clamp(0,1);_res.heat=(_res.heat-30).clamp(0,100);
      case PowerUpKind.energyBoost:
        _res.energy=(_res.energy+35).clamp(0,_player.build.maxEnergy);
        _res.heat=(_res.heat-25).clamp(0,100);
    }
  }
  Color  _puColor(PowerUpKind k)=>switch(k){PowerUpKind.rapidFire=>cFire,PowerUpKind.tripleShot=>cGold,PowerUpKind.shield=>cShield,PowerUpKind.coreArmor=>cIce,PowerUpKind.energyBoost=>cGreen};
  String _puLabel(PowerUpKind k)=>switch(k){PowerUpKind.rapidFire=>'⚡ RAPID FIRE',PowerUpKind.tripleShot=>'💥 TRIPLE SHOT',PowerUpKind.shield=>'🛡 ESCUDO',PowerUpKind.coreArmor=>'❄ CORE ARMOR',PowerUpKind.energyBoost=>'💚 ENERGÍA +35'};

  void _spawnEnemy(){
    final c=_phase.cycleCount;final s=_stage.stageNum;final r=_rng.nextDouble();
    EnemyKind k;
    if(c==0&&s==1) k=EnemyKind.interceptor;
    else if(c<=1&&s<=2) k=r<0.55?EnemyKind.interceptor:EnemyKind.frigate;
    else if(c<=2) k=r<0.35?EnemyKind.interceptor:r<0.65?EnemyKind.frigate:EnemyKind.parasite;
    else k=r<0.28?EnemyKind.interceptor:r<0.52?EnemyKind.frigate:r<0.76?EnemyKind.parasite:EnemyKind.corrupter;
    final base=18.0+c*6+(s-1)*8;
    final hp=k==EnemyKind.parasite?base*1.6:k==EnemyKind.frigate?base*0.85:base;
    _enemies.add(Enemy(
      x:20+_rng.nextDouble()*(_sw-40),y:-kEnemyR,hp:hp,
      vx:(_rng.nextBool()?1:-1)*(55+_rng.nextDouble()*65+(s-1)*10),
      vy:70+c*4.5+_rng.nextDouble()*18+(s-1)*6,kind:k));
  }

  void _updateEnemies(double dt){
    for(final e in _enemies){
      if(e.dead)continue;
      if(e.hitFlash>0)e.hitFlash-=dt*5;e.animT+=dt*2;
      switch(e.kind){
        case EnemyKind.interceptor:
          e.x+=e.vx*dt;e.y+=e.vy*dt;
          if(e.x<kEnemyR||e.x>_sw-kEnemyR)e.vx*=-1;
        case EnemyKind.frigate:
          e.y=(e.y+e.vy*dt*0.4).clamp(-kEnemyR,_sh*0.25);
          e.x+=e.vx*dt;if(e.x<kEnemyR||e.x>_sw-kEnemyR)e.vx*=-1;
          e.actionTimer+=dt;
          if(e.actionTimer>1.5/_ai.counterFire){
            e.actionTimer=0;_bullets.add(Bullet(e.x,e.y+kEnemyR,9,isEnemy:true));}
        case EnemyKind.parasite:
          e.x+=(_player.x-e.x).sign*48*dt;e.y+=e.vy*dt*0.6;
          if((e.x-_player.x).abs()<40&&(e.y-_sh*0.72).abs()<40){
            _res.energy-=11*dt;
            if(_rng.nextDouble()<0.08)_particles.add(Particle(x:e.x,y:e.y,
                vx:(_player.x-e.x)*1.5,vy:(_sh*0.72-e.y)*1.5,life:0.4,color:cShield,size:5));}
        case EnemyKind.corrupter:
          e.x+=e.vx*dt;e.y+=e.vy*dt;
          if(e.x<kEnemyR||e.x>_sw-kEnemyR)e.vx*=-1;
          if(e.y>_sh*0.65){_res.heat+=5*dt;_addFloat(e.x,e.y,'+HEAT',cDanger);}
      }
      if(e.y>_sh*0.87){
        e.dead=true;_spawnBurst(e.x,e.y,cFire,10);_audio.playExplosion();
        if(!_player.shieldActive){
          _res.applyDamageHeat(kCoreHeatPerPass);_coreTemp+=kCoreHeatPerPass;
          hapticMedium();
          _addFloat(_sw/2,_sh*0.84,'NÚCLEO HIT',cDanger);
        }
      }
    }
    _enemies.removeWhere((e)=>e.dead&&e.hitFlash<=0);
  }

  void _updateBoss(double dt){
    final b=_boss!;if(b.dead)return;
    if(b.hitFlash>0)b.hitFlash-=dt*3;b.animT+=dt;

    // Stage 4 special: repel logic
    if(_stage.stageNum==4){
      // Boss slowly advances portal — player must push it back
      // Repel increases when player shoots boss
      // Already handled in resolveCollisions via repelMeter
      b.x+=b.vx*dt;b.y=_sh*0.16+sin(b.animT*0.8)*24;
      if(b.x<kBossR||b.x>_sw-kBossR)b.vx*=-1;
      if(b.repelMeter>=1.0){
        // Mirror victory — repelled!
        _mirrorVictory=true;
        hapticHeavy();
        _spawnBurst(b.x,b.y,cRed,50);
        _spawnBurst(_sw/2,_sh/2,cGold,40);
        _addFloat(_sw/2,_sh*0.4,'PORTAL CERRADO!',cGold);
        _audio.playExplosion(isBoss:true);
        _audio.switchToAmbient();
      }
    }

    switch(b.state){
      case BossState.moving:
        b.x+=b.vx*dt;b.y=_sh*0.16+sin(b.animT*0.8)*24;
        if(b.x<kBossR||b.x>_sw-kBossR)b.vx*=-1;
        b.stateTimer+=dt;
        if(b.stateTimer>=Boss.moveTime){b.state=BossState.charging;b.stateTimer=0;b.chargeGlow=0;}
      case BossState.charging:
        b.stateTimer+=dt;b.chargeGlow=(b.stateTimer/Boss.chargeTime).clamp(0,1);
        b.y=_sh*0.16+sin(b.animT*12)*3*b.chargeGlow;
        if(b.stateTimer>=Boss.chargeTime){b.state=BossState.firing;b.stateTimer=0;b.burstCount=0;b.burstTimer=0;}
      case BossState.firing:
        b.burstTimer+=dt;
        if(b.burstTimer>=0.5&&b.burstCount<3){b.burstTimer=0;b.burstCount++;_fireBossBurst(b);}
        if(b.burstCount>=3){b.state=BossState.cooldown;b.stateTimer=0;}
      case BossState.cooldown:
        b.x+=b.vx*dt;b.y=_sh*0.16;
        if(b.x<kBossR||b.x>_sw-kBossR)b.vx*=-1;
        b.stateTimer+=dt;b.chargeGlow=0;
        if(b.stateTimer>=Boss.cooldownTime){b.state=BossState.moving;b.stateTimer=0;}
    }
  }

  void _fireBossBurst(Boss b){
    final baseAngle=atan2(_player.x-b.x,_sh*0.5)*0.35;
    const spread=0.31;
    // Stage scaling: more bullets in later stages
    final bursts=_stage.stageNum>=3?4:3;
    final offsets=_stage.stageNum>=3
        ?[0.0,-spread,spread,-spread*0.5]
        :[0.0,-spread,spread];
    for(int i=0;i<bursts&&i<offsets.length;i++){
      _bullets.add(Bullet(b.x,b.y+kBossR,14+(_stage.stageNum-1)*3,
          isEnemy:true,fromBoss:true,angle:baseAngle+offsets[i]));
    }
  }

  void _resolveCollisions(){
    final rem=<Bullet>{};
    for(final bul in _bullets){
      if(bul.isEnemy){
        final px=_player.x,py=_sh*0.72;
        if((bul.x-px).abs()<kPhoenixSize&&(bul.y-py).abs()<kPhoenixSize){
          rem.add(bul);
          if(_player.shieldActive){
            _player.shieldActive=false;hapticLight();
            _spawnBurst(px,py,cShield,8);_addFloat(px,py-20,'ESCUDO!',cShield);
          }else{
            _res.energy-=bul.fromBoss?11:13;
            _res.applyDamageHeat(bul.fromBoss?0.045:0.06);
            _coreTemp+=bul.fromBoss?0.032:0.042;
            hapticMedium();
            _spawnBurst(px,py,cDanger,8);_addFloat(px,py-20,'-E',cDanger);
          }
        }
        final nx=_sw/2,ny=_sh*0.87;
        if(_nucleusIFrame<=0&&(bul.x-nx).abs()<kNucleusR&&(bul.y-ny).abs()<kNucleusR){
          rem.add(bul);_nucleusIFrame=kNucleusIFrame;
          _res.applyDamageHeat(bul.fromBoss?kBossBulletDmg:kCoreHeatPerHit);
          _coreTemp+=bul.fromBoss?kBossBulletDmg:kCoreHeatPerHit;
          hapticHeavy();
          _addFloat(nx,ny-20,'NÚCLEO!',cDanger);_spawnBurst(nx,ny,cDanger,6);
        }else if(_nucleusIFrame>0&&(bul.x-nx).abs()<kNucleusR&&(bul.y-ny).abs()<kNucleusR){
          rem.add(bul);_spawnBurst(bul.x,bul.y,cShield.withOpacity(0.5),4);
        }
      }else{
        bool hit=false;
        for(final e in _enemies){
          if(e.dead||hit)continue;
          if((bul.x-e.x).abs()<kEnemyR&&(bul.y-e.y).abs()<kEnemyR){
            rem.add(bul);hit=true;
            final dmg=_freeze.active?bul.damage*1.6:bul.damage;
            e.hp-=dmg;e.hitFlash=1.0;
            if(e.hp<=0){e.dead=true;_score+=_eScore(e.kind);
              _spawnBurst(e.x,e.y,_eColor(e.kind),16);_audio.playExplosion();
              _addFloat(e.x,e.y-10,'+${_eScore(e.kind)}',cGold);}
          }
        }
        if(!hit&&_bossAlive&&_boss!=null&&!_boss!.dead){
          final bo=_boss!;
          if((bul.x-bo.x).abs()<kBossR&&(bul.y-bo.y).abs()<kBossR){
            rem.add(bul);
            final dmg=_freeze.active?bul.damage*1.5:bul.damage;
            // Stage 4: repel instead of damage
            if(_stage.stageNum==4){
              bo.repelMeter=(bo.repelMeter+dmg/800).clamp(0,1);
              _score+=5;
              _addFloat(bo.x,bo.y+kBossR+10,'REPELIENDO ${(bo.repelMeter*100).toInt()}%',cRed);
            }else{
              bo.hp-=dmg;bo.hitFlash=1.0;_score+=_freeze.active?7:5;
              if(bo.hp<=0){
                bo.dead=true;_bossAlive=false;_score+=500+(_stage.stageNum-1)*200;
                _spawnBurst(bo.x,bo.y,cGold,40);_spawnBurst(bo.x-30,bo.y+20,cFire,20);
                _audio.playExplosion(isBoss:true);hapticHeavy();
                _addFloat(bo.x,bo.y,'+${500+(_stage.stageNum-1)*200} BOSS!',cGold);
                _phase.endBoss();_ai.analyze(_player.build,_stage.stageNum);_audio.switchToAmbient();
                // Stage clear check
                if(_phase.cycleCount>=3)_triggerStageClear();
              }
            }
          }
        }
      }
    }
    _bullets.removeWhere((b)=>rem.contains(b));
  }

  int   _eScore(EnemyKind k)=>switch(k){EnemyKind.interceptor=>100,EnemyKind.frigate=>150,EnemyKind.parasite=>200,EnemyKind.corrupter=>175};
  Color _eColor(EnemyKind k)=>switch(k){EnemyKind.interceptor=>cWarlord,EnemyKind.frigate=>cGreen,EnemyKind.parasite=>cShield,EnemyKind.corrupter=>const Color(0xFFFF6600)};

  void _triggerDecision(){_ai.analyze(_player.build,_stage.stageNum);_options=_buildOptions();_showDecision=true;}
  void _triggerBoss(){
    _enemies.clear();
    _boss=Boss(x:_sw/2,y:_sh*0.16,hp:_stage.bossHpBase+_phase.cycleCount*_stage.bossHpPerCycle);
    _bossAlive=true;_audio.switchToBoss();
    _addFloat(_sw/2,_sh*0.3,'⚠ ${_stage.bossName}',_stage.bossColor);
  }
  void _triggerStageClear(){
    _audio.stopAlarm();
    widget.onStageClear(_score,_player.build);
  }
  void _beginFrost(){if(_frosting||_quenching)return;_frosting=true;_coreTemp=1.0;_audio.stopAlarm();}
  void _spawnQuenchExplosion(){
    for(int i=0;i<80;i++){final a=_rng.nextDouble()*pi*2;final s=100+_rng.nextDouble()*320;
      _particles.add(Particle(x:_sw/2,y:_sh*0.87,vx:cos(a)*s,vy:sin(a)*s,
          life:1.2+_rng.nextDouble(),color:_rng.nextBool()?cFire:cIce,size:5+_rng.nextDouble()*12));}
  }
  void _spawnFrostParticles(){
    if(_rng.nextDouble()>0.3)return;
    final a=_rng.nextDouble()*pi*2;final r=kNucleusR+_rng.nextDouble()*60;
    _particles.add(Particle(x:_sw/2+cos(a)*r,y:_sh*0.87+sin(a)*r,
        vx:cos(a+pi)*40,vy:sin(a+pi)*40,
        life:0.8+_rng.nextDouble()*0.6,color:cFrost,size:3+_rng.nextDouble()*6,isFrost:true));
  }

  void _selectUpgrade(UpgradeOption opt){
    opt.apply(_player.build);
    _res.energy=(_res.energy+20).clamp(0,_player.build.maxEnergy);
    _showDecision=false;_phase.endDecision();
    // Check stage clear after boss was already defeated in this cycle
    if(!_bossAlive&&_phase.cycleCount>=3)_triggerStageClear();
  }

  List<UpgradeOption> _buildOptions(){
    final all=[
      UpgradeOption(title:'Plasma Overload',   description:'+40% daño',            emoji:'🔥',color:cFire,  apply:(b)=>b.damage*=1.4),
      UpgradeOption(title:'Cryo Stabilizer',   description:'Enfriamiento +60%',    emoji:'❄️',color:cIce,   apply:(b)=>b.cooling*=1.6),
      UpgradeOption(title:'Void Pulse',        description:'Cadencia +30%',        emoji:'⚡',color:cGold,  apply:(b)=>b.fireRate*=1.3),
      UpgradeOption(title:'Energy Core Expand',description:'Energía máxima +25',   emoji:'💙',color:cIce,   apply:(b)=>b.maxEnergy+=25),
      UpgradeOption(title:'Entropy Shield',    description:'Escudo 10 segundos',   emoji:'🛡️',color:cShield,apply:(b){b.shieldEfficiency+=0.4;}),
      UpgradeOption(title:'Triple Cannon',     description:'Disparo triple perm.', emoji:'💥',color:cFire,  apply:(b){b.hasTripleShot=true;b.fireRate=(b.fireRate*1.1).clamp(1,2.8);}),
      UpgradeOption(title:'Core Armor',        description:'Blindaje del núcleo',  emoji:'🔮',color:cShield,apply:(b)=>b.modules.add('core_armor')),
      UpgradeOption(title:'Phoenix Overdrive', description:'+20% daño y cadencia', emoji:'🦅',color:cGold,  apply:(b){b.damage*=1.2;b.fireRate*=1.2;}),
    ];
    all.shuffle(_rng);return all.take(3).toList();
  }

  void _spawnBurst(double x,double y,Color c,int n){
    for(int i=0;i<n;i++){final a=_rng.nextDouble()*pi*2;final s=40+_rng.nextDouble()*200;
      _particles.add(Particle(x:x,y:y,vx:cos(a)*s,vy:sin(a)*s,
          life:0.3+_rng.nextDouble()*0.6,color:c,size:2+_rng.nextDouble()*6));}
  }
  void _addFloat(double x,double y,String t,Color c)=>_floats.add(FloatingText(x,y,t,c));
  void _updateParticles(double dt){
    for(final p in _particles){p.x+=p.vx*dt;p.y+=p.vy*dt;if(!p.isFrost)p.vy+=40*dt;p.life-=dt;}
    _particles.removeWhere((p)=>p.life<=0);}
  void _updateFloats(double dt){
    for(final f in _floats){f.y-=55*dt;f.life-=dt*1.5;}
    _floats.removeWhere((f)=>f.life<=0);}

  void _onPanStart(DragStartDetails d){_touching=true;_touchX=d.localPosition.dx;}
  void _onPanUpdate(DragUpdateDetails d){_touchX=d.localPosition.dx;}
  void _onPanEnd(DragEndDetails _){_touching=false;}
  void _onTapDown(TapDownDetails d){_touching=true;_touchX=d.localPosition.dx;}
  void _onTapUp(TapUpDetails _){_touching=false;}
  void _onTapIndicator(bool isMG){
    if(isMG&&_machineGun.ready)_machineGun.consume();
    else if(!isMG&&_freeze.ready)_freeze.consume();
  }

  @override Widget build(BuildContext ctx){
    final sz=MediaQuery.of(ctx).size;_sw=sz.width;_sh=sz.height;
    final laserColor=Color.lerp(cIce,cGold,(_player.build.fireRate-1.0).clamp(0,1))!;
    final isTriple=_player.build.hasTripleShot||_player.build.fireRate>1.8;
    return Scaffold(backgroundColor:cBg,
      body:Stack(children:[
        GestureDetector(
          onPanStart:_onPanStart,onPanUpdate:_onPanUpdate,onPanEnd:_onPanEnd,
          onTapDown:_onTapDown,onTapUp:_onTapUp,
          child:CustomPaint(
            painter:GamePainter(sw:_sw,sh:_sh,player:_player,enemies:_enemies,
              bullets:_bullets,powerUps:_powerUps,boss:_bossAlive?_boss:null,
              particles:_particles,floats:_floats,score:_score,res:_res,phase:_phase,
              coreTemp:_coreTemp,corePulse:_corePulse,laserColor:laserColor,isTriple:isTriple,
              frosting:_frosting,frostT:_frostT,quenching:_quenching,quenchT:_quenchT,
              touching:_touching,sprites:_sprites,nucleusIFrame:_nucleusIFrame,
              freezeActive:_freeze.active,machineGunActive:_machineGun.active,
              stageNum:_stage.stageNum,bossColor:_stage.bossColor,
              asteroids:_asteroids,
              gravityTimer:_stage.hazard==StageHazard.gravityTimer?_gravityTimer:-1,
              portalGrow:_stage.hazard==StageHazard.mirrorPortal?_portalGrow:-1,
              mirrorVictory:_mirrorVictory,mirrorVictoryT:_mirrorVictoryT,
              repelMeter:_boss?.repelMeter??0,
              stageName:_stage.name),
            child:const SizedBox.expand())),
        // Charge rings
        Positioned(right:8,top:_sh*0.38,
          child:Column(children:[
            _ChargeRing(indicator:_machineGun,onTap:()=>_onTapIndicator(true)),
            const SizedBox(height:12),
            _ChargeRing(indicator:_freeze,onTap:()=>_onTapIndicator(false)),
          ])),
        if(_showDecision)_DecisionOverlay(options:_options,cycle:_phase.cycleCount,
            stageNum:_stage.stageNum,onSelect:_selectUpgrade),
        if(_phase.phase==GamePhase.boss&&_bossAlive)
          Positioned(top:8,left:0,right:0,
              child:Center(child:_GlowText('⚠ ${_stage.bossName} ⚠',color:_stage.bossColor,size:13))),
        if(isTriple)
          Positioned(bottom:_sh*0.14,right:20,child:_GlowText('💥 TRIPLE',color:cGold,size:11)),
        if(_machineGun.active)
          Positioned(bottom:_sh*0.16,left:20,child:_GlowText('⚡ RÁFAGA ${_machineGun.activeTimer.toStringAsFixed(1)}s',color:cGold,size:11)),
        if(_freeze.active)
          Positioned(bottom:_sh*0.18,left:20,child:_GlowText('❄ FREEZE ${_freeze.activeTimer.toStringAsFixed(1)}s',color:cIce,size:11)),
        // Stage 3 gravity warning
        if(_gravityWarning&&_stage.hazard==StageHazard.gravityTimer)
          Positioned(top:_sh*0.3,left:0,right:0,
              child:Center(child:_GlowText('⚠ GRAVEDAD: ${_gravityTimer.toInt()}s',color:cDanger,size:16))),
        // Stage 4 repel bar
        if(_stage.stageNum==4&&_bossAlive&&_boss!=null)
          Positioned(bottom:_sh*0.22,left:20,right:20,
              child:Column(children:[
                _GlowText('REPELER PORTAL ${(_boss!.repelMeter*100).toInt()}%',color:cRed,size:12),
                const SizedBox(height:4),
                ClipRRect(borderRadius:BorderRadius.circular(4),child:LinearProgressIndicator(
                    value:_boss!.repelMeter,backgroundColor:Colors.white12,
                    valueColor:AlwaysStoppedAnimation(cRed),minHeight:8)),
              ])),
      ]));
  }
}

// ── GAME PAINTER ─────────────────────────────────────────
class GamePainter extends CustomPainter {
  final double sw,sh,coreTemp,corePulse,frostT,quenchT,nucleusIFrame;
  final double gravityTimer,portalGrow,mirrorVictoryT,repelMeter;
  final bool frosting,quenching,touching,isTriple,freezeActive,machineGunActive,mirrorVictory;
  final Color laserColor,bossColor;
  final int stageNum;
  final String stageName;
  final Player player;
  final List<Enemy> enemies;
  final List<Bullet> bullets;
  final List<PowerUp> powerUps;
  final List<Asteroid> asteroids;
  final Boss? boss;
  final List<Particle> particles;
  final List<FloatingText> floats;
  final int score;
  final ResourceSystem res;
  final PhaseEngine phase;
  final SpriteCache sprites;

  const GamePainter({
    required this.sw,required this.sh,required this.player,
    required this.enemies,required this.bullets,required this.powerUps,
    required this.boss,required this.particles,required this.floats,
    required this.score,required this.res,required this.phase,
    required this.coreTemp,required this.corePulse,required this.laserColor,
    required this.isTriple,required this.frosting,required this.frostT,
    required this.quenching,required this.quenchT,required this.touching,
    required this.sprites,required this.nucleusIFrame,
    required this.freezeActive,required this.machineGunActive,
    required this.stageNum,required this.bossColor,required this.asteroids,
    required this.gravityTimer,required this.portalGrow,
    required this.mirrorVictory,required this.mirrorVictoryT,required this.repelMeter,
    required this.stageName,
  });

  @override void paint(Canvas canvas,Size size){
    _bg(canvas);
    if(portalGrow>0)_drawPortal(canvas);
    _drawNucleus(canvas);_drawPowerUps(canvas);
    _drawAsteroids(canvas);
    _drawEnemies(canvas);if(boss!=null)_drawBoss(canvas,boss!);
    _drawBullets(canvas);_drawPhoenix(canvas);
    _drawParticles(canvas);_drawFloats(canvas);_drawHUD(canvas);
    if(frosting)_drawFrost(canvas);if(quenching)_drawQuench(canvas);
    if(mirrorVictory)_drawMirrorVictory(canvas);
  }

  void _bg(Canvas canvas){
    // Stage-specific background tint
    final Color stageAccent=switch(stageNum){
      2=>const Color(0xFF001A00), 3=>const Color(0xFF0A001A),
      4=>const Color(0xFF1A0000), _=>const Color(0xFF001022)};
    final danger=coreTemp>0.5?Color.lerp(stageAccent,const Color(0xFF200008),(coreTemp-0.5)*2)!:stageAccent;
    canvas.drawRect(Rect.fromLTWH(0,0,sw,sh),Paint()..shader=LinearGradient(
        begin:Alignment.topCenter,end:Alignment.bottomCenter,
        colors:[const Color(0xFF000814),stageAccent,danger]).createShader(Rect.fromLTWH(0,0,sw,sh)));
    final rng=Random(77+stageNum);final sp=Paint()..color=Colors.white.withOpacity(0.5);
    for(int i=0;i<70;i++)canvas.drawCircle(Offset(rng.nextDouble()*sw,rng.nextDouble()*sh),rng.nextDouble()*1.3,sp);
    if(res.entropyFrac>0.4)canvas.drawRect(Rect.fromLTWH(0,0,sw,sh),
        Paint()..color=const Color(0xFF330044).withOpacity(res.entropyFrac*0.25)
          ..maskFilter=const MaskFilter.blur(BlurStyle.normal,60));
    // Stage name top-right
    _txt(canvas,'STAGE $stageNum',Offset(sw-12,sh*0.06+20),Colors.white24,9,right:true);
  }

  void _drawPortal(Canvas canvas){
    final cx=sw/2,cy=sh*0.25;
    final pg=portalGrow.clamp(0.0,1.0);
    final r=60+pg*120;
    // Swirling portal
    for(int i=8;i>=1;i--)canvas.drawCircle(Offset(cx,cy),r*i*0.12,
        Paint()..color=cRed.withOpacity(pg*0.06*i)..maskFilter=const MaskFilter.blur(BlurStyle.normal,20));
    canvas.drawCircle(Offset(cx,cy),r,
        Paint()..color=const Color(0xFF1A0000).withOpacity(pg*0.8));
    canvas.drawCircle(Offset(cx,cy),r,
        Paint()..color=cRed.withOpacity(pg*0.6)..style=PaintingStyle.stroke..strokeWidth=3);
    if(pg>0.5)_txt(canvas,'PORTAL DIMENSIONAL',Offset(cx,cy),cRed.withOpacity(pg),11);
  }

  void _drawAsteroids(Canvas canvas){
    for(final a in asteroids){
      if(a.dead)continue;
      canvas.save();
      canvas.translate(a.x,a.y);canvas.rotate(a.angle);
      final paint=Paint()..color=const Color(0xFF666655)..style=PaintingStyle.fill;
      final path=Path();
      for(int i=0;i<8;i++){
        final ang=i*pi/4;final r2=a.r*(0.7+0.3*(i%2==0?1:0.6));
        if(i==0)path.moveTo(cos(ang)*r2,sin(ang)*r2);
        else path.lineTo(cos(ang)*r2,sin(ang)*r2);
      }
      path.close();canvas.drawPath(path,paint);
      canvas.drawPath(path,Paint()..color=const Color(0xFF888877)..style=PaintingStyle.stroke..strokeWidth=1.5);
      canvas.restore();
    }
  }

  void _drawNucleus(Canvas canvas){
    final cx=sw/2,cy=sh*0.87;
    final tempC=Color.lerp(cIce,cDanger,coreTemp)!;
    final pulse=kNucleusR+corePulse*5;
    if(nucleusIFrame>0)canvas.drawCircle(Offset(cx,cy),pulse+10,
        Paint()..color=cShield.withOpacity(0.35)..maskFilter=const MaskFilter.blur(BlurStyle.normal,15));
    for(int i=4;i>=1;i--)canvas.drawCircle(Offset(cx,cy),pulse+i*12,
        Paint()..color=tempC.withOpacity(0.06*i)..style=PaintingStyle.stroke..strokeWidth=1.5);
    canvas.drawCircle(Offset(cx,cy),pulse*1.4,Paint()..color=tempC.withOpacity(0.18)..maskFilter=const MaskFilter.blur(BlurStyle.normal,20));
    canvas.drawCircle(Offset(cx,cy),pulse,Paint()..shader=RadialGradient(
        colors:[Colors.white.withOpacity(0.95),tempC.withOpacity(0.85),tempC.withOpacity(0.2)],
        stops:const[0.0,0.45,1.0]).createShader(Rect.fromCircle(center:Offset(cx,cy),radius:pulse)));
    canvas.drawCircle(Offset(cx,cy),pulse+4,Paint()..color=tempC.withOpacity(0.35)..style=PaintingStyle.stroke..strokeWidth=0.8);
    final lp=Paint()..color=tempC.withOpacity(0.2)..strokeWidth=0.7;
    canvas.drawLine(Offset(cx-pulse-10,cy),Offset(cx+pulse+10,cy),lp);
    canvas.drawLine(Offset(cx,cy-pulse-10),Offset(cx,cy+pulse+10),lp);
    final rng=Random((corePulse*20).toInt());
    final blp=Paint()..color=tempC.withOpacity(0.6)..style=PaintingStyle.stroke..strokeWidth=1.2;
    for(int i=0;i<8;i++){final a=i*pi/4+corePulse*pi*0.5;
      _bolt(canvas,blp,Offset(cx+cos(a)*pulse*0.5,cy+sin(a)*pulse*0.5),
          Offset(cx+cos(a)*(pulse+22),cy+sin(a)*(pulse+22)),rng);}
    _arcBar(canvas,cx,cy,pulse+32,coreTemp,tempC);
    _txt(canvas,'NÚCLEO CUÁNTICO',Offset(cx,cy+pulse+22),tempC.withOpacity(0.8),9);
  }
  void _arcBar(Canvas canvas,double cx,double cy,double r,double frac,Color c){
    const st=-pi*0.75,sw2=pi*1.5;
    canvas.drawArc(Rect.fromCircle(center:Offset(cx,cy),radius:r),st,sw2,false,
        Paint()..color=Colors.white12..style=PaintingStyle.stroke..strokeWidth=4..strokeCap=StrokeCap.round);
    if(frac>0)canvas.drawArc(Rect.fromCircle(center:Offset(cx,cy),radius:r),st,sw2*frac,false,
        Paint()..color=c..style=PaintingStyle.stroke..strokeWidth=4..strokeCap=StrokeCap.round);
  }
  void _bolt(Canvas canvas,Paint p,Offset a,Offset b,Random rng){
    final path=Path()..moveTo(a.dx,a.dy);
    for(int i=1;i<4;i++){final t=i/4;path.lineTo(
        a.dx+(b.dx-a.dx)*t+(rng.nextDouble()-0.5)*10,
        a.dy+(b.dy-a.dy)*t+(rng.nextDouble()-0.5)*10);}
    path.lineTo(b.dx,b.dy);canvas.drawPath(path,p);
  }

  void _drawPowerUps(Canvas canvas){
    for(final p in powerUps){if(p.collected)continue;
      final c=_puC(p.kind);final pulse=sin(p.animT)*0.15+1.0;
      canvas.drawCircle(Offset(p.x,p.y),22*pulse,Paint()..color=c.withOpacity(0.25)..maskFilter=const MaskFilter.blur(BlurStyle.normal,10));
      canvas.drawCircle(Offset(p.x,p.y),18*pulse,Paint()..color=c.withOpacity(0.7)..style=PaintingStyle.stroke..strokeWidth=2);
      _txt(canvas,_puI(p.kind),Offset(p.x,p.y),c,16);}
  }
  Color  _puC(PowerUpKind k)=>switch(k){PowerUpKind.rapidFire=>cFire,PowerUpKind.tripleShot=>cGold,PowerUpKind.shield=>cShield,PowerUpKind.coreArmor=>cIce,PowerUpKind.energyBoost=>cGreen};
  String _puI(PowerUpKind k)=>switch(k){PowerUpKind.rapidFire=>'⚡',PowerUpKind.tripleShot=>'💥',PowerUpKind.shield=>'🛡',PowerUpKind.coreArmor=>'❄',PowerUpKind.energyBoost=>'💚'};

  void _drawPhoenix(Canvas canvas){
    final px=player.x,py=sh*0.72;
    if(player.shieldActive){
      canvas.drawCircle(Offset(px,py),kPhoenixSize*1.7,Paint()..color=cShield.withOpacity(0.3)..maskFilter=const MaskFilter.blur(BlurStyle.normal,10));
      canvas.drawCircle(Offset(px,py),kPhoenixSize*1.7,Paint()..color=cShield.withOpacity(0.7)..style=PaintingStyle.stroke..strokeWidth=2);}
    if(isTriple)canvas.drawCircle(Offset(px,py),kPhoenixSize*0.9,Paint()..color=cGold.withOpacity(0.2)..maskFilter=const MaskFilter.blur(BlurStyle.normal,8));
    if(machineGunActive)canvas.drawCircle(Offset(px,py),kPhoenixSize*1.1,Paint()..color=cGold.withOpacity(0.3)..maskFilter=const MaskFilter.blur(BlurStyle.normal,10));
    if(sprites.loaded&&sprites.player!=null){
      drawSprite(canvas,sprites.player!,Offset(px,py),kPhoenixSize*2.4);return;}
    // Fallback
    canvas.drawCircle(Offset(px,py+kPhoenixSize*0.55),kPhoenixSize*0.35,
        Paint()..color=cFire.withOpacity(touching?0.85:0.3)..maskFilter=const MaskFilter.blur(BlurStyle.normal,12));
    final bp=Paint()..shader=LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
        colors:[const Color(0xFF999999),const Color(0xFF555555)])
        .createShader(Rect.fromCenter(center:Offset(px,py),width:kPhoenixSize*0.6,height:kPhoenixSize*1.8));
    canvas.drawPath(Path()..moveTo(px,py-kPhoenixSize*0.85)..lineTo(px+kPhoenixSize*0.22,py+kPhoenixSize*0.45)..lineTo(px,py+kPhoenixSize*0.25)..lineTo(px-kPhoenixSize*0.22,py+kPhoenixSize*0.45)..close(),bp);
    final wc=const Color(0xFF666666);
    canvas.drawPath(Path()..moveTo(px-kPhoenixSize*0.18,py)..lineTo(px-kPhoenixSize*1.25,py+kPhoenixSize*0.1)..lineTo(px-kPhoenixSize*0.9,py+kPhoenixSize*0.5)..lineTo(px-kPhoenixSize*0.2,py+kPhoenixSize*0.35)..close(),Paint()..color=wc);
    canvas.drawPath(Path()..moveTo(px+kPhoenixSize*0.18,py)..lineTo(px+kPhoenixSize*1.25,py+kPhoenixSize*0.1)..lineTo(px+kPhoenixSize*0.9,py+kPhoenixSize*0.5)..lineTo(px+kPhoenixSize*0.2,py+kPhoenixSize*0.35)..close(),Paint()..color=wc);
    canvas.drawCircle(Offset(px,py-kPhoenixSize*0.3),kPhoenixSize*0.18,Paint()..color=cIce.withOpacity(0.8)..maskFilter=const MaskFilter.blur(BlurStyle.normal,5));
    _txt(canvas,'G·G',Offset(px,py+kPhoenixSize*0.05),cGold.withOpacity(0.8),7);
    if(touching)canvas.drawPath(Path()..moveTo(px-7,py+kPhoenixSize*0.42)..lineTo(px,py+kPhoenixSize*0.42+30)..lineTo(px+7,py+kPhoenixSize*0.42),
          Paint()..shader=LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
              colors:[const Color(0xFFFFDD00),cFire,cFire.withOpacity(0)])
              .createShader(Rect.fromLTWH(px-8,py+kPhoenixSize*0.4,16,32)));
  }

  void _drawEnemies(Canvas canvas){
    for(final e in enemies){if(e.dead)continue;
      final base=_eColor(e.kind);final c=e.hitFlash>0?Color.lerp(base,Colors.white,e.hitFlash)!:base;
      canvas.drawCircle(Offset(e.x,e.y),kEnemyR*1.45,Paint()..color=c.withOpacity(0.18)..maskFilter=const MaskFilter.blur(BlurStyle.normal,10));
      final img=sprites.enemyImg(e.kind);
      if(sprites.loaded&&img!=null){
        drawSprite(canvas,img,Offset(e.x,e.y),kEnemyR*2.4,flash:e.hitFlash);
      }else{_enemyFallback(canvas,e,c);}
      if(e.maxHp>20){
        final bw=kEnemyR*2;final frac=(e.hp/e.maxHp).clamp(0.0,1.0);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(e.x-bw/2,e.y-kEnemyR-8,bw,3),const Radius.circular(2)),Paint()..color=Colors.white24);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(e.x-bw/2,e.y-kEnemyR-8,bw*frac,3),const Radius.circular(2)),Paint()..color=c);
      }
    }
  }
  void _enemyFallback(Canvas canvas,Enemy e,Color c){
    switch(e.kind){
      case EnemyKind.interceptor:
        canvas.drawOval(Rect.fromCenter(center:Offset(e.x,e.y),width:kEnemyR*1.8,height:kEnemyR*0.9),Paint()..color=c.withOpacity(0.85));
        canvas.drawCircle(Offset(e.x,e.y),kEnemyR*0.28,Paint()..color=Colors.white.withOpacity(0.9)..maskFilter=const MaskFilter.blur(BlurStyle.normal,4));
      case EnemyKind.frigate:
        canvas.drawPath(Path()..moveTo(e.x,e.y-kEnemyR*1.1)..lineTo(e.x+kEnemyR*0.5,e.y)..lineTo(e.x,e.y+kEnemyR*1.1)..lineTo(e.x-kEnemyR*0.5,e.y)..close(),Paint()..color=c.withOpacity(0.85));
        canvas.drawCircle(Offset(e.x,e.y),kEnemyR*0.22,Paint()..color=Colors.white.withOpacity(0.7)..maskFilter=const MaskFilter.blur(BlurStyle.normal,4));
      case EnemyKind.parasite:
        final p=Path();for(int i=0;i<6;i++){final a=i*pi/3+e.animT*0.2;if(i==0)p.moveTo(e.x+cos(a)*kEnemyR,e.y+sin(a)*kEnemyR);else p.lineTo(e.x+cos(a)*kEnemyR,e.y+sin(a)*kEnemyR);}
        p.close();canvas.drawPath(p,Paint()..color=c.withOpacity(0.85));
        canvas.drawCircle(Offset(e.x,e.y),kEnemyR*0.28,Paint()..color=Colors.white.withOpacity(0.85)..maskFilter=const MaskFilter.blur(BlurStyle.normal,3));
      case EnemyKind.corrupter:
        final p=Path();for(int i=0;i<8;i++){final a=i*pi/4+e.animT*0.5;final r=i.isEven?kEnemyR:kEnemyR*0.42;if(i==0)p.moveTo(e.x+cos(a)*r,e.y+sin(a)*r);else p.lineTo(e.x+cos(a)*r,e.y+sin(a)*r);}
        p.close();canvas.drawPath(p,Paint()..color=c);
        canvas.drawCircle(Offset(e.x,e.y),kEnemyR*0.22,Paint()..color=const Color(0xFFFF0000).withOpacity(0.9)..maskFilter=const MaskFilter.blur(BlurStyle.normal,5));
    }
  }
  Color _eColor(EnemyKind k)=>switch(k){EnemyKind.interceptor=>cWarlord,EnemyKind.frigate=>cGreen,EnemyKind.parasite=>cShield,EnemyKind.corrupter=>const Color(0xFFFF6600)};

  void _drawBoss(Canvas canvas,Boss b){
    final isCharging=b.state==BossState.charging;
    if(isCharging){
      canvas.drawCircle(Offset(b.x,b.y),kBossR*2.2,
          Paint()..color=bossColor.withOpacity(b.chargeGlow*0.35)..maskFilter=const MaskFilter.blur(BlurStyle.normal,30));
      for(int i=1;i<=3;i++)canvas.drawCircle(Offset(b.x,b.y),kBossR*(1.0+i*0.4*b.chargeGlow),
          Paint()..color=bossColor.withOpacity((1-b.chargeGlow)*0.3/(i*0.8))..style=PaintingStyle.stroke..strokeWidth=1.5);
    }
    final img=sprites.bossImg(stageNum);
    if(sprites.loaded&&img!=null){
      drawSprite(canvas,img,Offset(b.x,b.y),kBossR*2.4,flash:b.hitFlash);
    }else{
      final c=b.hitFlash>0?Color.lerp(bossColor,Colors.white,b.hitFlash)!:bossColor;
      canvas.drawCircle(Offset(b.x,b.y),kBossR*1.8,Paint()..color=c.withOpacity(0.12)..maskFilter=const MaskFilter.blur(BlurStyle.normal,30));
      final path=Path();for(int i=0;i<6;i++){final a=i*pi/3+b.animT*0.15;if(i==0)path.moveTo(b.x+cos(a)*kBossR,b.y+sin(a)*kBossR);else path.lineTo(b.x+cos(a)*kBossR,b.y+sin(a)*kBossR);}
      path.close();canvas.drawPath(path,Paint()..shader=RadialGradient(colors:[c.withOpacity(0.95),const Color(0xFF112244)],stops:const[0.3,1.0]).createShader(Rect.fromCircle(center:Offset(b.x,b.y),radius:kBossR)));
      canvas.drawCircle(Offset(b.x,b.y),kBossR*0.18,Paint()..color=c..maskFilter=const MaskFilter.blur(BlurStyle.normal,12));
      canvas.drawCircle(Offset(b.x,b.y),kBossR*0.07,Paint()..color=Colors.white);
    }
    // HP or repel bar
    const bw=kBossR*2;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(b.x-bw/2,b.y-kBossR*1.3,bw,6),const Radius.circular(3)),Paint()..color=Colors.white24);
    if(stageNum==4){
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(b.x-bw/2,b.y-kBossR*1.3,bw*b.repelMeter,6),const Radius.circular(3)),Paint()..color=cRed);
      _txt(canvas,'REPEL ${(b.repelMeter*100).toInt()}%',Offset(b.x,b.y-kBossR*1.45),cRed,10);
    }else{
      final frac=(b.hp/b.maxHp).clamp(0.0,1.0);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(b.x-bw/2,b.y-kBossR*1.3,bw*frac,6),const Radius.circular(3)),Paint()..color=Color.lerp(cDanger,bossColor,frac)!);
      _txt(canvas,'${(frac*100).toInt()}%',Offset(b.x,b.y-kBossR*1.45),bossColor,10);
    }
    if(isCharging)_txt(canvas,'⚠ CARGANDO…',Offset(b.x,b.y+kBossR+18),cDanger,11);
  }

  void _drawBullets(Canvas canvas){
    for(final b in bullets){
      if(b.isEnemy){
        final c=b.fromBoss?bossColor:cWarlord;final r=b.fromBoss?9.0:7.0;
        canvas.drawCircle(Offset(b.x,b.y),r,Paint()..color=c..maskFilter=MaskFilter.blur(BlurStyle.normal,b.fromBoss?8:5));
        canvas.drawCircle(Offset(b.x,b.y),r*0.38,Paint()..color=b.fromBoss?Colors.orange:cFrost);
      }else{
        final lc=freezeActive?cIce:laserColor;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:Offset(b.x,b.y),width:10,height:24),const Radius.circular(5)),
            Paint()..color=lc.withOpacity(0.22)..maskFilter=const MaskFilter.blur(BlurStyle.normal,7));
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:Offset(b.x,b.y),width:3.5,height:22),const Radius.circular(2)),
            Paint()..shader=LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
                colors:[Colors.white,lc,lc.withOpacity(0.5)]).createShader(Rect.fromCenter(center:Offset(b.x,b.y),width:3.5,height:22)));
        canvas.drawCircle(Offset(b.x,b.y-10),3,Paint()..color=Colors.white.withOpacity(0.95));
      }
    }
  }

  void _drawParticles(Canvas canvas){
    for(final p in particles){final a=(p.life/p.maxLife).clamp(0.0,1.0);
      if(p.isFrost){
        final fp=Paint()..color=cFrost.withOpacity(a*0.9)..style=PaintingStyle.stroke..strokeWidth=1.2;
        for(int i=0;i<3;i++){final ang=i*pi/3;canvas.drawLine(Offset(p.x+cos(ang)*p.size,p.y+sin(ang)*p.size),Offset(p.x-cos(ang)*p.size,p.y-sin(ang)*p.size),fp);}
        canvas.drawCircle(Offset(p.x,p.y),p.size*0.3*a,Paint()..color=Colors.white.withOpacity(a));
      }else{canvas.drawCircle(Offset(p.x,p.y),p.size*a,Paint()..color=p.color.withOpacity(a)..maskFilter=MaskFilter.blur(BlurStyle.normal,p.size*0.5));}
    }
  }
  void _drawFloats(Canvas canvas){for(final f in floats)_txt(canvas,f.text,Offset(f.x,f.y),f.color.withOpacity(f.life.clamp(0,1)),11);}

  void _drawHUD(Canvas canvas){
    _txt(canvas,'SCORE  $score',Offset(16,56),Colors.white,15,left:true);
    final label=switch(phase.phase){GamePhase.combat=>'COMBAT  ${(phase.combatProgress*100).toInt()}%',GamePhase.decision=>'DECISIÓN',GamePhase.boss=>'⚠ BOSS'};
    _txt(canvas,label,Offset(sw/2,56),cIce,11);
    final bw=sw*0.4,bx=(sw-bw)/2;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx,66,bw,3),const Radius.circular(2)),Paint()..color=Colors.white12);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx,66,bw*phase.combatProgress,3),const Radius.circular(2)),Paint()..color=cIce);
    _vBar(canvas,14,sh*0.35,10,sh*0.32,res.energyFrac,cIce,'ENERGÍA');
    _vBar(canvas,sw-60,sh*0.35,10,sh*0.32,res.heatFrac,Color.lerp(cGold,cDanger,res.heatFrac)!,'HEAT');
    if(res.entropyFrac>0.3)_txt(canvas,'ENTROPÍA ${(res.entropyFrac*100).toInt()}%',Offset(sw/2,sh-28),cShield.withOpacity(res.entropyFrac),10);
    _txt(canvas,'DMG ${player.build.damage.toStringAsFixed(0)}  SPD ${player.build.fireRate.toStringAsFixed(1)}  COOL ${player.build.cooling.toStringAsFixed(1)}',Offset(sw/2,sh-14),Colors.white24,9);
    if(coreTemp>0.75)_txt(canvas,'⚠  QUENCH INMINENTE  ⚠',Offset(sw/2,sh*0.48),cDanger,15);
    if(res.overheating)_txt(canvas,'SOBRECALENTAMIENTO',Offset(sw/2,sh*0.53),cFire.withOpacity(0.85),11);
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
    canvas.drawRect(Rect.fromLTWH(0,0,sw,sh),Paint()..shader=RadialGradient(center:Alignment.center,radius:0.7,
        colors:[Colors.transparent,cFrost.withOpacity(ft*0.35),cFrost.withOpacity(ft*0.7)],stops:const[0.4,0.7,1.0])
        .createShader(Rect.fromLTWH(0,0,sw,sh)));
    final rng=Random(42);
    final cp=Paint()..color=cFrost.withOpacity(ft*0.55)..strokeWidth=1.0..style=PaintingStyle.stroke;
    void crack(double sx,double sy,int d){if(d<=0)return;for(int i=0;i<3;i++){
      final a=rng.nextDouble()*pi*2;final l=(20+rng.nextDouble()*40)*ft;
      final ex=sx+cos(a)*l;final ey=sy+sin(a)*l;canvas.drawLine(Offset(sx,sy),Offset(ex,ey),cp);
      if(rng.nextDouble()<0.5)crack(ex,ey,d-1);}}
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
  void _drawMirrorVictory(Canvas canvas){
    final t=(mirrorVictoryT/3.0).clamp(0.0,1.0);
    canvas.drawRect(Rect.fromLTWH(0,0,sw,sh),Paint()..color=const Color(0xFF000033).withOpacity(t*0.85));
    _txt(canvas,'PORTAL DIMENSIONAL CERRADO',Offset(sw/2,sh*0.38),cGold.withOpacity(t),18);
    _txt(canvas,'La puerta fue cerrada…',Offset(sw/2,sh*0.48),Colors.white.withOpacity(t),14);
    _txt(canvas,'por ahora.',Offset(sw/2,sh*0.54),cIce.withOpacity(t),18);
  }

  void _txt(Canvas canvas,String t,Offset pos,Color c,double sz,{bool left=false,bool right=false}){
    final tp=TextPainter(text:TextSpan(text:t,style:TextStyle(color:c,fontSize:sz,fontFamily:'Orbitron',fontWeight:FontWeight.bold,shadows:[Shadow(color:c.withOpacity(0.5),blurRadius:8)])),
        textAlign:left?TextAlign.left:TextAlign.center,textDirection:TextDirection.ltr)..layout();
    final dx=right?(pos.dx-tp.width):left?pos.dx:pos.dx-tp.width/2;
    tp.paint(canvas,Offset(dx,pos.dy-tp.height/2));
  }
  @override bool shouldRepaint(covariant CustomPainter _)=>true;
}

// ── CHARGE RING ──────────────────────────────────────────
class _ChargeRing extends StatelessWidget {
  final ChargeIndicator indicator;final VoidCallback onTap;
  const _ChargeRing({required this.indicator,required this.onTap});
  @override Widget build(BuildContext ctx){
    final c=indicator.color;final ready=indicator.ready&&!indicator.active;final active=indicator.active;
    return GestureDetector(onTap:onTap,child:SizedBox(width:48,height:48,
        child:CustomPaint(painter:_RingPainter(fraction:indicator.fraction,color:c,ready:ready,active:active,icon:indicator.icon))));
  }
}
class _RingPainter extends CustomPainter {
  final double fraction;final Color color;final bool ready,active;final String icon;
  const _RingPainter({required this.fraction,required this.color,required this.ready,required this.active,required this.icon});
  @override void paint(Canvas canvas,Size size){
    final cx=size.width/2,cy=size.height/2,r=size.width/2-4;
    canvas.drawCircle(Offset(cx,cy),r,Paint()..color=Colors.white12..style=PaintingStyle.stroke..strokeWidth=3);
    if(fraction>0)canvas.drawArc(Rect.fromCircle(center:Offset(cx,cy),radius:r),-pi/2,pi*2*fraction,false,
        Paint()..color=active?color.withOpacity(0.5):color..style=PaintingStyle.stroke..strokeWidth=3..strokeCap=StrokeCap.round);
    if(ready)canvas.drawCircle(Offset(cx,cy),r*0.7,Paint()..color=color.withOpacity(0.3)..maskFilter=const MaskFilter.blur(BlurStyle.normal,8));
    final tp=TextPainter(text:TextSpan(text:icon,style:TextStyle(fontSize:18,
        color:active?color.withOpacity(0.5):ready?color:Colors.white38)),textDirection:TextDirection.ltr)..layout();
    tp.paint(canvas,Offset(cx-tp.width/2,cy-tp.height/2));
  }
  @override bool shouldRepaint(covariant CustomPainter _)=>true;
}

// ── DECISION OVERLAY ─────────────────────────────────────
class _DecisionOverlay extends StatelessWidget {
  final List<UpgradeOption> options;final int cycle,stageNum;
  final void Function(UpgradeOption) onSelect;
  const _DecisionOverlay({required this.options,required this.cycle,required this.stageNum,required this.onSelect});
  @override Widget build(BuildContext ctx)=>Container(color:Colors.black.withOpacity(0.9),
    child:SafeArea(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      _GlowText('FASE DE DECISIÓN',color:cGold,size:22),const SizedBox(height:4),
      _GlowText('Stage $stageNum — Ciclo $cycle',color:Colors.white54,size:13),
      const SizedBox(height:28),
      ...[for(final opt in options)Padding(
        padding:const EdgeInsets.symmetric(horizontal:24,vertical:8),
        child:GestureDetector(onTap:()=>onSelect(opt),child:Container(
          width:double.infinity,padding:const EdgeInsets.all(18),
          decoration:BoxDecoration(border:Border.all(color:opt.color,width:1.5),borderRadius:BorderRadius.circular(12),
              color:opt.color.withOpacity(0.12),boxShadow:[BoxShadow(color:opt.color.withOpacity(0.25),blurRadius:16)]),
          child:Row(children:[Text(opt.emoji,style:const TextStyle(fontSize:28)),const SizedBox(width:16),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(opt.title,style:TextStyle(color:opt.color,fontSize:16,fontFamily:'Orbitron',fontWeight:FontWeight.bold)),
              const SizedBox(height:4),Text(opt.description,style:const TextStyle(color:Colors.white70,fontSize:12)),
            ])),Icon(Icons.arrow_forward_ios,color:opt.color,size:18)]))))],
      const SizedBox(height:20),
      const Text('(+20 energía al elegir)',style:TextStyle(color:Colors.white30,fontSize:11)),
    ])));
}

// ── MENU SCREEN ──────────────────────────────────────────
class MenuScreen extends StatefulWidget {
  final int best;final VoidCallback onStart;final SpriteCache sprites;
  const MenuScreen({super.key,required this.best,required this.onStart,required this.sprites});
  @override State<MenuScreen> createState()=>_MenuScreenState();
}
class _MenuScreenState extends State<MenuScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;late Animation<double> _pulse;
  @override void initState(){super.initState();
    _ctrl=AnimationController(vsync:this,duration:const Duration(milliseconds:1400))..repeat(reverse:true);
    _pulse=CurvedAnimation(parent:_ctrl,curve:Curves.easeInOut);}
  @override void dispose(){_ctrl.dispose();super.dispose();}
  @override Widget build(BuildContext ctx)=>Scaffold(backgroundColor:cBg,
    body:SafeArea(child:Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      _GlowText('PHOENIX CORE',color:cFire,size:38),const SizedBox(height:4),
      _GlowText('CRYO BALANCE  V4',color:cIce,size:16),const SizedBox(height:6),
      _GlowText('BEST: ${widget.best}',color:cGold,size:14),
      const SizedBox(height:32),_FleetLegend(sprites:widget.sprites),const SizedBox(height:32),
      AnimatedBuilder(animation:_pulse,builder:(_,__)=>Transform.scale(scale:1+_pulse.value*0.05,
        child:GestureDetector(onTap:widget.onStart,child:Container(
          padding:const EdgeInsets.symmetric(horizontal:52,vertical:18),
          decoration:BoxDecoration(border:Border.all(color:cFire,width:2),borderRadius:BorderRadius.circular(10),
              color:cFire.withOpacity(0.15),boxShadow:[BoxShadow(color:cFire.withOpacity(0.4),blurRadius:28)]),
          child:const _GlowText('INICIAR MISIÓN',color:Colors.white,size:22))))),
      const SizedBox(height:20),
      const Padding(padding:EdgeInsets.symmetric(horizontal:32),
        child:Text('4 Stages · 4 Jefes · Una Saga\nProtege el Núcleo Cuántico.',
            textAlign:TextAlign.center,style:TextStyle(color:Colors.white38,fontSize:12,height:1.5))),
    ]))));
}

class _FleetLegend extends StatelessWidget {
  final SpriteCache sprites;
  const _FleetLegend({required this.sprites});
  @override Widget build(BuildContext ctx){
    final items=[(sprites.enemy1,cWarlord,'Interceptor'),(sprites.enemy2,cGreen,'Frigate'),
                 (sprites.enemy3,cShield,'Parasite'),(sprites.enemy4,const Color(0xFFFF6600),'Corrupter')];
    return Column(children:[
      const Text('FLOTA DEL WARLORD',style:TextStyle(color:Colors.white38,fontSize:9,fontFamily:'Orbitron',letterSpacing:2)),
      const SizedBox(height:10),
      Row(mainAxisAlignment:MainAxisAlignment.center,children:items.map((e)=>Padding(
        padding:const EdgeInsets.symmetric(horizontal:10),
        child:Column(children:[
          SizedBox(width:52,height:52,child:e.$1!=null
              ?RawImage(image:e.$1,width:52,height:52,filterQuality:FilterQuality.high,fit:BoxFit.contain)
              :Container(decoration:BoxDecoration(shape:BoxShape.circle,color:e.$2.withOpacity(0.3),border:Border.all(color:e.$2,width:1.5)))),
          const SizedBox(height:6),
          Text(e.$3,style:const TextStyle(color:Colors.white54,fontSize:9,fontFamily:'Orbitron')),
        ]))).toList()),
    ]);
  }
}

// ── GAME OVER ────────────────────────────────────────────
class GameOverScreen extends StatelessWidget {
  final int score,best;final VoidCallback onRestart,onMenu;
  const GameOverScreen({super.key,required this.score,required this.best,required this.onRestart,required this.onMenu});
  @override Widget build(BuildContext ctx){final nr=score>=best&&score>0;
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

class _GlowText extends StatelessWidget {
  final String text;final Color color;final double size;
  const _GlowText(this.text,{required this.color,required this.size});
  @override Widget build(BuildContext ctx)=>Text(text,textAlign:TextAlign.center,
      style:TextStyle(color:color,fontSize:size,fontFamily:'Orbitron',fontWeight:FontWeight.bold,
          shadows:[Shadow(color:color.withOpacity(0.8),blurRadius:14),Shadow(color:color.withOpacity(0.3),blurRadius:28)]));
}
class _Btn extends StatelessWidget {
  final String label;final Color color;final VoidCallback onTap;
  const _Btn({required this.label,required this.color,required this.onTap});
  @override Widget build(BuildContext ctx)=>GestureDetector(onTap:onTap,child:Container(
    padding:const EdgeInsets.symmetric(horizontal:48,vertical:15),
    decoration:BoxDecoration(border:Border.all(color:color,width:1.5),borderRadius:BorderRadius.circular(8),
        color:color.withOpacity(0.12),boxShadow:[BoxShadow(color:color.withOpacity(0.3),blurRadius:14)]),
    child:_GlowText(label,color:color,size:17)));
}
