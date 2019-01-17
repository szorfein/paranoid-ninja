#!/bin/sh

SYSTEMD_SERVICE=/etc/systemd/system/
SYSTEMD_SCRIPT=/usr/lib/systemd/scripts/
DIR=$(pwd)

SCRIPTS="paranoid"
SERVICES="paranoid@.service paranoid-wifi@.service"

die() {
  printf "${red}%s${white}%s${endc}\n" \
    "[Err]" " $1"
  exit 1
}

#######################################################
# Check root

check_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    printf "\\n${red}%s${endc}\\n" \
      "[ failed ] Please run this program as a root!" 2>&1
    exit 1
  fi
}

check_root

#######################################################
# Check systemd on the system

which systemctl >/dev/null
[[ ! $? -eq 0 ]] && die "systemd not available"

[[ ! -d $SYSTEMD_SERVICE ]] && die "dir $SYSTEMD_SERVICE is no found"
[[ ! -d $SYSTEMD_SCRIPT ]] && mkdir -p $SYSTEMD_SCRIPT

######################################################
# Copy scripts

s="$DIR/systemd"
for script in $SCRIPTS ; do
  install -m 755 "$s/$script" $SYSTEMD_SCRIPT
  echo "[*] $script installed"
done

for service in $SERVICES ; do
  install -m 755 "$s/$service" $SYSTEMD_SERVICE
  echo "[*] $service installed"
done

install -m 755 "$DIR/nftables.sh" $SYSTEMD_SCRIPT
echo "[*] nftables.sh installed"

######################################################
# 

echo "[*] For ethernet card: systemctl start paranoid@enp3s0"
echo "[*] For wifi card: systemctl start paranoid-wifi@wlp2s0"
