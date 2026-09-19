# Xtream Player

A cross-platform IPTV client for **Xtream-Codes** panels — Linux, Windows and Android —
built so a subscription can be used *without* the phone app that normally locks it in.

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

## Troubleshooting login failures

The login screen distinguishes the cases the phone apps blur together:

| Message | Meaning | Fix |
|---|---|---|
| `HTTP 403 ... error code 1034` (Cloudflare) | the server hostname resolves to a placeholder, e.g. an `A → 1.1.1.1` proxied record | correct the DNS record; no client can log in |
| `HTTP 401/403/511/512` | panel answered but refuses this IP or these credentials | try another network/VPN, or ask the provider to whitelist you |
| `Cannot reach ...` | nothing listening / wrong port / firewall | check host and port |
| `Non-JSON reply` | something answered that is not an Xtream panel | check the address ends in the panel port |
| `Panel refused username/password` | wrong credentials or too many connections | verify with the provider |
| `Account expired on ...` | subscription lapsed | renew |

## Project layout

```
lib/
  main.dart                 app entry, global AppState, MaterialApp
  models.dart               AccountInfo, Category, StreamItem, EpgEntry
  xtream_client.dart        the API, error taxonomy, stream/playlist/EPG URL builders
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