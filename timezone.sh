#!/bin/sh

LOCALTIME=/etc/localtime
HWC=$(which hwclock)

OLD=$(ls -l $LOCALTIME | awk '{print $11}')

#######################################################
# Randomize the link /etc/localtime from systemd

randTimezone() {
  local loc rand1
  loc=(/usr/share/zoneinfo/*/*)
  rand1="${loc[RANDOM % ${#loc[@]}]}"
  [[ -s $LOCALTIME ]] && rm $LOCALTIME
  ln -s $rand1 $LOCALTIME
  echo "[*] Changed ${OLD##*/} from ${rand1##*/}"
}

#######################################################
# Update local timezone

updSys() {
  echo "[*] update time..."
  ${HWC} --systohc
}

#######################################################
# Main

randTimezone
updSys
