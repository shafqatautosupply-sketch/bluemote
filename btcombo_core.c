/*
 * BTCombo core: BTstack HID device (Mouse + Keyboard + Consumer/Media)
 * Runs the BTstack run loop on its own thread. The GUI sends text commands
 * through a pipe (btcombo_send), so no BTstack call is ever made from the UI thread.
 *
 * Commands (one per line):
 *   M dx dy [wheel]     MB mask      CLICK [mask]   W n   HW n (horizontal scroll)
 *   KEY usage [mod]     KD usage [mod]   KU
 *   TYPE text           TYPEMOD mod text
 *   MEDIA name|0xUSAGE  SWIPE dx dy (mouse drag gesture)
 *   PASTE / PASTECONT   (long text typed in small slices, see btcombo_paste_*)
 *   PAIR PAIRSTOP RECONNECT CONNECT n DISCONNECT FORGET FORGETDEV n PACE us
 *   PIN code | PINCANCEL | IOCAP 2|3
 */

#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <signal.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdarg.h>
#include <time.h>
#include <sys/stat.h>
#include "btstack_client.h"
#include "hci_cmd.h"
#include "daemon_cmds.h"
#include "bluetooth_psm.h"
#include "btstack_run_loop_posix.h"
#include "btcombo_core.h"

#define OLD_LINK_KEY_FILE "/var/mobile/bt_link_keys.bin"
static char key_file_path[512] = OLD_LINK_KEY_FILE;   /* replaced by btcombo_set_data_dir() */

typedef struct {
    bd_addr_t addr;
    uint8_t link_key[16];
} stored_link_key_t;

static uint16_t hid_control = 0;
static uint16_t hid_interrupt = 0;
static volatile int is_connected = 0;
static int we_initiated = 0;
static uint8_t mouse_buttons = 0;
static const char * volatile status_text = "Starting...";
static volatile int bt_working = 0;
static int sdp_registered = 0;                /* HCI reached HCI_STATE_WORKING */
static volatile time_t power_on_time = 0;          /* when we asked the daemon to power the chip on */

static btstack_data_source_t pipe_source;
static int cmd_pipe[2] = { -1, -1 };
static char line_buf[256];
static int line_len = 0;

static void flip_bd_addr(bd_addr_t dest, const uint8_t *src) {
    for (int i = 0; i < 6; i++) dest[i] = src[5 - i];
}

static int8_t clamp8(int v) {
    if (v > 127) v = 127;
    if (v < -127) v = -127;
    return (int8_t)v;
}

/* ---------------- SDP record: mouse(1) + keyboard(2) + consumer(3) ---------------- */

static const uint8_t hid_sdp_body[] = {
    0x09,0x00,0x01, 0x35,0x03, 0x19,0x11,0x24,
    0x09,0x00,0x04, 0x35,0x0d, 0x35,0x06, 0x19,0x01,0x00, 0x09,0x00,0x11,
                               0x35,0x03, 0x19,0x00,0x11,
    0x09,0x00,0x05, 0x35,0x03, 0x19,0x10,0x02,
    0x09,0x00,0x06, 0x35,0x09, 0x09,0x65,0x6e, 0x09,0x00,0x6a, 0x09,0x01,0x00,
    0x09,0x00,0x09, 0x35,0x08, 0x35,0x06, 0x19,0x11,0x24, 0x09,0x01,0x01,
    0x09,0x00,0x0d, 0x35,0x0f, 0x35,0x0d, 0x35,0x06, 0x19,0x01,0x00, 0x09,0x00,0x13,
                               0x35,0x03, 0x19,0x00,0x11,
    0x09,0x01,0x00, 0x25,0x0c, 'B','T',' ','C','o','m','b','o',' ','H','I','D',
    0x09,0x02,0x01, 0x09,0x01,0x11,
    0x09,0x02,0x02, 0x08,0xC0,
    0x09,0x02,0x03, 0x08,0x00,
    0x09,0x02,0x04, 0x28,0x01,
    0x09,0x02,0x05, 0x28,0x01,
    0x09,0x02,0x06, 0x35,0x9d,
      0x35,0x9b, 0x08,0x22, 0x25,0x97,
        /* Report ID 1: Mouse (61 bytes): buttons, X, Y, wheel, pan */
        0x05,0x01, 0x09,0x02, 0xa1,0x01, 0x85,0x01,
        0x09,0x01, 0xa1,0x00,
        0x05,0x09, 0x19,0x01, 0x29,0x03, 0x15,0x00, 0x25,0x01,
        0x75,0x01, 0x95,0x03, 0x81,0x02,
        0x95,0x05, 0x81,0x01,
        0x05,0x01, 0x09,0x30, 0x09,0x31, 0x09,0x38,
        0x15,0x81, 0x25,0x7f, 0x75,0x08, 0x95,0x03, 0x81,0x06,
        0x05,0x0c, 0x0a,0x38,0x02, 0x95,0x01, 0x81,0x06,      /* horizontal wheel (AC Pan) */
        0xc0, 0xc0,
        /* Report ID 2: Keyboard (65 bytes) */
        0x05,0x01, 0x09,0x06, 0xa1,0x01, 0x85,0x02,
        0x05,0x07, 0x19,0xe0, 0x29,0xe7, 0x15,0x00, 0x25,0x01,
        0x75,0x01, 0x95,0x08, 0x81,0x02,
        0x95,0x01, 0x75,0x08, 0x81,0x01,
        0x95,0x05, 0x75,0x01, 0x05,0x08, 0x19,0x01, 0x29,0x05, 0x91,0x02,
        0x95,0x01, 0x75,0x03, 0x91,0x01,
        0x95,0x06, 0x75,0x08, 0x15,0x00, 0x25,0x65,
        0x05,0x07, 0x19,0x00, 0x29,0x65, 0x81,0x00,
        0xc0,
        /* Report ID 3: Consumer Control (25 bytes) */
        0x05,0x0c, 0x09,0x01, 0xa1,0x01, 0x85,0x03,
        0x15,0x00, 0x26,0xff,0x03, 0x19,0x00, 0x2a,0xff,0x03,
        0x75,0x10, 0x95,0x01, 0x81,0x00,
        0xc0,
    0x09,0x02,0x07, 0x35,0x08, 0x35,0x06, 0x09,0x04,0x09, 0x09,0x01,0x00,
    0x09,0x02,0x09, 0x28,0x00,
    0x09,0x02,0x0a, 0x28,0x00,
    0x09,0x02,0x0d, 0x28,0x01,
    0x09,0x02,0x0e, 0x28,0x00
};

