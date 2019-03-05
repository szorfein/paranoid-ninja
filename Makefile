PROGRAM_NAME=paranoid-ninja
DESTDIR ?=

ifndef DESTDIR
	DESTDIR := /
endif

BIN_DIR=${DESTDIR}usr/bin
CONF_DIR=${DESTDIR}etc
CONFD_DIR=${DESTDIR}etc/conf.d
LIB_DIR=${DESTDIR}lib
DOC_DIR=${DESTDIR}usr/share/doc
SYSTEMD_SERVICE=${DESTDIR}usr/lib/systemd/system
BACKUP_DIR=${DESTDIR}etc/paranoid-ninja/backups

.PHONY: insDaemon
insDaemon:
	./systemd.sh -c paranoid.conf.sample $(DESTDIR)

prerequisites: insDaemon

install: prerequisites
	install -dm755 $(DOC_DIR)/$(PROGRAM_NAME)
	install -m644 README.md $(DOC_DIR)/$(PROGRAM_NAME)/README.md
	install -Dm755 paranoid.sh $(BIN_DIR)/$(PROGRAM_NAME)
	mkdir -p $(CONF_DIR)/$(PROGRAM_NAME)
	install -Dm644 paranoid.conf.sample $(CONF_DIR)/$(PROGRAM_NAME)/paranoid.conf
	mkdir -p $(LIB_DIR)/$(PROGRAM_NAME)
	install -Dm744 src/* $(LIB_DIR)/$(PROGRAM_NAME)/
	mkdir -p $(CONFD_DIR)
	install -Dm644 $(PROGRAM_NAME).confd $(CONFD_DIR)/$(PROGRAM_NAME)
	$(if $(shell [ -d $(SYSTEMD_SCRIPT) ]),, \
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
	rm -f $(CONFD_DIR)/$(PROGRAM_NAME)
	$(if $(shell [ -d $(SYSTEMD_SCRIPT) ]),, \
	  rm -r $(SYSTEMD_SERVICE)/paranoid@.service;\
    rm -r $(SYSTEMD_SERVICE)/paranoid@.timer;\
    rm -r $(SYSTEMD_SERVICE)/paranoid-wifi@.service;\
    rm -r $(SYSTEMD_SERVICE)/paranoid-wifi@.timer;\
    rm -r $(SYSTEMD_SERVICE)/paranoid-macspoof@.service;\
    systemctl unmask nftables;\
    systemctl unmask nftables-restore;\
    systemctl unmask iptables)
