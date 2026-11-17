# Pairing

## How it pairs

A real Bluetooth keyboard has no screen and no way to type a code, so it pairs with **Secure Simple Pairing "Just Works"**:
it announces IO capability *NoInputNoOutput*, the host accepts, and nothing is shown. Bluemote now does exactly that.

In `btstack/platform/daemon/src/daemon.c` the daemon enables SSP, sets IO capability *NoInputNoOutput*, MITM not required,
general bonding and auto accept. The stack itself answers the IO-capability and user-confirmation events; the app does not.

Before 7.1 the daemon called `gap_ssp_set_enable(0)`, so every TV fell back to legacy PIN pairing and asked for a passcode.

## Steps

1. Settings > Pairing & Devices > **Pair new device** (pairing mode: discoverable, anybody can connect and pair, and old keys are ignored so a TV that forgot the phone can pair again). Pairing mode closes by itself **after 2 minutes**, after a device paired, on **Connect**, and when the app is closed. Tap **Pair new device** again to restart the 2 minutes.
2. On the TV: Bluetooth > add device > choose the iPhone.
3. The keys are stored by the app in `~/Library/Application Support/Bluemote/link_keys.bin` (up to 8 devices, most recently connected first).

Other actions on that screen: **Reconnect to last**, **Disconnect**, **Forget saved devices**. Bluemote reconnects to the
last device that was connected when it starts (a device moves to the top of the list when it connects, not when it pairs).

## Who can connect

Only paired devices, unless pairing mode is on. With pairing mode off the iPhone is not discoverable, the daemon rejects
connection requests from unknown devices and refuses every new pairing (also from a paired device that lost its key: the TV
has to be paired again through **Pair new device**), and the app ignores unknown link keys and PIN requests.

## When a code is still asked

* **TV does not support SSP** (older TVs): it uses a legacy PIN. A box opens in the app; type the PIN shown on the TV
  (try `0000` if it shows none).
* **Passkey mode** (optional): *Pair tab > Type the TV's passkey* switches the IO capability to *KeyboardOnly*
  (daemon command `BTSTACK_SET_SSP_IOCAP`). The TV then shows a passkey to type in the app. Leave it off for normal use.

## After updating from an older version

Old keys are legacy keys. **Forget saved devices**, remove the iPhone from the TV's Bluetooth list, pair again. The HID
descriptor also changed in 5.11, and Android caches it at pairing time.

## Security note

Just Works has no man-in-the-middle protection. That is the same trade-off every keyboard without a display makes, and it is
fine for a TV remote. Use passkey mode if you want an authenticated pairing.
