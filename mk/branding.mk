# mk/branding.mk — build and package linus-branding
# Included by the root Makefile via: include mk/branding.mk

BRANDING_SRC     := branding
BRANDING_PKG_DIR := packaging/branding
BRANDING_VERSION := 1
BRANDING_DEB     := dist/packages/linus-branding_$(BRANDING_VERSION)-1_all.deb

.PHONY: branding branding-deb branding-clean

## branding: build the linus-branding .deb
branding: branding-deb

branding-deb: $(BRANDING_DEB)

$(BRANDING_DEB): $(shell find $(BRANDING_SRC) -type f) \
                  $(BRANDING_PKG_DIR)/debian/control \
                  $(BRANDING_PKG_DIR)/debian/rules
	@echo "==> Building linus-branding .deb"
	@mkdir -p dist/packages
	cd $(BRANDING_PKG_DIR) && dpkg-buildpackage -us -uc -b --root-command=fakeroot
	mv $(BRANDING_PKG_DIR)/../linus-branding_$(BRANDING_VERSION)-1_all.deb $(BRANDING_DEB) 2>/dev/null || \
		find $(BRANDING_PKG_DIR)/.. -name 'linus-branding_*.deb' -exec mv {} $(BRANDING_DEB) \;
	@echo "==> $(BRANDING_DEB) ready"

## branding-clean: remove branding build artefacts
branding-clean:
	cd $(BRANDING_PKG_DIR) && dh_clean 2>/dev/null || true
	rm -f $(BRANDING_DEB)
