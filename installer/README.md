# linus Calamares Installer

Branded Calamares graphical installer for linus. Ships as the
`calamares-settings-linus` Debian package; intended for the live image only.

## Config layout

All files under `installer/calamares/` are installed to `/etc/calamares/`:

```
/etc/calamares/
  settings.conf                        — module sequence, global flags
  branding/linus/
    branding.desc                      — product name, URLs, images, sidebar colours
    show.qml                           — slideshow shown during copy phase
    linus-logo.svg                     — sidebar logo (from branding/icons/)
    linus-icon.svg                     — window icon (32 px variant)
  modules/
    welcome.conf                       — pre-flight checks (disk space, internet opt-out)
    locale.conf / localecfg.conf       — timezone detection + /etc/locale.gen write
    keyboard.conf                      — keyboard model/layout selector
    partition.conf                     — partitioning UI (auto, manual, alongside)
    mount.conf                         — mount point mapping after partitioning
    unpackfs.conf                      — unsquash /run/live/medium squashfs → target
    machineid.conf                     — regenerate /etc/machine-id
    fstab.conf                         — write /etc/fstab
    luksbootkeyfile.conf               — add a LUKS key-file for the initramfs
    luksopenswaphookcfg.conf           — configure dracut/initramfs LUKS open hook
    initcfg.conf                       — update-initramfs for the target kernel
    grubcfg.conf                       — write /etc/default/grub
    bootloader.conf                    — grub-install (UEFI: ESP, BIOS: MBR)
    packages.conf                      — remove live-only packages from target
    networkcfg.conf                    — copy live NetworkManager state
    hwclock.conf                       — set RTC to UTC
    users.conf                         — create user, set password + sudo
    services-systemd.conf              — enable/disable systemd units
    shellprocess@post-install.conf     — run installer/hooks/post-install.sh in chroot
    shellprocess@live-cleanup.conf     — remove calamares-settings-linus from target
    summary.conf / finished.conf       — summary page, completion page
```

## Install sequence

1. **Show pages**: `welcome → locale → keyboard → partition → users → summary`
2. **Exec modules** (in order above): partition, mount, unpackfs, system config, users,
   bootloader, post-install hook, live-cleanup, umount.
3. **Finished page**: offers reboot.

## UEFI vs BIOS

`bootloader.conf` sets `efi-entry-name: linus` and uses `grub-install` for both
firmware types. Calamares detects the firmware at runtime; no manual switch needed.

## LUKS (optional full-disk encryption)

Selecting "Encrypt disk" in the partition page activates the LUKS flow:
- `partition` module creates a LUKS container and opens it.
- `luksbootkeyfile` adds a key-file to the initramfs so the unlock prompt only
  appears once (during boot, not on every kernel update).
- `luksopenswaphookcfg` wires the swap partition to the same LUKS volume.
- `initcfg` regenerates initramfs with the LUKS key embedded.

## Offline install

`unpackfs.conf` sources `/run/live/medium/live/filesystem.squashfs` — the same
squashfs the live session booted from. No network is required or used.

## Post-install hook

`installer/hooks/post-install.sh` runs inside the target chroot and:
1. Writes `/etc/greetd/config.toml` (cage → gtkgreet, linus-branding CSS).
2. Writes `/etc/greetd/environments` (mantle, sway, bash).
3. Creates the `greeter` system user if missing.
4. Removes live-session `.desktop` files and service units from the target.
5. Verifies `/usr/share/wayland-sessions/linus.desktop` exists (installation
   fails loudly if the session entry is absent).

## Live-environment protection

`shellprocess@live-cleanup` runs **after** `umount`, so it operates on the live
system, not the target. It removes `calamares-settings-linus` and its live-only
launchers so a failed or cancelled install leaves the live desktop intact.

## Building the package

```bash
make installer-deb   # produces dist/packages/calamares-settings-linus_1.0.0_all.deb
make installer-check # YAML + shell syntax validation only
```

Requires `branding/icons/` to be present in the repo root (provided by the
`branding` stream).
