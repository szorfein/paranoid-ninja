#!/bin/sh

# Bins
HWC=$(which hwclock)
HOSTNAME=$(which hostname)
XAUTH=$(which xauth)
CHOWN=$(which chown)
SYS=$(which systemctl)
IP=$(which ip)
IPCALC=$(which ipcalc)
SHUF=$(which shuf)
TOR=$(which tor)
HEXDUMP=$(which hexdump)
DD=$(which dd)

LOCALTIME=/etc/localtime
BACKUP_FILES="/etc/hosts /etc/hostname"

DIR=$(pwd)
FUNCS="$DIR/src/functions"
source "${FUNCS-:/etc/paranoid/functions}"

#######################################################
# Check deps

[[ -z $HWC ]] && die "util-linux is no found, plz install"
[[ -z $HOSTNAME ]] && die "command hostname is no found"
[[ -z $XAUTH ]] && die "xauth is no found, plz install"
[[ -z $SYS ]] && die "systemd is no found, plz install"
[[ -z $IP ]] && die "iproute2 is no found, plz install"
[[ -z $TOR ]] && die "tor is no found, plz install"

#######################################################
# Local Functions

# Write the new hostname in file from $other_host_files
otherHostFiles() {
  local f rule
  rule="$1"
  if [ $other_host_files ] ; then
    for f in $other_host_files ; do
      [[ -f $f ]] &&
        sed -i "$rule" $f
    done
  fi
}

