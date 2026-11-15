# Changelog

## 7.4.0
- **Softer keys.** Every key (keyboard sheet, trackpad Left / Right / Back / Home, media remote, VOL / CH rockers) now has a corner
  radius that follows its size (`BTKeyRadius`, about 42% of the short side), a thinner side wall, a domed face (sheen on top, a
  little shade below) and a light rounded rim, so they no longer look like square blocks.
- **Media page is one unibody** in Reels and trackpad-style pad mode, like the main Trackpad page: a full-page brushed block
  with the pad and the remote etched into it as separate sections. The D-pad page keeps its slab.
- **No more finish change when expanding / collapsing** the media pad: the aluminium is never resized or redrawn, only the
  etched borders (new `BTEtchedBoxView`, live layers instead of a bitmap) move.
- **Reels on / off flips the media page** the same way Trackpad <-> Media does.
- **Dark grey navigation bar** (was blue-grey) with lighter grey bar buttons, segmented controls and Back buttons to match.
- **Soft warning on untested setups.** Anything other than an iPhone 4s on iOS 6 gets an "Untested device" prompt (Quit /
  Continue). Bluetooth, and with it the daemon, only starts after Continue; the choice is remembered per model + iOS version.
- **Dark brushed graphite backdrop** (`BTBackdropColor`) replaces the linen / black behind the slabs, the window, the
  navigation controller and the keyboard sheet.

## 7.3.0
- **OK button works like a real remote.** OK used to send keyboard Enter, so with Gboard open it committed the text instead of
  selecting the highlighted suggestion. It now sends HID Consumer "Menu Pick" (0x41, Android DPAD_CENTER).
  *Settings > Media remote > OK button* switches between **Select** (default) and **Enter** (fallback).
- **D-pad OK is a held key**: finger down = key down, finger up = key up, so tap = click and hold = long press.
  Rolling off OK, or the pad being hidden, releases the key.
- Media gesture pad: a tap sends the same OK.
- Core: new commands `OK`, `OKD`, `OKU`, `OKMODE 0|1`.

## 7.2.0
- New iOS 6 style pre-rendered icon (brushed aluminium D-pad, glossy blue Bluetooth jewel, domed gloss), all four sizes.
- Trackpad, media pad and the D-pad backdrop now share a real **horizontally brushed aluminium slab** (`BTDrawPanel`),
  rendered once per size and cached.
- Added `tools/make_icon.py` and `tools/preview_slab.py`.

## 7.1.0
- **Automatic pairing, no passcode.** The daemon switched Secure Simple Pairing off (`gap_ssp_set_enable(0)`), so TVs fell
  back to legacy PIN pairing. It now runs SSP with IO capability NoInputNoOutput, general bonding, auto accept ("Just Works").
- The app no longer answers the IO-capability / user-confirmation events itself; the stack does (no duplicate replies).
- New daemon command `BTSTACK_SET_SSP_IOCAP` so the optional *Type the TV's passkey* switch still works.
- Legacy PIN prompt kept for TVs without SSP.
- Re-pair required after updating.

## 7.0.0
- Standalone build: BTstack v1.2 client library compiled into the app, daemon built from source as `BluemoteDaemon`
  (own socket, started by launchd on demand).
- Single main screen with a flip between Trackpad and Media, keyboard sheet, Settings, Pairing & Devices.
- Pairing keys moved to `~/Library/Application Support/Bluemote/link_keys.bin` (mode 0600).
- Earlier daemon / UI fixes are listed in [docs/DEVELOPER_NOTES.txt](docs/DEVELOPER_NOTES.txt).

## Repository housekeeping (with 7.3.0)
- Added `README.md`, `CHANGELOG.md`, `docs/`, `.gitignore`, `.gitattributes`.
- Removed tracked build output (`.theos/`), the stale `bluemote.zip` snapshot and the unused `btcombo_core.c/.h`.
- `README.txt` moved to `docs/DEVELOPER_NOTES.txt`.