static uint8_t hid_device_sdp_service_record[3 + sizeof(hid_sdp_body)];

static void build_sdp_record(void) {
    uint16_t len = (uint16_t)sizeof(hid_sdp_body);
    hid_device_sdp_service_record[0] = 0x36;
    hid_device_sdp_service_record[1] = (uint8_t)(len >> 8);
    hid_device_sdp_service_record[2] = (uint8_t)(len & 0xff);
    memcpy(&hid_device_sdp_service_record[3], hid_sdp_body, sizeof(hid_sdp_body));
}

/* ---------------- link key storage (up to 8 paired devices, newest first) ---------------- */

#define MAX_KEYS 8
static stored_link_key_t keys[MAX_KEYS];
static int key_count = 0;
static volatile int saved_count = 0;
static char saved_last_str[20] = "";
static char saved_addr_str[MAX_KEYS][20];     /* "AA:BB:CC:DD:EE:FF" of every saved device, newest first */
static bd_addr_t target_addr;                 /* device we are connecting to */
static int pending_connect = 0;               /* connect to target_addr once the current device has disconnected */
static char connected_str[20] = "";           /* address of the connected device, "" if none */

typedef struct { char addr_str[20]; char name[48]; } name_entry_t;
static name_entry_t name_cache[MAX_KEYS];     /* remote names read from the devices (shown in the UI) */
static int name_count = 0;

static void addr_to_str(const uint8_t *a, char *out) {
    snprintf(out, 20, "%02X:%02X:%02X:%02X:%02X:%02X", a[0], a[1], a[2], a[3], a[4], a[5]);
}
static volatile int pairing_mode = 0;

/* PIN / passkey entry requested by the TV: 0 none, 1 legacy PIN, 2 SSP passkey */
static volatile int pin_request = 0;
static volatile time_t pin_request_time = 0;
static bd_addr_t pin_addr;
static volatile int io_capability = 3;      /* 3 = NoInputNoOutput (auto), 2 = KeyboardOnly (type the passkey) */

static void keys_update_summary(void) {
    saved_count = key_count;
    for (int i = 0; i < MAX_KEYS; i++) {
        if (i < key_count) addr_to_str(keys[i].addr, saved_addr_str[i]);
        else saved_addr_str[i][0] = 0;
    }
    if (key_count > 0) {
        const uint8_t *a = keys[0].addr;
        snprintf(saved_last_str, sizeof(saved_last_str), "%02X:%02X:%02X:%02X:%02X:%02X",
                 a[0], a[1], a[2], a[3], a[4], a[5]);
    } else {
        saved_last_str[0] = 0;
    }
}

static void keys_load(void) {
    key_count = 0;
    FILE *f = fopen(key_file_path, "rb");
    if (f) {
        key_count = (int)fread(keys, sizeof(stored_link_key_t), MAX_KEYS, f);
        fclose(f);
        if (key_count < 0) key_count = 0;
    }
    keys_update_summary();
}

static void keys_save(void) {
    if (key_count == 0) {
        unlink(key_file_path);
        return;
    }
    FILE *f = fopen(key_file_path, "wb");
    if (f) {
        chmod(key_file_path, 0600);
        fwrite(keys, sizeof(stored_link_key_t), key_count, f);
        fclose(f);
    }
}

static int keys_find(const uint8_t *addr, uint8_t *key) {
    for (int i = 0; i < key_count; i++) {
        if (memcmp(keys[i].addr, addr, 6) == 0) {
            memcpy(key, keys[i].link_key, 16);
            return 1;
        }
    }
    return 0;
}

static void keys_upsert(const uint8_t *addr, const uint8_t *key) {
    int idx = -1;
    for (int i = 0; i < key_count; i++) {
        if (memcmp(keys[i].addr, addr, 6) == 0) { idx = i; break; }
    }
    if (idx < 0) {
        if (key_count < MAX_KEYS) key_count++;
        idx = key_count - 1;            /* overwrite the oldest when full */
    }
    for (int i = idx; i > 0; i--) keys[i] = keys[i - 1];
    memcpy(keys[0].addr, addr, 6);
    memcpy(keys[0].link_key, key, 16);
    keys_save();
    keys_update_summary();
}

/* ---------------- HID report senders ---------------- */

