#!/usr/bin/env bash

# fail on void variable and error
set -ue

IPT=iptables
BACKUP_FILES="/etc/tor/torrc /etc/resolv.conf"

####################################################
# Check Bins

checkBins modprobe iptables ip systemctl
checkRoot

####################################################
# Command line parser

while [ "$#" -gt 0 ] ; do
  case "$1" in
    -c | --conf) CONF=$2 ; shift ; shift ;;
    *) die "$0 unknown arg $1"
  esac
done

####################################################
# Check network device and ip

IF=$net_device
INT_NET=$(ip a show $IF | grep inet | awk '{print $2}' | head -n 1)

[[ -z $IF ]] && die "Device network UP no found"
[[ -z $INT_NET ]] && die "Ip addr no found"

echo "[*] Found interface $IF | ip $INT_NET"

####################################################
# Tor uid

tor_uid=$(searchTorUid)

####################################################
# backupFiles

backupFiles "$BACKUP_FILES"

####################################################
# TOR vars

readonly torrc="/etc/tor/torrc"

[[ ! -f $torrc ]] && die "$torrc no found, TOR isn't install ?"

# Tor transport
if ! grep TransPort $torrc > /dev/null ; then
  echo "[*] Add new TransPort 9040 to $torrc"
  echo "TransPort 9040 IsolateClientAddr IsolateClientProtocol IsolateDestAddr IsolateDestPort" >> $torrc
fi
readonly trans_port=$(grep TransPort $torrc | awk '{print $2}')

# Tor DNSPort
if ! grep "^DNSPort" $torrc > /dev/null ; then
  echo "[*] Add new DNSPort 5353 to $torrc"
  echo "DNSPort 5353" >> $torrc
fi
readonly dns_port=$(grep DNSPort $torrc | awk '{print $2}')

# Tor AutomapHostsOnResolve
if ! grep AutomapHostsOnResolve $torrc > /dev/null ; then
  echo "[*] Add new AutomapHostsOnResolve 1 to $torrc"
  echo "AutomapHostsOnResolve 1" >> $torrc
fi

# Tor VirtualAddrNetworkIPv4
if ! grep VirtualAddrNetworkIPv4 $torrc > /dev/null ; then
  echo "[*] Add VirtualAddrNetworkIPv4 10.192.0.0/10 to $torrc"
  echo "VirtualAddrNetworkIPv4 10.192.0.0/10" >> $torrc
fi
readonly virt_tor=$(grep VirtualAddrNetworkIPv4 $torrc | awk '{print $2}')

# non Tor addr
readonly non_tor="127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 $docker_ipv4 192.168.0.0/16 192.168.99.0/16"

# Just to be sure :)
[[ -z $trans_port ]] && die "No TransPort value found on $torrc"
[[ -z $dns_port ]] && die "No DNSPort value found on $torrc"
[[ -z $virt_tor ]] && die "No VirtualAddrNetworkIPv4 value found on $torrc"

####################################################
# resolv.conf

echo "[+] Update /etc/resolv.conf"
if $tor_proxy ; then
cat > /etc/resolv.conf << EOF
nameserver 127.0.0.1
EOF
else
cat > /etc/resolv.conf << EOF
nameserver 1.1.1.1
EOF
fi

####################################################
# load modules

# Look which system need
modprobe ip_tables iptable_nat ip_conntrack iptable-filter ipt_state

# Disable ipv6
# No need enable on archlinux
#sysctl -w net.ipv6.conf.all.disable_ipv6=1
#sysctl -w net.ipv6.conf.default.disable_ipv6=1

####################################################
# Flushing rules

echo "[+] Flushing existing rules..."
clearIptables

echo "[+] Setting up $firewall rules ..."

