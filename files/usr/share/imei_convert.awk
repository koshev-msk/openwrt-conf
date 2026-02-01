#!/usr/bin/awk -f
# Simple converter IMEI to TBCD for Telit modems nvram format
# by koshev-msk 2026

BEGIN {
    if (ARGC > 1) {
        imei = ARGV[1]
        ARGC = 1
        
        encoded = "80A" imei

        result = ""
        for (i = 1; i <= length(encoded); i += 2) {
            first = substr(encoded, i, 1)
            second = substr(encoded, i+1, 1)
            swapped = second first
            dec = sprintf("%d", "0x" swapped)
            hex_out = sprintf("%02X", dec)
            result = result hex_out ","
        }

        print substr(result, 1, length(result)-1)
    } else {
        print "Usage: ./imei_convert.awk IMEI"
        print "Example: ./imei_convert.awk 353990821092348"
    }
}
