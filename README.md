# paranoid-ninja

# about 

A script to protect your privacy and your system.    
Randomize MAC address, localtime, private ip, transparent-torrify with nftables (for now) and patch the kernel with harden feature recommanded by [ClipOS](https://docs.clip-os.org/clipos/kernel.html) and [KernSec](https://kernsec.org/wiki/index.php/Kernel_Self_Protection_Project/Recommended_Settings).

## Dependencies

iproute2, shuf, urandom, util-linux, nftables, systemd, ipcalc.  

Optionnal dependencies are: wpa_supplicant if use a wifi card and dhcpcd if need.

### Kernel
Combine the configuration of [ClipOS](https://docs.clip-os.org/clipos/kernel.html) and [KernSec](https://kernsec.org/wiki/index.php/Kernel_Self_Protection_Project/Recommended_Settings).  
**TODO List** 
+ Enhance compilation for iptables
+ Add kernel boot params for grub2

### Firewall
Just add a basic and secure firewall with log and transparent proxy with TOR, inspired by the script [kalitorify](https://github.com/brainfucksec/kalitorify.git), i've create custom rule for nftables.  
**TODO List** 
+ change /etc/resolv.conf
+ add iptables rules.

### Systemd
I'll write some services especially for randomize the MAC address,the timezone and the hostname at boot.  
**TODO List**
+ Verify the dependencie for wpa_supplicant 

Be careful, the project is not ready for production :)

## Install

    # git clone https://github.com/szorfein/paranoid-ninja.git

## Configure

Make a copy of `paranoid.conf.sample`:

    # cp -a paranoid.conf.sample paranoid.conf

And change at least the value of `net_device=` and `target_router=`

## Usage

    # ./paranoid.sh -h