static void send_mouse5(uint8_t buttons, int8_t x, int8_t y, int8_t wheel, int8_t pan) {
    if (!hid_interrupt) return;
    uint8_t report[7];
    report[0] = 0xa1;
    report[1] = 0x01;
    report[2] = buttons & 0x07;
    report[3] = (uint8_t)x;
    report[4] = (uint8_t)y;
    report[5] = (uint8_t)wheel;
    report[6] = (uint8_t)pan;            /* horizontal scroll */
    bt_send_l2cap(hid_interrupt, report, sizeof(report));
}

static void send_mouse(uint8_t buttons, int8_t x, int8_t y, int8_t wheel) {
    send_mouse5(buttons, x, y, wheel, 0);
}

static void send_keyboard(uint8_t modifiers, uint8_t key) {
    if (!hid_interrupt) return;
    uint8_t report[10];
    memset(report, 0, sizeof(report));
    report[0] = 0xa1;
    report[1] = 0x02;
    report[2] = modifiers;
    report[4] = key;
    bt_send_l2cap(hid_interrupt, report, sizeof(report));
}

static void send_consumer(uint16_t usage) {
    if (!hid_interrupt) return;
    uint8_t report[4];
    report[0] = 0xa1;
    report[1] = 0x03;
    report[2] = (uint8_t)(usage & 0xff);
    report[3] = (uint8_t)(usage >> 8);
    bt_send_l2cap(hid_interrupt, report, sizeof(report));
}

static void mouse_move(int dx, int dy, int wheel) {
    send_mouse(mouse_buttons, clamp8(dx), clamp8(dy), clamp8(wheel));
}

static void mouse_hscroll(int n) {
    send_mouse5(mouse_buttons, 0, 0, 0, clamp8(n));
}

static void mouse_click(uint8_t mask) {
    send_mouse(mask, 0, 0, 0);
    usleep(10000);
    send_mouse(0, 0, 0, 0);
    mouse_buttons = 0;
}

/* Drag gesture with the mouse: press, move dx/dy in 20 steps, release, move cursor back. */
static void mouse_swipe(int dx, int dy) {
    const int steps = 20;
    int sx = dx / steps, sy = dy / steps;
    send_mouse(0, 0, 0, 0);
    send_mouse(1, 0, 0, 0);
    usleep(40000);
    for (int i = 0; i < steps; i++) {
        send_mouse(1, clamp8(sx), clamp8(sy), 0);
        usleep(9000);
    }
    usleep(40000);
    send_mouse(0, 0, 0, 0);
    usleep(40000);
    for (int i = 0; i < steps; i++) {
        send_mouse(0, clamp8(-sx), clamp8(-sy), 0);
        usleep(3000);
    }
    mouse_buttons = 0;
}

static void key_tap(uint8_t modifiers, uint8_t key) {
    send_keyboard(modifiers, key);
    usleep(8000);
    send_keyboard(0, 0);
    usleep(4000);
}

static void media_tap(uint16_t usage) {
    send_consumer(usage);
    usleep(10000);
    send_consumer(0);
}

/* ---------------- ASCII -> HID ---------------- */

static int ascii_to_hid(char c, uint8_t *mod, uint8_t *key) {
    *mod = 0;
    if (c >= 'a' && c <= 'z') { *key = 0x04 + (c - 'a'); return 1; }
    if (c >= 'A' && c <= 'Z') { *mod = 0x02; *key = 0x04 + (c - 'A'); return 1; }
    if (c >= '1' && c <= '9') { *key = 0x1e + (c - '1'); return 1; }
    if (c == '0') { *key = 0x27; return 1; }
    switch (c) {
        case '\n': case '\r': *key = 0x28; return 1;
        case 0x1b: *key = 0x29; return 1;
        case 0x08: case 0x7f: *key = 0x2a; return 1;
        case '\t': *key = 0x2b; return 1;
        case ' ':  *key = 0x2c; return 1;
        case '-':  *key = 0x2d; return 1;
        case '_':  *mod = 0x02; *key = 0x2d; return 1;
        case '=':  *key = 0x2e; return 1;
        case '+':  *mod = 0x02; *key = 0x2e; return 1;
        case '[':  *key = 0x2f; return 1;
        case '{':  *mod = 0x02; *key = 0x2f; return 1;
        case ']':  *key = 0x30; return 1;
        case '}':  *mod = 0x02; *key = 0x30; return 1;
        case '\\': *key = 0x31; return 1;
        case '|':  *mod = 0x02; *key = 0x31; return 1;
        case ';':  *key = 0x33; return 1;
        case ':':  *mod = 0x02; *key = 0x33; return 1;
        case '\'': *key = 0x34; return 1;
        case '"':  *mod = 0x02; *key = 0x34; return 1;
        case '`':  *key = 0x35; return 1;
        case '~':  *mod = 0x02; *key = 0x35; return 1;
        case ',':  *key = 0x36; return 1;
        case '<':  *mod = 0x02; *key = 0x36; return 1;
        case '.':  *key = 0x37; return 1;
        case '>':  *mod = 0x02; *key = 0x37; return 1;
        case '/':  *key = 0x38; return 1;
        case '?':  *mod = 0x02; *key = 0x38; return 1;
        case '!':  *mod = 0x02; *key = 0x1e; return 1;
        case '@':  *mod = 0x02; *key = 0x1f; return 1;
        case '#':  *mod = 0x02; *key = 0x20; return 1;
        case '$':  *mod = 0x02; *key = 0x21; return 1;
        case '%':  *mod = 0x02; *key = 0x22; return 1;
        case '^':  *mod = 0x02; *key = 0x23; return 1;
        case '&':  *mod = 0x02; *key = 0x24; return 1;
        case '*':  *mod = 0x02; *key = 0x25; return 1;
        case '(':  *mod = 0x02; *key = 0x26; return 1;
        case ')':  *mod = 0x02; *key = 0x27; return 1;
    }
    return 0;
}

