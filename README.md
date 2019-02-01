# paranoid-ninja

# about 
A script to protect your privacy.  
Randomize the MAC address, localtime, private ip and apply a Transparent proxy through Tor with nftables or iptables.  

### Firewall
Add a basic and secure firewall with log and TOR, inspired by project like [TOR transparent-proxy](https://trac.torproject.org/projects/tor/wiki/doc/TransparentProxy), [anonsurf](https://github.com/ParrotSec/anonsurf), [kalitorify](https://github.com/brainfucksec/kalitorify.git), [iptables-essential](https://github.com/trimstray/iptables-essentials). 

### Systemd
The daemon work with systemd, i created a service for ethernet and wifi card.  
The wifi daemon require `wpa_supplicant`.  

## TODO List
+ Add an option to print firewall log or not
+ Create a systemd timer service to reload the daemon all the X minutes.
+ Stop the web browser, clean cache, and restore (Not easy with firejail and bleachbit do not support all web browsers :()
+ Create an ssh tunnel socks5 to connect tor via Socks5Proxy to make a [User] -> [SSH] -> [Tor] -> [Internet] or setup a VPN with wireshark ?

# Dependencies
### Archlinux
    
    # pacman -S ipcalc tor wget

And add `iptables` or `nftables`. `wpa_supplicant` if use wifi.

### Gentoo

    # euse -E urandom systemd
    # emerge -av net-misc/ipcalc net-vpn/tor sys-apps/iproute2 sys-apps/coreutils 

And add `net-firewall/iptables` or `net-firewall/nftables`, `net-wireless/wpa_supplicant` if use wifi.

### Other distribs
The name of the packages may be different but need:  
`iproute2`, `shuf`, `urandom`, `util-linux`, `nftables` or `iptables`, `systemd`, `ipcalc`, `wpa_supplicant` if use a wifi card.  

# Install

Clone this repository:

    # git clone https://github.com/szorfein/paranoid-ninja.git

Make a copy of `paranoid.conf.sample`:

    # cp paranoid.conf.sample paranoid.conf

Change the user:

    # sed -i "s:brakk:your_username:g" paranoid.conf

And change at least the value of `net_device=`, `target_router=` and the firewall used `firewall=`.

    # make install

# Usage

    # paranoid-ninja -h

# Demo

    # paranoid-ninja -r -c /etc/paranoid-ninja/paranoid.conf

```txt
[+] Apply a new hostname comet-8y1e0r1gh5
[*] change host in /home/ninja/.ssh/known_hosts
[*] change host in /home/ninja/.ssh/authorized_keys
[*] changed hostname with xauth
[+] Changed timezone Aden from Phoenix
[+] Changed mac af:2f:ba:15:be:13 to 1C:92:01:6a:13:FB
[+] Apply your new IP addr: 192.168.1.20/24
[*] Found interface wlp2s0 and your ip 192.168.1.20/24
[+] Update /etc/resolv.conf
[+] Flushing existing rules...
[+] Settings up nftables rules ...
[*] Relaunch your web browser is recommended
[+] Tor is working properly
==> Checking your public IP, please wait...

ip:101.123.115.30,
hostname:tor47.quintex.com,
city:SanAngelo,
region:Texas,
country:US,
loc:31.5468,-100.5610,
postal:76901,
phone:325,
org:AS62744QuintexAllianceConsulting
```
