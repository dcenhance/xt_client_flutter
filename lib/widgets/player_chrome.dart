import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models.dart';
import '../theme.dart';
import 'focus_ring.dart';

/// Back, what is playing, position in the list, fullscreen.
class PlayerTopChrome extends StatelessWidget {
  const PlayerTopChrome({
    super.key,
    required this.visible,
    required this.title,
    required this.kind,
    required this.epg,
    required this.index,
    required this.total,
    required this.fullscreen,
    required this.onBack,
    required this.onFullscreen,
  });

  final bool visible;
  final String title;
  final String kind;
  final List<EpgEntry> epg;
  final int index;
  final int total;
  final bool fullscreen;
  final VoidCallback onBack;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    final now = kind == 'live' && epg.isNotEmpty ? epg.first : null;
    return ExcludeFocus(
      excluding: !visible,
      child: Align(
        alignment: Alignment.topCenter,
        child: IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xCC000000), Color(0x00000000)],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 8, 18),
                  child: Row(
                    children: [
                      PlayerRoundButton(
                        icon: Icons.arrow_back,
                        tooltip: tr(context, 'Back'),
                        onTap: onBack,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              now == null
                                  ? _kindLabel(context, kind)
                                  : '${_clock(now.start)}–${_clock(now.end)}  ${now.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFFC9C2CC),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (total > 1) PlayerPill(label: '${index + 1}/$total'),
                      PlayerRoundButton(
                        icon: fullscreen
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                        tooltip: tr(context, 'Fullscreen'),
                        onTap: onFullscreen,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _kindLabel(BuildContext context, String kind) {
    switch (kind) {
      case 'live':
        return tr(context, 'Live TV');
      case 'movie':
        return tr(context, 'Movie');
      case 'episode':
        return tr(context, 'Episode');
      default:
        return kind;
    }
  }

  static String _clock(DateTime? d) {
    if (d == null) return '--:--';
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

/// Scrubber (when the source is seekable), transport row and volume.
/// Keyboard hints appear on wide windows only: a phone gets touch-sized
/// controls and no keyboard legend at all.
class PlayerBottomChrome extends StatelessWidget {
  const PlayerBottomChrome({
    super.key,
    required this.visible,
    required this.wide,
    required this.seekable,
    required this.playing,
    required this.volume,
    required this.muted,
    required this.position,
    required this.duration,
    required this.onPlayPause,
    required this.onSeek,
    required this.onVolume,
    required this.onMute,
    required this.onPrev,
    required this.onNext,
    required this.onCinema,
    required this.onFullscreen,
    required this.onScrub,
    required this.onPoke,
    this.canPrevious = true,
    this.canNext = true,
    this.cinema = false,
    this.playFocusNode,
  });

  final bool visible;
  final bool wide;
  final bool seekable;
  final bool playing;
  final double volume;
  final bool muted;
  final Stream<Duration> position;
  final Stream<Duration> duration;
  final VoidCallback onPlayPause;
  final void Function(int) onSeek;
  final void Function(double) onVolume;
  final VoidCallback onMute;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onCinema;
  final VoidCallback onFullscreen;
  final void Function(Duration) onScrub;
  final VoidCallback onPoke;
  final bool canPrevious;
  final bool canNext;
  final bool cinema;
  final FocusNode? playFocusNode;

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      excluding: !visible,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xE6000000), Color(0x00000000)],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 22 : 10,
                    26,
                    wide ? 22 : 10,
                    wide ? 14 : 6,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (seekable) _timeline(context) else _liveLine(context),
                      const SizedBox(height: 8),
                      if (wide)
                        _transport(context)
                      else
                        _transportNarrow(context),
                      if (wide) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: KeyHintBar(
                            hints: seekable
                                ? [
                                    ('↑ ↓', tr(context, 'channel')),
                                    ('← →', tr(context, 'seek 10s')),
                                    ('Enter', tr(context, 'play/pause')),
                                    ('M', tr(context, 'mute')),
                                    ('F', tr(context, 'fullscreen')),
                                    ('Esc', tr(context, 'back')),
                                  ]
                                : [
                                    ('↑ ↓', tr(context, 'channel')),
                                    ('← →', tr(context, 'volume')),
                                    ('Enter', tr(context, 'play/pause')),
                                    ('M', tr(context, 'mute')),
                                    ('F', tr(context, 'fullscreen')),
                                    ('Esc', tr(context, 'back')),
                                  ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeline(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: duration,
      builder: (context, durSnap) {
        final total = durSnap.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: position,
          builder: (context, posSnap) {
            final pos = posSnap.data ?? Duration.zero;
            final maxMs = total.inMilliseconds.toDouble();
            final value = maxMs <= 0
                ? 0.0
                : pos.inMilliseconds.clamp(0, total.inMilliseconds).toDouble();
            final remaining = total - pos;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (maxMs > 0)
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      activeTrackColor: AppTheme.accent,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: AppTheme.accent,
                      overlayColor: AppTheme.accent.withValues(alpha: 0.18),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 18,
                      ),
                    ),
                    child: Slider(
                      value: value,
                      max: maxMs,
                      onChangeStart: (_) => onPoke(),
                      onChanged: (v) =>
                          onScrub(Duration(milliseconds: v.round())),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: [
                      Text(_fmt(pos), style: _timeStyle),
                      const Spacer(),
                      Text('-${_fmt(remaining)}', style: _timeStyle),
                      const SizedBox(width: 12),
                      Text(_fmt(total), style: _timeStyle),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _liveLine(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 6, bottom: 2),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: AppTheme.danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            tr(context, 'LIVE'),
            style: _timeStyle.copyWith(letterSpacing: 1.1),
          ),
          const Spacer(),
          Text(tr(context, 'live stream'), style: _timeStyle),
        ],
      ),
    );
  }

  /// Phones: transport centred on its own row, volume on a second row. Fitting
  /// five buttons, a 56 dp play button, mute, a slider and cinema into one row
  /// overflows a 360 dp screen — this layout is what keeps it honest.
  Widget _transportNarrow(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PlayerRoundButton(
              icon: Icons.skip_previous,
              tooltip: tr(context, 'Previous (↑)'),
              onTap: canPrevious ? onPrev : null,
            ),
            if (seekable)
              PlayerRoundButton(
                icon: Icons.replay_10,
                tooltip: tr(context, 'Back 10 s (←)'),
                onTap: () => onSeek(-10),
              ),
            PlayerPlayButton(
              playing: playing,
              onTap: onPlayPause,
              focusNode: playFocusNode,
              onFocusChange: (v) {
                if (v) onPoke();
              },
            ),
            if (seekable)
              PlayerRoundButton(
                icon: Icons.forward_10,
                tooltip: tr(context, 'Forward 10 s (→)'),
                onTap: () => onSeek(10),
              ),
            PlayerRoundButton(
              icon: Icons.skip_next,
              tooltip: tr(context, 'Next (↓)'),
              onTap: canNext ? onNext : null,
            ),
          ],
        ),
        Row(
          children: [
            PlayerRoundButton(
              icon: muted || volume == 0 ? Icons.volume_off : Icons.volume_up,
              tooltip: tr(context, 'Mute (M)'),
              onTap: onMute,
            ),
            Expanded(child: _volumeSlider(context)),
            PlayerRoundButton(
              icon: cinema
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              tooltip: cinema
                  ? tr(context, 'Exit cinema (C)')
                  : tr(context, 'Cinema (C)'),
              onTap: onCinema,
            ),
          ],
        ),
      ],
    );
  }

  Widget _volumeSlider(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2.5,
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white24,
        thumbColor: Colors.white,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
      ),
      child: Slider(value: volume.clamp(0, 100), max: 100, onChanged: onVolume),
    );
  }

  Widget _transport(BuildContext context) {
    return Row(
      children: [
        PlayerRoundButton(
          icon: Icons.skip_previous,
          tooltip: tr(context, 'Previous (↑)'),
          onTap: canPrevious ? onPrev : null,
        ),
        if (seekable)
          PlayerRoundButton(
            icon: Icons.replay_10,
            tooltip: tr(context, 'Back 10 s (←)'),
            onTap: () => onSeek(-10),
          ),
        PlayerPlayButton(
          playing: playing,
          onTap: onPlayPause,
          focusNode: playFocusNode,
          onFocusChange: (v) {
            if (v) onPoke();
          },
        ),
        if (seekable)
          PlayerRoundButton(
            icon: Icons.forward_10,
            tooltip: tr(context, 'Forward 10 s (→)'),
            onTap: () => onSeek(10),
          ),
        PlayerRoundButton(
          icon: Icons.skip_next,
          tooltip: tr(context, 'Next (↓)'),
          onTap: canNext ? onNext : null,
        ),
        const Spacer(),
        PlayerRoundButton(
          icon: muted || volume == 0 ? Icons.volume_off : Icons.volume_up,
          tooltip: tr(context, 'Mute (M)'),
          onTap: onMute,
        ),
        SizedBox(width: 132, child: _volumeSlider(context)),
        const SizedBox(width: 2),
        PlayerRoundButton(
          icon: cinema ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          tooltip: cinema
              ? tr(context, 'Exit cinema (C)')
              : tr(context, 'Cinema (C)'),
          onTap: onCinema,
        ),
      ],
    );
  }

  static const _timeStyle = TextStyle(
    fontSize: 11.5,
    color: Color(0xFFCFC8D2),
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static String _fmt(Duration raw) {
    var d = raw;
    if (d.isNegative) d = Duration.zero;
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}

/// 44 dp touch target so a thumb can actually hit it.
class PlayerRoundButton extends StatelessWidget {
  const PlayerRoundButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: FocusRing(
        borderRadius: 24,
        onSelect: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 22,
            color: onTap == null ? Colors.white38 : Colors.white,
          ),
        ),
      ),
    );
  }
}

/// The one control that should never be missed.
class PlayerPlayButton extends StatelessWidget {
  const PlayerPlayButton({
    super.key,
    required this.playing,
    required this.onTap,
    this.focusNode,
    this.onFocusChange,
  });

  final bool playing;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChange;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tr(context, 'Play / pause (Enter, Space)'),
      child: FocusRing(
        borderRadius: 40,
        onSelect: onTap,
        focusNode: focusNode,
        onFocusChange: onFocusChange,
        child: Container(
          width: 56,
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(
            playing ? Icons.pause : Icons.play_arrow,
            size: 30,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Small translucent label, e.g. the position in the current list.
class PlayerPill extends StatelessWidget {
  const PlayerPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          color: Colors.white,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
