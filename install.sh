#!/bin/sh
set -euo pipefail
IFS=$'\n\t'

# If KEENETIC_ZAPRET_BUILD_FILE_URL set then KEENETIC_ZAPRET_REPO and KEENETIC_ZAPRET_TAG are ignored.
KEENETIC_ZAPRET_BUILD_FILE_URL="${KEENETIC_ZAPRET_BUILD_FILE_URL-}"
KEENETIC_ZAPRET_REPO="${KEENETIC_ZAPRET_REPO:-"GuFFy12/keenetic-zapret"}"
KEENETIC_ZAPRET_TAG="${KEENETIC_ZAPRET_TAG-}"

ZAPRET_BASE="${ZAPRET_BASE:-/opt/zapret}"

ZAPRET_CONFIG="${ZAPRET_CONFIG:-"$ZAPRET_BASE/config"}"
ZAPRET_CONFIG_IFACE_WAN="${ZAPRET_CONFIG_IFACE_WAN-}"

ZAPRET_INSTALL_BIN="${ZAPRET_INSTALL_BIN:-"$ZAPRET_BASE/install_bin.sh"}"

ZAPRET_IPSET_GET_CONFIG="${ZAPRET_IPSET_GET_CONFIG:-"$ZAPRET_BASE/ipset/get_config.sh"}"
ZAPRET_IPSET_GET_CONFIG_USE_CRON="${ZAPRET_IPSET_GET_CONFIG_USE_CRON:-ask}" # "1" or "0" or "ask"
ZAPRET_IPSET_GET_CONFIG_CRON_SCHEDULE="${ZAPRET_IPSET_GET_CONFIG_CRON_SCHEDULE:-"0 0 * * 0"}"

KEENETIC_ZAPRET_SCRIPT="${KEENETIC_ZAPRET_SCRIPT:-"$ZAPRET_BASE/init.d/sysv/keenetic-zapret"}"

ask_yes_no() {
	while true; do
		echo "$1 (Y/N): "
		read -r answer </dev/tty

		case "$answer" in
		[yY1]) return 0 ;;
		[nN0]) return 1 ;;
		*) echo Invalid choice ;;
		esac
	done
}

set_config_value() {
	sed -i "s/^$2=.*/$2=\"$3\"/;t;\$a $2=\"$3\"" "$1"
}

add_cron_job() {
	{
		{ crontab -l 2>/dev/null || true; } | grep -vF "$2" || true
		echo "$1 $2"
	} | crontab -
}

delete_service() {
	if [ -f "$2" ] && ! "$2" stop; then
		echo "Failed to stop service using script: $2" >&2
	fi

	if [ -d "$1" ]; then
		rm -r "$1"
	fi
}

get_ndm_version() {
	if ! command -v ndmc >/dev/null; then
		return 1
	fi

	NDM_VERSION="$(ndmc -c show version | grep -w title | head -n 1 | awk '{print $2}' | tr -cd "0-9.")"
	if [ -z "$NDM_VERSION" ]; then
		return 1
	fi
}

install_packages() {
	opkg update
	opkg install coreutils-sort cron curl grep gzip ipset iptables kmod_ndms xtables-addons_legacy
}

install() {
	SCRIPT="$(readlink -f "$0" || true)"
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
}

configure() {
	ZAPRET_CONFIG_IFACE_WAN="${ZAPRET_CONFIG_IFACE_WAN:-"$(ip route show default 0.0.0.0/0 | awk '{print $5}')"}"

	if [ -z "$ZAPRET_CONFIG_IFACE_WAN" ]; then
		return 1
	fi

	set_config_value "$ZAPRET_CONFIG" "IFACE_WAN" "$ZAPRET_CONFIG_IFACE_WAN"
}

main() {
	if ! get_ndm_version; then
		echo Invalid or missing Keenetic version >&2
		exit 1
	fi

	echo Installing packages...
	install_packages

	echo Deleting old Keenetic Zapret installation...
	delete_service "$ZAPRET_BASE" "$KEENETIC_ZAPRET_SCRIPT"

	echo Install Keenetic Zapret...
	install

	echo Link Zapret binaries...
	"$ZAPRET_INSTALL_BIN"

	echo Configuring Zapret...
	if ! configure; then
		echo Failed to retrieve WAN interface for Zapret >&2
		exit 1
	fi

	if [ "$ZAPRET_IPSET_GET_CONFIG_USE_CRON" = "1" ] ||
		{ [ "$ZAPRET_IPSET_GET_CONFIG_USE_CRON" = "ask" ] && ask_yes_no "Create a cron job to automatically update the Zapret ipset ($ZAPRET_IPSET_GET_CONFIG_CRON_SCHEDULE)?"; }; then
		add_cron_job "$ZAPRET_IPSET_GET_CONFIG_CRON_SCHEDULE" "$ZAPRET_IPSET_GET_CONFIG"
	fi

	echo Starting Zapret...
	"$KEENETIC_ZAPRET_SCRIPT" start

	echo Downloading latest Zapret ipset list...
	"$ZAPRET_IPSET_GET_CONFIG"

	echo Keenetic Zapret has been successfully installed. For further configuration please refer to README.md file!
}

main
