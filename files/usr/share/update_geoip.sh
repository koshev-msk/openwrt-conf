#!/bin/sh
# update iptables GEOIP DB

[ -x /usr/bin/xt_geoip_build ] || {
	echo "maxminddb-dump-coutry package not found!"
	exit 1
}

[ -d /usr/share/xt_geoip ] || {
	mkdir -p /usr/share/xt_geoip
	echo "Directory /usr/share/xt_geoip not exist!"
	exit 1
}


timestamp=$(date "+%Y-%m")
csvdbname=dbip-country-lite-$timestamp.csv.gz
mmdbname=GeoLite2-Country.mmdb
ip2loc=geolite2-country-ipv${f}.csv

download(){
	url=$1
	dest=$2
	local UTIL
	command -v wget >/dev/null 2>&1 && UTIL=w
	command -v curl >/dev/null 2>&1 && UTIL=c
	case $UTIL in
		c) curl --retry 3 --connect-timeout 5 -fsSLO --output-dir "$dest" "$url" ;;
		w) wget -T 5 -P "$dest" "$url" ;;
		*) exit 1 ;;
	esac
}


# Update GEOIP DB
update(){
	[ ! -d /tmp/geoipdb ] && {
		mkdir -p /tmp/geoipdb
	}
	
	[ ! -d /tmp/xt_geoip ] && {
		mkdir -p /tmp/xt_geoip
	}
	
	rm -rf /tmp/xt_geoip/* /tmp/geoipdb/*
	
	local FORMAT= SUCCESS=
	
	source=$1

	download "$source" /tmp/geoipdb && SUCCESS=OK
	
	[ "$SUCCESS" = "OK" ] || exit 1
	
	# get format DB
	ls /tmp/geoipdb/*.csv >/dev/null 2>&1 && FORMAT=csv
	ls /tmp/geoipdb/*.csv.gz >/dev/null 2>&1 && FORMAT=csvgz
	ls /tmp/geoipdb/*.mmdb >/dev/null 2>&1 && FORMAT=mmdb
	
	case $FORMAT in
		csv) /usr/bin/xt_geoip_build -d /tmp/geoipdb/*.csv -o /tmp/xt_geoip || exit 1 ;;
		csvgz) gzip -d /tmp/geoipdb/*.csv.gz && /usr/bin/xt_geoip_build -d /tmp/geoipdb/*.csv -o /tmp/xt_geoip || exit 1 ;;
		mmdb) /usr/bin/xt_geoip_build -o /tmp/xt_geoip /tmp/geoipdb/*.mmdb || exit 1 ;;
		*) exit 1
	esac
	# check files in dir
	if $(ls -1 /tmp/xt_geoip/*.iv* >/dev/null 2>&1); then
		cp -rp /tmp/xt_geoip/*.iv* /usr/share/xt_geoip
	else
		rm -rf /tmp/xt_geoip/ /tmp/geoipdb/
		exit 1
	fi
	rm -rf /tmp/xt_geoip/ /tmp/geoipdb/
}


helpmsg(){
	echo "USAGE: `basename $0` <arg>"
	echo -e "\t -d or --dbip - download and update dbip database"
	echo -e "\t -m or --maxmind - download and update maxmind database"
	echo -e "\t -i or --ip2location - download and update ip2location database"
}

for a in "$@"; do
	case $a in
		-d|--dbip) update https://download.db-ip.com/free/$csvdbname ;;
		-m|--maxmind) update https://github.com/P3TERX/GeoLite.mmdb/raw/download/$mmdbname ;;
		-i|--ip2location)
			for f in 4 6; do
				update https://github.com/sapics/ip-location-db/raw/refs/heads/main/geolite2-country/geolite2-country-ipv${f}.csv
			done
		;;
		*) helpmsg ;;
	esac
done


