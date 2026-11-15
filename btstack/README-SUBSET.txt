This folder is a trimmed copy of BTstack (github.com/bluekitchen/btstack), tag v1.2 (commit 039b5ecb8),
containing only what the iOS port needs: the daemon (platform/daemon), the iOS port (port/ios),
the CoreFoundation/POSIX run loops and the HCI/L2CAP/RFCOMM/SDP core (src).
Local changes: (1) platform/daemon/src/btstack_client.h: BTSTACK_UNIX is "/tmp/Bluemote" instead of "/tmp/BTstack"
so this package can live next to the Cydia BTstack package; (2) platform/daemon/src/btstack_version.h written by hand.
BTstack is (c) BlueKitchen GmbH - free for non-commercial use, see the license headers in every source file.
