# paranoid-ninja
![demo](https://raw.githubusercontent.com/szorfein/paranoid-ninja/master/demo/paranoid-ninja.png)

## About 
A script to protect your privacy.  
Apply a Transparent proxy through Tor with nftables or iptables and optionnaly can spoof a random MAC address, localtime, hostname, private ip.  

#### Firewall
Add basic and secure rules for nftables or iptables, inspired by project like [TOR transparent-proxy](https://trac.torproject.org/projects/tor/wiki/doc/TransparentProxy), [anonsurf](https://github.com/ParrotSec/anonsurf), [kalitorify](https://github.com/brainfucksec/kalitorify.git), [iptables-essential](https://github.com/trimstray/iptables-essentials). 

## Test if it work
+ [Are you using tor ?](https://check.torproject.org/)
+ [torrent ip](http://ipmagnet.services.cbcdn.com)
+ [dns leak](https://www.dnsleaktest.com)

## TODO List
+ Stop the web browser, clean cache, and restore (Not easy with firejail and bleachbit do not support all web browsers :()

## Dependencies
#### Archlinux
    
    # pacman -S ipcalc tor wget

And add `iptables` or `nftables`. `wpa_supplicant` if use wifi.

#### Gentoo ([ebuild](https://github.com/szorfein/paranoid-ninja/tree/master/packages))

    # emerge -av paranoid-ninja

#### Other distribs
The name of the packages may be different but need:  
`iproute2`, `shuf`, `urandom`, `util-linux`, `nftables` or `iptables`, `systemd`, `ipcalc`, `wpa_supplicant` if use a wifi card.  

## Install
Clone this repository:

    # git clone https://github.com/szorfein/paranoid-ninja.git
    # make install

## Configure
If install, edit the config file at `/etc/paranoid-ninja/paranoid.conf`.

+ Your network card: `net_device="wlp2s0"`
+ The target router: `target_router="192.168.1.1"`
+ Your favorite firewall: `firewall="iptables"`
+ If want forge a random timezone only: `randomize=( "timezone" )`
+ Change the username: `# sed -i "s:brakk:your_username:g" /etc/paranoid-ninja/paranoid.conf`

## Sshuttle (WORKFLOW)
There are a temporary working example of `sshuttle.service` in the [systemd dir](https://github.com/szorfein/paranoid-ninja/tree/master/systemd), you have to manually edit and copy this file at `/lib/systemd/system` or `/usr/lib/systemd/system`, depend of your system and create a ssh key for the root at `/root/.ssh/id_ed2559`.  
A complete howto can be found [here](https://github.com/szorfein/Gentoo-ZFS/wiki/12.privacy).  

## Systemd service
The script install 2 services, for ethernet card:

    # systemctl start paranoid@<interface>

And wifi card:

    # systemctl start paranoid-wifi@<interface>

## Usage

    # paranoid-ninja -h

### Options

    -t, --transparent-proxy  | Require arg  -c, --config <file.conf>

Apply only a transparent proxy through tor with nftables or iptables

    -r, --randomize  | Require arg -c, --config <file.conf>

Look the config file, can forge a random MAC, hostname, ip, timezone and apply a transparent proxy through tor too

    -s, --status

Check if tor work and display your current ip address

    -d, --delete

Restore your files and try to restore your firewall rule if any
