import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/player_chrome.dart';

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
  late final Player _player;
  late final VideoController _controller;
  final _videoKey = GlobalKey<VideoState>();
  final _keyboardFocus = FocusNode(debugLabel: 'player-keys');

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

  static const _chromeTimeout = Duration(seconds: 4);

  StreamSubscription? _errSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _bufferingSub;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);

    _queue = appState.visibleItems.isEmpty ? [widget.item] : appState.visibleItems;
    _index = _queue.indexWhere((e) => e.id == widget.item.id);
    if (_index < 0) {
      _queue = [..._queue, widget.item];
      _index = _queue.length - 1;
    }
    _current = widget.item;

    _errSub = _player.stream.error.listen((e) {
      if (!mounted) return;
      setState(() => _error = e.isEmpty ? 'Playback error' : e);
    });
    _playingSub = _player.stream.playing.listen((v) {
      if (!mounted) return;
      setState(() => _playing = v);
      _restartChromeTimer();
    });
    _bufferingSub = _player.stream.buffering.listen((v) {
      if (!mounted) return;
      setState(() => _buffering = v);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardFocus.requestFocus();
      _openCurrent();
    });
    _restartChromeTimer();
  }

  @override
  void dispose() {
    _epgTimer?.cancel();
    _chromeTimer?.cancel();
    _errSub?.cancel();
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _player.dispose();
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
      if (!mounted || !_playing) return;
      setState(() => _chrome = false);
    });
  }

  void _poke() {
    if (!_chrome) setState(() => _chrome = true);
    _restartChromeTimer();
  }

  void _toggleChrome() {
    setState(() => _chrome = !_chrome);
    _restartChromeTimer();
  }

  void _toggleCinema() {
    setState(() {
      _cinema = !_cinema;
      _chrome = !_cinema;
    });
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
      await SystemChrome.setPreferredOrientations(
          const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    _restartChromeTimer();
  }

  // ── playback ─────────────────────────────────────────────────────────────

  String _urlFor(StreamItem item) {
    if (widget.overrideUrl != null && item.id == widget.item.id) return widget.overrideUrl!;
    final c = appState.client!;
    if (item.kind == 'movie') return c.vodUrl(item);
    if (item.kind == 'episode') {
      return c.seriesEpisodeUrl(item.id, item.containerExtension ?? 'mp4');
    }
    // live: prefer HLS when the panel offers it, then fall back to ts
    final formats = appState.account?.allowedOutputFormats ?? const ['ts'];
    final ext = formats.contains('m3u8') ? 'm3u8' : (formats.first);
    return c.liveUrl(item, extension: ext);
  }

  Future<void> _openCurrent() async {
    final c = appState.client;
    if (c == null) {
      setState(() => _error = 'Not logged in.');
      return;
    }
    setState(() {
      _error = null;
      _current = _queue[_index];
      _epg = const [];
    });
    final url = _urlFor(_current);
    debugPrint('playing: $url');
    await _player.open(Media(url), play: true);
    await _player.setVolume(_volume);
    if (_current.kind == 'live') {
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
    final entries = await c.shortEpg(_current.id, limit: 2);
    if (!mounted) return;
    setState(() => _epg = entries);
  }

  void _step(int delta) {
    if (_queue.length < 2) return;
    setState(() {
      _index = (_index + delta).clamp(0, _queue.length - 1);
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
    await _player.seek(target.isNegative ? Duration.zero : target);
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
                Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 30),
                const SizedBox(height: 12),
                Text('Stream failed',
                    style: TextStyle(fontSize: 15, color: AppTheme.text)),
                const SizedBox(height: 8),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.muted, height: 1.5)),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton(onPressed: _openCurrent, child: const Text('Retry')),
                    const SizedBox(width: 10),
                    OutlinedButton(
                        onPressed: () => _step(1), child: const Text('Next')),
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