static void type_string_mod(const char *s, uint8_t extra_mod) {
    uint8_t mod, key;
    while (*s) {
        if (ascii_to_hid(*s, &mod, &key)) key_tap(mod | extra_mod, key);
        s++;
    }
}

/* ---------------- media names ---------------- */

typedef struct { const char *name; uint16_t usage; } media_name_t;

static const media_name_t media_names[] = {
    { "playpause", 0x00cd }, { "play", 0x00b0 }, { "pause", 0x00b1 },
    { "next", 0x00b5 },      { "prev", 0x00b6 }, { "stop", 0x00b7 },
    { "ffwd", 0x00b3 },      { "rewind", 0x00b4 },
    { "volup", 0x00e9 },     { "voldown", 0x00ea }, { "mute", 0x00e2 },
    { "chup", 0x009c },      { "chdown", 0x009d },
    { "home", 0x0223 },      { "back", 0x0224 },    { "menu", 0x0040 },
    { NULL, 0 }
};

static int media_by_name(const char *name, uint16_t *usage) {
    for (int i = 0; media_names[i].name; i++) {
        if (strcasecmp(name, media_names[i].name) == 0) {
            *usage = media_names[i].usage;
            return 1;
        }
    }
    char *end;
    long v = strtol(name, &end, 0);
    if (end != name && v > 0 && v < 0x400) {
        *usage = (uint16_t)v;
        return 1;
    }
    return 0;
}

/* ---------------- long paste: typed in small slices so the run loop stays responsive ---------------- */

static char *paste_buf = NULL;
static volatile int paste_len = 0;
static volatile int paste_pos = 0;
static volatile int paste_active = 0;
static volatile int paste_cancel = 0;
static volatile int paste_gap_us = 14000;      /* extra pause after each key (reliability vs speed) */
#define PASTE_SLICE_CHARS 6

static int queue_line(const char *line);

static void paste_finish(void) {
    char *b = paste_buf;
    paste_buf = NULL;
    free(b);
    send_keyboard(0, 0);
    __sync_synchronize();
    paste_active = 0;
}

static void paste_slice(void) {
    while (paste_active) {
        if (paste_cancel || !is_connected) { paste_finish(); return; }
        int n = 0;
        while (n < PASTE_SLICE_CHARS && paste_pos < paste_len) {
            if (paste_cancel) break;
            char ch = paste_buf[paste_pos++];
            uint8_t mod, key;
            if (ascii_to_hid(ch, &mod, &key)) {
                key_tap(mod, key);
                usleep(paste_gap_us);
            }
            n++;
        }
        if (paste_cancel || paste_pos >= paste_len) { paste_finish(); return; }
        /* yield to the run loop (so STOP, disconnects and Bluetooth events get processed) */
        if (queue_line("PASTECONT")) return;
        /* pipe full: just keep typing */
    }
}

/* ---------------- pairing / connection management ---------------- */

static void cmd_disconnect_now(void);

static void cmd_pair(void) {
    pairing_mode = 1;     /* during pairing mode we never hand out an old link key, so a TV that forgot us can re-pair */
    status_text = "Pairing mode: on the TV add a Bluetooth device and pick this iPhone";
    bt_send_cmd(&hci_write_scan_enable, 0x03);
    bt_send_cmd(&btstack_set_discoverable, 1);
}

static void cmd_pair_stop(void) {
    pairing_mode = 0;
    status_text = is_connected ? "Connected" : "Ready - waiting for TV";
}

static void cmd_forget(void) {
    key_count = 0;
    keys_save();
    keys_update_summary();
    pairing_mode = 0;
    status_text = "Saved devices forgotten. Tap Pair new device.";
}

static void start_connect(void) {
    pairing_mode = 0;
    we_initiated = 1;
    status_text = "Connecting...";
    bt_send_cmd(&l2cap_create_channel_cmd, target_addr, BLUETOOTH_PSM_HID_CONTROL, 48);
}

/* Connect to saved device number idx (0 = most recent). If another device is connected, drop it first. */
static void cmd_connect(int idx) {
    if (idx < 0 || idx >= key_count) {
        status_text = "No saved device. Tap Pair new device.";
        return;
    }
    if (is_connected && strcmp(connected_str, saved_addr_str[idx]) == 0) return;   /* already connected to it */
    memcpy(target_addr, keys[idx].addr, 6);
    if (is_connected || hid_control || hid_interrupt) {
        pending_connect = 1;
        status_text = "Switching device...";
        cmd_disconnect_now();
        return;
    }
    start_connect();
}

static void cmd_reconnect(void) { cmd_connect(0); }

static void cmd_forget_dev(int idx) {
    if (idx < 0 || idx >= key_count) return;
    int was_connected = is_connected && strcmp(connected_str, saved_addr_str[idx]) == 0;
    for (int i = idx; i < key_count - 1; i++) keys[i] = keys[i + 1];
    key_count--;
    keys_save();
    keys_update_summary();
    status_text = "Device forgotten";
    if (was_connected) cmd_disconnect_now();
}

