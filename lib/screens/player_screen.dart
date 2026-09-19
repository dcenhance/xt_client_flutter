import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/focus_ring.dart';

/// Plays a live channel, a movie or a series episode.
///
/// Full D-pad / remote control:
///   ↑ ↓            previous / next item in the current list
///   ← →            seek 10 s back / forward
///   Enter, Space   play / pause
///   M              mute,  + / -  volume
///   C              cinema mode (hide chrome),  Esc back
///   Backspace      stop and go back
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

  bool _cinema = false;
  bool _showInfo = true;
  double _volume = 100;
  bool _muted = false;
  bool _playing = false;
  String? _error;
  List<EpgEntry> _epg = const [];
  Timer? _epgTimer;

  StreamSubscription? _errSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _posSub;

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
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardFocus.requestFocus();
      _openCurrent();
    });
  }

  @override
  void dispose() {
    _epgTimer?.cancel();
    _errSub?.cancel();
    _playingSub?.cancel();
    _posSub?.cancel();
    _player.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

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
  }

  Future<void> _seek(int seconds) async {
    final pos = _player.state.position;
    final target = pos + Duration(seconds: seconds);
    await _player.seek(target.isNegative ? Duration.zero : target);
  }

  Future<void> _setVolume(double v) async {
    final clamped = v.clamp(0, 100).toDouble();
    setState(() {
      _volume = clamped;
      _muted = clamped == 0;
    });
    await _player.setVolume(clamped);
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
      setState(() => _muted = !_muted);
      _player.setVolume(_muted ? 0 : _volume);
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
    if (key == LogicalKeyboardKey.keyC) {
      setState(() => _cinema = !_cinema);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyI) {
      setState(() => _showInfo = !_showInfo);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _keyboardFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _cinema
            ? null
            : AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back (Esc)',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: Text(_current.name),
                actions: [
                  IconButton(
                    tooltip: 'Cinema mode (C)',
                    icon: Icon(_cinema ? Icons.fullscreen_exit : Icons.fullscreen),
                    onPressed: () => setState(() => _cinema = !_cinema),
                  ),
                ],
              ),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Video(
                      key: _videoKey,
                      controller: _controller,
                      controls: NoVideoControls,
                      fill: Colors.black,
                    ),
                  ),
                  if (_error != null)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.82),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: AppTheme.danger, size: 32),
                                const SizedBox(height: 12),
                                const Text('Stream failed',
                                    style: TextStyle(fontSize: 15, color: AppTheme.text)),
                                const SizedBox(height: 8),
                                Text(_error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 12, color: AppTheme.muted, height: 1.5)),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    FilledButton(
                                      onPressed: _openCurrent,
                                      child: const Text('Retry'),
                                    ),
                                    const SizedBox(width: 10),
                                    OutlinedButton(
                                      onPressed: () => _step(1),
                                      child: const Text('Next channel'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_showInfo && !_cinema)
                    Positioned(
                      left: 16,
                      top: 12,
                      child: _InfoCard(
                        title: _current.name,
                        epg: _epg,
                        kind: _current.kind,
                      ),
                    ),
                ],
              ),
            ),
            _ControlBar(
              playing: _playing,
              volume: _volume,
              muted: _muted,
              seekable: _current.kind != 'live',
              position: _player,
              item: _current,
              index: _index,
              total: _queue.length,
              onPlayPause: _togglePlay,
              onSeek: _seek,
              onVolume: _setVolume,
              onPrev: () => _step(-1),
              onNext: () => _step(1),
              onCinema: () => setState(() => _cinema = !_cinema),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.epg, required this.kind});

  final String title;
  final List<EpgEntry> epg;
  final String kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 460),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppTheme.text)),
          if (kind == 'live' && epg.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final e in epg)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${_clock(e.start)}–${_clock(e.end)}  ${e.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _clock(DateTime? d) {
    if (d == null) return '--:--';
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.playing,
    required this.volume,
    required this.muted,
    required this.seekable,
    required this.position,
    required this.item,
    required this.index,
    required this.total,
    required this.onPlayPause,
    required this.onSeek,
    required this.onVolume,
    required this.onPrev,
    required this.onNext,
    required this.onCinema,
  });

  final bool playing;
  final double volume;
  final bool muted;
  final bool seekable;
  final Player position;
  final StreamItem item;
  final int index;
  final int total;
  final VoidCallback onPlayPause;
  final void Function(int) onSeek;
  final void Function(double) onVolume;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onCinema;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              _Glyph(
                icon: Icons.skip_previous,
                tooltip: 'Previous item (↑)',
                onTap: onPrev,
              ),
              _Glyph(
                icon: playing ? Icons.pause : Icons.play_arrow,
                tooltip: 'Play / pause (Enter, Space)',
                onTap: onPlayPause,
              ),
              _Glyph(
                icon: Icons.skip_next,
                tooltip: 'Next item (↓)',
                onTap: onNext,
              ),
              _Glyph(
                icon: Icons.replay_10,
                tooltip: 'Back 10 s (←)',
                onTap: () => onSeek(-10),
                enabled: seekable,
              ),
              _Glyph(
                icon: Icons.forward_10,
                tooltip: 'Forward 10 s (→)',
                onTap: () => onSeek(10),
                enabled: seekable,
              ),
              const SizedBox(width: 12),
              StreamBuilder<Duration>(
                stream: position.stream.position,
                builder: (context, snap) {
                  final pos = snap.data ?? Duration.zero;
                  return Text(_fmt(pos),
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.muted));
                },
              ),
              const Spacer(),
              Text(
                '${index + 1} / $total',
                style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
              ),
              const SizedBox(width: 16),
              IconButton(
                tooltip: 'Mute (M)',
                icon: Icon(muted ? Icons.volume_off : Icons.volume_up,
                    size: 19, color: AppTheme.text),
                onPressed: () => onVolume(muted ? 100 : 0),
              ),
              SizedBox(
                width: 120,
                child: Slider(
                  value: volume.clamp(0, 100),
                  onChanged: onVolume,
                ),
              ),
              _Glyph(
                icon: Icons.fullscreen,
                tooltip: 'Cinema mode (C)',
                onTap: onCinema,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: KeyHintBar(
              hints: seekable
                  ? const [
                      ('↑ ↓', 'channel'),
                      ('← →', 'seek 10s'),
                      ('Enter', 'play/pause'),
                      ('M', 'mute'),
                      ('C', 'cinema'),
                      ('Esc', 'back'),
                    ]
                  : const [
                      ('↑ ↓', 'channel'),
                      ('← →', 'volume'),
                      ('Enter', 'play/pause'),
                      ('M', 'mute'),
                      ('C', 'cinema'),
                      ('Esc', 'back'),
                    ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Tooltip(
        message: '$tooltip — not available for live TV',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Icon(icon, size: 21, color: AppTheme.border),
        ),
      );
    }
    return Tooltip(
      message: tooltip,
      child: FocusRing(
        borderRadius: 4,
        onSelect: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Icon(icon, size: 21, color: AppTheme.text),
        ),
      ),
    );
  }
}