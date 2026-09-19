# Xtream Player

A cross-platform IPTV client for **Xtream-Codes** panels — Linux, Windows, Android and iOS —
built so a subscription can be used *without* the phone app that normally locks it in.

Repository: **https://github.com/dcenhance/xt_client_flutter**

It speaks the same protocol the phone apps use (`/player_api.php`, `/get.php`, `/xmltv.php`),
so the three values your provider gives you (server, username, password) are all it needs.

```
┌───────────────┐   player_api.php?username=..&password=..   ┌──────────────────┐
│ Xtream Player │ ─────────────────────────────────────────► │ your IPTV panel  │
│  Linux/Win/   │ ◄─────── live / VOD / series / EPG ─────── │ (host:8080 …)    │
│  Android      │   /live/u/p/<id>.ts · /movie/… · /series/…  └──────────────────┘
└───────────────┘
```

---

## Contents

- [What it does](#what-it-does)
- [Where the credentials come from](#where-the-credentials-come-from)
- [Build and run](#build-and-run)
  - [Linux](#linux)
  - [Windows](#windows)
  - [Android](#android)
- [Keyboard, TV remote and gamepad](#keyboard-tv-remote-and-gamepad)
- [Testing](#testing)
- [Using the subscription in other players](#using-the-subscription-in-other-players)
- [Troubleshooting login failures](#troubleshooting-login-failures)
- [Project layout](#project-layout)
- [Support boundaries](#support-boundaries)

---

## What it does

### One app, two interface styles

| Platform | Layout |
|---|---|
| Linux / Windows / macOS | tab strip (Live TV · Movies · Series) + category rail + keyboard-hint footer |
| Android / iOS | **bottom navigation** (Live TV · Movies · Series · Account), category chips, search toggled from the app bar, account summary under the title |

Both are fully D-pad / remote navigable — the mobile shell is what you get on Android TV and
Fire TV too.

### Fitting more on screen

Two toggles sit in the app bar on every platform, and both are remembered:

* **Grid ↔ list.** List view is one dense row per channel (logo, name, kind marker) instead of a
  card. On a 1600×1000 desktop window the grid shows **6 channels**, the compact list shows **13**.
* **Comfortable ↔ compact.** Compact shrinks cards to ~146 px, tightens spacing and drops the
  second title line, so a full live list is roughly 2× denser than the default.

### Looking at servers without a login

**Look at servers without login** on the login screen asks the address you typed plus every panel in
`lib/panels.dart` for their category lists with **no username or password attached**:

| Result | Meaning |
|---|---|
| `OPEN — 2 live / 1 VOD / 1 series categories without login` | the panel hands its lists to anyone: press **Browse** and the channels load with no account at all |
| `panel answers but keeps its lists private` | real panel, needs credentials |
| `answers, but not like an Xtream panel — HTTP 511` | something else is listening on that port |
| `no answer` | nothing answered there |

A guest session is marked **no login — open panel** in the app bar and the Account tab, and can be
left at any time without touching saved credentials.

| Area | Status |
|---|---|
| Login (`player_api.php`) with clear failure reasons | yes |
| Live TV: categories, channel grid, logos, search | yes |
| Movies (VOD) with container-extension aware URLs | yes |
| Series: seasons/episodes via `get_series_info`, per-episode playback | yes |
| EPG now/next per channel via `get_short_epg` (base64 decoded) | yes |
| Playback on Linux/Windows/Android (libmpv through `media_kit`) | yes |
| Playlist + EPG extraction for other players (copy buttons) | yes |
| HLS output when the panel advertises `m3u8` | yes |
| Remember me (server/user/password in local prefs) | yes |
| Catch-up/archive playback, recording, parental control, M3U-only mode | not implemented |
| Raw gamepads that expose no keyboard events | not mapped |

## Where the credentials come from

Your IPTV seller hands you three values:

1. **Server** — panel address with port, e.g. `http://example.com:8080`
2. **Username**
3. **Password**

The app only ever sends them to that server. They are stored locally
(`shared_preferences`) when *Remember me* is on, and are embedded in the
generated stream/playlist URLs — treat the M3U link as a secret.

## Download / release formats

Every tagged release (`v*`) carries all of these as assets; the CI jobs build them on every push.

| Platform | Format | Notes |
|---|---|---|
| Linux | `.AppImage` | single file, `chmod +x` and run; bundles libmpv, no install needed |
| Linux | `.deb` | Debian/Ubuntu/Mint — `sudo apt install ./xtream-player_*.deb` |
| Linux | `.rpm` | Fedora/Nobara/openSUSE — `sudo dnf install ./xtream-player-*.rpm` |
| Linux | `.tar.gz` / `.tar.xz` | portable bundle, run `xtream_player` from the extracted folder |
| Windows | `-setup.exe` | Inno Setup installer: Start-Menu/desktop entry, uninstaller |
| Windows | `-portable.zip` | unpack anywhere and run `xtream_player.exe` |
| Android | `universal.apk` | one APK for every device (also the sideload default) |
| Android | `arm64-v8a / armeabi-v7a / x86_64 .apk` | smaller per-architecture builds |
| Android | `.aab` | Play Store upload bundle |
| macOS | `.dmg` | drag-to-Applications installer |
| macOS | `.app.zip` | portable app bundle |
| iOS | `-unsigned.app.zip` | simulator/QA use; installing on a device needs a signing identity |

Local builds: `tool/package-linux.sh` produces every Linux format in `build/dist`;
`tool/windows-installer.iss` is the Inno Setup script used by CI.

> Linux note: the Flutter Linux build links the **system** `libmpv.so.2`
> (`mpv-libs` on Fedora, `libmpv2` on Debian/Ubuntu) — the `.deb`/`.rpm` declare that dependency,
> and the AppImage bundles its own copy so it runs anywhere.

## Build and run

Requirements per platform are Flutter's own; nothing extra.

### Linux

```bash
flutter pub get
flutter build linux --release
./build/linux/x64/release/bundle/xtream_player
```

A ready launcher for the KDE menu:

```bash
./tool/install-desktop-entry.sh      # writes ~/.local/share/applications/xtream-player.desktop
```

### Windows

Flutter cannot cross-compile, so this runs on a Windows machine (or the CI workflow below):

```powershell
flutter pub get
flutter build windows --release
build\windows\x64\runner\Release\xtream_player.exe
```

Everything the app needs (`media_kit` → libmpv, `shared_preferences`) is bundled by those
plugins; no external codecs to install.

### Android

Phone / tablet / Android TV / Fire TV:

```bash
flutter build apk --release            # universal APK
flutter build apk --split-per-abi      # smaller per-architecture APKs
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

The Android manifest enables leanback (TV) and touch modes, so the same APK works on a
phone and on a TV box.

### iOS

Apple's toolchain only runs on macOS, so this is a Mac-side step (the `ios/` folder is scaffolded and
already carries the `NSAllowsArbitraryLoads` exception that plain-HTTP panels need):

```bash
flutter pub get
flutter build ios --release --no-codesign     # or open ios/Runner.xcworkspace in Xcode
```

### CI builds for all three targets

`.github/workflows/build.yml` builds Linux, Windows and Android artifacts on every tag
(`v*`) and uploads them as release assets — no Windows machine needed locally.

## Keyboard, TV remote and gamepad

| Key / button | Action |
|---|---|
| `↑ ↓ ← →` | move focus |
| `Enter`, `OK` (remote), `Space` | activate / play-pause |
| `Esc`, `Back` (remote) | go back |
| `Ctrl+F` or `/` | jump to search |
| Player: `↑ ↓` | previous / next item in the current list |
| Player: `← →` | seek ±10 s (VOD and episodes) / volume (live) |
| Player: `Enter`, `Space`, media keys | play/pause |
| Player: `M` | mute · `+` `-` volume |
| Player: `C` | cinema mode (hides chrome) · `I` toggle info card |

Works with Fire TV / Android TV remotes, HID/IR remotes, keyboards and controllers that
present themselves as keyboards. Focus is always visible (accent ring) and every screen is
reachable without a mouse.

## Testing

* `flutter test` — unit tests run the client against a **real HTTP server** started inside the
  test (fake panel): success login, `auth:0` rejection, expired account, Cloudflare-style
  `403 error code: 1034`, closed port, and the stream-URL shapes.
* `python3 tool/mock_panel.py 8420` — stand-alone fake panel (login, 3 live channels, VOD,
  a series with 2 episodes, short EPG, M3U, XMLTV and a generated 20 s test clip). Log in with
  `http://127.0.0.1:8420` / `demo` / `demo` to exercise the whole UI without a real provider.
* `flutter analyze` — clean apart from informational lints.

## Using the subscription in other players

Open **Settings → Use the same subscription in another app** inside the app; it shows and
copies:

| Purpose | URL |
|---|---|
| M3U (all channels, ts) | `http://host:8080/get.php?username=U&password=P&type=m3u_plus&output=ts` |
| M3U (HLS) | `...&output=m3u8` |
| EPG | `http://host:8080/xmltv.php?username=U&password=P` |
| Live stream | `http://host:8080/live/U/P/<stream_id>.ts` (`.m3u8` for HLS) |
| Movie | `http://host:8080/movie/U/P/<stream_id>.<ext>` |
| Series episode | `http://host:8080/series/U/P/<episode_id>.<ext>` |

Those load in VLC (Media → Open Network Stream), `mpv <url>`, Kodi (PVR IPTV Simple Client
for M3U + XMLTV) or any other Xtream-compatible player.

`~/xtream-access.py` is a CLI that probes several candidate hosts, reports which one
authenticates, and writes a ready-to-play `.m3u` (created with mode 600, because it embeds
the password).

## Panel picker (parity with the Spectre/XCIPTV build)

The app these credentials came from does **not** log in to an address you type: it ships a
`SELECT PANEL` list and picks the server from it. This client reproduces that list under
**Select panel** (EUROPE 1 · EUROPE 2 · TÜRKİYE PANEL 1 · TÜRKİYE PANEL 2 · TÜRKİYE İZNE GELENLER),
fills the server field from your choice, and pre-fills **Test a list of servers** with all five so
one tap tells you which one answers from your current network.

The list is in `lib/panels.dart` — plain data, edit or empty it as you like.

**About refusals:** a panel that turns a login down answers with `HTTP 511/512` or drops the
connection. Probed with a deliberately wrong password, all five of these do exactly that:

```
http://e-de.dynu.net:8080      HTTP 511/512
http://3teamall.xyz:8080       HTTP 511/512
http://maxspectre.com:8080     connection closed before full header
http://kngkral38.com:8080      connection closed before full header
http://e-tr.dynuddns.com:8080  HTTP 512
```

That is the panel rejecting the *login*, not the network. With a real account the same address
answers normally — `http://e-de.dynu.net:8080` (EUROPE 1) served 4195 live channels to this client
on Linux with valid credentials. So if every address in the test comes back `refused`, check the
username and password first; the panel is reachable.

## Troubleshooting login failures

The login screen distinguishes the cases the phone apps blur together — and can check them for you:

* **Diagnose this server (DNS + ports)** — resolves the hostname, flags placeholder addresses
  (`1.1.1.1`, `1.0.0.1`, TEST-NET ranges: a DNS record pointing nowhere), then probes the port you
  typed plus the usual Xtream ports (8080, 80, 8880, 8000, 25461, 2095, 9000) with your credentials.
  It reports per port whether anything answered, whether it answered as an Xtream panel and whether
  the login was accepted, and ends with one verdict. If a probe does authenticate, it offers
  **Use this server**.
* **Test a list of servers** — paste one address per line (from your provider, a reseller list, an
  old invoice); the same username/password is tried against each and you get a tick or a cross with
  the expiry date. A working host gets a **Use** button that adopts it and logs in. Blank lines and
  `#` comments are ignored; nothing is sent anywhere except those hosts.

| Message | Meaning | Fix |
|---|---|---|
| `Cloudflare could not reach the origin … error code 1034` | the hostname's DNS record points at a placeholder (`1.1.1.1`), so no request reaches a server at all | ask the provider for the current panel host, or paste their host list into **Test a list of servers** |
| `HTTP 401/403/511/512` | panel answered but refuses this IP or these credentials | try another network/VPN, or ask the provider to whitelist you |
| `Cannot reach …` | nothing listening / wrong port / firewall | check host and port, or run **Diagnose this server** |
| `Non-JSON reply` | something answered that is not an Xtream panel | check the address ends in the panel port |
| `Panel refused these credentials (panel said: …)` | wrong credentials, expired subscription, or too many connections | verify with the provider |
| `Account expired on …` | subscription lapsed | renew |

## Project layout

```
lib/
  main.dart                 app entry, global AppState, MaterialApp
  models.dart               AccountInfo, Category, StreamItem, EpgEntry
  xtream_client.dart        the API, error taxonomy, stream/playlist/EPG URL builders
  diagnostics.dart          DNS/placeholder detection, port probing, multi-server test
  store.dart                login, persistence, per-tab content cache, search
  theme.dart                very dark flat theme (Breeze-blue accent)
  widgets/focus_ring.dart   D-pad focus ring, key-hint bar, app-level Esc/Back handling
  screens/
    login_screen.dart       server / username / password + failure explanation
    home_screen.dart        tabs, category rail, channel grid, series episode sheet
    player_screen.dart      media_kit player, EPG info card, D-pad control bar
    settings_sheet.dart     account status, playlist/EPG URLs, remote help
tool/
  mock_panel.py             fake Xtream panel for offline UI testing
  install-desktop-entry.sh  KDE menu entry pointing at the built binary
test/
  xtream_client_test.dart   HTTP-level tests against a real local socket
```

## Support boundaries

* Xtream-Codes compatible panels only (`player_api.php`). Plain M3U/Xtream UI
  (`panel_pro`), catch-up, recording and DRM are out of scope.
* No account, no telemetry beyond what Flutter/plugins bundle; nothing is sent anywhere
  except to the panel you configure.
* Streams themselves are the provider's business — this client only speaks the documented
  API and plays what the panel returns.