/* after a disconnect: start the connection that was waiting for it */
static void check_pending_connect(void) {
    if (pending_connect && !is_connected && !hid_control && !hid_interrupt) {
        pending_connect = 0;
        start_connect();
    }
}

static void cmd_disconnect(void) {
    pending_connect = 0;
    cmd_disconnect_now();
}

static void cmd_disconnect_now(void) {
#ifndef BTCOMBO_NO_L2CAP_DISCONNECT
    if (hid_interrupt) bt_send_cmd(&l2cap_disconnect_cmd, hid_interrupt, 0);
    if (hid_control) bt_send_cmd(&l2cap_disconnect_cmd, hid_control, 0);
    status_text = "Disconnecting...";
#else
    status_text = "Disconnect not available in this build";
#endif
}

static void cmd_pin(const char *text) {
    char pin[20];
    size_t n = 0;
    if (pin_request == 0) return;
    while (text[n] && n < 16 && text[n] != ' ') { pin[n] = text[n]; n++; }
    pin[n] = 0;
    if (n == 0) return;
    if (pin_request == 1) {
        bt_send_cmd(&hci_pin_code_request_reply, pin_addr, (int)n, pin);
        status_text = "PIN sent - finishing pairing...";
    }
#ifndef BTCOMBO_NO_PASSKEY
    else if (pin_request == 2) {
        bt_send_cmd(&hci_user_passkey_request_reply, pin_addr, (uint32_t)strtoul(pin, NULL, 10));
        status_text = "Passkey sent - finishing pairing...";
    }
#endif
    pin_request = 0;
}

static void cmd_pin_cancel(void) {
    if (pin_request == 1) bt_send_cmd(&hci_pin_code_request_negative_reply, pin_addr);
#ifndef BTCOMBO_NO_PASSKEY
    else if (pin_request == 2) bt_send_cmd(&hci_user_passkey_request_negative_reply, pin_addr);
#endif
    pin_request = 0;
    status_text = "Pairing cancelled";
}

/* ---------------- command parser (runs on the Bluetooth thread) ---------------- */

static void process_line(char *line) {
    size_t len = strlen(line);
    while (len > 0 && (line[len - 1] == '\r' || line[len - 1] == '\n')) line[--len] = 0;
    if (len == 0) return;

    char *rest = line;
    while (*rest && *rest != ' ') rest++;
    if (*rest) {
        *rest++ = 0;
        while (*rest == ' ') rest++;
    }

    /* commands that work even when nothing is connected */
    if (strcasecmp(line, "PAIR") == 0)       { cmd_pair(); return; }
    if (strcasecmp(line, "PAIRSTOP") == 0)   { cmd_pair_stop(); return; }
    if (strcasecmp(line, "FORGET") == 0)     { cmd_forget(); return; }
    if (strcasecmp(line, "RECONNECT") == 0)  { cmd_reconnect(); return; }
    if (strcasecmp(line, "CONNECT") == 0)    { int n = 0; if (sscanf(rest, "%d", &n) >= 1) cmd_connect(n); return; }
    if (strcasecmp(line, "FORGETDEV") == 0)  { int n = -1; if (sscanf(rest, "%d", &n) >= 1) cmd_forget_dev(n); return; }
    if (strcasecmp(line, "DISCONNECT") == 0) { cmd_disconnect(); return; }
    if (strcasecmp(line, "PIN") == 0)        { cmd_pin(rest); return; }
    if (strcasecmp(line, "PINCANCEL") == 0)  { cmd_pin_cancel(); return; }
    if (strcasecmp(line, "IOCAP") == 0) {
        int v = 0;
        if (sscanf(rest, "%d", &v) >= 1 && (v == 2 || v == 3)) io_capability = v;
        return;
    }
    if (strcasecmp(line, "PASTE") == 0 || strcasecmp(line, "PASTECONT") == 0) { paste_slice(); return; }
    if (strcasecmp(line, "PACE") == 0) {
        int us = 0;
        if (sscanf(rest, "%d", &us) >= 1 && us >= 0 && us <= 200000) paste_gap_us = us;
        return;
    }

    if (!is_connected) return;

    int a = 0, b = 0, c = 0, n;

    if (strcasecmp(line, "M") == 0) {
        n = sscanf(rest, "%d %d %d", &a, &b, &c);
        if (n >= 2) mouse_move(a, b, n >= 3 ? c : 0);
    } else if (strcasecmp(line, "MB") == 0) {
        if (sscanf(rest, "%i", &a) >= 1) {
            mouse_buttons = (uint8_t)(a & 7);
            send_mouse(mouse_buttons, 0, 0, 0);
        }
    } else if (strcasecmp(line, "CLICK") == 0) {
        a = 1;
        sscanf(rest, "%i", &a);
        mouse_click((uint8_t)(a & 7));
    } else if (strcasecmp(line, "W") == 0) {
        if (sscanf(rest, "%d", &a) >= 1) mouse_move(0, 0, a);
    } else if (strcasecmp(line, "HW") == 0) {
        if (sscanf(rest, "%d", &a) >= 1) mouse_hscroll(a);
    } else if (strcasecmp(line, "SWIPE") == 0) {
        if (sscanf(rest, "%d %d", &a, &b) >= 2) mouse_swipe(a, b);
    } else if (strcasecmp(line, "KEY") == 0) {
        n = sscanf(rest, "%i %i", &a, &b);
        if (n >= 1) key_tap(n >= 2 ? (uint8_t)b : 0, (uint8_t)a);
    } else if (strcasecmp(line, "KD") == 0) {
        n = sscanf(rest, "%i %i", &a, &b);
        if (n >= 1) send_keyboard(n >= 2 ? (uint8_t)b : 0, (uint8_t)a);
    } else if (strcasecmp(line, "KU") == 0) {
        send_keyboard(0, 0);
    } else if (strcasecmp(line, "TYPE") == 0) {
        type_string_mod(rest, 0);
    } else if (strcasecmp(line, "TYPEMOD") == 0) {
        char *p;
        long m = strtol(rest, &p, 0);
        if (*p == ' ') p++;           /* exactly one separator, keep the rest as typed */
        type_string_mod(p, (uint8_t)m);
    } else if (strcasecmp(line, "MEDIA") == 0) {
        uint16_t usage;
        if (media_by_name(rest, &usage)) media_tap(usage);
    }
}

