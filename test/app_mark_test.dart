import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/main.dart';
import 'package:xtream_player/widgets/app_mark.dart';

void main() {
  testWidgets('the app mark can be swapped and is remembered', (tester) async {
    appState.markVariant = 'orbit';

    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(body: Center(child: AppMark(size: 64))),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    Image image() => tester.widget<Image>(find.byType(Image));
    expect((image().image as AssetImage).assetName, 'assets/marks/orbit.png');

    // Switching repaints without a restart.
    appState.markVariant = 'prism';
    appState.setMarkVariant('prism');
    await tester.pump(const Duration(milliseconds: 200));
    expect((image().image as AssetImage).assetName, 'assets/marks/prism.png');

    // Every shipped variant has an asset and a label.
    expect(AppMark.variants.length, greaterThanOrEqualTo(4));
    expect(AppMark.ids, containsAll(['orbit', 'belt', 'monogram', 'prism', 'aperture', 'constellation']));
    appState.markVariant = 'orbit';
  });

  testWidgets('an unknown stored variant falls back to the first mark',
      (tester) async {
    appState.markVariant = 'nonsense';
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(body: Center(child: AppMark(size: 48))),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/marks/orbit.png');
    appState.markVariant = 'orbit';
  });
}