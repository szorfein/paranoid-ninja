#!/usr/bin/env bash

set -ue

NFT=nft
BACKUP_FILES="/etc/tor/torrc /etc/resolv.conf"

######################################################
# Check Bins

checkBins ip systemctl nft
checkRoot

######################################################
# Command line parser

checkArgConfig $1 $2

######################################################
# Check Network dev and ip

#IF=$(ip a | grep -i "state up" | head -n 1 | awk '{print $2}' | sed -e 's/://g')
IF=$net_device
# If fail, put your ip here, e.g: 192.168.1.2/24
INT_NET=$(ip a show $IF | grep inet | awk '{print $2}' | head -n 1)

[[ -z $IF ]] && die "Device network UP no found."
[[ -z $INT_NET ]] && die "Ip addr no found."

echo "[*] Found interface $IF and your ip $INT_NET"

######################################################
# Check Tor id

tor_uid=$(searchTorUid)

#####################################################
# Backups your files

backupFiles "$BACKUP_FILES"

#######################################################
# docker

docker_v4=$docker_ipv4

#####################################################
# Load Tor variables from /etc/tor/torrc

readonly torrc="/etc/tor/torrc"

[ -f $torrc ] || die "$torrc no found, TOR isn't install ?"

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

# Tor AutomapHostsOnResolve 
grep AutomapHostsOnResolve $torrc > /dev/null 2>&1
if [[ ! $? -eq 0 ]] ; then
  echo "[*] Add new AutomapHostsOnResolve 1 to $torrc"
  echo "AutomapHostsOnResolve 1" >> $torrc
fi

# Tor VirtualAddrNetworkIPv4
grep VirtualAddrNetworkIPv4 $torrc > /dev/null 2>&1
if [[ ! $? -eq 0 ]] ; then
  echo "[*] Add VirtualAddrNetworkIPv4 10.192.0.0/10 to $torrc"
  echo "VirtualAddrNetworkIPv4 10.192.0.0/10" >> $torrc
fi
readonly virt_tor=$(grep VirtualAddrNetworkIPv4 $torrc | awk '{print $2}')

# non Tor addr
readonly non_tor="127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 $docker_v4 192.168.0.0/16 224.0.0.0/4"

# Just to be sure :)
[[ -z $trans_port ]] && die "No TransPort value found on $torrc"
[[ -z $dns_port ]] && die "No DNSPort value found on $torrc"
[[ -z $virt_tor ]] && die "No VirtualAddrNetworkIPv4 value found on $torrc"

#######################################################
# resolv.conf

echo "[+] Update /etc/resolv.conf"
cat > /etc/resolv.conf << EOF
nameserver 127.0.0.1
EOF

#######################################################
# Disable ipv6 

#sysctl -w net.ipv6.conf.all.disable_ipv6=1
#sysctl -w net.ipv6.conf.default.disable_ipv6=1

#######################################################
# Process start

echo "[+] Flushing existing rules..."
$NFT flush ruleset
sleep 2

#######################################################
# Create necessary table|chain INPUT FORWARD OUTPUT

$NFT add table inet filter
sleep 2
$NFT add chain inet filter input { type filter hook input priority 0\; policy drop \; }
$NFT add chain inet filter forward { type filter hook forward priority 0 \; policy drop \; }
$NFT add chain inet filter output { type filter hook output priority 0\; policy drop \; }
# Add nat
$NFT add table nat
sleep 2
$NFT add chain nat prerouting { type nat hook prerouting priority 0 \; }
$NFT add chain nat postrouting { type nat hook postrouting priority 100 \; }
$NFT add chain nat output { type nat hook output priority 0 \; }

# Just a wrapper for inet (ipv4 & ipv6).
addInet() {
  $NFT add rule inet filter "$@"
}

echo "[+] Setting up $firewall rules ..."

########################################################
# INPUT CHAIN

# tracking rules
if [ $firewall_quiet == "no" ] ; then
  addInet input ct state invalid log prefix \"DROP INVALID \"
fi

addInet input ct state invalid counter drop

if [ $docker_use == "yes" ] ; then
  addInet input ip saddr $docker_v4 accept
fi

addInet input ct state established,related counter accept