# block bad tcp flags if secure_rules="yes"
secure_rules() {
  # bad flag chain
  $IPT -N BAD_FLAGS
  # pass traffic with bad flags to the bad flag chain
  $IPT -A INPUT -p tcp -j BAD_FLAGS
  $IPT -A BAD_FLAGS -p tcp --tcp-flags SYN,FIN SYN,FIN -j LOG --log-prefix "IPT: Bad SF Flag "
  $IPT -A BAD_FLAGS -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
  $IPT -A BAD_FLAGS -p tcp --tcp-flags SYN,RST SYN,RST -j LOG --log-prefix "IPT: Bad SR Flag "
  $IPT -A BAD_FLAGS -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
  $IPT -A BAD_FLAGS -p tcp --tcp-flags SYN,FIN,PSH SYN,FIN,PSH -j LOG --log-prefix "IPT: Bad SFP Flag "
  $IPT -A BAD_FLAGS -p tcp --tcp-flags SYN,FIN,PSH SYN,FIN,PSH -j DROP
  $IPT -A BAD_FLAGS -p tcp --tcp-flags SYN,FIN,RST SYN,FIN,RST -j LOG --log-prefix "IPT: Bad SFR Flag "
  $IPT -A BAD_FLAGS -p tcp --tcp-flags SYN,FIN,RST SYN,FIN,RST -j DROP
  $IPT -A BAD_FLAGS -p tcp --tcp-flags SYN,FIN,RST,PSH SYN,FIN,RST,PSH -j LOG --log-prefix "IPT: Bad SFRP Flag "
  $IPT -A BAD_FLAGS -p tcp --tcp-flags SYN,FIN,RST,PSH SYN,FIN,RST,PSH -j DROP
  $IPT -A BAD_FLAGS -p tcp --tcp-flags FIN FIN -j LOG --log-prefix "IPT: Bad F Flag "
  $IPT -A BAD_FLAGS -p tcp --tcp-flags FIN FIN -j DROP
  $IPT -A BAD_FLAGS -p tcp --tcp-flags ALL NONE -j LOG --log-prefix "IPT: Null Flag "
  $IPT -A BAD_FLAGS -p tcp --tcp-flags ALL NONE -j DROP
  $IPT -A BAD_FLAGS -p tcp --tcp-flags ALL ALL -j LOG --log-prefix "IPT: All Flags "
  $IPT -A BAD_FLAGS -p tcp --tcp-flags ALL ALL -j DROP
  $IPT -A BAD_FLAGS -p tcp --tcp-flags ALL FIN,URG,PSH -j LOG --log-prefix "IPT: Nmap:Xmas Flags "
  $IPT -A BAD_FLAGS -p tcp --tcp-flags ALL FIN,URG,PSH -j DROP
  $IPT -A BAD_FLAGS -p tcp --tcp-flags ALL RST,ACK,FIN,URG -j LOG --log-prefix "IPT: Merry Xmas Flags "
  $IPT -A BAD_FLAGS -p tcp --tcp-flags ALL RST,ACK,FIN,URG -j DROP
}

if [ $secure_rules == "yes" ] ; then secure_rules ; fi

####################################################
# Input chain

if ! $QUIET ; then
  $IPT -A INPUT -m state --state INVALID -j LOG --log-prefix "DROP INVALID " --log-ip-options --log-tcp-options
fi
$IPT -A INPUT -m state --state INVALID -j DROP
$IPT -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Anti-spoofing
if ! $QUIET ; then
  $IPT -A INPUT -i $IF ! -s $INT_NET -j LOG --log-prefix "SPOOFED PKT "
fi
$IPT -A INPUT -i $IF ! -s $INT_NET -j DROP

# Accept rule
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A INPUT -i $IF -p tcp -s $INT_NET --dport 22 --syn -m state --state NEW -j ACCEPT
$IPT -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
$IPT -A INPUT -i $IF -p udp -s $INT_NET --dport $dns_port -j ACCEPT

# default input log rule
if ! $QUIET ; then
  $IPT -A INPUT ! -i lo -j LOG --log-prefix "DROP " --log-ip-options --log-tcp-options
fi

####################################################
# Output chain

# Tracking rules
if ! $QUIET ; then
  $IPT -A OUTPUT -m state --state INVALID -j LOG --log-prefix "DROP INVALID " --log-ip-options --log-tcp-options
