import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../main.dart';
import '../l10n.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/player_chrome.dart';

/// One opening attempt for one player/channel. A failed HLS stream may try TS
/// once; errors from a retired attempt must not affect its successor.
class PlaybackOpening {
  const PlaybackOpening({required this.errors, required this.open});

  final Stream<String> errors;
  final Future<void> Function(String url) open;
}

class LivePlaybackAttempt {
  LivePlaybackAttempt({
    required this.primary,
    this.fallback,
    required this.onFailure,
  });

  final PlaybackOpening primary;
  final PlaybackOpening Function()? fallback;
  final void Function(String error) onFailure;
  StreamSubscription<String>? _subscription;
  String? _fallbackUrl;
  bool _active = true;
  bool _fallbackStarted = false;
  bool _terminal = false;

  Future<void> start(String url, {String? fallbackUrl}) async {
    _fallbackUrl = fallbackUrl;
    _subscription = primary.errors.listen((e) => _fail(e, primary: true));
    try {
      await primary.open(url);
    } catch (e) {
      _fail('$e', primary: true);
    }
  }

  void _fail(String error, {required bool primary}) {
    if (!_active || _terminal || (primary && _fallbackStarted)) return;
    final fallbackUrl = _fallbackUrl;
    if (primary && fallbackUrl != null && fallback != null) {
      _fallbackStarted = true;
      _subscription?.cancel();
      // The TS player has a separate error stream: delayed HLS errors cannot
      // be mistaken for TS errors, even after the new stream starts opening.
      try {
        final source = fallback!();
        _subscription = source.errors.listen((e) => _fail(e, primary: false));
        Future.sync(() => source.open(fallbackUrl)).catchError((Object e) {
          _fail('$e', primary: false);
        });
      } catch (e) {
        _fail('$e', primary: false);
      }
      return;
    }
    _terminal = true;
    onFailure(error);
  }

  void dispose() {
    _active = false;
    _subscription?.cancel();
  }
}

