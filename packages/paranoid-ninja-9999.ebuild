# Copyright 2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=6
inherit git-r3 systemd

DESCRIPTION="Transparent proxy over through tor with nftables or iptables"
HOMEPAGE="https://github.com/szorfein/paranoid-ninja"
EGIT_REPO_URI="https://github.com/szorfein/paranoid-ninja.git"

LICENSE="MIT"
SLOT="0"
KEYWORDS=""
IUSE="nftables iptables wifi systemd"

DEPEND="net-misc/ipcalc
net-vpn/tor
nftables? ( net-firewall/nftables )
iptables? ( net-firewall/iptables )
wifi? ( net-wireless/wpa_supplicant )
systemd? ( sys-apps/systemd )"

REQUIRED_USE="|| ( nftables iptables )"
RDEPEND="${DEPEND}"
BDEPEND=""

src_install() {
make DESTDIR="${D}" install

systemd_dounit "systemd/paranoid-wifi@.service"
systemd_dounit "systemd/paranoid@.service"
systemd_dounit "systemd/paranoid-macspoof@.service"
systemd_dounit "systemd/paranoid-wifi@.timer"
systemd_dounit "systemd/paranoid@.timer"
}
