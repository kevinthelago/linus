# mk/iso.mk — ISO build pipeline (live-build wrapper)
#
# Targets:
#   iso         Full build: clean + config + build  (requires root/loop devices)
#   iso-config  Run lb config only
#   iso-build   Run lb build only (requires root)
#   iso-clean   Purge live-build artifacts
#   iso-size    Report ISO size vs the size budget
#
# Environment variables:
#   SNAPSHOT_DATE    Pinned Debian snapshot date (default: 20260601T000000Z)
#   LINUS_REPO_URL   APT URL for the linus repo (optional; local dist/repo used if present)
#   ISO_LB_EXTRA     Extra args forwarded verbatim to lb config noauto

SNAPSHOT_DATE      ?= 20260601T000000Z
DIST_DIR           := dist

# ISO size budget in MiB — tracked and surfaced as a warning; adjust as the image grows.
ISO_SIZE_BUDGET_MIB := 2048

# Detect a local linus apt repo built by the packaging stream.
_LOCAL_REPO := $(abspath $(DIST_DIR)/repo)
_LINUS_REPO_URL ?= $(if $(LINUS_REPO_URL),$(LINUS_REPO_URL),\
    $(if $(wildcard $(_LOCAL_REPO)/conf/distributions),file://$(_LOCAL_REPO),))

.PHONY: iso iso-config iso-build iso-clean iso-size

iso: iso-clean iso-config iso-build ## Build the linus live ISO (requires root/loop devices)

iso-config: ## Configure live-build (reads config/auto/config)
	@echo "[iso] Configuring (snapshot=$(SNAPSHOT_DATE))"
	@mkdir -p $(DIST_DIR)
	SNAPSHOT_DATE=$(SNAPSHOT_DATE) LINUS_REPO_URL='$(_LINUS_REPO_URL)' lb config $(ISO_LB_EXTRA)

iso-build: ## Assemble the ISO (run as root: sudo make iso-build)
	@echo "[iso] Building..."
	lb build
	@if [ -f binary.hybrid.iso ]; then \
	    mkdir -p $(DIST_DIR); \
	    cp binary.hybrid.iso $(DIST_DIR)/linus.iso; \
	    echo "[iso] Written to $(DIST_DIR)/linus.iso"; \
	    $(MAKE) iso-size; \
	else \
	    echo "[iso] ERROR: binary.hybrid.iso not produced — check lb build output"; \
	    exit 1; \
	fi

iso-clean: ## Purge all live-build artifacts (chroot, binary, cache)
	@echo "[iso] Cleaning..."
	@lb clean --purge 2>/dev/null || true
	@rm -f binary.hybrid.iso $(DIST_DIR)/linus.iso

iso-size: ## Report ISO size against the $(ISO_SIZE_BUDGET_MIB) MiB budget
	@if [ -f $(DIST_DIR)/linus.iso ]; then \
	    SIZE_MIB=$$(du -m $(DIST_DIR)/linus.iso | cut -f1); \
	    echo "[iso] Size: $${SIZE_MIB} MiB / $(ISO_SIZE_BUDGET_MIB) MiB budget"; \
	    if [ "$$SIZE_MIB" -gt "$(ISO_SIZE_BUDGET_MIB)" ]; then \
	        echo "[iso] WARNING: ISO exceeds size budget — trim the package list"; \
	    fi; \
	else \
	    echo "[iso] $(DIST_DIR)/linus.iso not found"; \
	fi
