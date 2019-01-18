#!/bin/sh

DIR="$(pwd)"
readonly prog_name="$0"

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
  . $DIR/harden-kernel.sh $1
}

######################################################
# Firewall
firewall() {
  if [ $1 == "nftables" ] ; then 
    . $DIR/nftables.sh
  elif [ $1 == "iptables" ] ; then
    echo "Not available for now"
    exit 1
  else
    echo "Not a valid firewall"
    exit 1
  fi
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
    "-k, --kernel    Add [FEAT] to your kernel"

  printf "${green}%s${endc}\\n" \
    "-t, --transparent-tor    Transparent-tor on nftables or iptables"

  printf "${green}%s${endc}\\n" \
    "-s, --systemd    Install systemd script"

  printf "${green}%s\n%s\n%s${endc}\n" \
    "----------------------------" \
    "[FEAT] are harden, nftables, sysctl"

  printf "\n${white}%s${endc}\n" \
    "e.g: $prog_name -k harden OR $prog_name -t nftables"
}

######################################################
# Command options

if [ "$#" -eq 0 ]; then
    printf "%s\\n" "$prog_name: Argument required"
    printf "%s\\n" "Try '$prog_name --help' for more information."
    exit 1
fi

banner

while [ "$#" -gt 0 ]; do
  case "$1" in
    -k | --kernel)
      kernel $2
      shift
      ;;
    -t | --transparent-proxy)
      firewall $2
      shift
      ;;
    -s | --systemd)
      systemd
      exit 0
      ;;
    -v | --version)
      echo "print_version"
      ;;
    -h | --help)
      menu
      exit 0
      ;;
    -- | -* | *)
      printf "%s\\n" "$prog_name: Invalid option '$1'"
      printf "%s\\n" "Try '$prog_name --help' for more information."
      exit 1
      ;;
  esac
  shift
done
