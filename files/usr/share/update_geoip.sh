#!/bin/sh
# update iptables GEOIP DB

[ ! -d /usr/share/xt_geoip ] && {
	mkdir -p /usr/share/xt_geoip
}

update_ipt(){
	mkdir -p /tmp/geoip
	cd /tmp/geoip/
	/usr/lib/xtables-addons/xt_geoip_dl
	if [ $(ls -1 | wc -l) -ge 0 ]; then
		/usr/lib/xtables-addons/xt_geoip_build
		rm -rf /usr/share/xt_geoip/*
		cp *.iv4 *.iv6 /usr/share/xt_geoip/
		rm -rf /tmp/geoip
		/etc/init.d/firewall restart
		logger -t "GEOIP" "iptables databases has updated!"
	else
		logger -t "GEOIP" "failed to update iptables databases!"
	fi
}


# Update MaxMinDB GEOIP
update_maxmind(){
	[ ! -d /tmp/maxmind ] && {
		mkdir -p /tmp/maxmind
	}

	wget -P /tmp/ https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-Country.mmdb

	case $? in
		0)
			rm -rf /tmp/maxmind/*
			mv /tmp/GeoLite2-Country.mmdb /tmp/maxmind/
			mkdir -p /var/lib/nginx/body
			if [ -x /usr/bin/xt_geoip_build_maxmind ]; then
				rm -rf /usr/share/xt_geoip/*
        	                /usr/bin/xt_geoip_build_maxmind -o /usr/share/xt_geoip/ /tmp/maxmind/GeoLite2-Country.mmdb
				/etc/init.d/firewall restart
			fi
			logger -t "GEOIP" "Maxmind databases has updated!"
		;;
		*) logger -t "GEOIP" "failed to update Maxmind databases!" ;;
	esac
}


for a in "$@"; do
	case $a in
		-i|--iptables) update_ipt ;;
		-m|--maxmind) update_maxmind ;;
	esac
done

