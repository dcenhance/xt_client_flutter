import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/screens/player_screen.dart';

void main() {
  test(
    'HLS error opens TS once and only a TS failure reaches the UI',
    () async {
      final hlsErrors = StreamController<String>.broadcast(sync: true);
      final tsErrors = StreamController<String>.broadcast(sync: true);
      addTearDown(hlsErrors.close);
      addTearDown(tsErrors.close);
      final urls = <String>[];
      final failures = <String>[];
      var fallbackCreations = 0;
      final attempt = LivePlaybackAttempt(
        primary: PlaybackOpening(
          errors: hlsErrors.stream,
          open: (url) async => urls.add(url),
        ),
        fallback: () {
          fallbackCreations++;
          return PlaybackOpening(
            errors: tsErrors.stream,
            open: (url) async => urls.add(url),
          );
        },
        onFailure: failures.add,
      );
      addTearDown(attempt.dispose);

      await attempt.start(
        'https://panel/live/1.m3u8',
        fallbackUrl: 'https://panel/live/1.ts',
      );
      hlsErrors.add('HLS cannot open');
      await Future<void>.delayed(Duration.zero);
      expect(urls, ['https://panel/live/1.m3u8', 'https://panel/live/1.ts']);
      expect(failures, isEmpty);
      hlsErrors.add('late duplicate HLS error');
      await Future<void>.delayed(Duration.zero);
      expect(fallbackCreations, 1);
      expect(failures, isEmpty);

      tsErrors.add('TS cannot open');
      expect(failures, ['TS cannot open']);
      tsErrors.add('duplicate TS error');
      expect(failures, ['TS cannot open']);
      expect(urls, hasLength(2));
    },
  );

  test('a thrown HLS open also falls back once', () async {
    final hlsErrors = StreamController<String>.broadcast(sync: true);
    final tsErrors = StreamController<String>.broadcast(sync: true);
    addTearDown(hlsErrors.close);
    addTearDown(tsErrors.close);
    final urls = <String>[];
    final failures = <String>[];
    final attempt = LivePlaybackAttempt(
      primary: PlaybackOpening(
        errors: hlsErrors.stream,
        open: (url) async {
          urls.add(url);
          throw StateError('HLS open failed');
        },
      ),
      fallback: () => PlaybackOpening(
        errors: tsErrors.stream,
        open: (url) async => urls.add(url),
      ),
      onFailure: failures.add,
    );
    addTearDown(attempt.dispose);
    await attempt.start('1.m3u8', fallbackUrl: '1.ts');
    await Future<void>.delayed(Duration.zero);
    expect(urls, ['1.m3u8', '1.ts']);
    expect(failures, isEmpty);
  });

  test('retired channel cannot switch a newer channel to TS', () async {
    final oldErrors = StreamController<String>.broadcast(sync: true);
    final newErrors = StreamController<String>.broadcast(sync: true);
    addTearDown(oldErrors.close);
    addTearDown(newErrors.close);
    final urls = <String>[];
    final failures = <String>[];
    var oldFallbackCreations = 0;
    final oldChannel = LivePlaybackAttempt(
      primary: PlaybackOpening(
        errors: oldErrors.stream,
        open: (url) async => urls.add(url),
      ),
      fallback: () {
        oldFallbackCreations++;
        return PlaybackOpening(
          errors: oldErrors.stream,
          open: (url) async => urls.add(url),
        );
      },
      onFailure: failures.add,
    );
    await oldChannel.start('old.m3u8', fallbackUrl: 'old.ts');
    oldChannel.dispose(); // channel navigation retires the old player/attempt
    final newChannel = LivePlaybackAttempt(
      primary: PlaybackOpening(
        errors: newErrors.stream,
        open: (url) async => urls.add(url),
      ),
      onFailure: failures.add,
    );
    addTearDown(newChannel.dispose);
    await newChannel.start('new.ts');
    oldErrors.add('late old-channel HLS error');
    await Future<void>.delayed(Duration.zero);
    expect(urls, ['old.m3u8', 'new.ts']);
    expect(oldFallbackCreations, 0);
    expect(failures, isEmpty);
  });

  test(
    'late open failure from retired channel cannot start fallback',
    () async {
      final oldErrors = StreamController<String>.broadcast(sync: true);
      final newErrors = StreamController<String>.broadcast(sync: true);
      addTearDown(oldErrors.close);
      addTearDown(newErrors.close);
      final pendingOpen = Completer<void>();
      final urls = <String>[];
      final failures = <String>[];
      final oldChannel = LivePlaybackAttempt(
        primary: PlaybackOpening(
          errors: oldErrors.stream,
          open: (url) {
            urls.add(url);
            return pendingOpen.future;
          },
        ),
        fallback: () => PlaybackOpening(
          errors: oldErrors.stream,
          open: (url) async => urls.add(url),
        ),
        onFailure: failures.add,
      );
      final oldStart = oldChannel.start('old.m3u8', fallbackUrl: 'old.ts');
      oldChannel.dispose();
      final newChannel = LivePlaybackAttempt(
        primary: PlaybackOpening(
          errors: newErrors.stream,
          open: (url) async => urls.add(url),
        ),
        onFailure: failures.add,
      );
      addTearDown(newChannel.dispose);
      await newChannel.start('new.ts');
      pendingOpen.completeError(StateError('old HLS failed late'));
      await oldStart;
      expect(urls, ['old.m3u8', 'new.ts']);
      expect(failures, isEmpty);
    },
  );
}
