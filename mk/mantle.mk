# mk/mantle.mk — clone mantle at mantle.pin, build via Tauri 2, restamp the
# emitted .deb to the linus version scheme, augment runtime Depends, run lintian.
#
# Included by the root Makefile via -include mk/*.mk
#
# Targets
#   mantle-deb          primary: clone → npm ci → tauri:build → repack → lintian
#   mantle-fallback-deb fallback: dpkg-deb from binary + hand-authored control
#   mantle-clean        remove build and dist artefacts

MANTLE_REPO      := https://github.com/kevinthelago/mantle.git
MANTLE_PIN_FILE  := mantle.pin
MANTLE_BUILD_DIR := dist/.build/mantle-src
MANTLE_STAGE_DIR := dist/.stage/mantle-repack
MANTLE_DIST_DIR  := dist/packages
MANTLE_PKG_DIR   := packaging/mantle
# Tauri stamps a bare "mantle" as Maintainer, which lintian rejects
# (malformed-contact). The repack rewrites it to this and reuses it for the
# generated changelog trailer.
MANTLE_MAINTAINER := linus project <linus@example.com>

.PHONY: mantle-deb mantle-fallback-deb mantle-clean

# Hook into the apt.mk aggregate so `make packages` includes the mantle .deb.
packages: mantle-deb

