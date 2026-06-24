# mk/apt.mk — build and populate the linus signed apt repository.
#
# Outputs to dist/apt/; served statically (e.g. GitHub Pages).
#
# GPG signing:
#   Set LINUS_GPG_KEY to a key fingerprint that is already in the local keyring.
#   Alternatively GPG_SIGNING_KEY (the CI secret) is accepted as a fallback; if
#   it looks like ASCII-armored key material, it is imported automatically.
#   Without any signing key the repo builds UNSIGNED with a warning (local dev only).
#
# Snapshot pin:
#   Read from snapshot.pin at the repo root. Update that file to advance the pin.
#
# Targets:
#   apt-repo            populate dist/apt/ from dist/packages/*.deb
#   apt-repo-clean      remove dist/apt/
#   backport-hyprland   build hyprland .debs via backports/hyprland/recipe.sh

DIST_APT     := dist/apt
APT_CONF_SRC := apt/conf
PACKAGES_DIR := dist/packages

# Read snapshot date from snapshot.pin; fall back to a known-good default.
SNAPSHOT     := $(shell cat snapshot.pin 2>/dev/null | tr -d '[:space:]' || echo "20260601T000000Z")
SNAPSHOT_URL := http://snapshot.debian.org/archive/debian/$(SNAPSHOT)/

# Normalise the signing key variable: prefer LINUS_GPG_KEY, accept GPG_SIGNING_KEY.
LINUS_GPG_KEY ?= $(GPG_SIGNING_KEY)

.PHONY: apt-repo apt-repo-clean backport-hyprland

# --------------------------------------------------------------------------- #
# apt-repo: seed the repository config then include all built .deb files.
# --------------------------------------------------------------------------- #

apt-repo: $(DIST_APT)/conf/distributions
	@echo "==> Populating apt repository ($(DIST_APT)) [snapshot: $(SNAPSHOT)]..."
	@count=0; \
	if ls $(PACKAGES_DIR)/*.deb 1>/dev/null 2>&1; then \
		for deb in $(PACKAGES_DIR)/*.deb; do \
			echo "    + $$deb"; \
			reprepro --basedir $(DIST_APT) includedeb trixie "$$deb"; \
			count=$$((count + 1)); \
		done; \
		echo "==> Added $${count} package(s) to the apt repository."; \
	else \
		echo "    No .deb files in $(PACKAGES_DIR)/ — repository will be empty."; \
	fi
	@echo "==> apt repository ready at $(DIST_APT)/"

# Seed the reprepro config directory, wiring in the signing key fingerprint
# when available. Without a key the SignWith line is stripped so reprepro
# does not fail — but the repo is unsigned.
$(DIST_APT)/conf/distributions: $(APT_CONF_SRC)/distributions snapshot.pin
	@mkdir -p $(DIST_APT)/conf
ifdef LINUS_GPG_KEY
	@# If the value looks like ASCII-armored key material, import it first.
	@if printf '%s' "$(LINUS_GPG_KEY)" | grep -q "^-----BEGIN PGP"; then \
		echo "==> Importing GPG key material..."; \
		printf '%s' "$(LINUS_GPG_KEY)" | gpg --batch --import; \
	fi
	@sed 's/^SignWith:.*/SignWith: $(LINUS_GPG_KEY)/' $< > $@
	@echo "==> Repository will be GPG-signed (key: $(LINUS_GPG_KEY))."
else
	@grep -v '^SignWith:' $< > $@
	@printf '\n*** WARNING: LINUS_GPG_KEY (or GPG_SIGNING_KEY) is not set.\n'
	@printf '*** Building UNSIGNED apt repository — fine for local dev.\n'
	@printf '*** Set LINUS_GPG_KEY to a key fingerprint to produce a signed repo.\n\n'
endif

# --------------------------------------------------------------------------- #
# backport-hyprland: build hyprland and ecosystem from Debian sid source.
# Requires a privileged build environment (root / build container).
# --------------------------------------------------------------------------- #

backport-hyprland:
	@echo "==> Running Hyprland backport recipe (snapshot: $(SNAPSHOT))..."
	LINUS_DIST_PACKAGES=$(PACKAGES_DIR) \
	SID_SNAPSHOT=http://snapshot.debian.org/archive/debian/$(SNAPSHOT) \
	bash backports/hyprland/recipe.sh

# --------------------------------------------------------------------------- #

apt-repo-clean:
	rm -rf $(DIST_APT)
