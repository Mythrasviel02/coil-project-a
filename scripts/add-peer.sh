#!/usr/bin/env bash
# Add one WireGuard peer.  Usage: sudo add-peer.sh NAME LAST_NUMBER
# Example: sudo add-peer.sh ph-member1 2   ->  10.8.0.2
set -euo pipefail
NAME="${1:?Usage: sudo $0 NAME LAST_NUMBER  (example: sudo $0 ph-member1 2)}"
OCTET="${2:?Give the last number of the VPN address, 2 to 254}"
WG_IF=wg0
WG_DIR=/etc/wireguard
CLIENT_DIR=$WG_DIR/clients
CLIENT_IP="10.8.0.$OCTET"
[[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }
[[ "$NAME" =~ ^[a-z0-9-]+$ ]] || { echo "NAME: use lowercase letters, digits and - only"; exit 1; }
[[ "$OCTET" =~ ^[0-9]+$ ]] && (( OCTET >= 2 && OCTET <= 254 )) || { echo "LAST_NUMBER must be 2 to 254"; exit 1; }
if grep -q "AllowedIPs = $CLIENT_IP/32" "$WG_DIR/$WG_IF.conf"; then echo "$CLIENT_IP is already used"; exit 1; fi
if [[ -e "$CLIENT_DIR/$NAME.conf" ]]; then echo "Peer $NAME already exists"; exit 1; fi 
umask 077
mkdir -p "$CLIENT_DIR"
PRIV=$(wg genkey)
PUB=$(echo "$PRIV" | wg pubkey)
PSK=$(wg genpsk)
SERVER_PUB=$(cat "$WG_DIR/server.pub")
ENDPOINT=$(cat "$WG_DIR/endpoint")
cp "$WG_DIR/$WG_IF.conf" "$WG_DIR/$WG_IF.conf.bak.$(date +%F-%H%M%S)"
cat >> "$WG_DIR/$WG_IF.conf" <<EOF
[Peer]
# $NAME
PublicKey = $PUB
PresharedKey = $PSK
AllowedIPs = $CLIENT_IP/32
EOF
cat > "$CLIENT_DIR/$NAME.conf" <<EOF
[Interface]
# $NAME - COIL Project A
PrivateKey = $PRIV
Address = $CLIENT_IP/32
[Peer]
PublicKey = $SERVER_PUB
PresharedKey = $PSK
Endpoint = $ENDPOINT
AllowedIPs = 10.8.0.0/24
PersistentKeepalive = 25
EOF
wg syncconf "$WG_IF" <(wg-quick strip "$WG_IF")
echo "Added $NAME as $CLIENT_IP"
echo "Client config: $CLIENT_DIR/$NAME.conf"
