# mk/installer.mk — Calamares installer configuration targets for linus.
# Included by the top-level Makefile; not invoked standalone.
#
# Targets:
#   installer-install   Copy Calamares settings into $(DESTDIR) (for live-build hooks / deb build)
#   installer-deb       Build calamares-settings-linus_*.deb into dist/packages/
#   installer-check     Validate YAML and shell syntax of all installer files
#   installer-clean     Remove previously installed files from $(DESTDIR)

INSTALLER_SRC         := installer/calamares
INSTALLER_HOOK_SRC    := installer/hooks
CALAMARES_CONF        := $(DESTDIR)/etc/calamares
CALAMARES_HOOK_LIB    := $(DESTDIR)/usr/lib/calamares-settings-linus/hooks
XDG_AUTOSTART         := $(DESTDIR)/etc/xdg/autostart
USR_APPS              := $(DESTDIR)/usr/share/applications

INSTALLER_PKG_NAME    := calamares-settings-linus
INSTALLER_PKG_VERSION := 1.0.0
DIST_PKG_DIR          := dist/packages

.PHONY: installer-install installer-deb installer-check installer-clean

installer-install:
	install -d $(CALAMARES_CONF)/branding/linus
	install -d $(CALAMARES_CONF)/modules
	install -d $(CALAMARES_HOOK_LIB)
	install -d $(XDG_AUTOSTART)
	install -d $(USR_APPS)
	install -m 644 $(INSTALLER_SRC)/settings.conf \
		$(CALAMARES_CONF)/settings.conf
	install -m 644 $(INSTALLER_SRC)/branding/linus/branding.desc \
		$(CALAMARES_CONF)/branding/linus/branding.desc
	install -m 644 $(INSTALLER_SRC)/branding/linus/show.qml \
		$(CALAMARES_CONF)/branding/linus/show.qml
	install -m 644 branding/icons/linus-logo.svg \
		$(CALAMARES_CONF)/branding/linus/linus-logo.svg
	install -m 644 branding/icons/linus-logo-32.svg \
		$(CALAMARES_CONF)/branding/linus/linus-icon.svg
	for f in $(INSTALLER_SRC)/modules/*.conf; do \
		install -m 644 "$$f" $(CALAMARES_CONF)/modules/; \
	done
	install -m 755 $(INSTALLER_HOOK_SRC)/post-install.sh \
		$(CALAMARES_HOOK_LIB)/post-install.sh
	install -m 644 installer/linus-installer.desktop \
		$(XDG_AUTOSTART)/linus-installer.desktop
	install -m 644 installer/linus-installer.desktop \
		$(USR_APPS)/linus-installer.desktop

INSTALLER_DEB_STAGE := /tmp/$(INSTALLER_PKG_NAME)-stage

installer-deb: installer-check
	@echo "==> Building $(INSTALLER_PKG_NAME)_$(INSTALLER_PKG_VERSION)_all.deb..."
	rm -rf $(INSTALLER_DEB_STAGE)
	mkdir -p $(INSTALLER_DEB_STAGE)
	$(MAKE) installer-install DESTDIR=$(INSTALLER_DEB_STAGE)
	install -d $(INSTALLER_DEB_STAGE)/DEBIAN
	install -m 644 installer/debian/control $(INSTALLER_DEB_STAGE)/DEBIAN/control
	install -m 755 installer/debian/postinst $(INSTALLER_DEB_STAGE)/DEBIAN/postinst
	mkdir -p $(DIST_PKG_DIR)
	dpkg-deb --build --root-owner-group $(INSTALLER_DEB_STAGE) \
		$(DIST_PKG_DIR)/$(INSTALLER_PKG_NAME)_$(INSTALLER_PKG_VERSION)_all.deb
	rm -rf $(INSTALLER_DEB_STAGE)
	@echo "==> $(DIST_PKG_DIR)/$(INSTALLER_PKG_NAME)_$(INSTALLER_PKG_VERSION)_all.deb"

installer-check:
	@echo "==> Checking Calamares YAML syntax..."
	@for f in $$(find installer/calamares -name '*.conf' -o -name '*.desc'); do \
		python3 -c "import yaml, sys; yaml.safe_load(sys.stdin)" < "$$f" \
			|| { echo "YAML error in $$f"; exit 1; }; \
	done
	@echo "    YAML OK"
	@echo "==> Checking post-install.sh syntax..."
	@bash -n $(INSTALLER_HOOK_SRC)/post-install.sh
	@echo "    Shell OK"
	@echo "==> installer-check passed"

installer-clean:
	rm -f  $(CALAMARES_CONF)/settings.conf
	rm -rf $(CALAMARES_CONF)/branding/linus
	rm -rf $(CALAMARES_CONF)/modules
	rm -rf $(CALAMARES_HOOK_LIB)
	rm -f  $(XDG_AUTOSTART)/linus-installer.desktop
	rm -f  $(USR_APPS)/linus-installer.desktop
	rm -f  $(DIST_PKG_DIR)/$(INSTALLER_PKG_NAME)_$(INSTALLER_PKG_VERSION)_all.deb
