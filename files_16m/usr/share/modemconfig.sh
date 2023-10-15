#!/bin/sh

# wwan autoconfiguration interface 
INUSE=$(uci -q show network.wwan.device | awk -F [=] '/sys/{gsub("'\''","");print $2}')
if [ $INUSE ]; then
	/etc/init.d/modemconfig disable
	exit 0
fi


probe=0
while [ -z "$SYSPMODEM" ]; do
	MODEMS=$(mmcli -L | awk '{print $1}')
	for mp in $MODEMS; do
		SYSPMODEM=$(mmcli -J -m $mp | jsonfilter -e '@["modem"]["generic"]["device"]')
	done
	if [ $probe -gt 20 ]; then
		exit 0
	fi
	sleep 6
	probe=$(($probe+1))
done

probe=0
while [ -z "$MCC" ]; do
	MCC=$(mmcli -J -m $mp | jsonfilter -e '@["modem"]["3gpp"]["operator-code"]')
	case $MCC in
		*[0-9]*) APN=$(awk -F[\;] '/'$MCC'/ {print $2}' /usr/share/apn.list) ;;
		*)
			 unset MCC
			 mmcli -m $mp -e
		;;
	esac
	if [ $probe -gt 20 ]; then
		break
	fi
	sleep 6
	probe=$(($probe+1))
done

for p in $SYSPMODEM; do
	DEV=$p
done

if [ $DEV ]; then
	uci batch << EOF
set network.wwan=interface
set network.wwan.proto='modemmanager'
set network.wwan.device=$DEV
set network.wwan.iptype='ipv4'
set network.wwan.auth='none'
set modemconfig.@modem[0].device=$DEV
EOF
	if [ $APN ]; then
		uci set network.wwan.apn=$APN
	fi
	uci commit
	ifup wwan
	/etc/init.d/modemconfig disable
fi
exit 0
