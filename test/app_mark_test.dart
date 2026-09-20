import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/widgets/app_mark.dart';

void main() {
  testWidgets('the app mark is the one Spectre brand asset, everywhere',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(body: Center(child: AppMark(size: 64))),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/branding/spectre_icon.png');
    // The launcher icon and the in-app mark are the same file by design.
    expect(AppMark.asset, 'assets/branding/spectre_icon.png');
  });

  testWidgets('the mark stays the brand icon whatever the stored preference says',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(body: Center(child: AppMark(size: 48))),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/branding/spectre_icon.png');
  });
}
