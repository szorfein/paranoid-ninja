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
LIBS="randomize.sh nftables.sh iptables.sh"

DIR=$(pwd)
FUNCS="$DIR/src/functions"
source "${FUNCS-:/etc/paranoid/functions}"

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

ins "install -Dm0744 "$DIR/nftables.sh" $LIB_DIR/nftables.sh"
ins "install -Dm0744 "$DIR/iptables.sh" $LIB_DIR/iptables.sh"
ins "install -Dm0744 "$DIR/randomize.sh" $LIB_DIR/randomize.sh"
ins "install -Dm0644 $CONF $CONF_DIR/paranoid.conf"
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
  sed -i "s:\"mac\" ::g" $CONF_DIR/paranoid.conf
else
  createMACConf false
fi

######################################################
# Patch systemd script

# patch systemd script with real command path rather than the use of which
# patch some path too

DEPS+=" nft iptables iptables-restore xauth"

patchFiles() {
  local scripts dir s d comm rule
  scripts="$1"
  dir="$2"
  for s in $scripts ; do
    [[ ! -f $dir/$s ]] && die "File $dir/$s no found"
    for d in $DEPS ; do
      comm=$(which $d)
      rule="s:\$(which $d):$comm:g"
      sed -i "$rule" $dir/$s
      sed -i "s:\$DIR/src:$LIB_DIR:g" $dir/$s
      sed -i "s:\$DIR:$LIB_DIR:g" $dir/$s
      sed -i "s:\$LIB_DIR:$LIB_DIR:g" $dir/$s
      sed -i "s:\$SYSTEMD_SCRIPT:$SYSTEMD_SCRIPT:g" $dir/$s
      sed -i "s:\$CONF_DIR:$CONF_DIR:g" $dir/$s
      #echo "[*] patch file $dir/$s, with rule = $rule"
    done
  done
}

patchFiles "$SCRIPTS" "$SYSTEMD_SCRIPT"
patchFiles "$LIBS" "$LIB_DIR"
patchFiles "$SERVICES" "$SYSTEMD_SERVICE"
patchFiles "$SERVICES" "$SYSTEMD_SERVICE"
patchFiles $PN "$BIN_DIR"
sed -i "s:\$HOME/ninja/backups:$BACKUP_DIR:g" $CONF_DIR/paranoid.conf

######################################################
# Mask redundant service

# Mask firewall because scripts generate news rule 
# each times, some service back if only disabled
systemctl mask nftables
systemctl mask nftables-restore
systemctl mask iptables

######################################################
# Advice 

echo "[*] For ethernet card: systemctl start paranoid@enp3s0"
echo "[*] For wifi card: systemctl start paranoid-wifi@wlp2s0"
