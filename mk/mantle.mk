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

.PHONY: mantle-deb mantle-fallback-deb mantle-clean

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
	EXTRA="pipewire, wireplumber, network-manager, upower, xdg-desktop-portal, xdg-desktop-portal-wlr"; \
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
