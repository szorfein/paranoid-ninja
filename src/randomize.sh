#!/usr/bin/env bash

set -ue

BACKUP_FILES="/etc/hosts /etc/hostname"

checkRoot

#######################################################
# Randomize the link /etc/localtime from systemd
# from paranoid.conf, need $zoneinfo_dir , $timezone_dir

monthName() {
  case ${1#0} in 
    Jan*) echo 01 ;;
    Feb*) echo 02 ;;
    Mar*) echo 03 ;;
    Apr*) echo 04 ;;
    May*) echo 05 ;;
    Jun*) echo 06 ;;
    Jul*) echo 07 ;;
    Aug*) echo 08 ;;
    Sep*) echo 09 ;;
    Oct*) echo 10 ;;
    Nov*) echo 11 ;;
    Dec*) echo 12 ;;
    *) return 5 ;;
  esac
}

# split format like "Sunday, August 18, 2019, week 33" 
splitDate() {
  oldIFS=$IFS # save older value
  IFS=', ' # new separator field
  set -- $1 # split $1
  IFS=$oldIFS # restore old value of IFS
  dayname="${1#0}"
  month="$(monthName ${2#0})"
  day="${3#0}"
  year="${4#0}"
}

checkTimeAndDate() {
  if ! time=$(cat /tmp/time-$PID.html | grep "[0-9]*:[0-9]*:[0-9]*" -o) ; then
    die "Time no found"
  fi

  if date="$(cat /tmp/time-$PID.html | grep -io "[a-z]*, [a-z]* [0-9]*, [0-9]*, [a-z]* [0-9]*")" ; then
    splitDate "$date"
    # date $month$day$(echo ${time%:*} | tr -d :)$year , old date format MMDDHHMMYEAR
    timedatectl set-time "$year-$month-$day $time"
    log "Set time of $city $year-$month-$day $time"
  else 
    die "Date no found"
  fi
}

savePage() {
  PID=$$ 
  if [ $(ls /tmp/time-* | wc -l) -gt 5 ] ; then rm /tmp/time-* ; fi
  wget --quiet --https-only --no-cookies --user-agent="Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.0.3) Gecko/2008092416 Firefox/3.0.3" \
    https://time.is/${city-:Paris} -O /tmp/time-$PID.html || 
    die "Can't download https://time.is/${city}..."
  [ -f /tmp/time-$PID.html ] || die "Problem with wget, /tmp/time-$PID.html is no found"
}

setTheTimezone() {
  if [ -f $zoneinfo_dir/$country/$city ] ; then
    timedatectl set-timezone "$country/$city"
    log "Set timezone $country/$city"
  else
    die "Timezone $country/$city is no found"
  fi
}

genRandTimezone() {
  t_cut="${timezone_dir[RANDOM % ${#timezone_dir[@]}]}"
  t_cut="${t_cut#/*/*/*/*}"
  country=${t_cut%/*}
  city=${t_cut#*/}
  t_cut=
}

