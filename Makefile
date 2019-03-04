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
	install -dm755 $(DOC_DIR)/$(PROGRAM_NAME)
	install -Dm644 README.md $(DOC_DIR)/$(PROGRAM_NAME)/README.md
	install -Dm755 paranoid.sh $(BIN_DIR)/$(PROGRAM_NAME)
	mkdir -p $(CONF_DIR)/$(PROGRAM_NAME)
	install -Dm644 paranoid.conf.sample $(CONF_DIR)/$(PROGRAM_NAME)/paranoid.conf
	install -Dm644 paranoid-mac.conf $(CONF_DIR)/$(PROGRAM_NAME)/
	mkdir -p $(LIB_DIR)/$(PROGRAM_NAME)
	install -Dm744 src/* $(LIB_DIR)/$(PROGRAM_NAME)/
	mkdir -p /etc/conf.d
	install -Dm644 $(PROGRAM_NAME).confd /etc/conf.d/$(PROGRAM_NAME)
	$(if $(shell [ -d $(SYSTEMD_SCRIPT) ]),, \
	  mkdir -p $(SYSTEMD_SCRIPT);\
    install -Dm744 systemd/paranoid $(SYSTEMD_SCRIPT)/;\
    install -Dm644 systemd/*.service $(SYSTEMD_SERVICE)/;\
    install -Dm644 systemd/*.timer $(SYSTEMD_SERVICE)/;\
	  systemctl mask nftables;\
	  systemctl mask nftables-restore;\
	  systemctl mask iptables)

uninstall:
	rm -f $(BIN_DIR)/$(PROGRAM_NAME)
	rm -Rf $(DOC_DIR)/$(PROGRAM_NAME)
	rm -Rf $(BACKUP_DIR)
	rm -Rf $(CONF_DIR)/$(PROGRAM_NAME)
	rm -Rf $(LIB_DIR)/$(PROGRAM_NAME)
	rm -f /etc/conf.d/$(PROGRAM_NAME)
	$(if $(shell [ -d $(SYSTEMD_SCRIPT) ]),, \
    rm -f $(SYSTEMD_SCRIPT)/paranoid;\
	  rm -r $(SYSTEMD_SERVICE)/paranoid@.service;\
    rm -r $(SYSTEMD_SERVICE)/paranoid@.timer;\
    rm -r $(SYSTEMD_SERVICE)/paranoid-wifi@.service;\
    rm -r $(SYSTEMD_SERVICE)/paranoid-wifi@.timer;\
    rm -r $(SYSTEMD_SERVICE)/paranoid-macspoof@.service;\
    systemctl unmask nftables;\
    systemctl unmask nftables-restore;\
    systemctl unmask iptables)
