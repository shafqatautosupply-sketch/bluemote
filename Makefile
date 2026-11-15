# ---------------------------------------------------------------
# Bluemote v7.0 - standalone: app + BTstack v1.2 daemon built from source
# Theos, iOS 6.1 SDK, armv7 (iPhone 4s)
# ---------------------------------------------------------------
export ARCHS = armv7
export TARGET = iphone:6.1:6.0

BT = $(CURDIR)/btstack
# -iquote (not -I) so the v1.2 headers in this project always win over any old BTstack headers
# that may be installed in $(THEOS)/include (for example an old bluetooth.h)
BT_INC = -iquote $(BT)/src/ble -iquote $(BT)/src -iquote $(BT)/src/classic -iquote $(BT)/port/ios \
         -iquote $(BT)/platform/daemon/src -iquote $(BT)/platform/posix -iquote $(BT)/platform/corefoundation

# BTstack client library, compiled straight into the app (no libBTstack.dylib needed)
BTSTACK_CLIENT_FILES = \
	btstack/src/btstack_linked_list.c \
	btstack/src/btstack_run_loop.c \
	btstack/src/hci_cmd.c \
	btstack/src/hci_dump.c \
	btstack/src/btstack_util.c \
	btstack/platform/daemon/src/btstack.c \
	btstack/platform/daemon/src/daemon_cmds.c \
	btstack/platform/daemon/src/socket_connection.c \
	btstack/platform/corefoundation/btstack_run_loop_corefoundation.m \
	btstack/platform/posix/btstack_run_loop_posix.c \
	btstack/src/classic/sdp_util.c \
	btstack/src/classic/spp_server.c

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = Bluemote
Bluemote_FILES = main.m AppDelegate.m MainViewController.m SettingsViewController.m PairViewController.m StatusTitleView.m TrackpadView.m KeyboardView.m MediaView.m UIHelpers.m bluemote_core.c $(BTSTACK_CLIENT_FILES)
Bluemote_FRAMEWORKS = UIKit Foundation CoreGraphics CoreFoundation QuartzCore AudioToolbox
Bluemote_CFLAGS = -std=gnu99 $(BT_INC) -Wno-error

# BTstack daemon (the iOS port of v1.2), runs as root under launchd.
# NOTE: do not put "#" comment lines inside this list - a comment that ends in a backslash swallows the
# following lines (that is how att_server.c, daemon.c, btstack_control_iphone.m ... silently disappeared before).
# main() lives in btstack/platform/daemon/src/daemon.c - do not add another main.m.
TOOL_NAME = BluemoteDaemon
BluemoteDaemon_FILES = $(BTSTACK_CLIENT_FILES) \
	btstack/src/ad_parser.c \
	btstack/src/btstack_memory.c \
	btstack/src/btstack_memory_pool.c \
	btstack/src/classic/rfcomm.c \
	btstack/src/classic/sdp_server.c \
	btstack/src/hci.c \
	btstack/src/l2cap.c \
	btstack/src/l2cap_signaling.c \
	btstack/src/classic/sdp_client.c \
	btstack/src/classic/sdp_client_rfcomm.c \
	btstack/platform/corefoundation/btstack_device_name_db_corefoundation.m \
	btstack/platform/corefoundation/rfcomm_service_db_corefoundation.m \
	btstack/platform/daemon/src/daemon.c \
	btstack/port/ios/src/btstack_control_iphone.m \
	btstack/port/ios/src/hci_transport_h4_iphone.c \
	btstack/port/ios/src/platform_iphone.m \
	btstack/port/ios/SpringBoardAccess/SpringBoardAccess.c
BluemoteDaemon_FRAMEWORKS = Foundation CoreFoundation
BluemoteDaemon_PRIVATE_FRAMEWORKS = IOKit
# BLUEMOTE_FORCE_LOGGING + text log type: daemon log lines (incl. iphone_on / BlueTool output) go to /var/log/Bluemote.log.
# Remove both flags once everything works.
BluemoteDaemon_CFLAGS = -std=gnu99 $(BT_INC) -Wno-unused-variable -Wno-error -DBLUEMOTE_FORCE_LOGGING -DBLUEMOTE_QUIET_WHEN_NOT_LOGGING -DBTSTACK_LOG_TYPE=HCI_DUMP_STDOUT

include $(THEOS_MAKE_PATH)/application.mk
include $(THEOS_MAKE_PATH)/tool.mk

internal-stage::
	$(ECHO_NOTHING)chmod 0755 $(THEOS_STAGING_DIR)/DEBIAN/postinst $(THEOS_STAGING_DIR)/DEBIAN/prerm 2>/dev/null || true$(ECHO_END)
