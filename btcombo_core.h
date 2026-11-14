#ifndef BTCOMBO_CORE_H
#define BTCOMBO_CORE_H

#ifdef __cplusplus
extern "C" {
#endif

/* Private folder for the pairing keys (call before btcombo_start). Migrates the old key file. */
void btcombo_set_data_dir(const char *dir);

/* Starts the BTstack run loop on a background thread. Safe to call once. */
int btcombo_start(void);

/* Thread-safe: queue one text command for the Bluetooth thread. */
void btcombo_send(const char *line);
void btcombo_sendf(const char *fmt, ...) __attribute__((format(printf, 1, 2)));

/* Status for the UI (read from the main thread). */
int btcombo_is_connected(void);
const char *btcombo_status(void);
int btcombo_pairing_mode(void);
int btcombo_io_mode(void);             /* 3 = automatic, 2 = type the passkey */
int btcombo_pin_request(void);          /* 0 none, 1 = PIN requested by TV, 2 = passkey requested by TV */
int btcombo_saved_count(void);
const char *btcombo_saved_last(void);
const char *btcombo_saved_addr(int i);          /* address of saved device i (0 = most recent), "" if none */
const char *btcombo_connected_addr(void);       /* address of the connected device, "" if none */
const char *btcombo_device_name(const char *addr_str);   /* name read from the device, "" if not known yet */   /* "AA:BB:CC:DD:EE:FF" of the most recent device, or "" */

/* Long paste (ASCII text). begin returns 0 if started; cancel stops within one character. */
int btcombo_paste_begin(const char *text, int len);
void btcombo_paste_cancel(void);
int btcombo_paste_active(void);
int btcombo_paste_progress(void);
int btcombo_paste_total(void);

#ifdef __cplusplus
}
#endif

#endif