fi
$IPT -A OUTPUT -m state --state INVALID -j DROP
$IPT -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Accept rules out
$IPT -A OUTPUT -o lo -j ACCEPT
$IPT -A OUTPUT -p tcp --dport 22 --syn -m state --state NEW -j ACCEPT

# tor
if $tor_proxy ; then
  $IPT -A OUTPUT -p tcp --dport 8890 --syn -m state --state NEW -j ACCEPT
  $IPT -A INPUT -p tcp --sport 8890 --syn -m state --state NEW -j ACCEPT
fi

# Allow Tor process output
$IPT -A OUTPUT -o $IF -m owner --uid-owner $tor_uid -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -m state --state NEW -j ACCEPT

# Allow loopback output
$IPT -A OUTPUT -o lo -d 127.0.0.1/32 -j ACCEPT

if $tor_proxy ; then
  # Tor transproxy magic
  $IPT -A OUTPUT -d 127.0.0.1/32 -p tcp -m tcp --dport $trans_port --tcp-flags FIN,SYN,RST,ACK SYN -j ACCEPT
fi

#$IPT -A OUTPUT -m owner --uid-owner $tor_uid -j ACCEPT
$IPT -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT

# Torrents
$IPT -A OUTPUT -o $IF -p udp -m multiport --sports 6881,6882,6883,6884,6885,6886 -j ACCEPT

if $tor_proxy ; then
  $IPT -A OUTPUT -o $IF -s $INT_NET -p udp -m udp --dport $trans_port -j ACCEPT
  $IPT -A OUTPUT -o $IF -s $INT_NET -p udp -m udp --dport $dns_port -j ACCEPT
  $IPT -A OUTPUT -o $IF -s $INT_NET -p udp -m udp --sport $dns_port --dport $trans_port -j ACCEPT
else
  $IPT -A OUTPUT -o $IF -s $INT_NET -p udp -m udp --dport 53 -j ACCEPT
  $IPT -A OUTPUT -o $IF -s $INT_NET -p tcp -m tcp --dport 443 -j ACCEPT
fi

# sshuttle
for i in $(seq 12298 12300) ; do
  #$IPT -A OUTPUT -o $IF -d 127.0.0.1/32 -p tcp -m multiport --dports 12300,12299,12298 -j ACCEPT
  $IPT -A OUTPUT -o $IF -d 127.0.0.1/32 -p tcp -m tcp --dport $i -j ACCEPT

  if [ $docker_use == "yes" ] ; then
    for _docker_ipv4 in $docker_ipv4 ; do
      $IPT -A INPUT -s "$_docker_ipv4" -d "$_docker_ipv4" -p tcp -m tcp --dport $i -j ACCEPT
      $IPT -A OUTPUT -s "$_docker_ipv4" -d 8.8.8.8 -p udp -m udp --dport 53 -j ACCEPT # docker with nodejs
      $IPT -A OUTPUT -s "$_docker_ipv4" -d 8.8.4.4 -p udp -m udp --dport 53 -j ACCEPT # docker with nodejs
      $IPT -A OUTPUT -s "$_docker_ipv4" -p tcp -m tcp --dport 443 -j ACCEPT # docker with nodejs
      $IPT -A INPUT -s "$_docker_ipv4" -p tcp -m tcp --dport 443 -j ACCEPT # docker with nodejs
      $IPT -A INPUT -s "$_docker_ipv4" -p tcp -m tcp --dport 3000 -j ACCEPT # docker with nodejs
      $IPT -A OUTPUT -s "$_docker_ipv4" -p tcp -m tcp --dport 8080 -j ACCEPT # docker web
      $IPT -A OUTPUT -s "$_docker_ipv4" -p tcp -m tcp --dport 80 -j ACCEPT # docker web
      $IPT -A OUTPUT -s "$_docker_ipv4" -d "$_docker_ipv4" -p tcp -m tcp --dport $i -j ACCEPT
      $IPT -A OUTPUT -s "$_docker_ipv4" -d 127.0.0.1/32 -p tcp -m tcp --dport $i -j ACCEPT
    done
    #$IPT -A OUTPUT -s $INT_NET -p tcp -m tcp --dport 8443 -j ACCEPT # kubectl
    $IPT -A OUTPUT -d 192.168.99.0/16 -p tcp -m tcp --dport 8443 -j ACCEPT # kubectl
    $IPT -A INPUT -s 192.168.99.0/16 -p tcp -m tcp --sport 8443 -j ACCEPT # kubectl
  fi
