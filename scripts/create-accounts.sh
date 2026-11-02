#!/usr/bin/env bash
# Create COIL Project A groups and accounts. Run once: sudo /opt/coil/scripts/create-accounts.sh
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }
OUT=/root/coil-initial-passwords.txt
umask 077
for g in mati szczecin faculty; do
    occ group:add "$g" || echo "Group $g may already exist"
done
add_user() {
    local id="$1" name="$2" group="$3" pw
    pw=$(openssl rand -base64 18 | tr -d '/+=')
    OC_PASS="$pw" occ user:add --password-from-env --display-name="$name" --group="$group" "$id"
    echo "$id   $pw" >> "$OUT"
}
add_user ph-member1     "PH Member 1"              mati
add_user ph-member2     "PH Member 2"              mati
add_user pl-member1     "PL Member 1"              szczecin
add_user pl-member2     "PL Member 2"              szczecin
add_user fac-dorsu      "Faculty - DOrSU"          faculty
add_user fac-mus        "Faculty - Maritime Univ." faculty
echo "First passwords saved in $OUT (root only)."
