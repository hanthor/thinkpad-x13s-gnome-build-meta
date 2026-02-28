kind: ostree

build-depends:
- freedesktop-sdk.bst:vm/prepare-image.bst
- freedesktop-sdk.bst:components/ostree.bst
- boards/thinkpad-x13s/initial-scripts.bst
- filename: boards/thinkpad-x13s/filesystem.bst
  config:
    sysroot: true

variables:
  # Unique UUID for x13s filesystem
  uuidnamespace: bea54278-2587-4075-ae67-8688ace4ce3e
  sysroot: '%{build-root}/sysroot'
  ostree-branch: gnome-os/aarch64/thinkpad-x13s

config:
  ostree-branch: '%{ostree-branch}'
  initial-commands:
  - |
    prepare-image.sh \
       --sysroot %{sysroot} \
       --seed "%{uuidnamespace}" \
       --rootpasswd root \
       --rootsource LABEL=root \
       --efisource LABEL=EFI \
       --efipath /boot >/dev/null

  - mv %{sysroot}/etc %{sysroot}/usr/etc
