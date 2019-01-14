#!/bin/sh

DIR=/usr/src/linux
CONF=$DIR/.config
OLD=$(pwd)
#CONF=/usr/src/linux/.config
#CONF=~/ttt

# colors
red=$'\e[0;91m'
cyan=$'\e[0;96m'
white=$'\e[0;97m'
endc=$'\e[0m'

die() {
  printf "${red}%s${white}%s${endc}\n" \
    "[Err]" " $1"
  exit 1
}

# update config after apply a rule
updConf() {
  echo -e "\n[*] Update kernel .config..." 
  make olddefconfig >/dev/null ||\
    die "update conf failed"
}

# Return the regex for the sed command from applyRule()
retRule() {
  local s clean o rule old
  s=$1
  clean=${s%=*}
  o=${s#*=}
  old=$(grep -ie "$clean" $CONF | head -n 1)
  [[ -z $old ]] && die "Option '$s' no found"
  if [ $o == "n" ]; then
    rule="s:${old}:${clean}=n:g"
  elif [ $o == "y" ] ; then
    rule="s:${old}:${clean}=y:g"
  elif [ $o == "m" ] ; then
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
  sed -i "$rule" $CONF || die "sed $rule on $s"
  printf "${cyan}%s${white}%s${endc}" \
    "[OK]" " new rule apply $1"
  updConf
}

chkOption() {
  if grep $1 $CONF >/dev/null; then
    printf "${cyan}%s${white}%s${endc}\n" \
      "[OK]" " $1"
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

check_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    printf "\\n${red}%s${endc}\\n" \
      "[ failed ] Please run this program as a root!" 2>&1
    exit 1
  fi
}

check_root

# Check if /usr/src/linux exist
if [ ! -s /usr/src/linux ] ; then
  die "Link of /usr/src/linux no found, pls create one"
fi

cd $DIR

# Check .config
if [ ! -f $CONF ] ; then 
  echo "[*] Generate a base .config file"
  make defconfig >/dev/null || die "make defconfig not available"
fi

# Kernel options to check :)
for config in $(grep -ie "^config" $OLD/src/harden.txt) ; do
  chkOption "$config"
done

forIntel

# clean work
#echo -e "\n[*] Clean kernel config." 
#make mrproper >/dev/null

echo -e "\n[*] Your kernel is hardened." 
exit 0