/// Plays a live channel, a movie or a series episode.
///
/// The shell is one full-bleed picture with a single auto-hiding control layer
/// drawn on top of it: no fixed control bar and no reserved strip, so a phone
/// spends its whole screen on the video and a desktop window still gets the
/// wide layout with keyboard hints.
///
/// Keyboard / remote:
///   ↑ ↓            previous / next item in the current list
///   ← →            seek 10 s back / forward (volume for live TV)
///   Enter, Space   play / pause
///   M              mute,  + / -  volume
///   F              fullscreen (landscape + immersive)
///   C              cinema (hide the chrome),  I  now/next,  Esc back
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.item, this.overrideUrl});

  final StreamItem item;
  final String? overrideUrl;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late Player _player;
  late VideoController _controller;
  GlobalKey<VideoState> _videoKey = GlobalKey<VideoState>();
  final _keyboardFocus = FocusNode(debugLabel: 'player-keys');
  final _playFocus = FocusNode(debugLabel: 'player-play');

  late StreamItem _current;
  List<StreamItem> _queue = const [];
  int _index = 0;

  /// The chrome is everything that is not the picture. It hides itself while
  /// playback runs, and cinema mode starts with it hidden on purpose.
  bool _chrome = true;
  bool _cinema = false;
  bool _showInfo = true;
  bool _fullscreen = false;
  double _volume = 100;
  bool _muted = false;
  bool _playing = false;
  bool _buffering = false;
  String? _error;
  List<EpgEntry> _epg = const [];
  Timer? _epgTimer;
  Timer? _chromeTimer;
  TapDownDetails? _pendingTap;
  int _epgGeneration = 0;
  int _channelGeneration = 0;
  LivePlaybackAttempt? _attempt;
  bool _openedOnce = false;

  static const _chromeTimeout = Duration(seconds: 4);

  StreamSubscription? _playingSub;
  StreamSubscription? _bufferingSub;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);

    _queue = appState.visibleItems.isEmpty
        ? [widget.item]
        : appState.visibleItems;
    _index = _queue.indexWhere((e) => e.id == widget.item.id);
    if (_index < 0) {
      _queue = [..._queue, widget.item];
      _index = _queue.length - 1;
    }
    _current = widget.item;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _keyboardFocus.requestFocus();
      _openCurrent();
    });
    _restartChromeTimer();
  }

  @override
  void dispose() {
    _epgTimer?.cancel();
    _chromeTimer?.cancel();
    ++_channelGeneration;
    _attempt?.dispose();
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _player.dispose();
    _playFocus.dispose();
    _keyboardFocus.dispose();
    if (_fullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    super.dispose();
  }

  // ── chrome visibility ────────────────────────────────────────────────────

  void _restartChromeTimer() {
    _chromeTimer?.cancel();
    if (!_chrome || !_playing) return;
    _chromeTimer = Timer(_chromeTimeout, () {
      if (!mounted || !_playing || !_keyboardFocus.hasPrimaryFocus) return;
      setState(() => _chrome = false);
    });
  }

  void _poke() {
    if (!_chrome) setState(() => _chrome = true);
    _restartChromeTimer();
  }

  void _toggleChrome() {
    if (_chrome && !_keyboardFocus.hasPrimaryFocus) {
      _keyboardFocus.requestFocus();
    }
    setState(() => _chrome = !_chrome);
    _restartChromeTimer();
  }

  void _toggleCinema() {
    setState(() {
      _cinema = !_cinema;
      _chrome = !_cinema;
    });
    if (_cinema) _keyboardFocus.requestFocus();
    _restartChromeTimer();
  }

  // ── fullscreen ───────────────────────────────────────────────────────────

  Future<void> _toggleFullscreen() async {
    final next = !_fullscreen;
    setState(() {
      _fullscreen = next;
      if (next) _chrome = true;
    });
    if (next) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    _restartChromeTimer();
  }

  // ── playback ─────────────────────────────────────────────────────────────

  String _urlFor(StreamItem item, {String? liveExtension}) {
    if (widget.overrideUrl != null && item.id == widget.item.id) {
      return widget.overrideUrl!;
    }
    final c = appState.client!;
    if (item.kind == 'movie') return c.vodUrl(item);
    if (item.kind == 'episode') {
      return c.seriesEpisodeUrl(item.id, item.containerExtension ?? 'mp4');
    }
    // live: prefer HLS when the panel offers it, then fall back to ts
    final formats = appState.account?.allowedOutputFormats ?? const ['ts'];
    final ext =
        liveExtension ?? (formats.contains('m3u8') ? 'm3u8' : formats.first);
    return c.liveUrl(item, extension: ext);
  }

  Player _replacePlayer() {
    final oldPlayer = _player;
    _player = Player();
    _controller = VideoController(_player);
    _videoKey = GlobalKey<VideoState>();
    // Allow the old Video widget to detach before releasing its native player.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(oldPlayer.dispose());
    });
    return _player;
  }

  Future<void> _openCurrent() async {
    final generation = ++_channelGeneration;
    _attempt?.dispose();
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _epgTimer?.cancel();
    if (_openedOnce) {
      // An error emitted by the old native player cannot be attributed to the
      // new channel. Use a new player rather than reusing its error stream.
      _replacePlayer();
    }
    _openedOnce = true;
    final c = appState.client;
    if (c == null) {
      setState(() => _error = tr(context, 'Not logged in.'));
      return;
    }
    setState(() {
      _error = null;
      _current = _queue[_index];
      _epg = const [];
      _playing = false;
      _buffering = false;
    });
    ++_epgGeneration;
    final item = _current;
    final url = _urlFor(item);
    final formats = appState.account?.allowedOutputFormats ?? const ['ts'];
    final fallbackUrl =
        item.kind == 'live' &&
            (widget.overrideUrl == null || item.id != widget.item.id) &&
            formats.contains('m3u8') &&
            formats.contains('ts')
        ? _urlFor(item, liveExtension: 'ts')
        : null;
    bool current() => mounted && generation == _channelGeneration;
    PlaybackOpening openingFor(Player player) {
      _playingSub = player.stream.playing.listen((v) {
        if (!current()) return;
        setState(() => _playing = v);
        _restartChromeTimer();
      });
      _bufferingSub = player.stream.buffering.listen((v) {
        if (!current()) return;
        setState(() => _buffering = v);
      });
      return PlaybackOpening(
        errors: player.stream.error,
        open: (url) async {
          if (!current()) return;
          await player.open(Media(url), play: true);
          if (current()) await player.setVolume(_volume);
        },
      );
    }

    _attempt = LivePlaybackAttempt(
      primary: openingFor(_player),
      fallback: fallbackUrl == null
          ? null
          : () {
              if (!current()) {
                throw StateError('Playback changed');
              }
              _playingSub?.cancel();
              _bufferingSub?.cancel();
              final player = _replacePlayer();
              setState(() {
                _playing = false;
                _buffering = false;
              });
              return openingFor(player);
            },
      onFailure: (_) {
        if (!current()) return;
        // Native player errors can embed the media URL, including credentials.
        // Keep the UI message safe; the retry button remains available.
        setState(() => _error = tr(context, 'Playback error'));
      },
    );
    // Stream URLs carry username and password. Never print one in diagnostics.
    await _attempt!.start(url, fallbackUrl: fallbackUrl);
    if (!current()) return;
    if (item.kind == 'live') {
      _loadEpg();
      _epgTimer?.cancel();
      _epgTimer = Timer.periodic(const Duration(minutes: 2), (_) => _loadEpg());
    } else {
      _epgTimer?.cancel();
      _epg = const [];
    }
    _restartChromeTimer();
  }

  Future<void> _loadEpg() async {
    final c = appState.client;
    if (c == null) return;
    final generation = _epgGeneration;
    final entries = await c.shortEpg(_current.id, limit: 2);
    if (!mounted || generation != _epgGeneration) return;
    setState(() => _epg = entries);
  }

  void _step(int delta) {
    if (_queue.length < 2) return;
    final next = (_index + delta).clamp(0, _queue.length - 1);
    if (next == _index) return;
    setState(() {
      _index = next;
    });
    _openCurrent();
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    _poke();
  }

  Future<void> _seek(int seconds) async {
    if (_current.kind == 'live') return;
    final pos = _player.state.position;
    final target = pos + Duration(seconds: seconds);
    final duration = _player.state.duration;
    await _player.seek(
      target < Duration.zero
          ? Duration.zero
          : duration > Duration.zero && target > duration
          ? duration
          : target,
    );
    _poke();
  }

  Future<void> _setVolume(double v) async {
    final clamped = v.clamp(0, 100).toDouble();
    setState(() {
      _volume = clamped;
      _muted = clamped == 0;
    });
    await _player.setVolume(clamped);
    _poke();
  }

  Future<void> _toggleMute() => _setVolume(_muted ? 100 : 0);

  /// Double tap on the left or the right half scrubs, the middle toggles playback.
  void _onDoubleTap(TapDownDetails details) {
    final width = MediaQuery.of(context).size.width;
    final x = details.localPosition.dx;
    if (_current.kind == 'live') {
      _poke();
      return;
    }
    if (x < width * 0.4) {
      _seek(-10);
    } else if (x > width * 0.6) {
      _seek(10);
    } else {
      _togglePlay();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final seekable = _current.kind != 'live';
    // A control owns its arrows and OK. The parent must not steal them for
    // channel switching or a remote can never navigate the playback dock.
    if (!node.hasPrimaryFocus &&
        {
          LogicalKeyboardKey.arrowRight,
          LogicalKeyboardKey.arrowLeft,
          LogicalKeyboardKey.arrowUp,
          LogicalKeyboardKey.arrowDown,
          LogicalKeyboardKey.select,
          LogicalKeyboardKey.enter,
        }.contains(key)) {
      return KeyEventResult.ignored;
    }
    if (node.hasPrimaryFocus &&
        !_chrome &&
        {
          LogicalKeyboardKey.select,
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.arrowDown,
        }.contains(key)) {
      _poke();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _playFocus.requestFocus();
      });
      return KeyEventResult.handled;
    }
    if (node.hasPrimaryFocus &&
        _chrome &&
        key == LogicalKeyboardKey.arrowDown) {
      _playFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (seekable) {
        _seek(10);
      } else {
        _setVolume(_volume + 5);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (seekable) {
        _seek(-10);
      } else {
        _setVolume(_volume - 5);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _step(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _step(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter) {
      _togglePlay();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaTrackNext ||
        key == LogicalKeyboardKey.channelUp) {
      _step(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaTrackPrevious ||
        key == LogicalKeyboardKey.channelDown) {
      _step(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyM) {
      _toggleMute();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.add) {
      _setVolume(_volume + 5);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.minus) {
      _setVolume(_volume - 5);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF) {
      _toggleFullscreen();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyC) {
      _toggleCinema();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyI) {
      setState(() => _showInfo = !_showInfo);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && _fullscreen) {
      _toggleFullscreen();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final seekable = _current.kind != 'live';

    return Focus(
      focusNode: _keyboardFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Video(
              key: _videoKey,
              controller: _controller,
              controls: NoVideoControls,
              fill: Colors.black,
            ),
            // Tap layer: a single tap brings the chrome back, a double tap scrubs.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleChrome,
                onDoubleTapDown: (d) => _pendingTap = d,
                onDoubleTap: () {
                  final d = _pendingTap;
                  if (d != null) _onDoubleTap(d);
                },
              ),
            ),
            if (_error != null) Positioned.fill(child: _errorOverlay()),
            if (_buffering && _playing && _error == null)
              const Center(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            if (!_playing && !_buffering && _error == null && !_chrome)
              Center(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(18),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                ),
              ),
            PlayerTopChrome(
              visible: _chrome,
              title: _current.name,
              kind: _current.kind,
              epg: _showInfo ? _epg : const [],
              index: _index,
              total: _queue.length,
              fullscreen: _fullscreen,
              onBack: () => Navigator.of(context).pop(),
              onFullscreen: _toggleFullscreen,
            ),
            PlayerBottomChrome(
              visible: _chrome,
              wide: wide,
              seekable: seekable,
              playing: _playing,
              volume: _volume,
              muted: _muted,
              position: _player.stream.position,
              duration: _player.stream.duration,
              onPlayPause: _togglePlay,
              onSeek: _seek,
              onVolume: _setVolume,
              onMute: _toggleMute,
              onPrev: () => _step(-1),
              onNext: () => _step(1),
              onCinema: _toggleCinema,
              onFullscreen: _toggleFullscreen,
              onScrub: (d) => _player.seek(d),
              onPoke: _poke,
              canPrevious: _index > 0,
              canNext: _index < _queue.length - 1,
              cinema: _cinema,
              playFocusNode: _playFocus,
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.86),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.danger,
                  size: 30,
                ),
                const SizedBox(height: 12),
                Text(
                  tr(context, 'Stream failed'),
                  style: TextStyle(fontSize: 15, color: AppTheme.text),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton(
                      onPressed: _openCurrent,
                      child: Text(tr(context, 'Retry')),
                    ),
                    if (_index < _queue.length - 1) ...[
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () => _step(1),
                        child: Text(tr(context, 'Next')),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
