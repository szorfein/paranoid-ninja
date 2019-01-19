#!/bin/sh

DIR="$(pwd)"
readonly prog_name="$0"

FUNCS="$DIR/src/functions"
source "${FUNCS-:/etc/paranoid/functions}"
CONF_FILE=${DIR/paranoid.conf}

######################################################
# Colors

red=$'\e[0;91m'
green=$'\e[0;92m'
blue=$'\e[0;94m'
white=$'\e[0;97m'
bold_white=$'\e[1;97m'
cyan=$'\e[0;96m'
endc=$'\e[0m'

######################################################
# Banner

banner() {
  printf "${red}%s${endc}\n" \
    '
  88888b. 88888888b.  8888 8888b.
  888 "88b888888 "88b "888    "88b
  888  888888888  888  888.d888888
  888  888888888  888  888888  888
  888  888888888  888  888"Y888888
                     888
                    d88P
                  888
  '
}

######################################################
# Kernel

kernel() {
  . $DIR/kernel.sh -a "$KERNEL" -c $CONF
}

######################################################
# Firewall

firewall() {
  if [ $FIREWALL == "nftables" ] ; then 
    . $DIR/nftables.sh -c $CONF
  elif [ $FIREWALL == "iptables" ] ; then
    die "Not available for now"
  else
    die "Not a valid firewall"
  fi
}

######################################################
# Randomize

randomize() {
  . $DIR/randomize.sh -c $CONF
}

######################################################
# Systemd

systemd() {
  . $DIR/systemd.sh
}

######################################################
# Show menu

menu() {
  printf "${green}%s${endc}\n" \
    "-k, --kernel    Apply [FEAT] to your kernel source. Default is /usr/src/linux"
  echo "usage: $0 [-k FEAT] [-c paranoid.conf]"

  printf "${green}%s${endc}\\n" \
    "-t, --transparent-tor    Transparent-torrify on nftables"
  echo "usage: $0 [-t nftables] [-c paranoid.conf]"

  printf "${green}%s${endc}\\n" \
    "-r, --randomize    Can randomize host, ip, timezone and mac address"
  echo "usage: $0 [-r] [-c CONF]"

  printf "${green}%s${endc}\\n" \
    "-c, --config    Apply your config file, required for some commands"
  echo "usage: $0 [-c PATH]"

  printf "${green}%s${endc}\\n" \
    "-s, --systemd    Install systemd script"
  echo "usage: $0 [-s]"

  printf "${green}%s\n%s\n%s${endc}\n" \
    "----------------------------" \
    "[FEAT] are into kernel/* (harden, nftables)"
}

######################################################
# Command options

if [ "$#" -eq 0 ]; then
    printf "%s\\n" "$prog_name: Argument required"
    printf "%s\\n" "Try '$prog_name --help' for more information."
    exit 1
fi

banner

while [ "$#" -gt 0 ] ; do
  case "$1" in
    -k | --kernel)
      KERNEL="$2"
      shift
      shift
      ;;
    -t | --transparent-proxy)
      FIREWALL=$2
      shift
      shift
      ;;
    -s | --systemd)
      systemd
      shift
      ;;
    -r | --randomize)
      RAND=true
      shift
      ;;
    -c | --config)
      CONF="$2"
      shift
      shift
      ;;
    -v | --version)
      echo "print_version"
      shift
      ;;
    -h | --help)
      menu
      shift
      ;;
    *)
      printf "%s\\n" "$prog_name: Invalid option '$1'"
      printf "%s\\n" "Try '$prog_name --help' for more information."
      exit 1
      ;;
  esac
done

if [[ $KERNEL ]] && [[ $CONF ]] ; then
  kernel
fi

if [[ $FIREWALL ]] && [[ $CONF ]] ; then
  firewall
fi

if [[ $RAND ]] && [[ $CONF ]] ; then
  randomize
fi
