#!/usr/bin/env bash
# Remove one WireGuard peer.  Usage: sudo remove-peer.sh NAME
set -euo pipefail
NAME="${1:?Usage: sudo $0 NAME}"
CONF=/etc/wireguard/wg0.conf
[[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }
PUB=$(awk -v n="# $NAME" '$0==n{f=1;next} f&&/^PublicKey/{print $3; exit}' "$CONF")
[[ -n "$PUB" ]] || { echo "Peer $NAME not found"; exit 1; }
BAK="$CONF.bak.$(date +%F-%H%M%S)"
cp "$CONF" "$BAK"
awk -v n="# $NAME" 'BEGIN{RS="";ORS="\n\n"} { keep=1; k=split($0,L,"\n"); for(i=1;i<=k;i++) if(L[i]==n) keep=0; if(keep) print }' "$BAK" > "$CONF"
chmod 600 "$CONF"
wg set wg0 peer "$PUB" remove
rm -f "/etc/wireguard/clients/$NAME.conf"
echo "Removed $NAME (backup: $BAK)"
