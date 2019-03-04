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
TR=$(which tr)
HEAD=$(which head)

LOCALTIME=/etc/localtime
BACKUP_FILES="/etc/hosts /etc/hostname"

#######################################################
# Check deps

[[ -z $HWC ]] && die "util-linux is no found, plz install"
[[ -z $HOSTNAME ]] && die "command hostname is no found"
[[ -z $SYS ]] && die "systemd is no found, plz install"
[[ -z $IP ]] && die "iproute2 is no found, plz install"
[[ -z $TOR ]] && die "tor is no found, plz install"

checkArgConfig $1 $2
CONF="$2"
checkRoot

#######################################################
# Randomize the link /etc/localtime from systemd

randTimezone() {
  local rand1 old
  old=$(file $LOCALTIME | awk '{print $5}')
  rand1="${timezone_dir[RANDOM % ${#timezone_dir[@]}]}"
  [[ -s $LOCALTIME ]] && rm $LOCALTIME
  ln -s $rand1 $LOCALTIME
  ${HWC} --systohc || die "hwclock fail"
  echo "[+] Changed timezone ${old##*/} from ${rand1##*/}"
}

#######################################################
# Randomize the hostname

randHost() {
  local rand_what rand_word rand_keyword new all
  all=( "prefix" "suffix" )
  rand_word=$($TR -dc 'a-z0-9' < /dev/urandom | $HEAD -c 10)
  if [[ $prefix_hostname ]] && [[ -z $suffix_hostname ]] ; then
    rand_what="prefix"
  elif [[ -z $prefix_hostname ]] && [[ $suffix_hostname ]] ; then
    rand_what="suffix"
  else
    rand_what="${all[RANDOM % ${#all[@]}]}"
  fi
  if [[ $prefix_hostname ]] || [[ $suffix_hostname ]] ; then
    if [[ $rand_what == "prefix" ]] && [[ ! -z $prefix_hostname ]] ; then
      rand_keyword="${prefix_hostname[RANDOM % ${#prefix_hostname[@]}]}"
      new="$rand_keyword$rand_word"
      #echo "[+] hostname - apply prefix ... $new"
    else
      rand_keyword="${suffix_hostname[RANDOM % ${#suffix_hostname[@]}]}"
      new="$rand_word$rand_keyword"
      #echo "[+] hostname - apply suffix ... $new"
    fi
  else
    new="$rand_word"
    #echo "[+] hostname - no suffix or prefix so $new"
  fi
  echo "[+] Apply a new hostname $new"
  writeHost $new
  $HOSTNAME $new || die "hostname fail"
}

#######################################################
# Randomize the MAC address

changeMac() {
  local mac old lastfive firstbyte
  $IP link show $net_device > /dev/null 2>&1
  if [ $? -eq 0 ] ; then
    if [[ $static_mac ]] && [[ $static_mac == "random" ]] ; then
      old=$($IP link show $net_device | grep -i ether | awk '{print $2}')
      mac=$(echo -n ""; $DD bs=1 count=1 if=/dev/urandom 2>/dev/null | $HEXDUMP -v -e '/1 "%02X"')
      mac+=$(echo -n ""; $DD bs=1 count=5 if=/dev/urandom 2>/dev/null | $HEXDUMP -v -e '/1 ":%02X"')
      # Get solution here to create a valid MAC address:
      # https://unix.stackexchange.com/questions/279910/how-go-generate-a-valid-and-random-mac-address
      lastfive=$( echo "$mac" | cut -d: -f 2-6 )
      firstbyte=$( echo "$mac" | cut -d: -f 1 )
      firstbyte=$( printf '%02X' $(( 0x$firstbyte & 254 | 2)) )
      mac="$firstbyte:$lastfive"
    else
      mac="$static_mac"
    fi
    $IP link set dev $net_device down
    sleep 1
    $IP link set dev $net_device address $mac
    $IP link set dev $net_device up
    sleep 1
    echo "[+] Changed MAC $old to $mac"
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

  if [[ $static_ip ]] && [[ $static_ip == "random" ]] ; then
    randnb=$(rand)
  elif [[ $static_ip ]] ; then
    new_ip=$static_ip/${network#*/}
    echo "[*] configure addr with $static_ip"
  else
    echo "[Err] no value found from paranoid.conf"
    exit 1
  fi

  [[ -z $new_ip ]] && new_ip=${target_router%.*}.$randnb/${network#*/}

  valid=$($IPCALC $new_ip | grep -i invalid)
  if [[ -z $valid ]] ; then
    #echo "Router is $target_router/${network#*/}"
    echo "[+] Apply your new IP addr: $new_ip"
    $IP address flush dev $net_device
    sleep 1
    $IP addr add $new_ip broadcast $broad dev $net_device
    $IP route add default via $target_router dev $net_device
    # restart the firewall
    [[ $firewall == "nftables" ]] && . $LIB_DIR/nftables.sh -c $CONF
    [[ $firewall == "iptables" ]] && . $LIB_DIR/iptables.sh -c $CONF
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
  [[ $a == "hostname" ]] && randHost
  [[ $a == "timezone" ]] && randTimezone
  [[ $a == "priv_ip" ]] && updIp
done

echo "[*] Relaunch your web browser is recommended"
