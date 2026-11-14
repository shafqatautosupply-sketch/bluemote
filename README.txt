BTCombo v7.0 - standalone (BTstack v1.2 inside)
==============================================

WHAT CHANGED
  Everything BTstack needs is now built from source inside this project (btstack/ = trimmed copy of tag v1.2):
    * the BTstack client library is compiled into the app - no libBTstack.dylib, nothing in /usr/lib is replaced
    * the BTstack daemon is built as /usr/bin/BTComboDaemon and started by launchd on demand
      (/Library/LaunchDaemons/com.btcombo.BTdaemon.plist, socket /tmp/BTcombo, log /var/log/BTcombo.log)
  It uses its own socket, so it can stay installed next to the Cydia BTstack package, but only one daemon
  can drive the Bluetooth chip at a time - uninstall the Cydia one if both try to start.
  Why v4 failed: the iOS daemon takes its socket from launchd (USE_LAUNCHD), so it cannot be started directly
  by the app. v5 installs the launchd job the same way the original package does.

BUILD (on the phone, Theos, iOS 6.1 SDK)
  0. Run it as the mobile user and make sure it owns the folder:  sudo chown -R mobile:mobile BTCombo
  1. Unzip, cd BTCombo
  2. make package install      (the install step loads the launchd job; a respring is not required)
  3. Turn the iOS Bluetooth switch OFF and open "BT Combo".
  If the status line says "BTstack daemon not running": check  cat /var/log/BTcombo.log  and
  launchctl list | grep btcombo

  Notes: PatchBlueTool / BlueToolH4 is only used by the original package for CSR chipsets on iOS 4 - the
  iPhone 4s (Broadcom) does not need it. On iPhone the daemon runs without Secure Simple Pairing, which is why
  Android TV asks for a PIN: type it in the PIN box that the app shows.
  When the app is closed the daemon powers the chip off after its idle timeout and iOS Bluetooth comes back.

UI (v7.0)
  One main screen, no tab bar. Top bar: left = switch Trackpad <-> Media (flip animation), right = Settings (gear).
  The pad has a small "i" (top left, shows / hides the instructions, hidden by default) and a keyboard button (top right).
  Keyboard: slides up over the pad. Top bar then shows a drop-down button (left, goes back), [ Arrows | F-Keys ] in the
  middle and Paste / Stop (right). Arrows: Esc PgUp PgDn Insert / Ctrl Win Alt Shift / Tab Up Delete / Left Down Right.
  F-Keys: F1-F12, Home, Print Screen, End. Every key repeats while held; modifiers apply to the next key.
  Media: remote-control body with a D-pad (centred, rolling-thumb logic, hold to repeat) or a trackpad-style gesture pad,
  volume and channel rockers, Back / Home / Menu, previous / play-pause / next, rewind / stop / fast-forward, Mute, Reels.
  Reels mode shows a plain pad (tap = next video, double-tap = previous).
  Settings: "Pairing & Devices" has its own cell; Media pad = D-pad or Trackpad; Reels method and direction; natural scrolling.
  Choices are saved immediately and remembered.
  Icon: pre-rendered iOS 6 icon (rounded corners, gloss).
  Pairing keys now live in the app's private folder: ~/Library/Application Support/BTCombo/link_keys.bin (mode 0600).
  The old /var/mobile/bt_link_keys.bin is moved there automatically the first time, so existing pairings keep working.
  Core additions: btcombo_set_data_dir(), CHUP / CHDOWN media keys, CONNECT n, FORGETDEV n.

DAEMON NOTES (v5.12)
  daemon.c: l2cap_register_service(NULL, ...) now passes &stack_packet_handler. With NULL, l2cap.c created every INCOMING
  channel with a NULL handler and crashed (SIGSEGV) the moment the TV opened the HID channel right after pairing.
  daemon.c: L2CAP_ACCEPT_CONNECTION now calls daemon_add_client_l2cap_channel(), so the accepting client owns the incoming
  channel (opened / data / closed events are routed to it; the stock daemon dropped them).
  hci_dump.c: with BTCOMBO_QUIET_WHEN_NOT_LOGGING the "LOG --" lines are no longer printed when debug logging is off.

UI CHANGES (v5.11)
  * Trackpad: two-finger drag now scrolls horizontally too (new AC Pan axis in the mouse HID report: re-pair required, see below).
  * Vertical scroll direction flipped: drag down = scroll down. Set NATURAL_SCROLL to 1 in TrackpadView.m for the old behaviour.
  * Two-finger tap (right click / Back) no longer needs both fingers to land together: movement is checked per finger, the
    fingers may land up to 0.6 s apart and the tap time is counted from the last finger.
  * Vibration removed.
  * The HID descriptor changed (151 bytes, mouse report is 7 bytes). Android caches it at pairing time, so on the Pair tab
    tap "Forget saved devices", remove the iPhone from the TV's Bluetooth list and pair again.

DAEMON NOTES (v5.10)
  Debug logging is now OFF by default (it made the trackpad stutter: every HCI packet was printed to /var/log/BTcombo.log).
  Turn it on when you need a log:   touch /var/mobile/btcombo-debug
                                    launchctl unload /Library/LaunchDaemons/com.btcombo.BTdaemon.plist
                                    launchctl load   /Library/LaunchDaemons/com.btcombo.BTdaemon.plist
  and off again:                    rm /var/mobile/btcombo-debug   (then reload the job)
  Still stuttering with logging off? Test with Wi-Fi switched off on the iPhone: the BCM4330 shares its antenna with Wi-Fi.

