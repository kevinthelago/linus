# mk/apt.mk — build and populate the linus signed apt repository.
#
# Outputs to dist/apt/; served statically (e.g. GitHub Pages).
# GPG signing: set GPG_SIGNING_KEY to the ASCII-armored private key in CI.
# Locally the repo builds unsigned with a warning.
#
# Targets:
#   apt-repo            populate dist/apt/ from dist/packages/*.deb
#   apt-repo-clean      remove dist/apt/
#   backport-hyprland   build hyprland .debs via backports/hyprland/recipe.sh

DIST_APT     := dist/apt
APT_CONF_SRC := apt/conf
PACKAGES_DIR := dist/packages
SNAPSHOT     := 20260601T000000Z
SNAPSHOT_URL := http://snapshot.debian.org/archive/debian/$(SNAPSHOT)

.PHONY: apt-repo apt-repo-clean backport-hyprland

# --------------------------------------------------------------------------- #
# apt-repo: seed the repository config then include all built .deb files.
# --------------------------------------------------------------------------- #

apt-repo: $(DIST_APT)/conf/distributions
	@echo "==> Populating apt repository ($(DIST_APT))..."
	@count=0; \
	if ls $(PACKAGES_DIR)/*.deb 1>/dev/null 2>&1; then \
		for deb in $(PACKAGES_DIR)/*.deb; do \
			echo "    + $$deb"; \
			reprepro --basedir $(DIST_APT) includedeb trixie "$$deb"; \
			count=$$((count + 1)); \
		done; \
		echo "==> Added $${count} package(s) to the apt repository."; \
	else \
		echo "    No .deb files found in $(PACKAGES_DIR)/ — repository is empty."; \
	fi
	@echo "==> apt repository ready at $(DIST_APT)/"

# Seed the repo config directory. Strip SignWith when no key is available so
# reprepro doesn't fail; warn loudly so CI catches a misconfigured job.
$(DIST_APT)/conf/distributions: $(APT_CONF_SRC)/distributions
	@mkdir -p $(DIST_APT)/conf
ifdef GPG_SIGNING_KEY
	@echo "==> Importing GPG signing key..."
	@printf '%s' "$(GPG_SIGNING_KEY)" | gpg --batch --import
	@cp $< $@
	@echo "==> Repository will be GPG-signed."
else
	@grep -v '^SignWith:' $< > $@ || cp $< $@
	@printf '\n*** WARNING: GPG_SIGNING_KEY is not set.\n'
	@printf '*** Building UNSIGNED apt repository.\n'
	@printf '*** Set GPG_SIGNING_KEY in CI to produce a signed repo.\n\n'
endif

# --------------------------------------------------------------------------- #
# backport-hyprland: build hyprland and ecosystem from Debian sid source.
# Requires a privileged build environment (root / build container).
# --------------------------------------------------------------------------- #

backport-hyprland:
	@echo "==> Running Hyprland backport recipe..."
	LINUS_DIST_PACKAGES=$(PACKAGES_DIR) bash backports/hyprland/recipe.sh

# --------------------------------------------------------------------------- #

apt-repo-clean:
	rm -rf $(DIST_APT)
