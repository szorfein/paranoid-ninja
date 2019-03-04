#!/bin/sh

PN=$(grep -ie "^program_name" Makefile | awk 'BEGIN {FS="="}{print $2}')
BIN_DIR="$(grep -ie "^bin_dir" Makefile | awk 'BEGIN {FS="="}{print $2}')"
SYSTEMD_SERVICE=$(grep -ie "^systemd_service" Makefile | awk 'BEGIN {FS="="}{print $2}')
SYSTEMD_SCRIPT=$(grep -ie "^systemd_script" Makefile | awk 'BEGIN {FS="="}{print $2}')
CONF_DIR="$(grep -ie "^conf_dir" Makefile | awk 'BEGIN {FS="="}{print $2}')/${PN}"
LIB_DIR="$(grep -ie "^lib_dir" Makefile | awk 'BEGIN {FS="="}{print $2}')/${PN}"
BACKUP_DIR="$(grep -ie "^backup_dir" Makefile | awk 'BEGIN {FS="="}{print $2}')"

SCRIPTS="paranoid"
SERVICES="paranoid@.service paranoid-wifi@.service paranoid-macspoof@.service"
SERVICES+=" paranoid@.timer paranoid-wifi@.timer"
LIBS="randomize.sh nftables.sh iptables.sh functions"

DIR=$(pwd)
FUNCS=$DIR/src/functions
source $FUNCS

DEP_NO_OK=false

# check deps
DEPS="which systemctl hwclock hostname chown"
DEPS+=" ip ipcalc shuf tor dhcpcd tr hexdump dd modprobe"
DEPS+=" head"
DEPS_FILE="/dev/urandom"

#######################################################
# Check root

checkArgConfig $1 $2
CONF=$2

#######################################################
# Check systemd on the system and dependencies

for d in $DEPS ; do
  which $d >/dev/null 2>&1
  if [ $? -eq 0 ] ; then
    #echo "[OK] check command $d into $(which $d)"
    echo
  else
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

######################################################
# Create a config file for the MAC service

file="paranoid.conf.sample"
net_device=$(grep -e "^net_device" $file)

cat > paranoid-mac.conf << EOF
randomize=( "mac" )
net_device=$net_device
EOF

######################################################
# Create new env

cat > $PN.confd << EOF
PROGRAM_NAME=${PN}
BIN_DIR=${BIN_DIR}
CONF_DIR=${CONF_DIR}
LIB_DIR=${LIB_DIR}
SYSTEMD_SERVICE=${SYSTEMD_SERVICE}
SYSTEMD_SCRIPT=${SYSTEMD_SCRIPT}
BACKUP_DIR=${BACKUP_DIR}
EOF

######################################################
# Advice 

echo "[*] For ethernet card: systemctl start paranoid@enp3s0"
echo "[*] For wifi card: systemctl start paranoid-wifi@wlp2s0"
