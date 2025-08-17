#!/opt/bin/busybox sh
set -euo pipefail
IFS=$'\n\t'

# region Constants
SCRIPT="$(readlink -f "$0" || true)"

ZAPRET_BASE="/opt/zapret"
ZAPRET_INSTALL_BIN="$ZAPRET_BASE/install_bin.sh"
ZAPRET_NDM_HOOK_SCRIPTS="/opt/etc/ndm/netfilter.d/01-zapret.sh"
KEENETIC_ZAPRET_SCRIPT="$ZAPRET_BASE/init.d/sysv/keenetic-zapret"
# endregion

# region Configurable variables
# If KEENETIC_ZAPRET_BUILD_FILE_URL set then KEENETIC_ZAPRET_REPO and KEENETIC_ZAPRET_TAG are ignored.
KEENETIC_ZAPRET_BUILD_FILE_URL="${KEENETIC_ZAPRET_BUILD_FILE_URL-}"
KEENETIC_ZAPRET_REPO="${KEENETIC_ZAPRET_REPO:-"GuFFy12/keenetic-zapret"}"
KEENETIC_ZAPRET_TAG="${KEENETIC_ZAPRET_TAG-}"
# endregion

# region Functions
get_ndm_version() {
	if ! command -v ndmc >/dev/null; then
		return 1
	fi

	ndm_version="$(ndmc -c show version | grep -w title | head -n 1 | awk '{print $2}' | tr -cd "0-9.")"
	if [ -z "$ndm_version" ]; then
		return 1
	fi
}
# endregion

install_packages() {
	opkg update
	opkg install coreutils-sort cron curl grep gzip ipset iptables kmod_ndms xtables-addons_legacy
}

uninstall() {
	echo Stopping Keenetic Zapret...
	if [ -f "$KEENETIC_ZAPRET_SCRIPT" ] && ! "$KEENETIC_ZAPRET_SCRIPT" stop; then
		echo "Error: Failed to stop Keenetic Zapret." >&2
	fi

	echo Removing Keenetic Zapret...
	if [ -d "$ZAPRET_BASE" ]; then
		rm -r "$ZAPRET_BASE"
	fi

	local ifs_old="$IFS"
	IFS=' '
	for ndm_hook_script in $ZAPRET_NDM_HOOK_SCRIPTS; do
		echo "Removing Keenetic NDM hook script \"$ndm_hook_script\"..."
		if [ -f "$ndm_hook_script" ]; then
			rm -f "$ndm_hook_script"
		fi
	done
	IFS="$ifs_old"

	echo Keenetic Zapret has been successfully uninstalled.
}

install() {
	if ! get_ndm_version; then
		echo Error: Keenetic NDM version not found or invalid. >&2
		exit 1
	fi

	echo Installing required packages...
	install_packages

	echo Uninstall previous Zapret installation...
	uninstall

	echo Install Keenetic Zapret...
	SCRIPT_DIR="$(dirname "$SCRIPT")"
	if [ -n "$SCRIPT" ] && [ "$SCRIPT_DIR" != "/" ] && [ -d "$SCRIPT_DIR/opt" ]; then
		cp -r "$SCRIPT_DIR/opt/"* /opt/
	else
		# Wait ~1s after delete_service to let system update (e.g. iptables).
		# Without this, curl may fail due to incomplete network transition.
		sleep 1

		if [ -z "$KEENETIC_ZAPRET_BUILD_FILE_URL" ]; then
			if [ -n "$KEENETIC_ZAPRET_TAG" ]; then
				KEENETIC_ZAPRET_BUILD_FILE_URL="https://github.com/$KEENETIC_ZAPRET_REPO/releases/download/$KEENETIC_ZAPRET_TAG/keenetic-zapret-$KEENETIC_ZAPRET_TAG.tar.gz"
			else
				KEENETIC_ZAPRET_BUILD_FILE_URL="$(curl -fL "https://api.github.com/repos/$KEENETIC_ZAPRET_REPO/releases" | awk -F'"' '/"browser_download_url":/ {print $4}' | tail -n +1 | head -n 1)"
			fi
		fi

		curl -fL "$KEENETIC_ZAPRET_BUILD_FILE_URL" | tar -xz -C / ./opt/
	fi

	echo Link Zapret binaries...
	"$ZAPRET_INSTALL_BIN"

	echo Starting Keenetic Zapret...
	"$KEENETIC_ZAPRET_SCRIPT" start

	echo Keenetic Zapret has been successfully installed.
}

usage() {
	echo "Usage: $SCRIPT [install|uninstall]" >&2
	exit 1
}

if [ "$#" -gt 1 ]; then
	usage
elif [ -z "${1:-}" ]; then
	set -- install
fi
case "$1" in
install)
	install
	;;

uninstall)
	uninstall
	;;

*)
	usage
	;;
esac
