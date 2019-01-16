#!/bin/sh

# Dependencies: nftables, whois, bind-tools

die() {
  printf "${red}%s${white}%s${endc}\n" \
    "[Err]" " $1"
  exit 1
}

######################################################
# Check Nftables

NFT=$(which nft)
OUTPUT="/var/lib/nftables/rules-save"

[[ -z $NFT ]] && die "nftables no found, isn't install?"

######################################################
# Check Network dev and ip

# If fail, put your device up, e.g: eth0
IF=$(ip a | grep -i "state up" | head -n 1 | awk '{print $2}' | sed -e 's/://g')
# If fail, put your ip here, e.g: 192.168.1.2/24
INT_NET=$(ip a show $IF | grep inet | awk '{print $2}' | head -n 1)

[[ -z $IF ]] && die "Device network UP no found."
[[ -z $INT_NET ]] && die "Ip addr no found."

echo "[*] Found interface $IF and your ip $INT_NET"

######################################################
# Check Tor id

id -u debian-tor > /dev/null 2>&1
[[ $? -eq 0 ]] && tor_uid=$(id -u debian-tor)

id -u tor > /dev/null 2>&1
[[ $? -eq 0 ]] && tor_uid=$(id -u tor)

[[ -z $tor_uid ]] && die "tor_uid no found"
echo "[*] Found tor uid = $tor_uid"

#####################################################
# Load Tor variables from /etc/tor/torrc

readonly torrc="/etc/tor/torrc"

[[ ! -f $torrc ]] && die "$torrc no found, TOR isn't install ?"

# Tor transport
grep TransPort $torrc > /dev/null 2>&1
if [[ ! $? -eq 0 ]] ; then
  echo "[*] Add new TransPort 9040 to $torrc"
  echo "TransPort 9040 IsolateClientAddr IsolateClientProtocol IsolateDestAddr IsolateDestPort" >> $torrc
fi
readonly trans_port=$(grep TransPort $torrc | awk '{print $2}')

# Tor DNSPort
grep DNSPort $torrc > /dev/null 2>&1
if [[ ! $? -eq 0 ]] ; then
  echo "[*] Add new DNSPort 5353 to $torrc"
  echo "DNSPort 5353" >> $torrc
fi
readonly dns_port=$(grep DNSPort $torrc | awk '{print $2}')

# Tor VirtualAddrNetworkIPv4
grep VirtualAddrNetworkIPv4 $torrc > /dev/null 2>&1
if [[ ! $? -eq 0 ]] ; then
  echo "[*] Add VirtualAddrNetworkIPv4 10.192.0.0/10 to $torrc"
  echo "VirtualAddrNetworkIPv4 10.192.0.0/10" >> $torrc
fi
readonly virt_tor=$(grep VirtualAddrNetworkIPv4 $torrc | awk '{print $2}')

# non Tor addr
readonly non_tor="127.0.0.0/8 224.0.0.0/4 192.168.2.0/16"

# Just to be sure :)
[[ -z $trans_port ]] && die "No TransPort value found on $torrc"
[[ -z $dns_port ]] && die "No DNSPort value found on $torrc"
[[ -z $virt_tor ]] && die "No VirtualAddrNetworkIPv4 value found on $torrc"

#######################################################
# Process start

echo "[+] Flushing existing rules..."
$NFT flush ruleset

#######################################################
# Create necessary table|chain INPUT FORWARD OUTPUT

$NFT add table inet filter
$NFT add chain inet filter input { type filter hook input priority 0\; policy drop \; }
$NFT add chain inet filter forward { type filter hook forward priority 0 \; policy drop \; }
$NFT add chain inet filter output { type filter hook output priority 0\; policy drop \; }
# Add nat
$NFT add table nat
$NFT add chain nat prerouting { type nat hook prerouting priority 0 \; }
$NFT add chain nat postrouting { type nat hook postrouting priority 100 \; }
$NFT add chain nat output { type nat hook output priority 0 \; }

