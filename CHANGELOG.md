# Changelog

## 7.6.0
- **The app survives a restart of the BTstack daemon (or of the chip).** The client library reports
  `DAEMON_EVENT_CONNECTION_CLOSED` when the daemon goes away; the app ignored it, kept using a freed connection and never
  re-registered anything. Now `btstack.c` forgets the connection (`bt_send_*` are safe without one), the app forgets all link state,
  reopens the socket by timer (which starts the daemon again; it never gives up any more, the first start no longer ends the
  Bluetooth thread after 10 s), and repeats the whole start-up: L2CAP services, power on, SDP record, paired-device filter,
  reconnect (only if the person had not pressed Disconnect). If the chip goes `OFF` / `HALTING` while a link is up, the link state
  is reset too. `socket_connection_open_*` no longer leaks the descriptor of a failed connect (it is retried every few seconds).
- **Automatic reconnect.** The app now keeps trying to reach the last device (the SDP record says the phone reconnects, and many TVs
  never connect by themselves): after a failed attempt, a lost link or a fresh pairing it retries after 2 s, 5 s, 15 s, then every 30 s,
  at most 12 attempts per cycle (about 5 minutes; then the status says "TV not found - tap Reconnect to try again"). After a pairing the
  app waits 3 s for the TV to connect by itself, then connects to it. It runs only while the app is in the foreground (new
  `ACTIVE 1|0` command, sent from `applicationDidBecomeActive` / `applicationWillResignActive`; coming back starts a fresh cycle),
  never in pairing mode, and never after a deliberate Disconnect, Forget saved devices or forgetting the connected device.
  A retry goes to the device that was really connected last (`target_addr` follows every connection).
- **A second device can no longer take over a connection.** While a device is connected (or being connected) an incoming L2CAP
  channel from a different device is declined; the second channel of the same device is still accepted (`busy_with_other_device()`).
- **Only paired devices can connect, unless pairing mode is on.** Before, the iPhone was always discoverable and connectable,
  accepted every incoming connection and silently paired with anybody ("Just Works"). Now, with pairing mode off:
  - the iPhone is not discoverable (page scan only, so paired TVs can still reconnect);
  - the daemon rejects connection requests from any device that is not paired, before L2CAP or pairing
    (`gap_register_classic_connection_filter`), and refuses every new pairing, also from a listed device (the IO capability
    is "unknown", so the stack answers with "pairing not allowed"). A TV that forgot the iPhone has to be re-paired through
    **Pair new device**;
  - the app declines incoming L2CAP channels from unknown devices, ignores new link keys and PIN / passkey requests;
  - pairing mode **turns itself off after 2 minutes** (`PAIRING_TIMEOUT_MS`; tapping *Pair new device* again restarts the
    2 minutes; if a PIN / passkey box is open the timeout waits 30 s and looks again). It also closes when a device paired,
    when the app is closed (the daemon closes it when its last client goes away) and it is never on right after a start.
  New daemon command `BTSTACK_SET_CONNECTION_FILTER` (0x0A, `btstack_set_connection_filter`): the app sends the list of paired
  devices and the pairing mode flag; the daemon starts closed.
- **"Last device" is now the last one that connected, not the last one that paired.** The saved list is ordered by last
  connection: when a device connects it moves to the top, and *Reconnect to last* and the automatic reconnect at start use the
  top entry. Pairing no longer moves a device to the top; a new device goes to the end of the list (when 8 devices are saved it
  replaces the one that connected longest ago) and moves up as soon as it connects.
- **Crash-safe key file.** The pairing keys are now written to `link_keys.bin.tmp`, fsynced (`F_FULLFSYNC` on iOS, plain `fsync`
  as a fallback), renamed over `link_keys.bin`, and the folder is fsynced. A crash or power loss can no longer leave a truncated
  key file that loses every pairing; if a write fails the old file stays as it was. The one-time migration of the old
  `/var/mobile/bt_link_keys.bin` uses the same routine, so a half-copied file can no longer be mistaken for a complete one.
- **No more half open connections.** HID needs the control and the interrupt channel. When the interrupt channel fails to open
  (refused by the TV, link dropped, timeout) while the control channel is up, the app now closes the control channel
  (`drop_half_open_link()`), so the next connect starts clean instead of being blocked by a dead channel. The status line keeps
  "Connection to TV failed - try again" instead of being overwritten by the close.
  When the interrupt channel never answers at all (no failure event comes), a 10 second timer
  (`HALF_OPEN_TIMEOUT_MS`, started when the control channel opens, stopped when the interrupt channel opens or the control
  channel closes) closes the control channel too ("Connection to TV incomplete - try again").
- **Scroll tab reacts on the very edge of the screen.** The touch area was only the 40 pt tab, which starts about 14 pt inside the
  screen (the pad sits inside the aluminium frame), so a thumb on the screen edge did nothing. The touch area now starts at the
  left edge of the screen and reaches 8 pt past the right side of the tab (`TAB_HIT_RIGHT`); the drawn tab is unchanged.
- The scan state (page / inquiry scan) is now owned by the stack too (`gap_connectable_control(1)` in the daemon), so the stack's
  own scan updates no longer undo the app's setting.

## 7.5.0
- **Keyboard sheet: bigger keys, cleaner look.** The hint line under the keys ("Type with the iOS keyboard. Ctrl / Win / Alt / Shift
  apply to the next key.") is gone and its space now goes to the keys: the key section is 195 pt tall (was 178), rows are 40 pt
  (were 36) and the border is wider (10 pt sides, 11 pt top, 6 pt bottom; the key frame adds ~5 pt of shadow room under the face).
- **Paste progress and error messages removed** from the keyboard sheet (the status label is gone). Paste and Stop paste work as
  before; a failed paste (not connected, empty clipboard, nothing typeable, busy) now does nothing silently, and the top bar still
  updates when a paste ends.
- **Arrow keys match.** Up / Down / Left / Right are one triangle drawn four ways (`KBArrowImage`) instead of different unicode glyphs,
  so all four have the same size and thickness.
- **"Print Screen" key renamed "PrintScrn"** so the label fits the key.
- **Slightly squarer keys in the keyboard view.** New `BTKeyButton setRadiusScale:`; the keyboard sheet uses 0.8 of the normal corner
  radius. Other pages keep the default.
- **Scroll tab** on the trackpad: a strip along the left edge, nearly invisible until touched, then a finger dragging along it sends
  wheel scrolling. *Settings > Trackpad > Scroll tab* turns it on or off (on by default; `BTScrollTabEnabled`, `kPrefScrollTab`).
- **About section** in Settings: version, developer (Daniyal), a link to the GitHub repo, and a credit link to BTstack by BlueKitchen GmbH.
- **New app icon.** A dark graphite rounded square with a metallic bezel and gloss, a brushed aluminium D-pad ring with engraved
  arrows, and a recessed centre button with a glowing cyan Bluetooth symbol. The icon is a rendered image (`tools/icon_source.jpg`);
  `tools/export_icon.py` crops it to the rounded square and writes the PNG sizes into `Resources/`.
- Docs: removed the README links to `docs/images/icon.png` and `docs/images/slab-preview.png` (the files are no longer in the repo).

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