DAEMON NOTES (v5.9)
  daemon.c: the two l2cap_create_channel(NULL, ...) calls (L2CAP_CREATE_CHANNEL / _MTU) now pass &stack_packet_handler.
  With NULL, l2cap.c called a NULL function pointer when the outgoing channel opened and the daemon crashed with SIGSEGV
  ("launchctl list" showed exit status -11). Visible symptom: app says "Reconnecting to last device..." and the daemon is gone.

DAEMON NOTES (v5.8)
  hci.c: hand-built init commands (Write Local Name / EIR) now release the packet buffer for synchronous transports
  (iPhone). Before, init stopped silently after the name. The BTCOMBO_SKIP_EIR workaround is no longer used.
  btcombo_core.c: after power-on the app sends btstack_get_state. If the daemon is already running with the chip on,
  powering on is a no-op and no state event is sent, so the app never set up discoverability / the HID service record.

DAEMON NOTES (v5.6)
  Init stalled after "Write Local Name". Next in the v1.2 init list: Write EIR (opcode 52 0C, 244 bytes), Write Inquiry Mode
  (45 0C), Write Scan Enable (1A 0C), then HCI_STATE_WORKING ("New state: 2" in the log).
  * -DBTCOMBO_SKIP_EIR (Makefile) skips the EIR write (hci.c). Remove the flag to get it back.
  * h4_send_packet() now writes in 64-byte chunks and gives up with a logged errno after ~2 s instead of retrying forever.
  * The app shows "No answer from the Bluetooth chip" if the chip is not working 25 s after power on.
  How to read the log: the LAST line starting with "CMD =>" is the command that got no answer.

DAEMON NOTES (v5.5)
  Second v1.2 iOS-port bug fixed in btstack/port/ios/src/hci_transport_h4_iphone.c: h4_open() worked out the UART speed
  ('baud', from the IORegistry transport-speed when baudrate_init is 0) but then configured the socket with baudrate_init
  itself, i.e. 0 baud. BlueTool had booted the chip at 3000000 baud, so HCI_Reset got no answer. The log now shows
  "h4_open: UART speed 3000000".

DAEMON NOTES (v5.4)
  Fixed in btstack/platform/daemon/src/daemon.c (a bug in the BTstack v1.2 iOS daemon): btstack_server_run() declared a local
  'control' that shadowed the global one, so hci_set_control() was never called and btstack_control_iphone.iphone_on()
  never ran - iOS Bluetooth (BTServer/BlueTool) was never unloaded and the chip was never booted. The daemon log now starts with
  "BTCombo daemon: control=btstack_control_iphone". If it says NONE the old binary is still installed.
  HAVE_UNIX_SOCKETS is now defined in btstack/port/ios/btstack_config.h so the app uses /tmp/BTcombo, not TCP.
  Logging is forced on (text, /var/log/BTcombo.log): check it with  tail -f /var/log/BTcombo.log

DAEMON NOTES (v5.3)
  The v1.2 iOS port lists no BLE files and its config has no ENABLE_BLE. daemon.c, however, set up a TLV store, a TLV
  link-key database and the BLE device database unconditionally. That block is now disabled in btstack/platform/daemon/src/daemon.c
  (define BTCOMBO_USE_TLV to restore it). This also keeps the app in charge of link keys, which the Pair tab relies on
  (with the TLV database the daemon would answer link-key requests itself and "Forget" / "Pair new device" would not work).
  Keep the Makefile file list free of "#" comment lines: a comment ending in a backslash swallows the following lines.

PAIRING (built into the app, "Pair" tab)
  Pair new device    : enters pairing mode (discoverable, old keys are ignored so a TV that forgot
                       the iPhone can pair again). On the TV: Bluetooth > add device > pick this iPhone.
                       Keys are saved by the app in /var/mobile/bt_link_keys.bin (up to 8 devices, newest first).
  Reconnect to last  : connects to the most recently paired device.
  Disconnect         : drops the Bluetooth HID channels.
  Forget saved       : deletes all stored keys (asks first).
  PIN prompt         : when the TV shows a PIN, a box opens on any tab; type the code and tap Pair
                       (prefilled with 0000 for TVs that show nothing).
  The app also reconnects to the last device automatically at start.

TRACKPAD  drag move | tap click | 2-finger tap right click | 2-finger drag scroll |
          tap then touch-and-drag = drag&drop | buttons: Left Right Back Home
KEYBOARD  iOS keyboard + Esc/Tab/Bksp/Del/Enter, arrows, Space, Home/End/PgUp/PgDn,
          one-shot Ctrl/Shift/Alt/Win, Kbd (show/hide iOS keyboard)
          Paste : types the iOS clipboard on the TV. Long text is typed in small slices
                  (about 35-40 characters per second) so nothing is dropped.
                  While running the button turns red and says Stop; tapping it stops
                  within one character. Progress is shown under the keys.
                  Smart quotes/dashes/ellipsis are converted to plain ASCII; characters that
                  cannot be typed (emoji, non-Latin letters) are skipped and counted.
MEDIA     swipe = arrows (repeat while dragging) | tap = OK | hold = Back |
          2-finger tap = Play/Pause | 2-finger drag up/down = Volume |
          2-finger swipe left/right = Prev/Next | 2-finger hold = Home | 3-finger tap = Mute
          Reels button: tap = swipe down (next video), double-tap = swipe up (previous video).
            Method: Keys  -> Down/Up arrow keys
                    Wheel -> mouse wheel
                    Drag  -> mouse press-and-drag swipe
            Dir: Normal/Swapped flips next/previous if your app goes the wrong way.

TUNING (btcombo_core.c)
  paste_gap_us (default 14000) = extra pause after every pasted key. Raise it if the TV drops
  characters, lower it for speed. It can also be changed at runtime with the command: PACE <microseconds>
