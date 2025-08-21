#!/bin/sh

# simple mwan3 config generator
# copyright by koshev-msk 2025

# check args
if [ $# -lt 1 ]; then
    echo "Usage: $0 <interface1> [interface2] ..." >&2
    exit 1
fi

if [ $# -eq 1 ]; then
    echo "Error: interaces must be two or more." >&2
    exit 1
fi

# get network address from LAN
eval $(ipcalc.sh $(uci -q get network.lan.ipaddr) $(uci -q get network.lan.netmask))

if ! [ -n ${NETWORK} -o -n ${PREFIX} ]; then
    echo "Error: LAN interface doest not address"
    exit 1
fi

# awk config generator
echo "$@" | awk -v lan=${NETWORK}/${PREFIX} '
{


    print "config globals '\''globals'\''"
    print "    option mmx_mask '\''0x3F00'\''"
    print ""

    n = NF
    BASE_WEIGHT = 1000
    # iface section generate
    for (i = 1; i <= n; i++) {
        print "config interface '\''" $i "'\''"
        print "    option enabled '\''1'\''"
        print "    option family '\''ipv4'\''"
        print "    option track_method '\''ping'\''"
        print "    list track_ip '\''132lan.ru'\''"
        print "    option reliability '\''1'\''"
        print "    option count '\''1'\''"
        print "    option timeout '\''2'\''"
        print "    option interval '\''30'\''"
        print "    option down '\''3'\''"
        print "    option up '\''3'\''"
	print "    option initial_state '\''online'\''"
	print "    list flush_conntrack '\''ifup'\''"
        print "    list flush_conntrack '\''ifdown'\''"
        print "    list flush_conntrack '\''connected'\''"
        print "    list flush_conntrack '\''disconnected'\''"
        print ""
    }

    # Gen members all balance
    for (i = 1; i <= n; i++) {
        print "config member '\''" $i "_member_balanced'\''"
        print "    option interface '\''" $i "'\''"
        print "    option metric '\''1'\''"
        print "    option weight '\''" BASE_WEIGHT "'\''"
        print ""
    }

    # Gen members 70% primary iface
    for (i = 1; i <= n; i++) {
        primary_weight = int(BASE_WEIGHT * 0.7)
        other_weight = int(BASE_WEIGHT * 0.3 / (n - 1))

        # Primary iface 70%
        print "config member '\''" $i "_member_primary'\''"
        print "    option interface '\''" $i "'\''"
        print "    option metric '\''1'\''"
        print "    option weight '\''" primary_weight "'\''"
        print ""

        # Other all to 30%
        for (j = 1; j <= n; j++) {
            if (j != i) {
                print "config member '\''" $j "_member_primary_" i "'\''"
                print "    option interface '\''" $j "'\''"
                print "    option metric '\''1'\''"
                print "    option weight '\''" other_weight "'\''"
                print ""
            }
        }
    }


    # Gen members 50% primary iface
    if (n > 2) {
        for (i = 1; i <= n; i++) {
            half_weight = int(BASE_WEIGHT * 0.5)
            other_weight = int(BASE_WEIGHT * 0.5 / (n - 1))

           # Primary iface 50%
            print "config member '\''" $i "_member_half'\''"
            print "    option interface '\''" $i "'\''"
            print "    option metric '\''1'\''"
            print "    option weight '\''" half_weight "'\''"
            print ""

            # All to 50%
            for (j = 1; j <= n; j++) {
                if (j != i) {
                    print "config member '\''" $j "_member_half_" i "'\''"
                    print "    option interface '\''" $j "'\''"
                    print "    option metric '\''1'\''"
                    print "    option weight '\''" other_weight "'\''"
                    print ""
                }
            }
        }
    }

    # Gen balance policies
    for (i = 1; i <= n; i++) {
        # Only iface mode
        print "config policy '\''only_" $i "'\''"
        print "    list use_member '\''" $i "_member_balanced'\''"
        print ""
    }

    for (i = 1; i <= n; i++) {
        # 70% traffic primary iface
        print "config policy '\''primary_" $i "'\''"
        print "    list use_member '\''" $i "_member_primary'\''"
        for (j = 1; j <= n; j++) {
            if (j != i) {
                print "    list use_member '\''" $j "_member_primary_" i "'\''"
            }
        }
        print ""
    }

    if (n > 2) {
        for (i = 1; i <= n; i++) {
            # 50% traffic primary iface
            print "config policy '\''half_" $i "'\''"
            print "    list use_member '\''" $i "_member_half'\''"
            for (j = 1; j <= n; j++) {
                if (j != i) {
                    print "    list use_member '\''" $j "_member_half_" i "'\''"
                }
            }
            print ""
        }
    }

    # all balanced mode
    print "config policy '\''balanced'\''"
    for (i = 1; i <= n; i++) {
        print "    list use_member '\''" $i "_member_balanced'\''"
    }
    print ""

    # LAN rule
    print "config rule '\''lan'\''"
    print "    option family '\''ipv4'\''"
    print "    option proto '\''all'\''"
    print "    option sticky '\''0'\''"
    print "    option src_ip '\'' "lan" '\''"
    print "    option use_policy '\''balanced'\''"
    print ""

    # Default rule ( future use )
    #print "config rule '\''default_rule'\''"
    #print "    option family '\''ipv4'\''"
    #print "    option proto '\''all'\''"
    #print "    option sticky '\''0'\''"
    #print "    option use_policy '\''balanced'\''"
    #print ""
}
'
