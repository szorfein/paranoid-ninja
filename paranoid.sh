#!/bin/sh

STOP=false
STATUS=false

# Bins
NFT=$(which nft)
IPT_RES=$(which iptables-restore)
XAUTH=$(which xauth)
CHOWN=$(which chown)
HOSTNAME=$(which hostname)
SYSTEMCTL=$(which systemctl)

DIR="$(pwd)"
readonly prog_name="$0"

if [ -f /lib/paranoid-ninja/functions ] ; then
  FUNCS="/lib/paranoid-ninja/functions"
elif [ -f $DIR/src/functions ] ; then
  FUNCS="$DIR/src/functions"
else
  echo "Function no found..."
  exit 1
fi

source $FUNCS
loadEnv

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
  #printf "${red}%s${endc}\n" \
cat << EOF

$endc                     ########                  #
                 #################            #
              ######################         #
             #########################      #
           ############################
          ##############################
          ###############################
         ###############################
         ##############################
                         #    ########   #
             $red##$endc        $red###$endc       ####   ##
                                 ###   ###
                               ####   ###
          ####          ##########   ####
          #######################   ####
            ####################   ####
             ##################  ####
               ############      ##
                  ########        ###
                 #########        #####
               ############      ######
              ########      #########
                #####       ########
                  ###       #########
                 ######    ############
                #######################
                #   #   ###  #   #   ##
                ########################
                 ##     ##   ##     ##

EOF
}

######################################################
# Firewall

firewall() {
  if [[ $firewall == "nftables" ]] ; then 
    . $LIB_DIR/nftables.sh -c $CONF
  elif [[ $firewall == "iptables" ]] ; then
    . $LIB_DIR/iptables.sh -c $CONF
  else
    die "$firewall Not a valid firewall"
  fi
  loadTor
  testTor
}

######################################################
# Randomize

randomize() {
  . $LIB_DIR/randomize.sh -c $CONF
  loadTor
  testTor
}

######################################################
# Stop

stopParanoid() {
  local hostname
  hostname="$(cat $BACKUP_DIR/hostname | head -n 1)"
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
  loadTor
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
    "-c, --config    Apply your config file, required for all commands"
  echo "usage: $0 [-c paranoid.conf]"

  printf "${green}%s${endc}\\n" \
    "-s, --status    Check if tor running and look infos on your ip"
  echo "usage: $0 [-s]"

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
    -s | --status)
      STATUS=true
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

if [[ $STOP == true ]] && [[ $CONF ]] ; then
  stopParanoid
fi

if [[ $STATUS == true ]] ; then
  testTor
fi
