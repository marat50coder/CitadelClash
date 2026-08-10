import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_assets.dart';
import '../core/audio_manager.dart';
import '../core/game_storage.dart';
import '../core/ui_kit.dart';
import '../game/tower_engine.dart';
import '../game/tower_world.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/game_menu_sheet.dart';
import '../widgets/rules_sheet.dart';
import 'web_page_screen.dart';

enum _Phase { idle, hanging, dropping, collapsing, cashing }

class TowerScreen extends StatefulWidget {
  const TowerScreen({super.key});

  @override
  State<TowerScreen> createState() => _TowerScreenState();
}

class _TowerScreenState extends State<TowerScreen>
    with TickerProviderStateMixin {
  final TowerEngine _engine = TowerEngine();
  final GameStorage _storage = GameStorage.instance;
  final math.Random _random = math.Random();

  late final AnimationController _drop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final AnimationController _camera = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();
  late final AnimationController _collapse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// Landing squash-and-bounce for the block that just settled.
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  final List<PlacedBlock> _tower = <PlacedBlock>[];
  final List<RoundResult> _history = <RoundResult>[];

  _Phase _phase = _Phase.idle;
  int _balance = 0;
  int _bet = 100;
  int _stake = 0;
  int _fallingBlock = 0;
  int _nextArt = 0;
  double _cameraFrom = 0;
  double _cameraTo = 0;

  /// Horizontal offset and tilt of the crane load captured the instant BUILD is
  /// pressed, so the falling block starts from exactly where it was swinging.
  double _dropStartX = 0;
  double _dropStartAngle = 0;
  bool _blockFalls = false;
  bool _showHistory = true;
  _Banner? _banner;

  bool get _roundActive => _tower.isNotEmpty || _phase == _Phase.dropping;
  bool get _busy =>
      _phase == _Phase.dropping ||
      _phase == _Phase.collapsing ||
      _phase == _Phase.cashing;
  double get _multiplier => TowerEngine.multiplierFor(_tower.length);
  int get _cashoutValue => _engine.payout(_stake, _tower.length);

  @override
  void initState() {
    super.initState();
    _balance = _storage.balance;
    _bet = _storage.bet.clamp(GameStorage.minBet, GameStorage.maxBet);
    _pickNextBlock();
    AudioManager.instance.playMusic(AppAssets.musicGame);
  }

  @override
  void dispose() {
    _drop.dispose();
    _camera.dispose();
    _sway.dispose();
    _collapse.dispose();
    _flash.dispose();
    _bounce.dispose();
    super.dispose();
  }

  void _pickNextBlock() {
    _nextArt = _random.nextInt(BlockArt.all.length);
  }

  // Pendulum motion of the block hanging on the crane.
  static const double _swingAmpFactor = 0.11; // fraction of the field width
  static const double _swingTiltMax = 0.13; // radians

  double get _swingSin => math.sin(_sway.value * 2 * math.pi);
  double _swingOffset(TowerGeometry geometry) =>
      _swingSin * geometry.size.width * _swingAmpFactor;
  double get _swingTilt => _swingSin * _swingTiltMax;

  /// Height above the shop of the tower's *visible* top edge (transparent
  /// pixels on the block art are excluded so the next block rests on the
  /// painted silhouette, not on an invisible edge).
  double get _towerVisibleTop {
    if (_tower.isEmpty) return 0;
    final PlacedBlock top = _tower.last;
    return top.bottom + top.height * (1 - BlockArt.all[top.artIndex].topInset);
  }

  /// Where a new block of the given art must sit so its own painted bottom
  /// touches the current tower top without gap or overlap.
  double _bottomFor(int artIndex, double height) =>
      _towerVisibleTop - height * BlockArt.all[artIndex].bottomInset;

  // ------------------------------------------------------------------ wagers

  void _setBet(int value) {
    final int capped = value.clamp(
      GameStorage.minBet,
      math.max(GameStorage.minBet, math.min(_balance, GameStorage.maxBet)),
    );
    if (capped == _bet) return;
    setState(() => _bet = capped);
    _storage.setBet(capped);
  }

  int _betStep(int value) {
    if (value < 100) return 10;
    if (value < 500) return 50;
    if (value < 1000) return 100;
    if (value < 5000) return 500;
    if (value < 20000) return 1000;
    return 5000;
  }

  void _nudgeBet(int direction) {
    AudioManager.instance.click();
    final int step = direction > 0
        ? _betStep(_bet)
        : _betStep(math.max(_bet - 1, 1));
    _setBet(_bet + step * direction);
  }

  Future<void> _offerRefill() async {
    final bool claim = await showConfirmDialog(
      context,
      title: 'OUT OF FUNDS',
      message:
          'Your site budget is empty. Claim '
          '${formatAmount(GameStorage.refillAmount)} '
          '${GameStorage.currency} for free and keep building?',
      confirmLabel: 'CLAIM',
      cancelLabel: 'LATER',
    );
    if (!claim || !mounted) return;
    await _storage.setBalance(_storage.balance + GameStorage.refillAmount);
    unawaited(AudioManager.instance.playSfx(AppAssets.sfxCashout));
    if (!mounted) return;
    setState(() => _balance = _storage.balance);
    _setBet(_bet);
  }

  // ------------------------------------------------------------------- round

  Future<void> _build() async {
    if (_busy) return;

    if (!_roundActive) {
      if (_balance < _bet) {
        await _offerRefill();
        return;
      }
      await _storage.setBalance(_balance - _bet);
      unawaited(_storage.registerRound());
      if (!mounted) return;
      setState(() {
        _balance = _storage.balance;
        _stake = _bet;
        _fallingBlock = _engine.rollFallingBlock();
        _banner = null;
      });
    }

    final int attempt = _tower.length + 1;
    _blockFalls = attempt == _fallingBlock;
    // Keep the drop within reach of the block below so the two always overlap
    // and touch, while still letting the aim lean the tower over time.
    final double prevOffset = _tower.isEmpty ? 0 : _tower.last.offsetX;
    final double maxRel = _geometry.blockWidth * 0.28;
    final double maxAbs = _geometry.blockWidth * 0.55;
    _dropStartX = _swingOffset(_geometry)
        .clamp(-maxAbs, maxAbs)
        .clamp(prevOffset - maxRel, prevOffset + maxRel);
    _dropStartAngle = _swingTilt;
    _bounce.value = 0;
    setState(() => _phase = _Phase.dropping);
    unawaited(AudioManager.instance.playSfx(AppAssets.sfxSpin, volume: 0.7));

    await _drop.forward(from: 0);
    if (!mounted) return;

    if (_blockFalls) {
      await _crash();
    } else {
      await _land(attempt);
    }
  }

  Future<void> _land(int attempt) async {
    final TowerGeometry geometry = _geometry;
    final double height = geometry.blockHeight(_nextArt);
    setState(() {
      _tower.add(
        PlacedBlock(
          artIndex: _nextArt,
          offsetX: _dropStartX,
          bottom: _bottomFor(_nextArt, height),
          height: height,
        ),
      );
      _phase = _Phase.hanging;
    });
    unawaited(
      AudioManager.instance.playSfx(
        AppAssets.sfxReelStop,
        volume: (0.5 + attempt * 0.05).clamp(0.5, 1.0),
      ),
    );
    if (attempt % 5 == 0) {
      unawaited(
        AudioManager.instance.playSfx(AppAssets.sfxSmallWin, volume: 0.7),
      );
    }
    unawaited(_storage.registerMultiplier(_multiplier));
    _bounce.forward(from: 0);
    _pickNextBlock();
    _moveCamera(geometry);
  }

  Future<void> _crash() async {
    unawaited(AudioManager.instance.playSfx(AppAssets.sfxLose));
    setState(() {
      _phase = _Phase.collapsing;
      _banner = _Banner(
        title: 'TOWER DOWN',
        detail: '-${formatAmount(_stake)} ${GameStorage.currency}',
        good: false,
      );
      _history.insert(
        0,
        RoundResult(multiplier: _multiplier, cashedOut: false),
      );
      if (_history.length > 8) _history.removeLast();
    });
    await _collapse.forward(from: 0);
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _resetRound();
  }

  Future<void> _cashOut() async {
    if (_busy || _tower.isEmpty) return;
    final int win = _cashoutValue;
    final double multiplier = _multiplier;
    await _storage.setBalance(_storage.balance + win);
    if (!mounted) return;
    setState(() {
      _phase = _Phase.cashing;
      _balance = _storage.balance;
      _banner = _Banner(
        title: formatMultiplier(multiplier),
        detail: '+${formatAmount(win)} ${GameStorage.currency}',
        good: true,
      );
      _history.insert(0, RoundResult(multiplier: multiplier, cashedOut: true));
      if (_history.length > 8) _history.removeLast();
    });
    unawaited(
      AudioManager.instance.playSfx(
        multiplier >= 5 ? AppAssets.sfxBigWin : AppAssets.sfxCashout,
      ),
    );
    unawaited(AudioManager.instance.playSfx(AppAssets.sfxCoin, volume: 0.7));
    await _flash.forward(from: 0);
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    _resetRound();
  }

  void _resetRound() {
    setState(() {
      _tower.clear();
      _stake = 0;
      _phase = _Phase.idle;
    });
    _collapse.value = 0;
    _flash.value = 0;
    _cameraFrom = 0;
    _cameraTo = 0;
    _camera.value = 0;
    _pickNextBlock();
    Future<void>.delayed(const Duration(milliseconds: 2200), () {
      if (mounted && _phase == _Phase.idle) setState(() => _banner = null);
    });
  }

  void _moveCamera(TowerGeometry geometry) {
    final double target = geometry.cameraFor(
      geometry.storeHeight + _towerVisibleTop,
    );
    if ((target - _cameraTo).abs() < 0.5) return;
    _cameraFrom = _cameraValue;
    _cameraTo = target;
    _camera.forward(from: 0);
  }

  double get _cameraValue {
    final double t = Curves.easeOutCubic.transform(_camera.value);
    return _cameraFrom + (_cameraTo - _cameraFrom) * t;
  }

  late TowerGeometry _geometry = TowerGeometry(const Size(360, 640));

  // -------------------------------------------------------------------- view

  Future<void> _openMenu() async {
    final GameMenuAction? action = await showGameMenu(context);
    if (action == null || !mounted) return;
    switch (action) {
      case GameMenuAction.rules:
        await showRules(context);
      case GameMenuAction.privacy:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const WebPageScreen(
              title: 'PRIVACY POLICY',
              url: WebPageScreen.privacyPolicyUrl,
            ),
          ),
        );
      case GameMenuAction.support:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const WebPageScreen(
              title: 'SUPPORT',
              url: WebPageScreen.supportUrl,
            ),
          ),
        );
      case GameMenuAction.mainMenu:
        await _leave();
    }
  }

  Future<void> _leave() async {
    if (_roundActive) {
      final bool leave = await showConfirmDialog(
        context,
        title: 'LEAVE THE SITE?',
        message:
            'A round is still running. Leaving now forfeits the '
            'current tower.',
        confirmLabel: 'LEAVE',
        cancelLabel: 'STAY',
      );
      if (!leave || !mounted) return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets inset = MediaQuery.viewPaddingOf(context);
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: AppPalette.fieldDark,
        body: Column(
          children: <Widget>[
            _buildTopBar(inset.top),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  _geometry = TowerGeometry(
                    Size(constraints.maxWidth, constraints.maxHeight),
                  );
                  return _buildField(_geometry);
                },
              ),
            ),
            _buildControls(inset.bottom),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ chrome

  Widget _buildTopBar(double topInset) {
    return Container(
      color: AppPalette.barDark,
      padding: EdgeInsets.only(top: topInset),
      child: Column(
        children: <Widget>[
          const HazardStrip(
            height: 8,
            base: Color(0xFF56565A),
            stripe: Color(0xFF2A2A2C),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 14, 8),
            child: Row(
              children: <Widget>[
                _IconTapTarget(icon: Icons.menu_rounded, onTap: _openMenu),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      'ID : ${_storage.playerId}',
                      style: const TextStyle(
                        color: Color(0xFFBFBFC4),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Text(
                          formatAmount(_balance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          GameStorage.currency,
                          style: TextStyle(
                            color: Color(0xFFBFBFC4),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(double bottomInset) {
    final bool canBet = !_roundActive && !_busy;
    return Container(
      color: AppPalette.panelDark,
      child: Column(
        children: <Widget>[
          const HazardStrip(height: 7),
          Padding(
            padding: EdgeInsets.fromLTRB(
              10,
              10,
              10,
              12 + math.max(bottomInset, 16),
            ),
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 48,
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 96,
                        child: ActionButton(
                          enabled: canBet && _balance >= GameStorage.minBet,
                          onTap: () => _setBet(_balance),
                          child: const _ButtonLabel('ALL IN'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _buildStepper(canBet)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 78,
                        child: ActionButton(
                          enabled: canBet,
                          onTap: () => _setBet(_bet * 2),
                          child: const _ButtonLabel('x2'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _buildMainButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper(bool enabled) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppPalette.fieldDark,
        border: Border.all(color: const Color(0xFF3E3E42), width: 1.5),
      ),
      child: Row(
        children: <Widget>[
          _StepperButton(
            icon: Icons.remove_rounded,
            enabled: enabled && _bet > GameStorage.minBet,
            onTap: () => _nudgeBet(-1),
          ),
          Expanded(
            child: FittedBox(
              child: Text(
                formatAmount(_bet),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            enabled: enabled && _bet < _balance,
            onTap: () => _nudgeBet(1),
          ),
        ],
      ),
    );
  }

  Widget _buildMainButtons() {
    final bool topped = _tower.length >= TowerEngine.ladder.length;
    final Widget buildButton = GoldBarButton(
      enabled: !_busy && !topped,
      onTap: _build,
      label: !_roundActive
          ? 'BUILD'
          : topped
          ? 'TOP FLOOR'
          : 'BUILD  '
                '${formatMultiplier(TowerEngine.multiplierFor(_tower.length + 1))}',
    );

    if (!_roundActive) {
      return SizedBox(width: double.infinity, child: buildButton);
    }
    return Row(
      children: <Widget>[
        Expanded(
          child: ActionButton(
            height: 62,
            radius: 14,
            color: AppPalette.blue,
            shadowColor: AppPalette.blueDark,
            enabled: !_busy,
            onTap: _cashOut,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text(
                  'CASHOUT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    decoration: TextDecoration.none,
                  ),
                ),
                Text(
                  '${formatAmount(_cashoutValue)} ${GameStorage.currency}',
                  style: const TextStyle(
                    color: Color(0xFFDCEBFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: buildButton),
      ],
    );
  }

  // ------------------------------------------------------------------- field

  Widget _buildField(TowerGeometry geometry) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(AppAssets.sky, fit: BoxFit.cover),
          _buildHaze(geometry),
          _buildClouds(geometry),
          _buildWorld(geometry),
          if (_tower.isNotEmpty) _buildMultiplierHud(),
          Positioned(
            top: 10,
            right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                _RoundIconButton(
                  icon: Icons.more_horiz_rounded,
                  onTap: () => setState(() => _showHistory = !_showHistory),
                ),
                const SizedBox(height: 8),
                if (_showHistory && _history.isNotEmpty)
                  for (final RoundResult result in _history.take(6))
                    ResultChip(
                      multiplier: result.multiplier,
                      cashedOut: result.cashedOut,
                    ),
              ],
            ),
          ),
          if (_banner != null) _buildBanner(_banner!),
        ],
      ),
    );
  }

  Widget _buildHaze(TowerGeometry geometry) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: geometry.size.height * 0.55,
      child: const IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0x00A9DCF7),
                Color(0x66DCEBEA),
                Color(0xB3E9D9BC),
              ],
              stops: <double>[0, 0.55, 1],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClouds(TowerGeometry geometry) {
    return AnimatedBuilder(
      animation: _sway,
      builder: (BuildContext context, _) {
        final double width = geometry.size.width;
        final double height = geometry.size.height;
        return IgnorePointer(
          child: Stack(
            children: <Widget>[
              for (final List<double> cloud in const <List<double>>[
                <double>[0.06, 0.42, 0.28, 0.75],
                <double>[0.30, 0.26, 0.74, 0.5],
                <double>[0.17, 0.20, 0.12, 0.3],
              ])
                Positioned(
                  top: height * cloud[0],
                  left:
                      ((_sway.value * 0.25 + cloud[2]) % 1.2 - 0.1) * width -
                      width * cloud[1] * 0.5,
                  width: width * cloud[1],
                  child: Opacity(
                    opacity: cloud[3],
                    child: Image.asset(
                      cloud[1] > 0.4
                          ? AppAssets.cloudLarge
                          : AppAssets.cloudSmall,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Small, decaying shudder while the tower collapses. Kept gentle on purpose.
  double _collapseShake() {
    if (_collapse.value <= 0 || _collapse.value >= 1) return 0;
    return math.sin(_collapse.value * math.pi * 6) *
        2.5 *
        (1 - _collapse.value);
  }

  /// Gentle rocking of the standing tower. The amplitude is small and capped so
  /// the top never drifts far (which is what made it jittery before).
  double _towerSway() {
    if (_tower.length < 2) return 0;
    final double amp = 0.0016 * math.min(_tower.length, 6);
    return math.sin(_sway.value * 2 * math.pi) * amp;
  }

  /// The play field is drawn in independent layers so that, while idle, only the
  /// light crane layer repaints for the swing; the ground and tower stay still,
  /// which keeps everything smooth.
  Widget _buildWorld(TowerGeometry geometry) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        // Ground: reacts only to the camera and the collapse shudder.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[_camera, _collapse]),
            builder: (BuildContext context, _) => Transform.translate(
              offset: Offset(_collapseShake(), _cameraValue),
              child: _buildGround(geometry),
            ),
          ),
        ),
        // Tower: shop and the standing blocks. No sway rotation, so nothing
        // wobbles or drifts sideways as it grows.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[
              _camera,
              _collapse,
              _flash,
              _bounce,
              _sway,
            ]),
            builder: (BuildContext context, _) => Transform.translate(
              offset: Offset(_collapseShake(), _cameraValue),
              child: Transform.rotate(
                angle: _towerSway(),
                alignment: Alignment.bottomCenter,
                child: _buildTower(geometry),
              ),
            ),
          ),
        ),
        // The block dropping from the crane: perfectly vertical, never swayed.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[_drop, _camera]),
            builder: (BuildContext context, _) {
              if (_phase != _Phase.dropping) return const SizedBox.shrink();
              return Transform.translate(
                offset: Offset(0, _cameraValue),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    _buildFallingBlock(geometry, geometry.size.width / 2),
                  ],
                ),
              );
            },
          ),
        ),
        // Crane with the swinging load.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[_sway, _drop]),
            builder: (BuildContext context, _) => Stack(
              clipBehavior: Clip.none,
              children: <Widget>[_buildCrane(geometry)],
            ),
          ),
        ),
        // Multiplier read-out, on top of everything so it is never covered.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[_camera, _bounce]),
            builder: (BuildContext context, _) {
              if (_tower.isEmpty || _phase != _Phase.hanging) {
                return const SizedBox.shrink();
              }
              return Transform.translate(
                offset: Offset(0, _cameraValue),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    _buildFloatingMultiplier(geometry, geometry.size.width / 2),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGround(TowerGeometry geometry) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          left: 0,
          right: 0,
          top: geometry.groundLine - geometry.streetHeight,
          height: geometry.streetHeight,
          child: Image.asset(
            AppAssets.city,
            fit: BoxFit.fill,
            alignment: Alignment.bottomCenter,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: geometry.groundLine,
          height: geometry.soilHeight * 2.5,
          child: CustomPaint(painter: SoilPainter(band: geometry.soilHeight)),
        ),
      ],
    );
  }

  Widget _buildTower(TowerGeometry geometry) {
    final double centerX = geometry.size.width / 2;
    final double glow = _flash.isAnimating || _flash.value > 0
        ? math.sin(_flash.value * math.pi)
        : 0;

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          left: centerX - geometry.storeWidth * 0.8,
          top: geometry.groundLine - geometry.storeHeight * 0.9,
          child: GroundGlow(size: geometry.storeWidth * 1.6),
        ),
        Positioned(
          left: centerX - geometry.storeWidth / 2,
          top: geometry.groundLine - geometry.storeHeight,
          width: geometry.storeWidth,
          height: geometry.storeHeight,
          child: Image.asset(AppAssets.shop, fit: BoxFit.fill),
        ),
        for (int i = 0; i < _tower.length; i++)
          _buildPlacedBlock(geometry, i, centerX, glow),
        if (_tower.isNotEmpty &&
            _phase == _Phase.hanging &&
            _bounce.value > 0 &&
            _bounce.value < 1)
          _buildDust(geometry, centerX),
      ],
    );
  }

  Widget _buildPlacedBlock(
    TowerGeometry geometry,
    int index,
    double centerX,
    double glow,
  ) {
    final PlacedBlock block = _tower[index];
    final double top =
        geometry.groundLine -
        geometry.storeHeight -
        block.bottom -
        block.height;

    // Landing squash-and-bounce for the block that just settled.
    double scaleY = 1;
    double scaleX = 1;
    if (index == _tower.length - 1 &&
        _phase == _Phase.hanging &&
        _bounce.value > 0 &&
        _bounce.value < 1) {
      final double e = Curves.elasticOut.transform(_bounce.value);
      scaleY = 0.8 + 0.2 * e;
      scaleX = 1 + (1 - scaleY) * 0.5;
    }

    // Collapse: blocks tip over from the top down.
    double fall = 0;
    double spin = 0;
    double fade = 1;
    if (_collapse.value > 0) {
      final int fromTop = _tower.length - 1 - index;
      final double delay = fromTop * 0.07;
      final double t = ((_collapse.value - delay) / (1 - delay)).clamp(
        0.0,
        1.0,
      );
      final double eased = t * t;
      fall = eased * geometry.size.height * 1.3;
      spin = eased * (index.isEven ? 1.4 : -1.4);
      fade = (1 - t * 1.15).clamp(0.0, 1.0);
      if (t > 0) {
        scaleY = 1;
        scaleX = 1;
      }
    }

    return Positioned(
      left: centerX - geometry.blockWidth / 2 + block.offsetX,
      top: top + fall,
      width: geometry.blockWidth,
      height: block.height,
      child: Opacity(
        opacity: fade,
        child: Transform.rotate(
          angle: spin,
          child: Transform.scale(
            scaleX: scaleX,
            scaleY: scaleY,
            alignment: Alignment.bottomCenter,
            child: _BlockImage(
              artIndex: block.artIndex,
              glow: index == _tower.length - 1 ? glow : glow * 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallingBlock(TowerGeometry geometry, double centerX) {
    final double height = geometry.blockHeight(_nextArt);
    final double startTop = geometry.hangingTop - _cameraValue;
    final double landingBottom = _bottomFor(_nextArt, height);
    final double landingTop =
        geometry.groundLine - geometry.storeHeight - landingBottom - height;

    final double t = _drop.value;
    final double descend = math.min(t / 0.72, 1);
    final double travel = Curves.easeInQuad.transform(descend);
    final double settle = Curves.easeOutCubic.transform(descend);

    double top = startTop + (landingTop - startTop) * travel;
    // Straight drop from wherever the load was swinging when BUILD was pressed,
    // so the block lands exactly where the player aimed.
    double x = _dropStartX;
    double angle = _dropStartAngle * (1 - settle);
    double opacity = 1;

    if (_blockFalls && t > 0.72) {
      final double f = (t - 0.72) / 0.28;
      final double eased = f * f;
      final int dir = _dropStartX >= 0 ? 1 : -1;
      top = landingTop + eased * geometry.size.height * 1.1;
      x = _dropStartX + eased * geometry.size.width * 0.42 * dir;
      angle = eased * 1.6 * dir;
      opacity = (1 - f * 0.6).clamp(0.0, 1.0);
    }

    return Positioned(
      left: centerX - geometry.blockWidth / 2 + x,
      top: top,
      width: geometry.blockWidth,
      height: height,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: angle,
          child: _BlockImage(artIndex: _nextArt, glow: 0),
        ),
      ),
    );
  }

  Widget _buildFloatingMultiplier(TowerGeometry geometry, double centerX) {
    final PlacedBlock block = _tower.last;
    final double topY =
        geometry.groundLine -
        geometry.storeHeight -
        block.bottom -
        block.height;
    return Positioned(
      left: centerX + block.offsetX - geometry.blockWidth,
      top: topY - geometry.blockWidth * 0.5,
      width: geometry.blockWidth * 2,
      child: Center(
        child: RisingMultiplier(
          key: ValueKey<int>(_tower.length),
          text: formatMultiplier(_multiplier),
        ),
      ),
    );
  }

  Widget _buildDust(TowerGeometry geometry, double centerX) {
    final PlacedBlock block = _tower.last;
    final double baseY = geometry.groundLine - geometry.storeHeight - block.bottom;
    final double span = geometry.blockWidth * 1.5;
    return Positioned(
      left: centerX - span / 2 + block.offsetX,
      top: baseY - span * 0.32,
      width: span,
      height: span * 0.42,
      child: IgnorePointer(
        child: CustomPaint(painter: DustPainter(progress: _bounce.value)),
      ),
    );
  }

  Widget _buildCrane(TowerGeometry geometry) {
    final bool carrying = _phase != _Phase.dropping;
    final double width = geometry.size.width;
    final double blockHeight = geometry.blockHeight(_nextArt);
    // The hook stays put; the cables and block swing like a pendulum below it.
    final double swingX = carrying ? _swingOffset(geometry) : 0;
    final double swingTilt = carrying ? _swingTilt : 0;

    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: geometry.hangingTop + blockHeight + 20,
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            if (carrying)
              Positioned.fill(
                child: CustomPaint(
                  painter: CablePainter(
                    hookBottom: geometry.hookHeight * 0.94,
                    blockTop: geometry.hangingTop,
                    blockWidth: geometry.blockWidth,
                    blockDx: swingX,
                  ),
                ),
              ),
            Positioned(
              left: width / 2 - geometry.hookHeight * 0.16,
              top: -geometry.hookHeight * 0.12,
              width: geometry.hookHeight * 0.32,
              height: geometry.hookHeight,
              child: Transform.rotate(
                angle: swingTilt * 0.35,
                alignment: Alignment.topCenter,
                child: Image.asset(AppAssets.hook, fit: BoxFit.fill),
              ),
            ),
            if (carrying)
              Positioned(
                left: width / 2 - geometry.blockWidth / 2 + swingX,
                top: geometry.hangingTop,
                width: geometry.blockWidth,
                height: blockHeight,
                child: Transform.rotate(
                  angle: swingTilt,
                  alignment: Alignment.topCenter,
                  child: _BlockImage(artIndex: _nextArt, glow: 0),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Current rung, shown as a heads-up chip so it never collides with the
  /// block waiting on the crane.
  Widget _buildMultiplierHud() {
    return Positioned(
      left: 12,
      top: 12,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xCC17130B),
            border: Border.all(color: AppPalette.gold, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const StrokedText(
                'TOWER',
                size: 9,
                color: Color(0xFFE9C88A),
                strokeWidth: 2,
                letterSpacing: 1.4,
              ),
              StrokedText(
                formatMultiplier(_multiplier),
                size: 20,
                color: AppPalette.goldLight,
                strokeWidth: 4,
              ),
              StrokedText(
                '${_tower.length} ${_tower.length == 1 ? 'BLOCK' : 'BLOCKS'}',
                size: 9,
                color: const Color(0xFFE9C88A),
                strokeWidth: 2,
                letterSpacing: 1.2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBanner(_Banner banner) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            key: ValueKey<String>('${banner.title}${banner.detail}'),
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 460),
            curve: Curves.elasticOut,
            builder: (BuildContext context, double value, Widget? child) =>
                Transform.scale(scale: 0.7 + value * 0.3, child: child),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: const Color(0xCC14100A),
                border: Border.all(
                  color: banner.good ? AppPalette.win : AppPalette.danger,
                  width: 3,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  StrokedText(
                    banner.title,
                    size: 40,
                    color: banner.good ? AppPalette.goldLight : Colors.white,
                    strokeWidth: 8,
                    letterSpacing: 1.5,
                  ),
                  const SizedBox(height: 4),
                  StrokedText(
                    banner.detail,
                    size: 21,
                    color: banner.good ? AppPalette.win : AppPalette.danger,
                    strokeWidth: 4.5,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner {
  const _Banner({
    required this.title,
    required this.detail,
    required this.good,
  });

  final String title;
  final String detail;
  final bool good;
}

class _BlockImage extends StatelessWidget {
  const _BlockImage({required this.artIndex, required this.glow});

  final int artIndex;
  final double glow;

  @override
  Widget build(BuildContext context) {
    final Widget image = Image.asset(
      BlockArt.all[artIndex].asset,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.low,
    );
    if (glow <= 0.01) return image;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        AppPalette.goldLight.withValues(alpha: glow * 0.55),
        BlendMode.srcATop,
      ),
      child: image,
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        color: Colors.transparent,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? const Color(0xFF3E3E44) : const Color(0xFF2A2A2E),
          ),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? Colors.white : const Color(0xFF6A6A70),
          ),
        ),
      ),
    );
  }
}

class _IconTapTarget extends StatelessWidget {
  const _IconTapTarget({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioManager.instance.click();
        onTap();
      },
      child: Container(
        width: 44,
        height: 40,
        alignment: Alignment.center,
        color: Colors.transparent,
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioManager.instance.click();
        onTap();
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF7EC8FF), Color(0xFF2F86EA)],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