static void pipe_process(struct btstack_data_source *ds, btstack_data_source_callback_type_t callback_type) {
    char tmp[256];
    int n = read(cmd_pipe[0], tmp, sizeof(tmp));
    if (n <= 0) return;
    for (int i = 0; i < n; i++) {
        char ch = tmp[i];
        if (ch == '\n') {
            line_buf[line_len] = 0;
            process_line(line_buf);
            line_len = 0;
        } else if (line_len < (int)sizeof(line_buf) - 1) {
            line_buf[line_len++] = ch;
        }
    }
}

/* ---------------- public API (called from the UI thread) ---------------- */

static int queue_line(const char *line) {
    char buf[256];
    size_t n, i;
    if (cmd_pipe[1] < 0 || !line) return 0;
    n = strlen(line);
    if (n > 240) n = 240;
    memcpy(buf, line, n);
    for (i = 0; i < n; i++) if (buf[i] == '\n' || buf[i] == '\r') buf[i] = ' ';
    buf[n++] = '\n';
    ssize_t r = write(cmd_pipe[1], buf, n);   /* <= PIPE_BUF so it is atomic */
    return r == (ssize_t)n;
}

void btcombo_send(const char *line) {
    queue_line(line);
}

void btcombo_sendf(const char *fmt, ...) {
    char buf[240];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    queue_line(buf);
}

int btcombo_is_connected(void) { return is_connected; }
const char *btcombo_status(void) {
    if (!bt_working && power_on_time != 0 && (time(NULL) - power_on_time) > 25)
        return "No answer from the Bluetooth chip - see /var/log/BTcombo.log";
    return status_text;
}
int btcombo_pairing_mode(void) { return pairing_mode; }
int btcombo_io_mode(void) { return io_capability; }
int btcombo_pin_request(void) {
    if (pin_request != 0 && (time(NULL) - pin_request_time) > 45) return 0;   /* the request has timed out */
    return pin_request;
}
int btcombo_saved_count(void) { return saved_count; }
const char *btcombo_saved_last(void) { return saved_last_str; }
const char *btcombo_saved_addr(int i) { return (i >= 0 && i < MAX_KEYS) ? saved_addr_str[i] : ""; }
const char *btcombo_connected_addr(void) { return is_connected ? connected_str : ""; }
const char *btcombo_device_name(const char *addr_str) {
    for (int i = 0; i < name_count; i++)
        if (strcmp(name_cache[i].addr_str, addr_str) == 0) return name_cache[i].name;
    return "";
}

/* Paste: text must already be plain ASCII (see the app's sanitizer). Returns 0 if started. */
int btcombo_paste_begin(const char *text, int len) {
    if (paste_active || !text || len <= 0) return -1;
    char *b = (char *)malloc((size_t)len + 1);
    if (!b) return -1;
    memcpy(b, text, (size_t)len);
    b[len] = 0;
    paste_buf = b;
    paste_len = len;
    paste_pos = 0;
    paste_cancel = 0;
    __sync_synchronize();
    paste_active = 1;
    if (!queue_line("PASTE")) {       /* could not wake the Bluetooth thread */
        paste_active = 0;
        paste_buf = NULL;
        free(b);
        return -1;
    }
    return 0;
}

void btcombo_paste_cancel(void) { paste_cancel = 1; }
int btcombo_paste_active(void) { return paste_active; }
int btcombo_paste_progress(void) { return paste_pos; }
int btcombo_paste_total(void) { return paste_len; }

/* ---------------- HID control channel ---------------- */

static void handle_hid_control(uint8_t *data, uint16_t size) {
    if (size < 1) return;
    uint8_t type = data[0] >> 4;
    uint8_t reply[2];
    switch (type) {
        case 0x1: break;
        case 0x5: case 0x7: case 0x9:
            reply[0] = 0x00;
            bt_send_l2cap(hid_control, reply, 1);
            break;
        case 0x6:
            reply[0] = 0xa0;
            reply[1] = 0x01;
            bt_send_l2cap(hid_control, reply, 2);
            break;
        default:
            reply[0] = 0x03;
            bt_send_l2cap(hid_control, reply, 1);
            break;
    }
}

/* ---------------- BTstack packet handler ---------------- */

