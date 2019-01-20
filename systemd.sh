#!/bin/sh

SYSTEMD_SERVICE=/etc/systemd/system
SYSTEMD_SCRIPT=/usr/lib/systemd/scripts
DIR=$(pwd)

SCRIPTS="paranoid"
SERVICES="paranoid@.service paranoid-wifi@.service"

FUNCS="$DIR/src/functions"
source "${FUNCS-:/etc/paranoid/functions}"
CONF_FILE=${DIR/paranoid.conf}

DEP_NO_OK=false

# check deps
DEPS="which systemctl hwclock hostname xauth chown"
DEPS+=" ip ipcalc shuf tor dhcpcd tr hexdump dd nft"
DEPS_FILE="/dev/urandom"

#######################################################
# Check root

checkArgConfig $1 $2
CONF=$2
checkRoot

#######################################################
# Check systemd on the system and dependencies

for d in $DEPS ; do
  which $d >/dev/null 2>&1
  if [ $? -eq 0 ] ; then
    echo "[OK] check command $d into $(which $d)"
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
[[ ! -d $install_path ]] && mkdir -p $install_path

######################################################
# Copy | Install scripts

s="$DIR/systemd"
for script in $SCRIPTS ; do
  install -m 755 "$s/$script" $SYSTEMD_SCRIPT/
  echo "[*] $script installed"
done

for service in $SERVICES ; do
  install -m 755 "$s/$service" $SYSTEMD_SERVICE/
  echo "[*] $service installed"
done

install -m 755 "$DIR/nftables.sh" $SYSTEMD_SCRIPT/
echo "[*] nftables.sh installed"
install -m 755 "$DIR/randomize.sh" $SYSTEMD_SCRIPT/
echo "[*] randomize.sh installed"
install -m 755 $CONF $install_path/paranoid.conf
echo "[*] paranoid.conf installed"
install -m 755 $DIR/src/functions $install_path/
echo "[*] functions installed"

######################################################
# Patch systemd script

# patch systemd script with real command path rather than use which
# patch some path too

SCRIPTS="randomize.sh nftables.sh paranoid"

for s in $SCRIPTS ; do
  [[ ! -f $SYSTEMD_SCRIPT/$s ]] && echo "[ Failed ] file $s no found"
  for l in $DEPS ; do
    comm=$(which $l)
    rule="s:\$(which $l):$comm:g"
    sed -i "$rule" $SYSTEMD_SCRIPT/$s
    sed -i "s:\$DIR/src/functions:/etc/paranoid/functions:g" $SYSTEMD_SCRIPT/$s
    sed -i "s:\$DIR/nftables.sh:$SYSTEMD_SCRIPT/nftables.sh:g" $SYSTEMD_SCRIPT/$s
    echo "[*] patch file $s, with rule = $rule"
  done
done

######################################################
# Advice 

echo "[*] For ethernet card: systemctl start paranoid@enp3s0"
echo "[*] For wifi card: systemctl start paranoid-wifi@wlp2s0"
