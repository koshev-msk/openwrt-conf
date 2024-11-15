#!/bin/sh

# Wi-Fi shedule script for OpenWrt
# by Konstantine Shevlakov at <shevlakov@132lan.ru>
# example run in cron
#
# 05 9 * * * /path/to/script/wifished.sh --enable|--disable --ssid SSID
#
# next arguments aviaible
# -e|--enable - enable wireless radio
# -d|--disable - disable wireless radio
# -s|--ssid <SSID> - enable or disable necessary ssid or multiple ssid's*
# * multiple ssid shoud be defined next syntax: SSID_1|SSID_2|SSID_N
# if ssid not defined turn off or on all radios

# help section
help(){
	echo "USAGE: `basename $0` --command"
	echo -e "\tAviaible commands:"
	echo -e "\t\t-e|--enable\t-\tenable wireless"
	echo -e "\t\t-d|--disable\t-\tdisable wireless"
	echo -e "\t\t-s|--ssid ssidA[|ssidB|ssidN] - enable or disable necessary SSID"
	echo -e "\t\t\tif ssid not defined turn off or on all radios"
	echo -e "\t\t-c|--calendar\t-\tuse working calendar script (RUSSIA only).\n\t\t\tSee holiday script on current directory"
	echo -e "\t\t-h|--help\t-\tthis help"
}

# args section
if [ "${@}x" = "x" ]; then
	help
fi

int=1
for a in "$@"; do
	int=$(($int+1))
	case $a in
		-e|--enable) ACTION=enable ;;
		-d|--disable) ACTION=disable ;;
		-s|--ssid) SSID="$(eval echo \$$int)" ;;
		-c|--calendar) CAL=true ;;
		-h|--help) help ;;
	esac
done

# calendar section. See holiday script on curdir
calendar(){
	if [ -f /tmp/holiday ]; then
		. /tmp/holiday
		if [ "$SLEEP" = "false" ]; then
			exit 0
		fi
	else
		exit 0
	fi
}

# if calendar option enable?
if [ "$CAL" = "true" ]; then
	calendar
fi

SLEEP="${SLEEP:=0}"

# stuff code
if [ $SSID ]; then
	SECTION=$(uci show wireless | awk -F [.] '/ssid/&&/'$SSID'/{print $2}')
	if [ $SECTION ]; then
		for s in $SECTION; do
			case $ACTION in
				disable) sleep $SLEEP && uci set wireless.$s.disabled='1' >/dev/null 2>&1 ;;
				enable) uci delete wireless.$s.disabled >/dev/null 2>&1;;
			esac
		done
		uci commit
		/sbin/wifi
	fi
else
	case $ACTION in
		disable) sleep $SLEEP && /sbin/wifi down >/dev/null 2>&1 ;;
		enable) /sbin/wifi >/dev/null 2>&1 ;;
	esac
fi


