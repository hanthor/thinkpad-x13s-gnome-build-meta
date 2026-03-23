kind: ostree

build-depends:
- freedesktop-sdk.bst:vm/prepare-image.bst
- freedesktop-sdk.bst:components/ostree.bst
- boards/thinkpad-x13s/initial-scripts.bst
- filename: boards/thinkpad-x13s/filesystem.bst
  config:
    sysroot: true

variables:
  uuidnamespace: 48ebbf46-0855-4ab6-807c-6badcd9efbac
  sysroot: '%{build-root}/sysroot'
  ostree-branch: gnome-os/aarch64/thinkpad-x13s

config:
  ostree-branch: '%{ostree-branch}'
  initial-commands:
  - |
    # Wrap setcap to be non-fatal in environments without CAP_SETFCAP.
    # BST's bwrap sandbox drops all capabilities by default; shadow's integration
    # script calls setcap which fails on restricted CI runners (e.g. GitHub Actions).
    # Replace setcap with a shim that logs a warning instead of failing.
    _real_setcap=$(command -v setcap 2>/dev/null || true)
    if [ -n "${_real_setcap}" ] && ! "${_real_setcap}" cap_kill+ep /dev/null 2>/dev/null; then
      mv "${_real_setcap}" "${_real_setcap}.real"
      printf '#!/bin/sh\n"%s.real" "$@" 2>/dev/null || echo "WARNING: setcap skipped (no CAP_SETFCAP)" >&2\n' \
        "${_real_setcap}" > "${_real_setcap}"
      chmod +x "${_real_setcap}"
    fi
    prepare-image.sh \
       --sysroot %{sysroot} \
       --seed "%{uuidnamespace}" \
       --rootpasswd root \
       --rootsource LABEL=root \
       --efisource LABEL=EFI \
       --efipath /boot >/dev/null

  - mv %{sysroot}/etc %{sysroot}/usr/etc