## mantle-deb: clone mantle at mantle.pin, build via npm/Tauri, restamp, run lintian
mantle-deb:
	@set -e; \
	test -f $(MANTLE_PIN_FILE) || { echo "ERROR: $(MANTLE_PIN_FILE) missing"; exit 1; }; \
	PIN=$$(cat $(MANTLE_PIN_FILE) | tr -d '[:space:]'); \
	test -n "$$PIN" || { echo "ERROR: $(MANTLE_PIN_FILE) is empty"; exit 1; }; \
	SHORT=$$(echo "$$PIN" | cut -c1-7); \
	\
	echo "==> Cloning kevinthelago/mantle at $$PIN"; \
	rm -rf $(MANTLE_BUILD_DIR); \
	mkdir -p dist/.build; \
	git clone --no-tags $(MANTLE_REPO) $(MANTLE_BUILD_DIR); \
	git -C $(MANTLE_BUILD_DIR) checkout "$$PIN"; \
	\
	echo "==> npm ci"; \
	(cd $(MANTLE_BUILD_DIR) && npm ci); \
	echo "==> npm run tauri:build"; \
	(cd $(MANTLE_BUILD_DIR) && npm run tauri:build) || { \
		echo "ERROR: mantle build failed — see output above; no artifact produced"; \
		exit 1; \
	}; \
	\
	echo "==> Locating Tauri .deb bundle"; \
	TAURI_DEB=$$(find $(MANTLE_BUILD_DIR)/src-tauri/target/release/bundle/deb \
	                  -name 'mantle_*_amd64.deb' 2>/dev/null | head -1); \
	if [ -z "$$TAURI_DEB" ]; then \
		echo "WARN: Tauri .deb not found — activating dpkg-deb fallback"; \
		$(MAKE) mantle-fallback-deb; \
		exit 0; \
	fi; \
	echo "==> Found: $$TAURI_DEB"; \
	\
	UPSTREAM_VER=$$(dpkg-deb -f "$$TAURI_DEB" Version | tr -d '[:space:]'); \
	LINUS_VER="$${UPSTREAM_VER}~linus1+$$SHORT"; \
	echo "==> Restamping $$UPSTREAM_VER -> $$LINUS_VER"; \
	\
	rm -rf $(MANTLE_STAGE_DIR); \
	mkdir -p $(MANTLE_STAGE_DIR)/DEBIAN; \
	dpkg-deb --extract "$$TAURI_DEB" $(MANTLE_STAGE_DIR); \
	dpkg-deb --control "$$TAURI_DEB" $(MANTLE_STAGE_DIR)/DEBIAN; \
	\
	sed -i "s|^Version:.*|Version: $$LINUS_VER|" $(MANTLE_STAGE_DIR)/DEBIAN/control; \
	\
	if ! grep -q '^Section:' $(MANTLE_STAGE_DIR)/DEBIAN/control; then \
		echo "==> Injecting Section (Tauri omits it; reprepro refuses such packages)"; \
		sed -i '/^Package:/a Section: x11' $(MANTLE_STAGE_DIR)/DEBIAN/control; \
	fi; \
	\
	echo "==> Normalising Maintainer (Tauri emits a bare name; lintian: malformed-contact)"; \
	sed -i "s|^Maintainer:.*|Maintainer: $(MANTLE_MAINTAINER)|" $(MANTLE_STAGE_DIR)/DEBIAN/control; \
	\
	echo "==> Adding changelog + copyright (Tauri ships neither; lintian refuses)"; \
	mkdir -p $(MANTLE_STAGE_DIR)/usr/share/doc/mantle; \
	printf 'mantle (%s) trixie; urgency=medium\n\n  * linus repack of mantle at %s.\n\n -- %s  %s\n' \
		"$$LINUS_VER" "$$PIN" "$(MANTLE_MAINTAINER)" "$$(date -R)" \
		| gzip -9n > $(MANTLE_STAGE_DIR)/usr/share/doc/mantle/changelog.gz; \
	printf 'Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/\nUpstream-Name: mantle\nSource: %s\n\nFiles: *\nCopyright: mantle authors\nLicense: MIT\n\nFiles: debian/*\nCopyright: linus project\nLicense: MIT\n' \
		"$(MANTLE_REPO)" > $(MANTLE_STAGE_DIR)/usr/share/doc/mantle/copyright; \
	\
	EXTRA="libc6, pipewire, wireplumber, network-manager, upower, xdg-desktop-portal, xdg-desktop-portal-wlr"; \
	ORIG=$$(dpkg-deb -f "$$TAURI_DEB" Depends | tr -d '\n'); \
	if [ -n "$$ORIG" ]; then \
		sed -i "s|^Depends:.*|Depends: $$ORIG, $$EXTRA|" $(MANTLE_STAGE_DIR)/DEBIAN/control; \
	elif grep -q '^Depends:' $(MANTLE_STAGE_DIR)/DEBIAN/control; then \
		sed -i "s|^Depends:.*|Depends: $$EXTRA|" $(MANTLE_STAGE_DIR)/DEBIAN/control; \
	else \
		printf 'Depends: libwebkit2gtk-4.1-0, libayatana-appindicator3-1, %s\n' "$$EXTRA" \
		       >> $(MANTLE_STAGE_DIR)/DEBIAN/control; \
	fi; \
	\
	if ! find $(MANTLE_STAGE_DIR)/usr/share/icons -name 'mantle*' 2>/dev/null | grep -q .; then \
		echo "==> Injecting icons (Tauri bundle.icon was empty)"; \
		mkdir -p \
			$(MANTLE_STAGE_DIR)/usr/share/icons/hicolor/32x32/apps \
			$(MANTLE_STAGE_DIR)/usr/share/icons/hicolor/128x128/apps \
			$(MANTLE_STAGE_DIR)/usr/share/icons/hicolor/256x256/apps; \
		cp $(MANTLE_BUILD_DIR)/src-tauri/icons/icon_32x32.png \
		   $(MANTLE_STAGE_DIR)/usr/share/icons/hicolor/32x32/apps/mantle.png; \
		cp $(MANTLE_BUILD_DIR)/src-tauri/icons/icon_128x128.png \
		   $(MANTLE_STAGE_DIR)/usr/share/icons/hicolor/128x128/apps/mantle.png; \
		cp $(MANTLE_BUILD_DIR)/src-tauri/icons/icon_256x256.png \
		   $(MANTLE_STAGE_DIR)/usr/share/icons/hicolor/256x256/apps/mantle.png; \
	fi; \
	\
	(cd $(MANTLE_STAGE_DIR) && \
		find . -path './DEBIAN' -prune -o -type f -print \
		       | sed 's|^\./||' \
		       | while read f; do md5sum "$$f"; done \
		> DEBIAN/md5sums); \
	\
	mkdir -p $(MANTLE_DIST_DIR); \
	OUT="$(MANTLE_DIST_DIR)/mantle_$${LINUS_VER}_amd64.deb"; \
	echo "==> Packing $$OUT"; \
	dpkg-deb --build --root-owner-group $(MANTLE_STAGE_DIR) "$$OUT"; \
	\
	echo "==> Running lintian"; \
	LINT_OUT=$$(lintian --tag-display-limit 0 "$$OUT" 2>&1) || true; \
	echo "$$LINT_OUT"; \
	if echo "$$LINT_OUT" | grep -q '^E:'; then \
		echo "ERROR: lintian found blocking errors in $$OUT"; exit 1; \
	fi; \
	echo "==> $$OUT ready"