# forXorg, avoid error like display no found
# http://ubuntuhandbook.org/index.php/2016/06/change-hostname-ubuntu-16-04-without-restart/
forXorg() {
  local xorg_new xorg_old old_host rule x y z com user
  old_host=$1
  rule=$2
  if [[ $xauthority_file ]] && [[ -f $xauthority_file ]] ; then
    com="$XAUTH -f $xauthority_file"
    xorg_new="$($com list | grep $old_host | sed "$rule")"
    x=$(echo $xorg_new | awk '{print $1}')
    y=$(echo $xorg_new | awk '{print $2}')
    z=$(echo $xorg_new | awk '{print $3}')
    xorg_old="$($com list | grep $old_host | awk '{print $1}')"
    user=$(echo ${xauthority_file%/*} | sed s:/home/::g)
    echo "[*] changed hostname with xauth"

    # ex: xauth add "blackhole-opsbm4pvto/unix:0" MIT-MAGIC-COOKIE-1  240a406abe7fac0a35bbe1cb58e09c18
    $($com add "$x" $y $z)

    # ex: xauth remove "blackhole-opsbm4pvto/unix:0"
    $($com remove "$xorg_old")

    # fix permission
    $CHOWN $user:$user $xauthority_file
  else
    echo "[*] $xauthority_file no found, skip"
  fi
}

# exec if ssh_dir is set from conf file.
forSSH() {
  local old_host file files rule
  old_host="$1"
  rule="$2"
  if [ $ssh_dir ] ; then
    files=$(find $ssh_dir -type f | xargs grep $old_host | awk '{print $1}')
    echo "ssh file found $files"
    for file in ${files%:*} ; do
      sed -i "$rule" $file || die "sed in $file"
      echo "[*] change host in $file"
    done
  fi
}

# Write new value of hostname in multiple files
writeHost() {
  local new old file files rule
  # /etc/hostname 
  new="$1"
  old="$(cat /etc/hostname | head -n 1)"
  files="/etc/hostname /etc/hosts"
  rule="s:$old:$new:g"
  for file in $files ; do
    sed -i "$rule" $file || die "sed 1"
  done
  forSSH "$old" "$rule"
  forXorg "$old" "$rule"
  otherHostFiles "$rule"
}

#######################################################
# Randomize the link /etc/localtime from systemd

randTimezone() {
  local rand1 old
  old=$(file $LOCALTIME | awk '{print $5}')
  rand1="${timezone_dir[RANDOM % ${#timezone_dir[@]}]}"
  [[ -s $LOCALTIME ]] && rm $LOCALTIME
  ln -s $rand1 $LOCALTIME
  ${HWC} --systohc || die "hwclock fail"
  echo "[*] Changed timezone ${old##*/} from ${rand1##*/}"
}

#######################################################
# Randomize the hostname

randHost() {
  local new r rw
  if [ $prefix_hostname ] ; then
    r="${prefix_hostname[RANDOM % ${#prefix_hostname[@]}]}"
    new="$r-"
  fi
  rw=$(tr -dc 'a-z0-9' < /dev/urandom | head -c10)
  new+="$rw"
  echo "[*] Apply new hostname $new"
  writeHost $new
  $HOSTNAME $new || die "hostname fail"
}

#######################################################
# Randomize the MAC address

changeMac() {
  local hex mac old
  $IP link show $net_device > /dev/null 2>&1
  if [ $? -eq 0 ] ; then
    old=$($IP link show $net_device | grep -i ether | awk '{print $2}')
    hex=$(echo -n ""; $DD bs=1 count=1 if=/dev/urandom 2>/dev/null | $HEXDUMP -v -e '/1 "%02X"')
    mac=$(echo -n "$hex"; $DD bs=1 count=5 if=/dev/urandom 2>/dev/null | $HEXDUMP -v -e '/1 ":%02X"')
    $IP link set dev $net_device down
    $IP link set dev $net_device address $mac
    $IP link set dev $net_device up
    echo "[*] Changed mac $old to $mac"
    $SYS restart tor
  else
    echo "[*] Dev $net_device no found, update the config file"
  fi
}

#######################################################
# Update the network address

rand() {
  local max min range nb
  max=$($IPCALC $target_router | grep -i hostmax | awk '{print $2}')
  min=$($IPCALC $target_router | grep -i hostmin | awk '{print $2}')
  min=${min##*.}
  range="$(( min + 1 ))-${max##*.}"
  nb=$($SHUF -i $range -n 1)
  echo $nb
}

changeIp() {
  local randnb network new_ip broad valid
  network=$($IPCALC $target_router | grep -i network | awk '{print $2}')
  broad=$($IPCALC $target_router | grep -i broadcast | awk '{print $2}')

  if [[ $static ]] && [[ $static == "random" ]] ; then
    randnb=$(rand)
    echo "[*] create a random ip with $randnb"
  elif [[ $static ]] ; then
    new_ip=$static/${network#*/}
    echo "[*] configure addr with $static"
  else
    echo "[Err] no value found from paranoid.conf"
    exit 1
  fi

  [[ -z $new_ip ]] && new_ip=${target_router%.*}.$randnb/${network#*/}

  valid=$($IPCALC $new_ip | grep -i invalid)
  if [[ -z $valid ]] ; then
    echo "Router is $target_router/${network#*/}"
    echo "finally your new ip is $new_ip"
    $IP address flush dev $net_device
    $IP addr add $new_ip broadcast $broad dev $net_device
    $IP route add default via $target_router dev $net_device
    # restart the firewall
    sleep 2
    . $DIR/nftables.sh -c $CONF
  else
    echo "[Err] The address $new_ip is incorrect"
    exit 1
  fi
}

# If want random ip, start changeIp(), else use dhcpcd
updIp() {
  if [[ $want_dhcpcd ]] && [[ $want_dhcpcd == "no" ]] ; then
    changeIp
  elif [[ $want_dhcpcd ]] && [[ $want_dhcpcd == "yes" ]] ; then
    dhcp=$(which dhcpcd)
    [[ -z $dhcp ]] && die "[Err] dhcpcd is not installed"
    [[ -z $SYS ]] && die "{Err] systemd is not installed"
    $SYS restart dhcpcd
  else 
    echo "[Err] Config file is bad... dhcpcd=$want_dhcpcd"
    exit 1
  fi
}

#######################################################
# Main

checkArgConfig $1 $2
CONF="$2"
checkRoot

# Add ssh_dir to the backup list
if [ $ssh_dir ] ; then
  [[ -d $ssh_dir ]] && BACKUP_FILES+=" $ssh_dir"
fi

# Add other_host_files to the backup list
if [ $other_host_files ] ; then
  for f in $other_host_files ; do
    [[ -f $f ]] && BACKUP_FILES+=" $f"
  done
fi
 
backupFiles "$BACKUP_FILES"

# variable from paranoid.conf
for a in "${randomize[@]}" ; do
  [[ $a == "mac" ]] && changeMac
  [[ $a == "timezone" ]] && randTimezone
  [[ $a == "hostname" ]] && randHost
  [[ $a == "priv_ip" ]] && updIp
done

echo "[*] Relaunch your web browser is recommended"