done

# if Docker
if [ $docker_use == "yes" ] ; then

  for _docker_ipv4 in $docker_ipv4 ; do
    # allow local server 80
    $IPT -A OUTPUT -s $_docker_ipv4 -d $_docker_ipv4 -p tcp -m tcp --dport 80 -j ACCEPT

    # allow local database on 5432
    $IPT -A OUTPUT -s $_docker_ipv4 -d $_docker_ipv4 -p tcp -m tcp --dport 5432 -j ACCEPT
  done
fi

# freenode 7000
$IPT -A OUTPUT -p tcp -m tcp --dport 7000 -j ACCEPT

# Default output log rule
if ! $QUIET ; then
  $IPT -A OUTPUT ! -o lo -j LOG --log-prefix "DROP " --log-ip-options --log-tcp-options
fi

####################################################
# Forward chain

# Tracking rule
if ! $QUIET ; then
  $IPT -A FORWARD -m state --state INVALID -j LOG --log-prefix "DROP INVALID " --log-ip-options --log-tcp-options
fi
$IPT -A FORWARD -m state --state INVALID -j DROP
$IPT -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# Anti-spoofing rule
if ! $QUIET ; then
  $IPT -A FORWARD -i $IF ! -s $INT_NET -j LOG --log-prefix "SPOOFED PKT "
fi
$IPT -A FORWARD -i $IF ! -s $INT_NET -j DROP

# Accept rule

# Default log rule
if ! $QUIET ; then
  $IPT -A FORWARD ! -i lo -j LOG --log-prefix "DROP " --log-ip-options --log-tcp-options
fi

####################################################
# NAT chain

if $tor_proxy ; then
  echo "Active transparent proxy throught tor"
  echo "Nat rules tor_uid: $tor_uid, dns: $dns_port, trans: $trans_port, virt: $virt_tor"
  $IPT -t nat -A OUTPUT -m owner --uid-owner $tor_uid -j RETURN
  $IPT -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $dns_port
  $IPT -t nat -A OUTPUT -m owner --uid-owner $tor_uid -p udp --dport 53 -j REDIRECT --to-ports $dns_port

  $IPT -t nat -A OUTPUT -p tcp -d $virt_tor -j REDIRECT --to-ports $trans_port
  $IPT -t nat -A OUTPUT -p udp -d $virt_tor -j REDIRECT --to-ports $trans_port

  # Do not torrify torrent - not sure this is required
  $IPT -t nat -A OUTPUT -p udp -m multiport --dports 6881,6882,6883,6884,6885,6886 -j RETURN

  # Don't nat the tor process on local network
  $IPT -t nat -A OUTPUT -o lo -j RETURN

  # Allow lan access for non_tor 
  for lan in $non_tor 127.0.0.0/9 127.128.0.0/10; do
    $IPT -t nat -A OUTPUT -d "$lan" -j RETURN
  done

  #for _iana in $_resv_iana ; do
  #  $IPT -t nat -A OUTPUT -d "$_iana" -j RETURN
  #done

  # Redirect all other output to TOR
  $IPT -t nat -A OUTPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -j REDIRECT --to-ports $trans_port
  $IPT -t nat -A OUTPUT -p icmp -j REDIRECT --to-ports $trans_port
  $IPT -t nat -A OUTPUT -p udp -j REDIRECT --to-ports $trans_port
fi

echo "Setting iptable ended"
