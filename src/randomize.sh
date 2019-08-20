#!/bin/sh

# Bins
HWC=$(which hwclock)
HOSTNAME=$(which hostname)
XAUTH=$(which xauth)
CHOWN=$(which chown)
SYS=$(which systemctl)
HEXDUMP=$(which hexdump)
TR=$(which tr)
HEAD=$(which head)

LOCALTIME=/etc/localtime
BACKUP_FILES="/etc/hosts /etc/hostname"

#######################################################
# Check deps

[[ -z $HWC ]] && die "util-linux is no found, plz install"
[[ -z $HOSTNAME ]] && die "command hostname is no found"
[[ -z $SYS ]] && die "systemd is no found, plz install"

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
# from paranoid.conf, need variable $net_device , $static_mac

setMac() {
  ip link set dev $net_device down
  sleep 1
  ip link set dev $net_device address $mac
  ip link set dev $net_device up
  sleep 1
  log "Changed MAC $old to $mac"
  old= mac=
}

changeMac() {
  local lastfive firstbyte
  if [[ $static_mac == "random" ]] ; then
    old=$(ip link show $net_device | grep -i ether | awk '{print $2}')
    mac=$(echo -n ""; dd bs=1 count=1 if=/dev/urandom 2>/dev/null | hexdump -v -e '/1 "%02X"')
    mac+=$(echo -n ""; dd bs=1 count=5 if=/dev/urandom 2>/dev/null | hexdump -v -e '/1 ":%02X"')
    # Get solution here to create a valid MAC address:
    # https://unix.stackexchange.com/questions/279910/how-go-generate-a-valid-and-random-mac-address
    lastfive=$( echo "$mac" | cut -d: -f 2-6 )
    firstbyte=$( echo "$mac" | cut -d: -f 1 )
    firstbyte=$( printf '%02X' $(( 0x$firstbyte & 254 | 2)) )
    mac="$firstbyte:$lastfive"
  else
    mac="$static_mac"
  fi
  setMac
}

checkMacConf() {
  ctrl_net_device
  ctrl_static_mac
}

updMac() {
  title "Change MAC"
  checkMacConf
  checkBins ip dd hexdump
  changeMac
}

#######################################################
# Update the network address
# from paranoid.conf, need variable $target_router, $static_ip, $net_device

rand() {
  max=$(ipcalc $target_router | grep -i hostmax | awk '{print $2}')
  min=$(ipcalc $target_router | grep -i hostmin | awk '{print $2}')
  min=${min##*.}
  range="$(( min + 1 ))-${max##*.}"
  nb=$(shuf -i $range -n 1)
  echo $nb
  max= min= range= nb=
}

checkNetworkConf() {
  isValidAddress $target_router
  ctrl_net_device
  checkRoot
}

setDhcp() {
  sleep 1
  dhcpcd $net_device 2> /dev/null
  log "dhcpd is setup."
}

staticOrRand() {
  if [ $static_ip == "random" ] ; then
    randnb=$(rand)
    new_ip=${target_router%.*}.$randnb/${network#*/}
    log "Configure a random ip addr with $randnb -> $new_ip"
  elif isValidAddress $static_ip ; then
    new_ip=$static_ip/${network#*/}
    log "Configure a static ip addr with $static_ip -> $new_ip"
  else
    die "Error in change_ip() , network:$network , broad:$broad , static_ip:$static_ip"
  fi
}

setIp() {
  if isValidAddress $new_ip ; then
    ip address flush dev $net_device
    sleep 1
    ip addr add $new_ip broadcast $broad dev $net_device
    ip route add default via $target_router dev $net_device
    log "Ip Address has been changed"
  else
    die "The address $new_ip is incorrect, target_router:$target_router , new_ip:$new_ip"
  fi
}

changeIp() {
  if [ $static_ip == "dhcp" ] ; then
    checkBins dhcpcd
    setDhcp
  else
    checkBins ipcalc shuf ip
    network="$(ipcalc $target_router | grep -i network | awk '{print $2}')"
    broad="$(ipcalc $target_router | grep -i broadcast | awk '{print $2}')"
    staticOrRand
    setIp
  fi
}

updIp() {
  title "Change ip"
  checkNetworkConf
  killDhcp
  changeIp
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

while [ "$#" -gt 0 ] ; do
  case "$1" in
    -c | --conf ) CONF=${2:-/etc/paranoid-ninja/paranoid.conf} ; shift ; shift ;;
    -h | --hostname ) randHost ; shift ;;
    -i | --ip ) updIp ; shift ;;
    -m | --mac ) updMac ; shift ;;
    -t | --timezone ) randTimezone ; shift ;;
    *) die "Unknown arg $1" ;;
  esac
done
