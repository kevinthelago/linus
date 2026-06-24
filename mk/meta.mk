# mk/meta.mk — build the linus-desktop meta Debian package.
#
# Source: packaging/meta/  (standard debian/ layout)
# Output: dist/packages/linus-desktop_<version>_all.deb
#
# Targets:
#   meta-package        build and lintian-check linus-desktop.deb
#   meta-package-clean  remove linus-desktop artifacts from dist/packages/

META_SRC     := packaging/meta
PACKAGES_DIR := dist/packages

META_VERSION := $(shell dpkg-parsechangelog \
    -l $(META_SRC)/debian/changelog -S Version 2>/dev/null || echo "1.0.0-1")

META_DEB     := $(PACKAGES_DIR)/linus-desktop_$(META_VERSION)_all.deb

.PHONY: meta-package meta-package-clean

# --------------------------------------------------------------------------- #

meta-package: $(META_DEB)

$(META_DEB): $(META_SRC)/debian/control \
             $(META_SRC)/debian/changelog \
             $(META_SRC)/debian/rules \
             $(META_SRC)/debian/copyright
	@mkdir -p $(PACKAGES_DIR)
	@echo "==> Building linus-desktop $(META_VERSION)..."
	cd $(META_SRC) && dpkg-buildpackage -us -uc -b --no-pre-clean
	@# dpkg-buildpackage writes artifacts to packaging/ (parent of meta/).
	find packaging -maxdepth 1 \
	    \( -name "linus-desktop_*.deb" \
	    -o -name "linus-desktop_*.buildinfo" \
	    -o -name "linus-desktop_*.changes" \) \
	    -exec mv {} $(PACKAGES_DIR)/ \;
	@echo "==> Running lintian..."
	lintian "$(META_DEB)"
	@echo "==> linus-desktop $(META_VERSION) is lintian-clean."

# --------------------------------------------------------------------------- #

meta-package-clean:
	rm -f $(PACKAGES_DIR)/linus-desktop_*.deb \
	      $(PACKAGES_DIR)/linus-desktop_*.buildinfo \
	      $(PACKAGES_DIR)/linus-desktop_*.changes
