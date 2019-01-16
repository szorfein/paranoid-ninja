#!/bin/sh

FILE="$1.txt"
DIR=/usr/src/linux-4.19.9-gentoo/
#DIR=/usr/src/linux
CONF=$DIR/.config
OLD=$(pwd)

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
  local s clean q rule old
  s=$1
  clean=${s%=*}
  q=${s#*=}
  old=$(grep -ie "$clean" $CONF | head -n 1)
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
  sed -i "$rule" $CONF || die "sed $rule on $s"
  printf "${cyan}%s${white}%s${endc}" \
    "[OK]" " new rule apply $1"
  updConf
}

chkOption() {
  local s clean q not_set is_void
  s=$1
  clean=${s%=*}
  q=${s#*=}
  not_set=$(grep -iE "^# $clean is not set" $CONF)
  is_void=$(grep -i $clean $CONF)
  if grep $1 $CONF >/dev/null; then
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

# Apply src/sysctl.txt to /etc/sysctl.conf
addSysctl() {
  local s f clean sysl is_exist
  f=/etc/sysctl.conf
  [[ ! -f $f ]] && die "file $f no found"
  echo -e "\n[*] Check $f..."
  for sysl in $(grep -iE "^[a-z]" $OLD/src/sysctl.txt); do
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

check_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    printf "\\n${red}%s${endc}\\n" \
      "[ failed ] Please run this program as a root!" 2>&1
    exit 1
  fi
}

check_root

# Check arg
[[ ! -f src/$FILE ]] && die "config not available"

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
for config in $(grep -ie "^config" $OLD/src/$FILE) ; do
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

# clean work
#echo -e "\n[*] Clean kernel config." 
#make mrproper >/dev/null

echo -e "\n[*] $FILE has beed apply :)." 
exit 0
