# paranoid-ninja

# about 

A script to protect your privacy.  
Randomize the MAC address, localtime, private ip and apply a Transparent proxy through Tor with nftables or iptables.  

### Firewall
Add a basic and secure firewall with log and TOR, inspired by project like [TOR transparent-proxy](https://trac.torproject.org/projects/tor/wiki/doc/TransparentProxy), [anonsurf](https://github.com/ParrotSec/anonsurf), [kalitorify](https://github.com/brainfucksec/kalitorify.git), [iptables-essential](https://github.com/trimstray/iptables-essentials). 

### Systemd
The daemon work with systemd, i created a service for ethernet and wifi card.  
The wifi daemon require `wpa_supplicant`.  

TODO List:
+ create an option --stop --halt or --clean
+ stop the web browser, clean cache, and restore
+ create an ssh tunnel socks5 to connect tor via Socks5Proxy to make a [User] -> [SSH] -> [Tor] -> [Internet] ?
+ Test if the connection via tor work with script
+ Add an option to print firewall log or not

# Dependencies

### Archlinux
    
    # pacman -S ipcalc tor wget

And add `iptables` or `nftables`. `wpa_supplicant` if use wifi.

### Gentoo

    # euse -E urandom systemd
    # emerge -av net-misc/ipcalc net-vpn/tor sys-apps/iproute2 sys-apps/coreutils 

And add `net-firewall/iptables` or `net-firewall/nftables`, `net-wireless/wpa_supplicant` if use wifi.

### Other distrib need

iproute2, shuf, urandom, util-linux, nftables or iptables, systemd, ipcalc.  

Optionnal dependencies are: wpa_supplicant if use a wifi card and dhcpcd if need.

# Install

    # git clone https://github.com/szorfein/paranoid-ninja.git

# Configure

Make a copy of `paranoid.conf.sample`:

    # cp -a paranoid.conf.sample paranoid.conf

And change at least the value of `net_device=`, `target_router=` and the firewall used `firewall=`.

# Usage

    # ./paranoid.sh -h

# Demo

    # ./paranoid -r -c paranoid.conf

```txt
[+] Apply a new hostname comet-8y1e0r1gh5
[*] change host in /home/ninja/.ssh/known_hosts
[*] changed hostname with xauth
[+] Changed timezone Tijuana from Central
[+] Changed mac af:2f:ba:15:be:13 to 1C:92:01:6a:13:FB
[+] Apply your new IP addr: 192.168.1.20/24
[*] Found interface wlp2s0 and your ip 192.168.1.20/24
[+] Flushing existing rules...
[+] Settings up nftables rules ...
[+] Done
[*] Relaunch your web browser is recommended
```
