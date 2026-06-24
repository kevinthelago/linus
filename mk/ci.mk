DIST        ?= dist
ISO         ?= $(DIST)/linus.iso
SMOKE_BIN   ?= tools/smoke-boot/target/release/smoke-boot
BOOT_TIMEOUT ?= 300

# Markers expected on the serial console (greeter + mantle session)
BOOT_MARKERS ?= --marker "greetd" --marker "mantle"

.PHONY: ci-build ci-test ci-lint ci-smoke ci-sign ci-checksums

ci-build:
	$(MAKE) packages apt-repo iso

$(SMOKE_BIN):
	cargo build --manifest-path tools/smoke-boot/Cargo.toml --release

ci-lint:
	lintian --fail-on error $(DIST)/*.deb

ci-smoke: $(SMOKE_BIN) $(ISO)
	$(SMOKE_BIN) --iso $(ISO) --timeout $(BOOT_TIMEOUT) $(BOOT_MARKERS)

ci-test: ci-lint ci-smoke

ci-sign: $(ISO)
	printf '%s' "$$GPG_SIGNING_PASSPHRASE" | \
		gpg --batch --yes --pinentry-mode loopback \
		--passphrase-fd 0 \
		--detach-sign --armor $(ISO)

ci-checksums: $(ISO)
	sha256sum $(ISO) > $(DIST)/SHA256SUMS
	printf '%s' "$$GPG_SIGNING_PASSPHRASE" | \
		gpg --batch --yes --pinentry-mode loopback \
		--passphrase-fd 0 \
		--detach-sign --armor $(DIST)/SHA256SUMS
