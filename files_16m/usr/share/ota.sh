#!/bin/sh

# simple update firmware script for 132lan.ru site
# by Konstantine Shevlakov (c) 2025

BOARD=$(jsonfilter -s "$(cat /etc/board.json)" -e '@["model"]["id"]')

. /etc/openwrt_release

URL_BASE=https://openwrt.132lan.ru/releases_cell/latest/targets/${DISTRIB_TARGET}


rm -rf /tmp/profiles.json /tmp/firmware.bin
if [ ! -f /tmp/update.lock ]; then
	echo "Check updates."
fi
wget ${URL_BASE}/profiles.json -O /tmp/profiles.json > /dev/null 2&>1
case $? in
	0) continue ;;
	*) echo "No updates for this board: $BOARD" && exit 0;;
esac

BASE_BOARD=$(jsonfilter -s "$(cat /tmp/profiles.json)" -e '@["profiles"][*]["supported_devices"].*')

board_stuff(){
	jsonfilter -s "$(cat /tmp/profiles.json)" \
		-e FILE="$['profiles']['$FW_BOARD']['images'][-1]['name']" \
		-e SHA256="$['profiles']['$FW_BOARD']['images'][-1]['sha256']"
}

for b in $BASE_BOARD; do
	if [ "${b}" = "${BOARD}" ]; then
		FW_BOARD=$(echo $BOARD | sed -e 's/\,/_/')
		eval $(board_stuff)
		FW_REV_EXT=$(echo $FILE | awk -F [-] '{gsub("rev",""); gsub(/\./,"",$2);  print $2$5$6}')
		if [ -f /rom/etc/uci-defaults/fw_rev ]; then
			. /rom/etc/uci-defaults/fw_rev
			VER_LOCAL=$(echo $FW_REV | awk -F [-] '{gsub("rev",""); print $1$2}')
			DIGIT_ELEASE=$(echo ${DISTRIB_RELEASE} | awk '{gsub(/\./,""); print $0}')
			FW_VER_LOCAL=${DIGIT_ELEASE}${VER_LOCAL}
		else
			echo "Failed! Abort update"
			exit 0
		fi
		if [ -f /tmp/update.lock ]; then
			echo "Download firmware $FILE"
			echo "from $URL_BASE"
			wget $URL_BASE/$FILE -O /tmp/firmware.bin > /dev/null 2&>1
			case $? in
				0) echo "Download complete." ;;
				*) echo "No updates for this board: $BOARD" && exit 0 ;;
			esac
			SHA256_DL=$(sha256sum /tmp/firmware.bin | awk '{print $1}')
			echo -n "Check sha256 sum: "
			if [ "$SHA256" = "$SHA256_DL" ]; then
				echo "OK"
				echo "Update process start!"
				echo "Device will be rebooted."
				echo "DO NOT TURN OFF DEVICE!"
				sysupgrade -T /tmp/firmware.bin
				case $? in
					0) echo "Flashing firmware" ;;
					*) echo "Failed! Abort update" && exit 0 ;;
				esac
				sleep 5 && sysupgrade /tmp/firmware.bin &
			else
				echo "Failed! Abort update"
				rm -f /tmp/update.lock
			fi
		else
			if [ $FW_REV_EXT -gt $FW_VER_LOCAL ]; then
				echo "New firmware upgrade release!"
				echo "*** $FILE ***"
				echo "Please run again scrit to update!"
				touch /tmp/update.lock
			else
				echo "No update aviaible!"
			fi
		fi
	fi
done
