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

# urls example




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

is_url() {
    case "$1" in
 	http://*|https://*) return 0 ;;
	*) return 1 ;;
    esac
}


helpmsg(){
	echo "USAGE: `basename $0` -s url"
	echo -e "\t-s or --source - download and update database"
	echo -e "\tsupported formats:"
	echo -e "\t\t*.mmdb *.csv or *.csv.gz comressed"
	echo -e "\turls example:"
	echo -e "\t\thttps://download.db-ip.com/free/dbip-country-lite-\$(date \"+%Y-%m\").csv.gz"
	echo -e "\t\thttps://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-Country.mmdb"
}

while [ $# -gt 0 ]; do
	case "$1" in
		-s|--source)
			shift
			if [ $# -eq 0 ]; then
				echo "ERROR: $a need arg (URL)" >&2
				helpmsg
				exit 1
			fi
			if is_url "$1"; then
				update "$1"
			else
				echo "ERROR: \"$1\" is not URL http(s)" >&2
				helpmsg
				exit 1
			fi
		;;
		*)
			helpmsg
			exit 1
		;;
	esac
	shift
done

