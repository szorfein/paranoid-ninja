#!/bin/sh

HWC=$(which hwclock)
HOSTNAME=$(which hostname)
XAUTH=$(which xauth)
CHOWN=$(which chown)

LOCALTIME=/etc/localtime
DIR=$(pwd)
BACKUP_FILES="/etc/hosts /etc/hostname"

die() {
  echo "[Err] $1"
  exit 1
}

#######################################################
# Check deps

[[ -z $HWC ]] && die "command hwclock no found"
[[ -z $HOSTNAME ]] && die "command hostname no found"
[[ -z $XAUTH ]] && die "command xauth no found"

#######################################################
# Local Functions

# forXorg, avoid error like display no found
# http://ubuntuhandbook.org/index.php/2016/06/change-hostname-ubuntu-16-04-without-restart/
forXorg() {
  local xorg_new xorg_old old_host rule x y z com user
  com="$XAUTH -f $xauthority_file"
  old_host=$1
  rule=$2
  user=$(echo ${auto%/*} | sed s:/home/::g)
  xorg_new="$($com list | grep $old_host | sed "$rule")"
  x=$(echo $xorg_new | awk '{print $1}')
  y=$(echo $xorg_new | awk '{print $2}')
  z=$(echo $xorg_new | awk '{print $3}')
  xorg_old="$($com list | grep $old_host | awk '{print $1}')"
  if [ -f $xauthority_file ] ; then
    echo "[*] changed hostname with xauth"

    # ex: xauth add "$ooo" MIT-MAGIC-COOKIE-1  240a406abe7fac0a35bbe1cb58e09c18
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
rldSSH() {
  local old_host file files rule
  old_host="$1"
  rule="$2"
  files=$(find $ssh_dir -type f | xargs grep $old_host | awk '{print $1}')
  echo "ssh file found $files"
  for file in ${files%:*} ; do
    sed -i "$rule" $file || die "sed in $file"
    echo "[*] change host in $file"
  done
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
  if [ $ssh_dir ] ; then
    rldSSH "$old" "$rule"
  fi
  forXorg "$old" "$rule"
}

backupFiles() {
  if [ $backup_dir ] ; then
    [[ ! -d $backup_dir ]] && mkdir -p $backup_dir
    for file in $BACKUP_FILES; do
      if [[ ! -f $backup_dir/${file##*/} ]] &&
        [[ ! -d $backup_dir/${file##*/} ]] ; then
        cp -a $file $backup_dir
        echo "[*] Backups $file to $backup_dir ..."
      fi
    done
  else
    echo "[*] backup_dir is unset from config file"
  fi
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
  if [ $hostname_keywords ] ; then
    r="${hostname_keywords[RANDOM % ${#hostname_keywords[@]}]}"
    new="$r-"
  fi
  rw=$(tr -dc 'a-z0-9' < /dev/urandom | head -c10)
  new+="$rw"
  echo "[*] Apply new hostname $new"
  writeHost $new
  $HOSTNAME $new || die "hostname fail"
}

#######################################################
# Command option

checkConf() {
  local relativ_path full_path
  relativ_path="$DIR/$1"
  full_path="$1"
  if [ -f $relativ_path ] ; then
    source "$relativ_path"
  elif [ -f $full_path ] ; then
    source "$full_path"
  else
    die "No config file found"
  fi
}

[[ "$#" -eq 0 ]] && echo "No config file found" && exit 1
while [ "$#" -gt 0 ] ; do
  case "$1" in
    -c | --config)
      checkConf $2
      shift
      ;;
    -- | -* | *)
      echo "No config file found"
      exit 1
      ;;
  esac
  shift
done

#######################################################
# Main

# Add ssh_dir to the backup list
[[ $ssh_dir ]] && BACKUP_FILES+=" $ssh_dir"

backupFiles
randTimezone
randHost

echo "[*] Relaunch your web browser is recommended"
