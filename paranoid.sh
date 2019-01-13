#!/bin/sh

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

######################################################
# Firewall

######################################################
# Show menu
menu() {
  printf "${green}%s${endc}\n" \
    "-k, --kernel    Add [FEAT] to your kernel"

  printf "${green}%s${endc}\\n" \
    "-t, --transparent-proxy    Transparent-proxy|TOR on [PROXY]"

  printf "${green}%s\n%s\n%s${endc}\n" \
    "----------------------------" \
    "[FEAT] are harden,nftable" \
    "[PROXY] are nftables"

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
