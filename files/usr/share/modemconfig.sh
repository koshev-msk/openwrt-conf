#!/bin/sh

# wwan autoconfiguration interface 
INUSE=$(uci show network.wwan.device | awk -F [=] '/sys/{gsub("'\''","");print $2}')
if [ $INUSE ]; then
	/etc/init.d/modemconfig stop
	/etc/init.d/modemconfig disable
	exit 0
fi


probe=0
while [ -z "$SYSPMODEM" ]; do
	SYSPMODEM=$(mmcli -J -m $(mmcli -L | awk '{print $1}') | jsonfilter -e '@["modem"]["generic"]["device"]')
	if [ $probe -gt 20 ]; then
		exit 0
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
set firewall.@zone[1].network='wan wwan'
EOF
	uci commit
	ifup wwan
	/etc/init.d/modemconfig stop
	/etc/init.d/modemconfig disable
fi
exit 0
