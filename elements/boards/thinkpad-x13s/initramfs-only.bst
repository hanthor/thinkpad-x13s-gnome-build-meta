kind: script

# Extracts only /usr/lib/modules/<version>/initramfs.img from gnomeos/initramfs.bst
# without including the /efi/ tree that would conflict with gnomeos/signed-boot-common.bst
# (which is pulled in via gnomeos/usr/deps.bst and also outputs /efi/ files).
#
# ostree admin deploy needs initramfs.img alongside vmlinuz in /usr/lib/modules/.

build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- gnomeos/initramfs.bst

config:
  commands:
  - |
    version="$(ls -1 /usr/lib/modules | head -n1)"
    mkdir -p "%{install-root}/usr/lib/modules/${version}"
    cp "/usr/lib/modules/${version}/initramfs.img" \
       "%{install-root}/usr/lib/modules/${version}/initramfs.img"
