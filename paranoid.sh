#!/bin/sh

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

menu() {
  banner

  printf "${green}%s${endc}\\n" \
    "-b, --restore-backup    Restore your files"
  echo "usage: $0 [-b] [-c paranoid.conf]"

  printf "${green}%s${endc}\\n" \
    "-p, --transparent-tor    Transparent-torrify on nftables or iptables"
  echo "usage: $0 [-p] [-c paranoid.conf]"

  printf "${green}%s${endc}\\n" \
    "-H, --hostname    Make a random hostname"
  echo "usage: $0 [-h] [-c paranoid.conf]"

  printf "${green}%s${endc}\\n" \
    "-i, --ip    Make a random private ip based on your target router, work like dhcpcd but random :)"
  echo "usage: $0 [-i] [-c paranoid.conf]"

  printf "${green}%s${endc}\\n" \
    "-m, --mac    Make a random mac address"
  echo "usage: $0 [-m] [-c paranoid.conf]"

  printf "${green}%s${endc}\\n" \
    "-t, --timezone    Choose a random timezone, look at /usr/share/zoneinfo"
  echo "usage: $0 [-t] [-c paranoid.conf]"

  printf "${green}%s${endc}\\n" \
    "-D, --disable-transparent-proxy    Just remove the transparent-proxy throught tor"
  echo "usage: $0 [-t] [-c paranoid.conf]"

  printf "${green}%s${endc}\\n" \
    "-c, --config    Apply your config file, required for all commands"
  echo "usage: $0 [-c paranoid.conf]"

  printf "${green}%s${endc}\\n" \
    "-s, --status    Check if tor running and look infos on your ip"
  echo "usage: $0 [-s]"

  printf "${green}%s${endc}\\n" \
    "-d, --verbose    Display more informations to debug"
  echo "usage: $0 [-d]"

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

if [ ! -f $CONF ] ; then
  die "config file no found"
fi

randomize
if $FIREWALL ; then firewall ; fi
if $BACKUP ; then useBackup ; fi
if $STOP ; then stopFirewall ; fi

if $RESTART ; then restartDaemons ; fi

#sshuttle -r yagdra@localhost 0/0 -e "ssh -i /root/.ssh/id_ed25519" &
#testTor
