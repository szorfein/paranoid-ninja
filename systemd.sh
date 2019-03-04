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

[[ ! -d $SYSTEMD_SERVICE ]] && die "dir $SYSTEMD_SERVICE is no found"

# Create necessary path
[[ ! -d $SYSTEMD_SCRIPT ]] && mkdir -p $SYSTEMD_SCRIPT

######################################################
# Copy | Install scripts

ins() {
  local com
  com="$1"
  $com
  echo "[+] $com"
}

s="$DIR/systemd"
for script in $SCRIPTS ; do
  ins "install -Dm0744 "$s/$script" $SYSTEMD_SCRIPT/$script"
done

for service in $SERVICES ; do
  ins "install -Dm0644 "$s/$service" $SYSTEMD_SERVICE/$service"
done

for l in $LIBS ; do
  ins "install -Dm0744 "$DIR/src/$l" $LIB_DIR/$l"
done

# Don't erase the config file if exist
if [ ! -f $CONF_DIR/paranoid.conf ] ; then
  ins "install -Dm0644 $CONF $CONF_DIR/paranoid.conf"
else
  echo "You may probably update your config file"
fi

ins "install -Dm0755 "$DIR/paranoid.sh" $BIN_DIR/$PN"

######################################################
# Create a config file for the MAC service

file="$CONF"
rand=$(grep -e "^randomize" $file)
if_mac=$(echo $rand | grep mac)

createMACConf() {
  local new_conf if_true
  new_conf="$CONF_DIR/paranoid-mac.conf"
  if_true=$1
  if [ $if_true == true ] ; then
    echo 'randomize=( "mac" )' > $new_conf
  else
    echo 'randomize=()' > $new_conf
  fi
  grep -e "^net_device" $file >> $new_conf
  grep -e "^firewall" $file >> $new_conf
  echo "[+] $CONF_DIR/paranoid-mac.conf created"
}

if [[ ! -z $if_mac ]] ; then
  createMACConf true
else
  createMACConf false
fi

######################################################
# Create new env

cat > new_env << EOF
PROGRAM_NAME=${PN}
BIN_DIR=${BIN_DIR}
CONF_DIR=${CONF_DIR}
LIB_DIR=${LIB_DIR}
SYSTEMD_SERVICE=${SYSTEMD_SERVICE}
SYSTEMD_SCRIPT=${SYSTEMD_SCRIPT}
BACKUP_DIR=${BACKUP_DIR}
EOF

if [ ! -d /etc/conf.d ] ; then
  mkdir -p /etc/conf.d
fi

ins "install -Dm0644 new_env /etc/conf.d/$PN"
rm new_env

######################################################
# Advice 

echo "[*] For ethernet card: systemctl start paranoid@enp3s0"
echo "[*] For wifi card: systemctl start paranoid-wifi@wlp2s0"
