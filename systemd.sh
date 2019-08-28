#!/bin/sh

set -ue

PN=$(grep -ie "^program_name" Makefile | awk 'BEGIN {FS="="}{print $2}')
BIN_DIR="$(grep -ie "^bin_dir" Makefile | awk 'BEGIN {FS="="}{print $2}')"
SYSTEMD_SERVICE=$(grep -ie "^systemd_service" Makefile | awk 'BEGIN {FS="="}{print $2}')
CONF_DIR="$(grep -ie "^conf_dir" Makefile | awk 'BEGIN {FS="="}{print $2}')/${PN}"
LIB_DIR="$(grep -ie "^lib_dir" Makefile | awk 'BEGIN {FS="="}{print $2}')/${PN}"
BACKUP_DIR="$(grep -ie "^backup_dir" Makefile | awk 'BEGIN {FS="="}{print $2}')"

SERVICES="paranoid@.service paranoid-wifi@.service paranoid-macspoof@.service"
SERVICES+=" paranoid@.timer paranoid-wifi@.timer"
LIBS="randomize.sh nftables.sh iptables.sh functions"

DIR=$(pwd)
FUNCS=$DIR/src/functions
source $FUNCS

DEPS="which systemctl hwclock hostname chown"
DEPS+=" ip ipcalc shuf tor dhcpcd tr hexdump dd modprobe"
DEPS+=" head jq"
DEPS_FILE="/dev/urandom"

CONF=$2

for d in $DEPS ; do
  checkBins $d
  echo "[OK] Found $d"
done

for f in $DEPS_FILE ; do
  if [ -f $f ] || [ -c $f ] ; then
    echo "[OK] Found $f"
  else
    die "[ Failed ] $f is no found"
  fi
done

DESTDIR=/
cat > $PN.confd << EOF
PROGRAM_NAME=$(echo $PN | sed "s:\${DESTDIR}:$DESTDIR:g")
BIN_DIR=$(echo $BIN_DIR | sed "s:\${DESTDIR}:$DESTDIR:g")
CONF_DIR=$(echo $CONF_DIR | sed "s:\${DESTDIR}:$DESTDIR:g")
LIB_DIR=$(echo $LIB_DIR | sed "s:\${DESTDIR}:$DESTDIR:g")
SYSTEMD_SERVICE=$(echo $SYSTEMD_SERVICE | sed "s:\${DESTDIR}:$DESTDIR:g")
BACKUP_DIR=$(echo $BACKUP_DIR | sed "s:\${DESTDIR}:$DESTDIR:g")
EOF
