#!/opt/bin/busybox sh
set -euo pipefail
IFS=$'\n\t'

# region Constants
SCRIPT="$(readlink -f "$0" || true)"

ZAPRET_BASE="/opt/zapret"
ZAPRET_INSTALL_BIN="$ZAPRET_BASE/install_bin.sh"
ZAPRET_IPSET_GET_CONFIG="$ZAPRET_BASE/ipset/get_config.sh"
ZAPRET_NDM_HOOK_SCRIPTS="/opt/etc/ndm/netfilter.d/01-zapret.sh"
KEENETIC_ZAPRET_SCRIPT="$ZAPRET_BASE/init.d/sysv/keenetic-zapret"
# endregion

# region Configurable variables
ZAPRET_IPSET_GET_CONFIG_ADD_CRONJOB="${ZAPRET_IPSET_GET_CONFIG_ADD_CRONJOB:-ask}" # "1" or "0" or "ask"
ZAPRET_IPSET_GET_CONFIG_CRONJOB_SCHEDULE="${ZAPRET_IPSET_GET_CONFIG_CRONJOB_SCHEDULE:-"0 0 * * 0"}"

# If KEENETIC_ZAPRET_BUILD_FILE_URL set then KEENETIC_ZAPRET_REPO and KEENETIC_ZAPRET_TAG are ignored.
KEENETIC_ZAPRET_BUILD_FILE_URL="${KEENETIC_ZAPRET_BUILD_FILE_URL-}"
KEENETIC_ZAPRET_REPO="${KEENETIC_ZAPRET_REPO:-"GuFFy12/keenetic-zapret"}"
KEENETIC_ZAPRET_TAG="${KEENETIC_ZAPRET_TAG-}"
# endregion

# region Functions
ask_yes_no() {
	while true; do
		echo "$1 [Y/n]: "
		read -r ask_yes_no_answer </dev/tty

		case "$ask_yes_no_answer" in
		[yY1]) return 0 ;;
		[nN0]) return 1 ;;
		*) echo Invalid choice ;;
		esac
	done
}

ask_value() {
	while true; do
		echo "$1 [default: \"$2\"]: "
		read -r ask_value_answer </dev/tty

		if [ -z "$ask_value_answer" ]; then
			ask_value_answer="$2"
		fi

		if ask_yes_no "Is \"$ask_value_answer\" correct?"; then
			break
		fi
	done
}

set_cronjob() {
	{
		{ crontab -l 2>/dev/null || true; } | sed '1,3{/^#/d}' | grep -vF "$3" || true
		if [ "$1" = "1" ]; then
			echo "$2 $3"
		fi
	} | crontab -
}

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

	echo Removing cron job for automatic list updates...
	set_cronjob 0 "" "$ZAPRET_IPSET_GET_CONFIG" || true

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

	echo Downloading latest Zapret ipset list...
	"$ZAPRET_IPSET_GET_CONFIG"

	if [ "$ZAPRET_IPSET_GET_CONFIG_ADD_CRONJOB" = "1" ] || \
	{ [ "$ZAPRET_IPSET_GET_CONFIG_ADD_CRONJOB" = "ask" ] && ask_yes_no "Enable cron job for automatic ipset list updates?"; }; then
		add_cronjob
	fi

	echo Keenetic Zapret has been successfully installed.
}

add_cronjob() {
	if [ "$ZAPRET_IPSET_GET_CONFIG_ADD_CRONJOB" = "ask" ]; then
		ask_value "Enter cron schedule" "$ZAPRET_IPSET_GET_CONFIG_CRONJOB_SCHEDULE"
		ZAPRET_IPSET_GET_CONFIG_CRONJOB_SCHEDULE="$ask_value_answer"
	fi
	set_cronjob 1 "$ZAPRET_IPSET_GET_CONFIG_CRONJOB_SCHEDULE" "$ZAPRET_IPSET_GET_CONFIG"
}

usage() {
	echo "Usage: $SCRIPT [install|uninstall|add-cronjob|remove-cronjob]" >&2
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

add-cronjob|add_cronjob)
	add_cronjob
	;;

remove-cronjob|remove_cronjob)
	set_cronjob 0 "" "$ZAPRET_IPSET_GET_CONFIG" || true
	;;

*)
	usage
	;;
esac

exit 0
