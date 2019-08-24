#!/usr/bin/env bash

set -ue

STOP=false
TOR=true
BACKUP=false
QUIET=false
FIREWALL=false
RESTART=false

R_HOST=false
R_IP=false
R_MAC=false
R_TIMEZONE=false

# Bins
IPT_RES=$(which iptables-restore)

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
    NFT=$(which nft)
    . $LIB_DIR/nftables.sh -c $CONF 
  elif [[ $firewall == "iptables" ]] ; then
    if ! $TOR ; then
      echo "paranoid-ninja, i disable tor : $TOR"
      . $LIB_DIR/iptables.sh -c $CONF --disable
    else
      echo "paranoid-ninja, i enable tor : $TOR"
      . $LIB_DIR/iptables.sh -c $CONF
    fi
  else
    die "$firewall Not a valid firewall"
  fi
  RESTART=true
  #loadTor
}

######################################################
# Randomize

randomize() {
  if $R_HOST ; then 
    log "$0 call randomize.sh --hostname"
    . $LIB_DIR/randomize.sh --conf $CONF --hostname
  fi
  if $R_MAC ; then
    log "$0 call randomize.sh --mac"
    . $LIB_DIR/randomize.sh --conf $CONF --mac
  fi
  if $R_TIMEZONE ; then
    log "$0 call randomize.sh --timezone"
    . $LIB_DIR/randomize.sh --conf $CONF --timezone
  fi
  if $R_IP ; then
    log "$0 call randomize.sh --ip"
    . $LIB_DIR/randomize.sh --conf $CONF --ip
    #RESTART=true
  fi
}

######################################################
# reload backup files

useBackup() {
  echo "$0 call useBackup , backup : $BACKUP"
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
  #loadTor
}

######################################################
# stop firewall

stopFirewall() {
  if [[ $firewall == "nftables" ]] ; then
    $NFT flush ruleset
  elif [[ $firewall == "iptables" ]] ; then
    clearIptables
  else
    die "$firewall is no valid"
  fi
  #loadTor
}

######################################################
# Show menu

doption() {
  printf "${green}%s\\t${white}%s${endc}\\n" "$1" "$2"
}

menu() {
  banner

  printf "${green}%s${endc}\\n" \
    "Usage: $0 [ OPTIONS ] [ -c PATH_CONFIG_FILE ]"

  echo -e "\nOPTIONS are: "
  doption "-b, --restore-backup" "Restore your files"
  doption "-p, --transparent-tor" "Apply a transparent-torrify on nftables or iptables"
  doption "-H, --hostname" "Make a random hostname, can use a custom prefix or suffix"
  doption "-i, --ip" "Can build your ip with dhcpcd, forge a random or a static"
  doption "-m, --mac" "Can build a fully random or static mac address"
  doption "-t, --timezone" "Can build a random timezone or check one based on your ip"
  doption "-D, --disable-transparent-proxy" "Just remove the transparent-proxy throught tor"
  doption "-s, --status" "Check if tor running and look infos on your ip"
  doption "-q, --quiet" "Delete messages when running and hide firewall logs too"
  doption "-h, --help" "Display this"

  exit 0
}

######################################################
# Command options

if [ "$#" -eq 0 ]; then
    printf "%s\\n" "$prog_name: Argument required"
    printf "%s\\n" "Try '$prog_name --help' for more information."
    exit 1
fi

while [ "$#" -gt 0 ] ; do
  case "$1" in
    -b | --restore-backup) BACKUP=true ; shift ;;
    -c | --config)
      CONF="$2"
      checkConfigFile "$2"
      shift
      shift
      ;;
    -H | --hostname) R_HOST=true ; shift ;;
    -i | --ip) R_IP=true ; shift ;;
    -m | --mac) R_MAC=true; shift ;;
    -p | --transparent-proxy) FIREWALL=true ; shift ;;
    -t | --timezone ) R_TIMEZONE=true ; shift ;;
    -s | --status) testTor ; shift ;;
    -D | --disable-transparent-proxy) TOR=false ; shift ;;
    -v | --version) echo "print_version" ; shift ;;
    -q | --quiet) QUIET=true ; shift ;;
    -h | --help) menu ; shift ;;
    *)
      printf "%s\\n" "$prog_name: Invalid option '$1'"
      printf "%s\\n" "Try '$prog_name --help' for more information."
      exit 1
      ;;
  esac
done

[ -f $CONF ] || die "config file no found"

bye() { printf "\n${green}%s${endc}\n" "$0 has finish, bye." ; }
trap bye EXIT

randomize
if $FIREWALL ; then firewall ; fi
if $BACKUP ; then useBackup ; fi
if $STOP ; then stopFirewall ; fi
if $RESTART ; then restartDaemons ; fi
