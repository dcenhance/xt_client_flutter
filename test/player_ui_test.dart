import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/models.dart';
import 'package:xtream_player/widgets/focus_ring.dart';
import 'package:xtream_player/widgets/player_chrome.dart';

/// The player chrome is the phone-facing part of the player, so it is pinned
/// here: nothing may overflow a 360 dp phone, the keyboard legend belongs on
/// wide windows only, every control keeps a 44 dp touch target, and a live
/// stream never shows a scrubber it cannot honour.
void main() {
  const phone = Size(360, 640);
  const desktop = Size(1280, 720);

  Stream<Duration> once(Duration value) => Stream<Duration>.value(value);

  Widget host(Widget child) => MaterialApp(
        home: Scaffold(backgroundColor: Colors.black, body: child),
      );

  Future<void> pumpBottom(
    WidgetTester tester, {
    required Size size,
    required bool wide,
    required bool seekable,
    Duration position = const Duration(seconds: 62),
    Duration duration = const Duration(minutes: 2, seconds: 5),
    double volume = 70,
    bool muted = false,
    bool playing = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(PlayerBottomChrome(
      visible: true,
      wide: wide,
      seekable: seekable,
      playing: playing,
      volume: volume,
      muted: muted,
      position: once(position),
      duration: once(duration),
      onPlayPause: () {},
      onSeek: (_) {},
      onVolume: (_) {},
      onMute: () {},
      onPrev: () {},
      onNext: () {},
      onCinema: () {},
      onFullscreen: () {},
      onScrub: (_) {},
      onPoke: () {},
    )));
    await tester.pump();
  }

  testWidgets('phone chrome fits a 360 dp screen without overflowing',
      (tester) async {
    await pumpBottom(tester, size: phone, wide: false, seekable: true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone chrome hides the keyboard legend', (tester) async {
    await pumpBottom(tester, size: phone, wide: false, seekable: true);
    expect(find.byType(KeyHintBar), findsNothing);
  });

  testWidgets('wide chrome keeps the keyboard legend', (tester) async {
    await pumpBottom(tester, size: desktop, wide: true, seekable: true);
    expect(find.byType(KeyHintBar), findsOneWidget);
  });

  testWidgets('every transport control is at least 44 dp', (tester) async {
    await pumpBottom(tester, size: phone, wide: false, seekable: true);
    for (final button in find.byType(PlayerRoundButton).evaluate()) {
      final size = tester.getSize(find.byWidget(button.widget));
      expect(size.height, greaterThanOrEqualTo(44.0));
      expect(size.width, greaterThanOrEqualTo(44.0));
    }
    final play = tester.getSize(find.byType(PlayerPlayButton));
    expect(play.height, greaterThanOrEqualTo(44.0));
  });

  testWidgets('the volume slider stays inside the screen', (tester) async {
    await pumpBottom(tester, size: phone, wide: false, seekable: true);
    final sliders = find.byType(Slider).evaluate().toList();
    expect(sliders, isNotEmpty);
    for (final slider in sliders) {
      final rect = tester.getRect(find.byWidget(slider.widget));
      expect(rect.left, greaterThanOrEqualTo(0.0));
      expect(rect.right, lessThanOrEqualTo(phone.width));
    }
  });

  testWidgets('a seekable stream shows elapsed, remaining and total',
      (tester) async {
    await pumpBottom(tester, size: phone, wide: false, seekable: true);
    expect(find.text('01:02'), findsOneWidget);
    expect(find.text('-01:03'), findsOneWidget);
    expect(find.text('02:05'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(2)); // timeline + volume
  });

  testWidgets('live TV shows LIVE and no scrubber', (tester) async {
    await pumpBottom(tester, size: phone, wide: false, seekable: false);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget); // volume only
    expect(find.byIcon(Icons.replay_10), findsNothing);
    expect(find.byIcon(Icons.forward_10), findsNothing);
  });

  testWidgets('a muted player shows the muted glyph', (tester) async {
    await pumpBottom(tester, size: phone, wide: false, seekable: true, volume: 0, muted: true);
    expect(find.byIcon(Icons.volume_off), findsOneWidget);
  });

  testWidgets('top chrome shows the title, kind and list position',
      (tester) async {
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(PlayerTopChrome(
      visible: true,
      title: 'EAGLE CINEMA Entdeckernatur 4K',
      kind: 'live',
      epg: [
        EpgEntry(
          title: 'Fantastic Fungi',
          description: '',
          start: DateTime(2026, 9, 20, 12, 0),
          end: DateTime(2026, 9, 20, 13, 30),
        ),
      ],
      index: 2,
      total: 38,
      fullscreen: false,
      onBack: () {},
      onFullscreen: () {},
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('EAGLE CINEMA Entdeckernatur 4K'), findsOneWidget);
    expect(find.text('3/38'), findsOneWidget);
    expect(find.textContaining('12:00–13:30'), findsOneWidget);
  });

  testWidgets('top chrome falls back to the kind when there is no EPG',
      (tester) async {
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(PlayerTopChrome(
      visible: true,
      title: 'Some Movie',
      kind: 'movie',
      epg: const [],
      index: 0,
      total: 1,
      fullscreen: false,
      onBack: () {},
      onFullscreen: () {},
    )));
    await tester.pump();
    expect(find.text('Movie'), findsOneWidget);
    expect(find.byType(PlayerPill), findsNothing); // single item, no counter
  });
}