genTimezoneWithIp() {
  if timezone=$(curl -s https://freegeoip.app/json/) ; then
    t_cut=$(echo $timezone | jq '.time_zone' | tr -d \")
    country=${t_cut%/*}
    city=${t_cut#*/}
  else
    die "No found timezone on freegeoip.app"
  fi
  t_cut=
}

selectATimezone() {
  if testPing ; then
    log "Network work, check timezone based on your ip..."
    genTimezoneWithIp
    setTheTimezone
    savePage # for the time and date
    checkTimeAndDate
  else
    log "Network doesn't work, build a random timezone..."
    genRandTimezone
    setTheTimezone
  fi
}

updTimezone() {
  title "Change timezone"
  checkBins wget jq timedatectl
  [ -d $zoneinfo_dir ] || die "zoneinfo dir no found at $zoneinfo_dir"
  selectATimezone
}

#######################################################
# Randomize the hostname
# from paranoid.conf, need $prefix_hostname, $suffix_hostname , $paranoid_user
# $paranoid_home , $other_host_files , $xauthority_file , $ssh_dir

# Write the new hostname in file from $other_host_files
otherHostFiles() {
  echo -n "[+] Update other files..."
  if [ -n $other_host_files ] ; then
    for f in $other_host_files ; do
      applySed $f $1 $new_host
    done
  fi
  echo " done"
}

setXauth() {
  $XAUTH_COM add "$1" $2 $3
  $XAUTH_COM remove "$4"
  chown $paranoid_user:$paranoid_user $xauthority_file
  XAUTH_COM=
}

splitXauth() {
  dpy=$($XAUTH_COM list | grep $ifarg | awk '{print $1}')
  proto=$($XAUTH_COM list | grep $ifarg | awk '{print $2}')
  hexkey=$($XAUTH_COM list | grep $ifarg | awk '{print $3}')
  if [ -z $dpy ] || [ -z $proto ] || [ -z $hexkey ] ; then
    # fallback if fail to detect the old hostname
    dpy=$($XAUTH_COM list | head -n 1 | awk '{print $1}')
    proto=$($XAUTH_COM list | head -n 1 | awk '{print $2}')
    hexkey=$($XAUTH_COM list | head -n 1 | awk '{print $3}')
  fi
}

checkXauth() {
  local new_dpy
  ifarg="${1:-unix}"
  splitXauth
  if new_dpy="$(echo $dpy | sed s:${dpy%/*}:$new_host:g)" ; then
    setXauth "$new_dpy" "$proto" "$hexkey" "$dpy"
  else
    die "xauth fail"
  fi
  ifarg= dpy= proto= hexkey=
}

updForXorg() {
  local if_one old_host 
  checkBins xauth
  [ -f $xauthority_file ] || die "paranoid.conf : xauthority_file=$xauthority_file no found."
  XAUTH_COM="xauth -f $xauthority_file"
  if_one=$($XAUTH_COM list | wc -l)
  old_host="$1"
  echo -n "[+] Update Xauth..."
  if [[ $if_one == 1 ]] ; then
    #echo "[+] xauth - changing the single entry..."
    checkXauth
  elif [[ $old_host ]] ; then
    #echo "[+] xauth - there is more than one entry, check with $old_host"
    checkXauth "$old_host"
  else
    die "xauth - unable to change the hostname $old_host"
  fi
  echo " done."
}

# exec if ssh_dir is set from conf file.
updSshKey() {
  local old
  old=$(grep $paranoid_user $1 | awk '{print $3}')
  if grep -q $paranoid_user $1 ; then
    #echo "[+] ssh - changed $paranoid_user@$new_host at $1..."
    applySed $1 $old "$paranoid_user@$new_host"
  else
    #echo "[+] ssh - changed $new_host at $1..."
    applySed $1 $2 $new_host
  fi
}

forSsh() {
  local file pub_key if_pub_key
  file="$(find $ssh_dir -type f | xargs grep $paranoid_user | awk '{print $1}')"
  pub_key="$(grep $paranoid_user $ssh_dir/authorized_keys | awk '{print $2}')"
  echo -n "[+] Update ssh keys..."
  for f in $file ; do
    updSshKey ${f%%:*}
  done
  if [[ $pub_key ]] && if_pub_key=$(grep ${pub_key:0:20} $ssh_dir/known_hosts | awk '{print $1}' | head -n 1) ; then
    #echo "[*] ssh - found a old hostname in $ssh_dir/known_hosts"
    updSshKey $ssh_dir/known_hosts $if_pub_key
  fi
  echo " done."
}

# Write new value of hostname in multiple files
writeHost() {
  old="$(cat /etc/hostname | head -n 1)"
  for f in /etc/hostname /etc/hosts ; do
    applySed $f $old $new_host
  done
  if [ -d $ssh_dir ] ; then forSsh ; else
    log "paranoid.conf : ssh_dir=$ssh_dir is no found..." 
  fi
  if pgrep -x Xorg >/dev/null ; then updForXorg "$old" ; fi
  otherHostFiles $old
  hostnamectl set-hostname $new_host
  old=
}

rand_prefix_suffix() {
  if [ -z $prefix_hostname ] && [ -z $suffix_hostname ] ; then
    rand_what="none"
  elif [ -n $prefix_hostname ] && [ -z $suffix_hostname ] ; then
    rand_what="prefix"
  elif [ -z $prefix_hostname ] && [ -n $suffix_hostname ] ; then
    rand_what="suffix"
  else
    all=( "prefix" "suffix" )
    rand_what="${all[RANDOM % ${#all[@]}]}"
    all=
  fi
}

randHost() {
  rand_word=$(tr -dc 'a-z0-9' < /dev/urandom | head -c 10)
  rand_prefix_suffix
  case $rand_what in
    none) : "$rand_word" ;;
    prefix)
      rand_keyword="${prefix_hostname[RANDOM % ${#prefix_hostname[@]}]}"
      : "$rand_keyword$rand_word"
      ;;
    suffix)
      rand_keyword="${suffix_hostname[RANDOM % ${#suffix_hostname[@]}]}"
      : "$rand_word$rand_keyword"
      ;;
    *) die "Unknown value rand_word=$rand_what" ;; 
  esac
  new_host="$_"
  log "Apply a new hostname $new_host..."
  writeHost 
  rand_what= rand_word= rand_keyword=
}

checkHostnameConf() {
  [ -d /home/$paranoid_user ] ||
    die "paranoid.conf : paranoid_user=$paranoid_user, /home/$paranoid_user is no found"
  }

updHost() {
  title "Change hostname"
  checkBins ssh hexdump hostnamectl
  checkHostnameConf
  randHost
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
}

setDhcp() {
  sleep 1
  dhcpcd -S domain_name_servers=127.0.0.1 $net_device 2> /dev/null
  sleep 2
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
    -h | --hostname ) updHost ; shift ;;
    -i | --ip ) updIp ; shift ;;
    -m | --mac ) updMac ; shift ;;
    -t | --timezone ) updTimezone ; shift ;;
    *) die "Unknown arg $1" ;;
  esac
done