## mantle-fallback-deb: dpkg-deb fallback — wraps target/release/mantle + hand-authored control
mantle-fallback-deb:
	@set -e; \
	test -f $(MANTLE_PIN_FILE) || { echo "ERROR: $(MANTLE_PIN_FILE) missing"; exit 1; }; \
	PIN=$$(cat $(MANTLE_PIN_FILE) | tr -d '[:space:]'); \
	SHORT=$$(echo "$$PIN" | cut -c1-7); \
	\
	BIN=$(MANTLE_BUILD_DIR)/src-tauri/target/release/mantle; \
	test -f "$$BIN" || { \
		echo "ERROR: binary not found at $$BIN"; \
		echo "       Run mantle-deb (or a prior build step) before mantle-fallback-deb"; \
		exit 1; \
	}; \
	\
	UPVER=$$(grep '"version"' $(MANTLE_BUILD_DIR)/package.json \
	         | sed 's/.*"version": "\([^"]*\)".*/\1/' | tr -d '[:space:]' | head -1); \
	test -n "$$UPVER" || UPVER="0.0.0"; \
	LINUS_VER="$${UPVER}~linus1+$$SHORT"; \
	echo "==> Fallback: assembling mantle_$${LINUS_VER}_amd64.deb from binary"; \
	\
	STAGE="$(MANTLE_STAGE_DIR)-fallback"; \
	rm -rf "$$STAGE"; \
	mkdir -p \
		"$$STAGE/DEBIAN" \
		"$$STAGE/usr/bin" \
		"$$STAGE/usr/share/applications"; \
	\
	install -m 755 "$$BIN" "$$STAGE/usr/bin/mantle"; \
	cp $(MANTLE_PKG_DIR)/fallback/usr/share/applications/mantle.desktop \
	   "$$STAGE/usr/share/applications/mantle.desktop"; \
	\
	ICONS_SRC=$(MANTLE_BUILD_DIR)/src-tauri/icons; \
	mkdir -p \
		"$$STAGE/usr/share/icons/hicolor/32x32/apps" \
		"$$STAGE/usr/share/icons/hicolor/128x128/apps" \
		"$$STAGE/usr/share/icons/hicolor/256x256/apps"; \
	cp "$$ICONS_SRC/icon_32x32.png"    "$$STAGE/usr/share/icons/hicolor/32x32/apps/mantle.png"; \
	cp "$$ICONS_SRC/icon_128x128.png"  "$$STAGE/usr/share/icons/hicolor/128x128/apps/mantle.png"; \
	cp "$$ICONS_SRC/icon_256x256.png"  "$$STAGE/usr/share/icons/hicolor/256x256/apps/mantle.png"; \
	\
	sed "s/@VERSION@/$$LINUS_VER/" $(MANTLE_PKG_DIR)/fallback/DEBIAN/control \
	    > "$$STAGE/DEBIAN/control"; \
	\
	(cd "$$STAGE" && \
		find . -path './DEBIAN' -prune -o -type f -print \
		       | sed 's|^\./||' \
		       | while read f; do md5sum "$$f"; done \
		> DEBIAN/md5sums); \
	\
	mkdir -p $(MANTLE_DIST_DIR); \
	OUT="$(MANTLE_DIST_DIR)/mantle_$${LINUS_VER}_amd64.deb"; \
	echo "==> Packing fallback $$OUT"; \
	dpkg-deb --build --root-owner-group "$$STAGE" "$$OUT"; \
	\
	echo "==> Running lintian (warnings allowed on fallback path)"; \
	lintian --tag-display-limit 0 "$$OUT" 2>&1 || true; \
	echo "==> Fallback: $$OUT ready"

## mantle-clean: remove mantle build and dist artefacts
mantle-clean:
	@rm -rf $(MANTLE_BUILD_DIR) $(MANTLE_STAGE_DIR) "$(MANTLE_STAGE_DIR)-fallback"; \
	find $(MANTLE_DIST_DIR) -name 'mantle_*.deb' -delete 2>/dev/null || true; \
	echo "==> mantle artefacts cleaned"
