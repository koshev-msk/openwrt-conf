#!/bin/sh

# Wi-Fi shedule script for OpenWrt
# by Konstantine Shevlakov at <shevlakov@132lan.ru>
# example run in cron
#
# 05 9 * * * /path/to/script/wifished.sh enable|disable [SSID]
#
# next arguments aviaible
# enable - enable wireless radio
# disable - disable wireless radio
# ssid - enable or disable necessary ssid or multiple ssid's*
# * multiple ssid shoud be defined next syntax: ssid1|ssid2|ssidN
# if ssid not defined turn off or on all radios

# calendar section 
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

# uncomment line "calendar" if you use
# working calendar (only from RUSSIA)
# see holiday script in this directory
#calendar


# stuff code
if [ $2 ]; then
	SECTION=$(uci show wireless | awk -F [.] '/ssid/&&/'$2'/{print $2}')
	if [ $SECTION ]; then
		for s in $SECTION; do
			case $1 in
				disable) sleep $SLEEP && uci set wireless.$s.disabled='1' ;;
				enable) uci delete wireless.$s.disabled ;;
			esac
		done
		uci commit
		/sbin/wifi
	fi
else
	case $1 in
		disable) sleep $SLEEP && /sbin/wifi down ;;
		enable) /sbin/wifi ;;
	esac
fi

