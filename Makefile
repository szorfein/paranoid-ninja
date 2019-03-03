PROGRAM_NAME=paranoid-ninja

BIN_DIR=/usr/bin
CONF_DIR=/etc
LIB_DIR=/lib
DOC_DIR=/usr/share/doc
SYSTEMD_SERVICE=/etc/systemd/system
SYSTEMD_SCRIPT=/usr/lib/systemd/scripts
BACKUP_DIR=/etc/paranoid-ninja/backups

.PHONY: insDaemon

insDaemon:
	./systemd.sh -c paranoid.conf.sample

prerequisites: insDaemon

install: prerequisites
	install -Dm644 README.md $(DOC_DIR)/$(PROGRAM_NAME)/README.md
	install -Dm744 src/functions ${LIB_DIR}/${PROGRAM_NAME}/functions

uninstall:
	rm -f ${BIN_DIR}/${PROGRAM_NAME}
	rm -Rf ${DOC_DIR}/${PROGRAM_NAME}
	rm -Rf ${BACKUP_DIR}
	rm -Rf ${CONF_DIR}/${PROGRAM_NAME}
	rm -Rf ${LIB_DIR}/${PROGRAM_NAME}
	rm -f ${SYSTEMD_SCRIPT}/paranoid
	rm -r ${SYSTEMD_SERVICE}/paranoid@.service
	rm -r ${SYSTEMD_SERVICE}/paranoid@.timer
	rm -r ${SYSTEMD_SERVICE}/paranoid-wifi@.service
	rm -r ${SYSTEMD_SERVICE}/paranoid-macspoof@.timer
	rm -r ${SYSTEMD_SERVICE}/paranoid-macspoof@.service
	systemctl unmask nftables
	systemctl unmask nftables-restore
	systemctl unmask iptables
