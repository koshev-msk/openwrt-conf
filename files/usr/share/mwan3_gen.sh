#!/bin/sh

# simple mwan3 config generator
# copyright by koshev-msk 2025

OFFSET_METRIC=1000
DEFAULT_POLICY="balanced"
LAN_INTERFACE="lan"  # default LAN interface

# Parse command line arguments
INTERFACES=""
while [ $# -gt 0 ]; do
    case "$1" in
        -i|--interface)
            shift
            while [ $# -gt 0 ] && ! echo "$1" | grep -q '^-'; do
                if [ -z "$INTERFACES" ]; then
                    INTERFACES="$1"
                else
                    INTERFACES="$INTERFACES $1"
                fi
                shift
            done
            ;;
        -p|--policy)
            if [ $# -gt 1 ]; then
                DEFAULT_POLICY="$2"
                shift 2
            else
                echo "Error: -p requires a policy name" >&2
                exit 1
            fi
            ;;
        -l|--lan)
            if [ $# -gt 1 ]; then
                LAN_INTERFACE="$2"
                shift 2
            else
                echo "Error: -l requires a LAN interface name" >&2
                exit 1
            fi
            ;;
        -h|--help)
            echo "Usage: $0 -i <interface1> [interface2 ...] [-p <default_policy>] [-l <lan_interface>]"
            echo ""
            echo "Options:"
            echo "  -i, --interface    WAN interfaces to configure (required, at least 2)"
            echo "  -p, --policy       Default policy name (default: balanced)"
            echo "  -l, --lan          LAN interface name (default: lan)"
            echo "  -h, --help         Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 -i wan1 wan2"
            echo "  $0 -i wan1 wan2 wan3 -p 90_wan1"
            echo "  $0 -i eth0 eth1 -p 100_eth0 -l br-lan"
            echo "  $0 -i wwan0 wwan1 -p balanced -l lan"
            exit 0
            ;;
        -*)
            echo "Error: Unknown option: $1" >&2
            echo "Use -h for help" >&2
            exit 1
            ;;
        *)
            # Backward compatibility: treat non-option arguments as interfaces
            if [ -z "$INTERFACES" ]; then
                INTERFACES="$1"
            else
                INTERFACES="$INTERFACES $1"
            fi
            shift
            ;;
    esac
done

# Check interfaces
if [ -z "$INTERFACES" ]; then
    echo "Error: No WAN interfaces specified" >&2
    echo "Usage: $0 -i <interface1> [interface2 ...] [-p <default_policy>] [-l <lan_interface>]" >&2
    exit 1
fi

# Count interfaces
set -- $INTERFACES
IFACE_COUNT=$#

if [ $IFACE_COUNT -eq 1 ]; then
    echo "Error: At least 2 WAN interfaces are required" >&2
    exit 1
fi

# Check LAN interface exists in network config
if ! uci -q get network."$LAN_INTERFACE" > /dev/null; then
    echo "Error: LAN interface '$LAN_INTERFACE' not found in network configuration" >&2
    exit 1
fi

# get network address from LAN interface
lan_ipaddr=$(uci -q get network."$LAN_INTERFACE".ipaddr)
lan_netmask=$(uci -q get network."$LAN_INTERFACE".netmask)

if [ -z "$lan_ipaddr" ] || [ -z "$lan_netmask" ]; then
    echo "Error: LAN interface '$LAN_INTERFACE' does not have IP address or netmask configured" >&2
    echo "Please configure IP address for $LAN_INTERFACE interface first" >&2
    exit 1
fi

eval $(ipcalc.sh "$lan_ipaddr" "$lan_netmask")

if [ -z "$NETWORK" ] || [ -z "$PREFIX" ]; then
    echo "Error: Failed to calculate network address for $LAN_INTERFACE" >&2
    exit 1
fi

# awk config generator - используем echo для передачи интерфейсов в awk
echo "$INTERFACES" | awk -v lan="${NETWORK}/${PREFIX}" -v offset_metric="$OFFSET_METRIC" -v default_policy="$DEFAULT_POLICY" -v lan_interface="$LAN_INTERFACE" '
{

    print "config globals '\''globals'\''"
    print "    option mmx_mask '\''0x3F00'\''"
    print ""

    n = NF
    BASE_WEIGHT = 1000
    # iface section generate
    for (i = 1; i <= n; i++) {

        off_metric = i * 100 + offset_metric

        print "config interface '\''" $i "'\''"
        print "    option enabled '\''1'\''"
        print "    option family '\''ipv4'\''"
        print "    option track_method '\''ping'\''"
        print "    list track_ip '\''dns.yandex'\''"
        print "    option reliability '\''1'\''"
        print "    option count '\''1'\''"
        print "    option timeout '\''2'\''"
        print "    option interval '\''30'\''"
        print "    option down '\''3'\''"
        print "    option up '\''3'\''"
        print "    option off_metric '\''" off_metric "'\''"
        print "    option initial_state '\''offline'\''"
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

    # Gen members 90% main iface
    for (i = 1; i <= n; i++) {
        main_weight = int(BASE_WEIGHT * 0.9)
        other_weight = int(BASE_WEIGHT * 0.1 / (n - 1))

        # Main iface 90%
        print "config member '\''" $i "_member_main'\''"
        print "    option interface '\''" $i "'\''"
        print "    option metric '\''1'\''"
        print "    option weight '\''" main_weight "'\''"
        print ""

        # Other all to 10%
        for (j = 1; j <= n; j++) {
            if (j != i) {
                print "config member '\''" $j "_member_main_" i "'\''"
                print "    option interface '\''" $j "'\''"
                print "    option metric '\''1'\''"
                print "    option weight '\''" other_weight "'\''"
                print ""
            }
        }
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
        print "config policy '\''100_" $i "'\''"
        print "    list use_member '\''" $i "_member_balanced'\''"
        print "    option last_resort '\''default'\''"
        print ""
    }

    # Main policy (90%)
    for (i = 1; i <= n; i++) {
        print "config policy '\''90_" $i "'\''"
        print "    list use_member '\''" $i "_member_main'\''"
        for (j = 1; j <= n; j++) {
            if (j != i) {
                print "    list use_member '\''" $j "_member_main_" i "'\''"
            }
        }
        
        print ""
    }

    for (i = 1; i <= n; i++) {
        # 70% traffic primary iface
        print "config policy '\''70_" $i "'\''"
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
            print "config policy '\''50_" $i "'\''"
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

    # LAN rule - note: rule name is still '\''lan'\'' but uses specified LAN interface network
    print "config rule '\''lan'\''"
    print "    option family '\''ipv4'\''"
    print "    option proto '\''all'\''"
    print "    option sticky '\''0'\''"
    print "    option src_ip '\''"lan"'\''"
    print "    option use_policy '\''" default_policy "'\''"
    print ""

    # Default rule
    # future use
    #print "config rule '\''default_rule'\''"
    #print "    option family '\''ipv4'\''"
    #print "    option proto '\''all'\''"
    #print "    option sticky '\''0'\''"
    #print "    option use_policy '\''" default_policy "'\''"
    #print ""
    
    # Note: LAN interface name is available as lan_interface variable if needed
    # print "# Generated for LAN interface: " lan_interface
}
'
