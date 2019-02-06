# paranoid-ninja
![demo](https://raw.githubusercontent.com/szorfein/paranoid-ninja/master/demo/paranoid-ninja.png)

## About 
A script to protect your privacy.  
Apply a Transparent proxy through Tor with nftables or iptables and optionnaly can spoof a random MAC address, localtime, hostname, private ip.  

#### Firewall
Add basic and secure rules for nftables or iptables, inspired by project like [TOR transparent-proxy](https://trac.torproject.org/projects/tor/wiki/doc/TransparentProxy), [anonsurf](https://github.com/ParrotSec/anonsurf), [kalitorify](https://github.com/brainfucksec/kalitorify.git), [iptables-essential](https://github.com/trimstray/iptables-essentials). 

#### Systemd
The daemon work with systemd, i created a service for ethernet and wifi card.  
The wifi daemon require `wpa_supplicant`.  

## TODO List
+ Add an option to print firewall log or not
+ Create a systemd timer service to reload the daemon all the X minutes.
+ Stop the web browser, clean cache, and restore (Not easy with firejail and bleachbit do not support all web browsers :()
+ Create an ssh tunnel socks5 to connect tor via Socks5Proxy to make a [User] -> [SSH] -> [Tor] -> [Internet] or setup a VPN with wireguard ?

## Dependencies
#### Archlinux
    
    # pacman -S ipcalc tor wget

And add `iptables` or `nftables`. `wpa_supplicant` if use wifi.

#### Gentoo

    # euse -E urandom systemd
    # emerge -av net-misc/ipcalc net-vpn/tor sys-apps/iproute2 sys-apps/coreutils 

And add `net-firewall/iptables` or `net-firewall/nftables`, `net-wireless/wpa_supplicant` if use wifi.

#### Other distribs
The name of the packages may be different but need:  
`iproute2`, `shuf`, `urandom`, `util-linux`, `nftables` or `iptables`, `systemd`, `ipcalc`, `wpa_supplicant` if use a wifi card.  

## Install
Clone this repository:

    # git clone https://github.com/szorfein/paranoid-ninja.git

Make a copy of `paranoid.conf.sample`:

    # cp paranoid.conf.sample paranoid.conf

If you doesn't want to randomize anything, change the value of `randomize` by `randomize=()`

    # make install

## Configure
Edit the config file at `/etc/paranoid-ninja/paranoid.conf`:

+ Change the user: `# sed -i "s:brakk:your_username:g" /etc/paranoid-ninja/paranoid.conf`
+ Your network card: `net_device="wlp2s0"`
+ The target router: `target_router="192.168.1.1"`
+ Your preferer firewall: `firewall="nftables"`
+ If want forge a random timezone only: `randomize=( "timezone" )`

## Usage

    # paranoid-ninja -h
