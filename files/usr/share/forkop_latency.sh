#!/bin/sh
# forkop-best: выбрать ноду с минимальным latency через clash_api

#GROUP="${1:?usage: $0 <selector>}"
SKIP="${1:-^$}"
TIMEOUT="${2:-2000}"
GROUP=$(forkop clash_api get_proxies | jsonfilter -e '@.proxies[@.type="Selector"].name')

best=$(
	forkop clash_api get_proxies |
	#jsonfilter -e '@["proxies"]["GLOBAL"]["all"].*' |
	jsonfilter -e "@[\"proxies\"][\"$GROUP\"][\"all\"].*" |
	while IFS= read -r node; do
		case "$node" in
			GLOBAL|direct|reject|dns-out) continue ;;
		esac
		d=$(forkop clash_api get_proxy_latency "$node" "$TIMEOUT" 2>/dev/null |
			jsonfilter -e '@.delay')
		[ "${d:-0}" -gt 0 ] 2>/dev/null && echo "$d $node"
	done | sort -n | head -n1
)

[ -n "$best" ] || { echo "no alive nodes" >&2; exit 1; }

node=${best#* }
echo "best: $node (${best%% *} ms)"
forkop clash_api set_group_proxy "$GROUP" "$node"
