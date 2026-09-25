/// Panel presets.
///
/// The Spectre/XCIPTV build these credentials came with ships a "SELECT PANEL"
/// list; picking an entry is what fills its server field — it never uses a
/// provider address typed from a note. The same five panels are reproduced here
/// so this client can be used the same way.
///
/// They are ordinary Xtream-Codes panels on port 8080. Most of them only answer
/// to their own customers' IP ranges (an nginx 401/511/512 from anywhere else),
/// so expect some to be unusable from a given network — that is what the
/// "Test a list of servers" screen reports. Edit or extend this list freely;
/// nothing here is required.
library;

class PanelPreset {
  final String name;
  final String url;
  final String region;

  const PanelPreset({
    required this.name,
    required this.url,
    required this.region,
  });
}

const List<PanelPreset> kPanelPresets = [
  PanelPreset(
    name: 'EUROPE 1',
    url: 'http://e-de.dynu.net:8080',
    region: 'Europe',
  ),
  PanelPreset(
    name: 'EUROPE 2',
    url: 'http://3teamall.xyz:8080',
    region: 'Europe',
  ),
  PanelPreset(
    name: 'TÜRKİYE PANEL 1',
    url: 'http://maxspectre.com:8080',
    region: 'Türkiye',
  ),
  PanelPreset(
    name: 'TÜRKİYE PANEL 2',
    url: 'http://kngkral38.com:8080',
    region: 'Türkiye',
  ),
  PanelPreset(
    name: 'TÜRKİYE İZNE GELENLER',
    url: 'http://e-tr.dynuddns.com:8080',
    region: 'Türkiye',
  ),
];

/// Every preset URL, one per line — used to prefill the server tester.
String presetUrlsAsText() => kPanelPresets.map((p) => p.url).join('\n');
