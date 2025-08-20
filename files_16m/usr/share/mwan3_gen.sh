#!/bin/sh

# check args
if [ $# -lt 1 ]; then
    echo "Usage: $0 <interface1> [interface2] ..." >&2
    exit 1
fi

if [ $# -eq 1 ]; then
    echo "Error: interaces must be two or more." >&2
    exit 1
fi

# awk config generator
echo "$@" | awk '
{


    print "config globals '\''globals'\''"
    print "    option mmx_mask '\''0x3F00'\''"
    print ""

    n = NF
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
        print "    option weight '\''1'\''"
        print ""
    }

    # Gen members 70% primary iface
    for (i = 1; i <= n; i++) {
        print "config member '\''" $i "_member_primary'\''"
        print "    option interface '\''" $i "'\''"
        print "    option metric '\''1'\''"
        print "    option weight '\''7'\''"  # Primary 70%
        print ""

        for (j = 1; j <= n; j++) {
            if (j != i) {
                print "config member '\''" $j "_member_primary_" i "'\''"
                print "    option interface '\''" $j "'\''"
                print "    option metric '\''1'\''"
                other_weight = int(3 / (n - 1))  # All to 30%
                print "    option weight '\''" other_weight "'\''"
                print ""
            }
        }
    }

    # Gen members 50% primary iface
    if (n > 2) {
        for (i = 1; i <= n; i++) {
            print "config member '\''" $i "_member_half'\''"
            print "    option interface '\''" $i "'\''"
            print "    option metric '\''1'\''"
            print "    option weight '\''5'\''"  # Primary 50%
            print ""

            for (j = 1; j <= n; j++) {
                if (j != i) {
                    print "config member '\''" $j "_member_half_" i "'\''"
                    print "    option interface '\''" $j "'\''"
                    print "    option metric '\''1'\''"
                    other_weight = int(5 / (n - 1))  # All to 50%
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

    # LAN rule ( future use )
    #print "config rule '\''lan'\''"
    #print "    option family '\''ipv4'\''"
    #print "    option proto '\''all'\''"
    #print "    option sticky '\''0'\''"
    #print "    option src_ip '\''192.168.1.0/24'\''"
    #print "    option use_policy '\''balanced'\''"
    #print ""

    # Default rule
    print "config rule '\''default_rule'\''"
    print "    option family '\''ipv4'\''"
    print "    option proto '\''all'\''"
    print "    option sticky '\''0'\''"
    print "    option use_policy '\''balanced'\''"
    print ""
}
'
