# mk/greeter.mk — build the linus-greeter Debian package.
# Include from the root Makefile with: include mk/greeter.mk

GREETER_VERSION  ?= 0.1.0
GREETER_PKG       = linus-greeter
GREETER_STAGEDIR  = dist/.stage/$(GREETER_PKG)
GREETER_DEB       = dist/packages/$(GREETER_PKG)_$(GREETER_VERSION)_all.deb

.PHONY: greeter greeter-stage greeter-clean

greeter: $(GREETER_DEB)

$(GREETER_DEB): greeter-stage
	@mkdir -p dist/packages
	dpkg-deb --build --root-owner-group $(GREETER_STAGEDIR) $@
	@echo "Built: $@"

greeter-stage: packaging/session/linus-greeter/DEBIAN/control
	@rm -rf $(GREETER_STAGEDIR)
	@mkdir -p \
		$(GREETER_STAGEDIR)/DEBIAN \
		$(GREETER_STAGEDIR)/etc/greetd \
		$(GREETER_STAGEDIR)/etc/pam.d \
		$(GREETER_STAGEDIR)/etc/systemd/system/greetd.service.d

	# DEBIAN control files
	cp packaging/session/linus-greeter/DEBIAN/control  $(GREETER_STAGEDIR)/DEBIAN/control
	cp packaging/session/linus-greeter/DEBIAN/postinst $(GREETER_STAGEDIR)/DEBIAN/postinst
	cp packaging/session/linus-greeter/DEBIAN/prerm    $(GREETER_STAGEDIR)/DEBIAN/prerm
	chmod 755 $(GREETER_STAGEDIR)/DEBIAN/postinst $(GREETER_STAGEDIR)/DEBIAN/prerm

	# greetd config (/etc/greetd/)
	cp greeter/config.toml     $(GREETER_STAGEDIR)/etc/greetd/
	cp greeter/autologin.toml  $(GREETER_STAGEDIR)/etc/greetd/
	cp greeter/gtkgreet.css    $(GREETER_STAGEDIR)/etc/greetd/
	# Mark autologin.conf as a conffile so dpkg asks on upgrade
	echo "/etc/greetd/config.toml"    >> $(GREETER_STAGEDIR)/DEBIAN/conffiles
	echo "/etc/greetd/autologin.toml" >> $(GREETER_STAGEDIR)/DEBIAN/conffiles
	echo "/etc/greetd/gtkgreet.css"   >> $(GREETER_STAGEDIR)/DEBIAN/conffiles

	# PAM config (/etc/pam.d/)
	cp greeter/pam/greetd $(GREETER_STAGEDIR)/etc/pam.d/
	echo "/etc/pam.d/greetd" >> $(GREETER_STAGEDIR)/DEBIAN/conffiles

	# Live-ISO systemd drop-in (shipped but not activated on installed systems)
	cp greeter/autologin.conf \
		$(GREETER_STAGEDIR)/etc/systemd/system/greetd.service.d/autologin.conf.live-iso
	# The image build hook renames .live-iso → the active override; do NOT
	# activate it here or every installed system would autologin.

greeter-clean:
	rm -rf $(GREETER_STAGEDIR) $(GREETER_DEB)
