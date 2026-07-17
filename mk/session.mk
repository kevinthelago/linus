# mk/session.mk — build the linus-session Debian package.
# Include from the root Makefile with: include mk/session.mk

SESSION_VERSION  ?= 0.1.0
SESSION_PKG       = linus-session
SESSION_STAGEDIR  = dist/.stage/$(SESSION_PKG)
SESSION_DEB       = dist/packages/$(SESSION_PKG)_$(SESSION_VERSION)_all.deb

.PHONY: session session-stage session-clean

session: $(SESSION_DEB)

$(SESSION_DEB): session-stage
	@mkdir -p dist/packages
	dpkg-deb --build --root-owner-group $(SESSION_STAGEDIR) $@
	@echo "Built: $@"

session-stage: packaging/session/linus-session/DEBIAN/control
	@rm -rf $(SESSION_STAGEDIR)
	@mkdir -p \
		$(SESSION_STAGEDIR)/DEBIAN \
		$(SESSION_STAGEDIR)/usr/bin \
		$(SESSION_STAGEDIR)/usr/lib/linus \
		$(SESSION_STAGEDIR)/usr/share/wayland-sessions \
		$(SESSION_STAGEDIR)/usr/share/xdg-desktop-portal/portals \
		$(SESSION_STAGEDIR)/etc/sway/config.d \
		$(SESSION_STAGEDIR)/etc/hypr \
		$(SESSION_STAGEDIR)/etc/skel/.config/mantle \
		$(SESSION_STAGEDIR)/etc/mantle

	# DEBIAN control files
	cp packaging/session/linus-session/DEBIAN/control  $(SESSION_STAGEDIR)/DEBIAN/control
	cp packaging/session/linus-session/DEBIAN/postinst $(SESSION_STAGEDIR)/DEBIAN/postinst
	cp packaging/session/linus-session/DEBIAN/prerm    $(SESSION_STAGEDIR)/DEBIAN/prerm
	chmod 755 $(SESSION_STAGEDIR)/DEBIAN/postinst $(SESSION_STAGEDIR)/DEBIAN/prerm

	# Session entries (/usr/share/wayland-sessions/)
	cp session/linus.desktop              $(SESSION_STAGEDIR)/usr/share/wayland-sessions/
	cp session/linus-plain-sway.desktop   $(SESSION_STAGEDIR)/usr/share/wayland-sessions/
	cp session/linus-hyprland.desktop     $(SESSION_STAGEDIR)/usr/share/wayland-sessions/

	# Public session commands to /usr/bin/ (names match the session entry Exec fields
	# in the .desktop files and the contract: /usr/bin/linus-session)
	cp session/scripts/linus-session.sh          $(SESSION_STAGEDIR)/usr/bin/linus-session
	cp session/scripts/linus-hyprland-session.sh $(SESSION_STAGEDIR)/usr/bin/linus-hyprland-session
	chmod 755 \
		$(SESSION_STAGEDIR)/usr/bin/linus-session \
		$(SESSION_STAGEDIR)/usr/bin/linus-hyprland-session

	# Internal helpers stay in /usr/lib/linus/
	cp session/scripts/mantle-watchdog.sh        $(SESSION_STAGEDIR)/usr/lib/linus/
	cp session/scripts/mantle-watchdog-hypr.sh   $(SESSION_STAGEDIR)/usr/lib/linus/
	chmod 755 \
		$(SESSION_STAGEDIR)/usr/lib/linus/mantle-watchdog.sh \
		$(SESSION_STAGEDIR)/usr/lib/linus/mantle-watchdog-hypr.sh

	# Compositor config drop-ins
	cp session/sway/90-mantle.conf     $(SESSION_STAGEDIR)/etc/sway/config.d/
	cp session/hyprland/mantle.conf    $(SESSION_STAGEDIR)/etc/hypr/

	# XDG portal config (/usr/share/xdg-desktop-portal/portals/)
	cp session/portals/sway.portals        $(SESSION_STAGEDIR)/usr/share/xdg-desktop-portal/portals/
	cp session/portals/Hyprland.portals    $(SESSION_STAGEDIR)/usr/share/xdg-desktop-portal/portals/

	# Default mantle theme — skeleton for new users, plus a system-wide fallback
	# for existing ones.
	#
	# NB: config.toml is deliberately NOT shipped here. linus-branding owns
	# mantle's default config ("default mantle theme tokens and config" per its
	# description) and installs it to these same two paths — shipping it from both
	# packages makes dpkg abort the unpack:
	#   trying to overwrite '/etc/mantle/config.toml', which is also in package
	#   linus-branding
	# Exactly one package must own each file.
	cp session/skel/.config/mantle/theme.toml  $(SESSION_STAGEDIR)/etc/skel/.config/mantle/
	cp session/skel/.config/mantle/theme.toml  $(SESSION_STAGEDIR)/etc/mantle/

session-clean:
	rm -rf $(SESSION_STAGEDIR) $(SESSION_DEB)