# Anti spoofing
if [ $firewall_quiet == "no" ] ; then
  addInet input iif $IF ip saddr != $INT_NET log prefix \"SPOOFED PKT \"
fi
addInet input iif $IF ip saddr != $INT_NET drop

# Accept rules
addInet input iifname lo counter accept
addInet input ip protocol icmp icmp type echo-request accept

# Default input log rule
if [ $firewall_quiet == "no" ] ; then
  addInet input iif != lo log prefix \"DROP \"
fi

########################################################
# OUTPUT

# Tracking rules
if [ $firewall_quiet == "no" ] ; then
  addInet output ct state invalid log prefix \"DROP INVALID \"
fi
addInet output ct state invalid counter drop

addInet output ct state established,related counter accept

# Allow Tor process output
addInet output oifname $IF skuid $tor_uid "tcp flags & (fin|syn|rst|ack) == syn" ct state new counter accept

# Allow loopback output
addInet output ip daddr 127.0.0.1/32 oifname lo counter accept

# Tor transproxy magic
addInet output ip daddr 127.0.0.1/32 tcp dport $trans_port "tcp flags & (fin|syn|rst|ack) == syn" counter accept

#addInet output skuid $tor_uid counter accept
addInet output ip protocol icmp icmp type echo-request counter accept

# torrents
# Ex config with aria2c contain:
# listen-port = 6881-6886 | dht-listen-port = 6881-6886
addInet output oifname $IF udp sport 6881-6886 counter accept

# Default output log rule
if [ $firewall_quiet == "no" ] ; then
  addInet output oifname != lo log prefix \"DROP \"
fi

########################################################
# FORWARD CHAIN

if [ $firewall_quiet == "no" ] ; then
  addInet forward ct state invalid log prefix \"FORWARD INVALID \"
fi
addInet forward ct state invalid counter drop

if [ $docker_use == "yes" ] ; then
  addInet forward ip saddr $docker_v4 oif $IF accept
fi

addInet forward ct state established,related counter accept

# Anti-spoofing rules
if [ $firewall_quiet == "no" ] ; then
  addInet forward iifname $IF ip saddr != $INT_NET log prefix \"SPOOFED PKT \"
fi
addInet forward iifname $IF ip saddr != $INT_NET drop

# Default output log rule
if [ $firewall_quiet == "no" ] ; then
  addInet forward iifname != lo log prefix \"DROP \"
fi

########################################################
# NAT CHAIN

# Transparent proxy with TOR 
# doc: https://trac.torproject.org/projects/tor/wiki/doc/TransparentProxy
$NFT add rule nat output skuid $tor_uid counter return
$NFT add rule nat output udp dport 53 counter redirect to $dns_port
$NFT add rule nat output skuid $tor_uid udp dport 53 counter redirect to $dns_port

$NFT add rule nat output counter ip protocol tcp ip daddr $virt_tor redirect to $trans_port
$NFT add rule nat output counter ip protocol udp ip daddr $virt_tor redirect to $trans_port

if [ $docker_use == "yes" ] ; then
  $NFT add rule nat postrouting ip saddr $docker_v4 oif $IF masquerade
fi

# Do not torrify torrent
$NFT add rule nat output oifname $IF udp sport 6881-6886 counter return

#$NFT add rule nat output ip protocol tcp ip daddr != 127.0.0.1/32 skuid != $tor_uid counter dnat to "127.0.0.1:$trans_port"
#$NFT add rule nat output ip daddr != 127.0.0.1/32 skuid != $tor_uid udp dport 53 counter dnat to "127.0.0.1:$dns_port"

# Don't nat the tor process on local network
$NFT add rule nat output oifname lo counter return

# allow lan access
for _lan in $non_tor; do
  $NFT add rule nat output ip daddr $_lan counter return
done

for _iana in $_resv_iana ; do
  $NFT add rule nat output ip daddr $_iana counter return
done

# Redirect all other output to TOR
$NFT add rule nat output "tcp flags & (fin|syn|rst|ack) == syn" counter redirect to $trans_port
$NFT add rule nat output ip protocol icmp counter redirect to $trans_port
$NFT add rule nat output ip protocol udp counter redirect to $trans_port

########################################################
# BLOCK IP
# echo "[+] Setting up blocking IPS..."
