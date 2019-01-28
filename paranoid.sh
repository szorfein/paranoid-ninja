#!/bin/sh

STOP=false
NFT=$(which nft)
IPT_RES=$(which iptables-restore)
XAUTH=$(which xauth)
CHOWN=$(which chown)
HOSTNAME=$(which hostname)

DIR="$(pwd)"
readonly prog_name="$0"

FUNCS="${DIR}/src/functions"
source "${FUNCS-:/etc/paranoid/functions}"

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
# Firewall

firewall() {
  if [[ $firewall == "nftables" ]] ; then 
    . $DIR/nftables.sh -c $CONF
  elif [[ $firewall == "iptables" ]] ; then
    . $DIR/iptables.sh -c $CONF
  else
    die "$firewall Not a valid firewall"
  fi
  sleep 2
  testTor
}

######################################################
# Randomize

randomize() {
  . $DIR/randomize.sh -c $CONF
  testTor
}

######################################################
# Systemd

systemd() {
  . $DIR/systemd.sh -c $CONF
}

######################################################
# Stop

stopParanoid() {
  local hostname
  hostname="$(cat $backup_dir/hostname | head -n 1)"
  [[ ! -z $hostname ]] && writeHost $hostname
  restoreFiles
  if [[ $firewall == "nftables" ]] ; then
    echo "[+] restore old nftables rule"
    nftReload
  elif [[ $firewall == "iptables" ]] ; then
    echo "[+] restore old iptables rule"
    iptReload
  else
    echo "[-] no firewall $firewall found."
  fi
  systemctl restart tor
  sleep 1
  testTor
}

######################################################
# Show menu

menu() {
  printf "${green}%s${endc}\\n" \
    "-t, --transparent-tor    Transparent-torrify on nftables or iptables"
  echo "usage: $0 [-t] [-c paranoid.conf]"

  printf "${green}%s${endc}\\n" \
    "-r, --randomize    Can randomize host, ip, timezone and mac address"
  echo "usage: $0 [-r] [-c paranoid.conf]"

  printf "${green}%s${endc}\\n" \
    "-c, --config    Apply your config file, required for some commands"
  echo "usage: $0 [-c paranoid.conf]"

  printf "${green}%s${endc}\\n" \
    "-s, --systemd    Install systemd script"
  echo "usage: $0 [-s] [-c paranoid.conf]"

  printf "${green}%s${endc}\\n" \
    "-d, --delete    Stop and restore your files"
  echo "usage: $0 [-d] [-c paranoid.conf]"
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
    -t | --transparent-proxy)
      FIREWALL=true
      shift
      ;;
    -s | --systemd)
      SYSTEMD=true
      shift
      ;;
    -r | --randomize)
      RAND=true
      shift
      ;;
    -c | --config)
      CONF="$2"
      checkConfigFile "$2"
      shift
      shift
      ;;
    -d | --delete)
      STOP=true
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

if [[ $FIREWALL == true ]] && [[ $CONF ]] ; then
  firewall
fi

if [[ $RAND ]] && [[ $CONF ]] ; then
  randomize
fi

if [[ $SYSTEMD ]] && [[ $CONF ]] ; then
  systemd
fi

if [[ $STOP == true ]] && [[ $CONF ]] ; then
  stopParanoid
fi
