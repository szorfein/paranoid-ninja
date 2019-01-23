#!/bin/sh

#SOURCE_DIR=/usr/src/linux-4.19.9-gentoo
SOURCE_DIR="/usr/src/linux"
SOURCE_CONF="$SOURCE_DIR/.config"

DIR=$(pwd)
FUNCS="$DIR/src/functions"
source "${FUNCS-:/etc/paranoid/functions}"

FEATS="$DIR/kernel"
BACKUP_FILES="$SOURCE_CONF /etc/sysctl.conf /etc/default/grub"

# colors
red=$'\e[0;91m'
cyan=$'\e[0;96m'
white=$'\e[0;97m'
endc=$'\e[0m'

# update config after apply a rule
updConf() {
  echo -e "\n[*] Update kernel .config..." 
  make olddefconfig >/dev/null ||
    die "update conf failed"
}

# Return the regex for the sed command from applyRule()
retRule() {
  local s clean q rule old
  s=$1
  clean=${s%=*}
  q=${s#*=}
  old=$(grep -ie "$clean" $SOURCE_CONF | head -n 1)
  [[ -z $old ]] && return
  if [ $q == "n" ]; then
    rule="s:${old}:${clean}=n:g"
  elif [ $q == "y" ] ; then
    rule="s:${old}:${clean}=y:g"
  elif [ $q == "m" ] ; then
    rule="s:${old}:${clean}=m:g"
  else
    rule="s:${old}:${s}:g"
  fi
  echo "$rule"
}

applyRules() {
  local s rule
  s=$1
  rule=$(retRule $s)
  [[ -z $rule ]] && die "rule is void - $s"
  sed -i "$rule" $SOURCE_CONF || die "sed $rule on $s"
  printf "${cyan}%s${white}%s${endc}" \
    "[OK]" " new rule apply $1"
  updConf
}

chkOption() {
  local s clean q not_set is_void
  s=$1
  clean=${s%=*}
  q=${s#*=}
  not_set=$(grep -iE "^# $clean is not set" $SOURCE_CONF)
  is_void=$(grep -i $clean $SOURCE_CONF)
  if grep $1 $SOURCE_CONF >/dev/null; then
    printf "${cyan}%s${white}%s${endc}\n" "[OK]" " $1"
  elif [[ $q == n ]] && [[ $not_set ]] ; then
    printf "${cyan}%s${white}%s${endc}\n" "[OK]" " $1"
  elif [[ -z $is_void ]] ; then
    printf "${red}%s${endc}\n" "Option $s no found..."
  else
    applyRules $1
  fi
}

# Specific to intel
forIntel() {
  local cpu
  cpu=$(lscpu | grep -i intel | head -n 1)
  [[ -z $cpu ]] && return
  echo -e "\n[*] Add intel features." 
  chkOption "CONFIG_INTEL_IOMMU=y"
  chkOption "CONFIG_INTEL_IOMMU_SVM=y"
  chkOption "CONFIG_INTEL_IOMMU_DEFAULT_ON=y"
}

# Apply kernel/sysctl.txt to /etc/sysctl.conf
addSysctl() {
  local s f clean sysl is_exist
  f=/etc/sysctl.conf
  [[ ! -f $f ]] && die "file $f no found"
  echo -e "\n[*] Check $f..."
  for sysl in $(grep -iE "^[a-z]" $FEATS/sysctl.txt); do
    s=$(grep $sysl $f)
    clean=${sysl%=*}
    is_exist=$(grep $clean $f)
    if [[ -z $s ]] && [[ -z $is_exist ]]; then
      printf "${cyan}%s${white}%s${endc}\n" \
        "[OK]" " New rule $sysl added"
      echo $sysl >> $f
    elif [[ -z $s ]] && [[ $is_exist ]] ; then
      sed -i "s:${is_exist}:${sysl}:g" $f
      printf "${cyan}%s${white}%s${endc}\n" \
        "[OK]" "Changed rule $is_exist with $sysl"
    else
      printf "${cyan}%s${white}%s${endc}\n" \
        "[OK]" " $sysl"
    fi
  done
}

# Add kernel boot params to grub2
applyGrubCmdArgs() {
  local grub_conf line only_args
  grub_conf=/etc/default/grub
  line=$(grep -iE "^GRUB_CMDLINE_LINUX=" $grub_conf)
  only_args="${line#*=}"

  [[ -f $grub.conf ]] && die "$grub_conf no found"
  if [[ -z $line ]] ; then
    echo "option GRUB_CMDLINE_LINUX no found in $grub_conf"
    exit 1
  fi

  echo "[*] Check kernel boot params..."
  for opt in $(grep -ie "^[a-z]" $FEATS/grub.txt) ; do
    if_here=$(echo $line | grep -i $opt)
    if [[ -z $if_here ]] ; then
      echo "[*] Option lacked, apply additional value '$opt'"
      only_args+=" $opt"
    fi
  done

  only_args="GRUB_CMDLINE_LINUX=\"$(echo $only_args | sed "s:\"::g")\""
  echo "[*] Your line final is $only_args"

  sed -i "s:$line:$only_args:g" $grub_conf
}

#########################################################
# Command line parser

usage() {
  printf "Usage: %s [-a value] [-c paranoid.conf] args %s\n" $0 $1
  exit 0
}

while getopts ":a:c:vh" args ; do
  case "$args" in
    a ) FILE="$OPTARG.txt" ;;
    c ) config="$OPTARG" ;;
    v | h ) usage 1 ;;
    \? ) usage 2 ;;
  esac
done
shift $(( $OPTIND - 1 ))

if [[ -z $FILE ]] || [[ -z $config ]] ; then
  usage 3
fi

# Check arg
[[ ! -f $FEATS/$FILE ]] && die "config $FILE not available in $FEATS"

checkConfigFile $config

#########################################################
# Main

checkRoot
backupFiles "$BACKUP_FILES"

# Check if /usr/src/linux exist
# if your system do not have kernel source, just exit.
if [ ! -s /usr/src/linux ] ; then
  echo "[*] Link of /usr/src/linux no found, skip..."
  exit 0
else
  echo "[*] Patching kernel source at $SOURCE_DIR"
fi

cd $SOURCE_DIR

# Check if .config exist or generate a new
if [ ! -f $SOURCE_CONF ] ; then 
  echo "[*] Generate a base .config file"
  make defconfig >/dev/null || die "make defconfig not available"
fi

# Kernel options to check :)
for config in $(grep -ie "^config" $FEATS/$FILE) ; do
  chkOption "$config"
done

# Add special configs by CPU
if [ $FILE == "harden.txt" ] ; then
  forIntel
fi

# Add sysctl
if [[ $FILE == "harden.txt" ]] ||
  [[ $FILE == "sysctl.txt" ]] ; then
  addSysctl
fi

# Add grub2 cmdline
if [[ $FILE == "harden.txt" ]] ||
  [[ $FILE == "grub.txt" ]] ; then
  applyGrubCmdArgs
fi

# clean work
#echo -e "\n[*] Clean kernel config." 
#make mrproper >/dev/null

echo -e "\n[*] $FILE has beed apply" 
exit 0
