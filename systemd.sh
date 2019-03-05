#!/bin/sh

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

DEP_NO_OK=false

DEPS="which systemctl hwclock hostname chown"
DEPS+=" ip ipcalc shuf tor dhcpcd tr hexdump dd modprobe"
DEPS+=" head"
DEPS_FILE="/dev/urandom"

checkArgConfig $1 $2
CONF=$2

for d in $DEPS ; do
  which $d >/dev/null 2>&1
  if [ $? -ne 0 ] ; then
    DEP_NO_OK=true
    echo "[ Failed ] command $d no found, install it plz"
  fi
done

[[ $DEP_NO_OK == true ]] && die "Dependencies are not complete"

for f in $DEPS_FILE ; do
  file=$(file $f | grep "cannot open")
  if [[ -z $file ]] ; then
    echo "[OK] found $f"
  else
    DEP_NO_OK=true
    echo "[ Failed ] $f is no found"
  fi
done

[[ $DEP_NO_OK == true ]] && die "dependencies are not complete"

cat > $PN.confd << EOF
PROGRAM_NAME=$(echo $PN | sed "s:\${DESTDIR}:$3:g")
BIN_DIR=$(echo $BIN_DIR | sed "s:\${DESTDIR}:$3:g")
CONF_DIR=$(echo $CONF_DIR | sed "s:\${DESTDIR}:$3:g")
LIB_DIR=$(echo $LIB_DIR | sed "s:\${DESTDIR}:$3:g")
SYSTEMD_SERVICE=$(echo $SYSTEMD_SERVICE | sed "s:\${DESTDIR}:$3:g")
BACKUP_DIR=$(echo $BACKUP_DIR | sed "s:\${DESTDIR}:$3:g")
EOF