static void packet_handler(uint8_t packet_type, uint16_t channel, uint8_t *packet, uint16_t size) {
    bd_addr_t event_addr;
    uint16_t psm;
    uint16_t local_cid;
    uint8_t stored_key[16];

    switch (packet_type) {
        case L2CAP_DATA_PACKET:
            if (channel == hid_control) handle_hid_control(packet, size);
            break;

        case HCI_EVENT_PACKET:
            switch (packet[0]) {
                case BTSTACK_EVENT_POWERON_FAILED:
                    status_text = "Bluetooth power on failed";
                    break;

                case BTSTACK_EVENT_STATE:
                    if (btstack_event_state_get_state(packet) != HCI_STATE_WORKING) {
                        bt_working = 0;               /* chip is (re)starting or asleep: set up again when it is working */
                        break;
                    }
                    if (bt_working) break;            /* already set up (we also ask for the state, so it can arrive twice) */
                    bt_working = 1;
                    status_text = "Ready - use the Pair tab to pair";
                    bt_send_cmd(&hci_write_class_of_device, 0x0025C0);
                    /* bt_send_cmd(&hci_write_simple_pairing_mode, 1); */
                    bt_send_cmd(&hci_write_scan_enable, 0x03);
                    bt_send_cmd(&btstack_set_discoverable, 1);
                    if (!sdp_registered) {            /* the daemon keeps the record until we disconnect: register it once */
                        bt_send_cmd(&sdp_register_service_record_cmd, hid_device_sdp_service_record);
                        sdp_registered = 1;
                    }
                    if (key_count > 0) {
                        status_text = "Reconnecting to last device...";
                        memcpy(target_addr, keys[0].addr, 6);
                        start_connect();
                    }
                    break;

                case L2CAP_EVENT_INCOMING_CONNECTION:
                    local_cid = l2cap_event_incoming_connection_get_local_cid(packet);
                    bt_send_cmd(&l2cap_accept_connection_cmd, local_cid);
                    break;

                case HCI_EVENT_LINK_KEY_REQUEST:
                    hci_event_link_key_request_get_bd_addr(packet, event_addr);
                    if (!pairing_mode && keys_find(event_addr, stored_key)) {
                        bt_send_cmd(&hci_link_key_request_reply, event_addr, stored_key);
                    } else {
                        bt_send_cmd(&hci_link_key_request_negative_reply, event_addr);
                    }
                    break;

                case HCI_EVENT_LINK_KEY_NOTIFICATION:
                    flip_bd_addr(event_addr, &packet[2]);
                    memcpy(stored_key, &packet[8], 16);
                    keys_upsert(event_addr, stored_key);
                    pairing_mode = 0;
                    pin_request = 0;
                    if (!is_connected) status_text = "Paired - waiting for the device to connect";
                    break;

                case HCI_EVENT_PIN_CODE_REQUEST:
                    hci_event_pin_code_request_get_bd_addr(packet, pin_addr);
                    pin_request_time = time(NULL);
                    pin_request = 1;
                    status_text = "Enter the PIN shown on the TV";
                    break;

#ifndef BTCOMBO_NO_PASSKEY
                case 0x34: /* HCI_EVENT_USER_PASSKEY_REQUEST */
                    flip_bd_addr(pin_addr, &packet[2]);
                    pin_request_time = time(NULL);
                    pin_request = 2;
                    status_text = "Enter the passkey shown on the TV";
                    break;
#endif

                case 0x31: /* IO capability request */
                {
                    bd_addr_t addr;
                    flip_bd_addr(addr, &packet[2]);
                    bt_send_cmd(&hci_io_capability_request_reply, addr, io_capability, 0, io_capability == 2 ? 0x05 : 0x04);
                    break;
                }

                case 0x33: /* user confirmation request */
                {
                    bd_addr_t addr;
                    flip_bd_addr(addr, &packet[2]);
                    bt_send_cmd(&hci_user_confirmation_request_reply, addr);
                    break;
                }

                case L2CAP_EVENT_CHANNEL_OPENED:
                    if (l2cap_event_channel_opened_get_status(packet)) {
                        status_text = "Connection to TV failed - pair again";
                        break;
                    }
                    psm = little_endian_read_16(packet, 11);
                    local_cid = little_endian_read_16(packet, 13);
                    if (psm == BLUETOOTH_PSM_HID_CONTROL) {
                        hid_control = local_cid;
                        if (we_initiated && !hid_interrupt) {
                            bt_send_cmd(&l2cap_create_channel_cmd, target_addr, BLUETOOTH_PSM_HID_INTERRUPT, 48);
                        }
                    }
                    if (psm == BLUETOOTH_PSM_HID_INTERRUPT) {
                        hid_interrupt = local_cid;
                        mouse_buttons = 0;
                        is_connected = 1;
                        status_text = "Connected";
                        {
                            bd_addr_t peer;
                            l2cap_event_channel_opened_get_address(packet, peer);
                            addr_to_str(peer, connected_str);
                            bt_send_cmd(&hci_remote_name_request, peer, 0, 0, 0);   /* learn the device name once */
                        }
                    }
                    break;

#ifdef L2CAP_EVENT_CHANNEL_CLOSED
                case L2CAP_EVENT_CHANNEL_CLOSED:
                    local_cid = little_endian_read_16(packet, 2);
                    if (local_cid == hid_interrupt) hid_interrupt = 0;
                    if (local_cid == hid_control) hid_control = 0;
                    if (!hid_interrupt) {
                        is_connected = 0;
                        mouse_buttons = 0;
                        connected_str[0] = 0;
                        if (!hid_control) {
                            we_initiated = 0;
                            status_text = "Disconnected - waiting for device";
                            check_pending_connect();
                        }
                    }
                    break;
#endif

                case HCI_EVENT_REMOTE_NAME_REQUEST_COMPLETE:
                    if (packet[2] == 0) {                       /* status ok: addr (reversed) at 3, name at 9 */
                        bd_addr_t who;
                        char as[20];
                        flip_bd_addr(who, &packet[3]);
                        addr_to_str(who, as);
                        int slot = -1;
                        for (int k = 0; k < name_count; k++) if (strcmp(name_cache[k].addr_str, as) == 0) slot = k;
                        if (slot < 0 && name_count < MAX_KEYS) slot = name_count++;
                        if (slot >= 0) {
                            snprintf(name_cache[slot].addr_str, sizeof(name_cache[slot].addr_str), "%s", as);
                            size_t n = strnlen((const char *)&packet[9], sizeof(name_cache[slot].name) - 1);
                            memcpy(name_cache[slot].name, &packet[9], n);
                            name_cache[slot].name[n] = 0;
                        }
                    }
                    break;

                case HCI_EVENT_DISCONNECTION_COMPLETE:
                    connected_str[0] = 0;
                    pin_request = 0;
                    is_connected = 0;
                    we_initiated = 0;
                    hid_control = 0;
                    hid_interrupt = 0;
                    mouse_buttons = 0;
                    status_text = "Disconnected - waiting for TV";
                    bt_send_cmd(&hci_write_scan_enable, 0x03);
                    bt_send_cmd(&btstack_set_discoverable, 1);
                    check_pending_connect();
                    break;

                default:
                    break;
            }
            break;

        default:
            break;
    }
}