# Just a wrapper for inet (ipv4 & ipv6).
addInet() {
  $NFT add rule inet filter "$@"
}

########################################################
# INPUT CHAIN
echo "[+] Settings up INPUT chain..."
# tracking rules
addInet input ct state invalid log prefix \"DROP INVALID \"
addInet input ct state invalid drop
addInet input ct state established,related accept

# Anti spoofing
addInet input iif $IF ip saddr != $INT_NET log prefix \"SPOOFED PKT \"
addInet input iif $IF ip saddr != $INT_NET drop

# Accept rules
addInet input iif lo accept
addInet input iif $IF ip saddr 127.0.0.0/8 tcp dport 22 tcp flags syn ct state new accept
addInet input ip protocol icmp icmp type echo-request accept

# Default input log rule
addInet input iif != lo log prefix \"DROP \"

########################################################
# OUTPUT
echo "[+] Settings up OUTPUT chain..."
# Tracking rules
addInet output ct state invalid log prefix \"DROP INVALID \"
addInet output ct state invalid drop
addInet output ct state established,related accept

# Accept rules
addInet output oif lo accept
addInet output tcp dport 22 tcp flags syn ct state new counter accept 
# Torrent
addInet output oif $IF udp sport 6881-6890 counter accept
# Tor
addInet output skuid $tor_uid counter accept
addInet output ip daddr 127.0.0.1 tcp dport $trans_port "tcp flags & (fin|syn|rst|ack) == syn" counter accept
addInet output ip protocol icmp icmp type echo-request accept

# Default output log rule
addInet output oifname != lo log prefix \"DROP \"

########################################################
# FORWARD CHAIN
echo "[+] Settings up FORWARD chain..."
addInet forward ct state invalid log prefix \"FORWARD INVALID \"
addInet forward ct state invalid drop
addInet forward ct state established,related accept

# Anti-spoofing rules
addInet forward iif $IF ip saddr != $INT_NET log prefix \"SPOOFED PKT \"
addInet forward iif $IF ip saddr != $INT_NET drop

# Default output log rule
addInet forward iif != lo log prefix \"DROP \"

########################################################
# NAT CHAIN
echo "[+] Settings up NAT rules..."

# Transparent proxy with TOR 
# doc: https://trac.torproject.org/projects/tor/wiki/doc/TransparentProxy
$NFT add rule nat prerouting iifname != lo "tcp flags & (fin|syn|rst|ack) == syn" counter redirect to $trans_port
$NFT add rule nat prerouting udp dport 53 counter redirect to $dns_port
$NFT add rule nat prerouting tcp dport 53 counter redirect to $dns_port
$NFT add rule nat output counter ip protocol tcp ip daddr $virt_tor redirect to $trans_port
$NFT add rule nat output counter ip protocol udp ip daddr $virt_tor redirect to $trans_port
# Do not torrify torrent
$NFT add rule nat output oif $IF udp sport 6881-6890 counter return
# Don't nat the tor process on local network
$NFT add rule nat output oifname lo counter return
$NFT add rule nat output skuid $tor_uid counter return
# Redirect all other output to TOR
$NFT add rule nat output counter "tcp flags & (fin|syn|rst|ack) == syn" counter redirect to $trans_port
$NFT add rule nat output counter ip protocol icmp redirect to $trans_port
$NFT add rule nat output counter ip protocol udp redirect to $trans_port

# allow lan access
for lan in $non_tor; do
  $NFT add rule nat prerouting ip daddr $lan counter return
done

# Default nat log rule
$NFT add rule nat output oifname != lo log prefix \"NAT DROP \"

########################################################
# BLOCK IPS
echo "[+] Settings up blocking IPS..."

$NFT list ruleset > /tmp/nftables_save
echo "[+] Rules saved to /tmp/nftables_save"
echo "[+] done"
exit 0