/* ---------------- Bluetooth thread ---------------- */

static void *btcombo_thread(void *arg) {
    build_sdp_record();

    keys_load();

    btstack_run_loop_init(btstack_run_loop_posix_get_instance());

    /* the daemon is started on demand by launchd the moment we connect to its socket */
    int opened = 0;
    for (int i = 0; i < 20 && !opened; i++) {
        opened = (bt_open() == 0);
        if (!opened) {
            status_text = "Waiting for BTstack daemon...";
            usleep(500000);
        }
    }
    if (!opened) {
        status_text = "BTstack daemon not running (see /var/log/BTcombo.log)";
        return NULL;
    }

    bt_register_packet_handler(packet_handler);

    btstack_run_loop_set_data_source_fd(&pipe_source, cmd_pipe[0]);
    btstack_run_loop_set_data_source_handler(&pipe_source, &pipe_process);
    btstack_run_loop_enable_data_source_callbacks(&pipe_source, DATA_SOURCE_CALLBACK_READ);
    btstack_run_loop_add_data_source(&pipe_source);

    bt_send_cmd(&l2cap_register_service_cmd, BLUETOOTH_PSM_HID_CONTROL, 250);
    bt_send_cmd(&l2cap_register_service_cmd, BLUETOOTH_PSM_HID_INTERRUPT, 250);
    power_on_time = time(NULL);
    bt_send_cmd(&btstack_set_power_mode, HCI_POWER_ON);
    /* If the chip is already on (daemon kept running), powering on is a no-op and no state event follows,
       so ask for the current state explicitly. */
    bt_send_cmd(&btstack_get_state);

    btstack_run_loop_execute();

    bt_close();
    return NULL;
}

/* Folder for the pairing keys (the app's private folder). Moves the old /var/mobile/bt_link_keys.bin there once.
   Call before btcombo_start(). */
void btcombo_set_data_dir(const char *dir) {
    char path[512];
    snprintf(path, sizeof(path), "%s/link_keys.bin", dir);
    if (access(path, F_OK) != 0 && access(OLD_LINK_KEY_FILE, F_OK) == 0) {
        FILE *in = fopen(OLD_LINK_KEY_FILE, "rb");
        FILE *out = in ? fopen(path, "wb") : NULL;
        int ok = 0;
        if (in && out) {
            char buf[256];
            size_t n;
            ok = 1;
            while ((n = fread(buf, 1, sizeof(buf), in)) > 0) if (fwrite(buf, 1, n, out) != n) ok = 0;
        }
        if (in) fclose(in);
        if (out) fclose(out);
        if (ok) unlink(OLD_LINK_KEY_FILE); else unlink(path);
    }
    chmod(path, 0600);
    snprintf(key_file_path, sizeof(key_file_path), "%s", path);
}

int btcombo_start(void) {
    static int started = 0;
    pthread_t th;
    if (started) return 0;
    signal(SIGPIPE, SIG_IGN);
    if (pipe(cmd_pipe) != 0) return -1;
    fcntl(cmd_pipe[0], F_SETFL, fcntl(cmd_pipe[0], F_GETFL, 0) | O_NONBLOCK);
    fcntl(cmd_pipe[1], F_SETFL, fcntl(cmd_pipe[1], F_GETFL, 0) | O_NONBLOCK);
    started = 1;
    status_text = "Starting Bluetooth...";
    if (pthread_create(&th, NULL, btcombo_thread, NULL) != 0) {
        status_text = "Could not start Bluetooth thread";
        return -1;
    }
    pthread_detach(th);
    return 0;
}
