kind: script

# Board-specific live ISO for the Lenovo ThinkPad X13s (Qualcomm SC8280XP).
# Based on gnomeos/live-image.bst, with additions for:
#   - X13s kernel args (arm64.nopauth, clk_ignore_unused, pd_ignore_unused,
#     modprobe.blacklist=qcom_q6v5_pas, efi=noruntime) via a cmdline addon EFI
#   - X13s DTB (sc8280xp-lenovo-thinkpad-x13s.dtb) embedded in the addon EFI
#
# The addon EFI is loaded by systemd-boot alongside the gnomeos UKI and appends
# board-specific args/DTB on top of the UKI's embedded cmdline.

build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/jq.bst
- freedesktop-sdk.bst:components/systemd.bst
- freedesktop-sdk.bst:components/systemd-ukify.bst
- freedesktop-sdk.bst:components/dosfstools.bst
- freedesktop-sdk.bst:components/mtools.bst
- freedesktop-sdk.bst:components/util-linux.bst
- gnomeos-deps/libisoburn.bst
- gnomeos/repart-config-iso.bst
- filename: gnomeos/usr/image.bst
  config:
    location: '/usr-image'
- filename: gnomeos/signed-boot.bst
  config:
    location: '/sysroot'
- filename: gnomeos/signed-boot-common.bst
  config:
    location: '/sysroot'
- filename: gnomeos/os-release.bst
  config:
    location: '/sysroot'
- filename: freedesktop-sdk.bst:components/linux.bst
  config:
    location: '/kernel'

variables:
  repart-seed: 3b9a2c1d-4e5f-6a7b-8c9d-0e1f2a3b4c5d
  x13s-kargs: >-
    arm64.nopauth
    clk_ignore_unused
    pd_ignore_unused
    modprobe.blacklist=qcom_q6v5_pas
    efi=noruntime

config:
  commands:
  - mkdir -p definitions
  - |
    cp /usr/lib/repart.iso.d/*.conf definitions/

  - |
    # Build the X13s cmdline+DTB addon EFI. This is loaded by systemd-boot
    # alongside the gnomeos UKI and appends X13s hardware requirements.
    # The DTB is embedded so the correct device tree is always used.
    extra_d="$(echo /sysroot/efi/EFI/Linux/gnomeos_*.efi.extra.d)"
    mkdir -p "${extra_d}"
    ukify build \
      --cmdline="%{x13s-kargs}" \
      --devicetree="/kernel/boot/dtbs/qcom/sc8280xp-lenovo-thinkpad-x13s.dtb" \
      --output="${extra_d}/x13s.addon.efi"

  - |
    # Keep only the live boot addon and our X13s addon; remove all others
    # (e.g. apparmor.addon.efi, nvidia.addon.efi from signed-boot.bst)
    for extra in /sysroot/efi/EFI/Linux/gnomeos_*.efi.extra.d/*; do
      case "${extra}" in
        */live.addon.efi|*/x13s.addon.efi)
          # keep root=live:gnomeos and X13s hardware args
          ;;
        *)
          rm -rf "${extra}"
          ;;
      esac
    done

  - |
    # Make a removable-media ESP: remove fallback/MOK EFIs that would try to
    # register boot entries or enroll secure boot keys on the host.
    rm -rf /sysroot/efi/EFI/org.gnome.os
    rm -f  /sysroot/efi/EFI/BOOT/fb*.efi
    rm -f  /sysroot/efi/EFI/BOOT/mm*.efi
    rm -rf /sysroot/efi/loader/keys

  - mkdir -p /var/tmp /build

  - |
    mv /usr-image/mini.usr.raw /sysroot/
    mv /usr-image/mini.usr-verity.raw /sysroot/

  - |
    usr_uuid=$(jq -r '.[0].uuid' /usr-image/mini.repart.json)
    usr_verity_uuid=$(jq -r '.[1].uuid' /usr-image/mini.repart.json)
    cat <<EOF >>definitions/21-usr.conf
    UUID=${usr_uuid}
    EOF
    cat <<EOF >>definitions/20-usr-verity.conf
    UUID=${usr_verity_uuid}
    EOF

  - |
    SYSTEMD_LOG_LEVEL=debug \
      systemd-repart \
        --sector-size=512 \
        --definitions=definitions \
        --empty=create \
        --dry-run=no \
        --size=auto \
        --discard=no \
        --offline=true \
        --no-pager \
        --seed=%{repart-seed} \
        --root=/sysroot \
        --split=true \
        /build/disk.raw \
        --json=pretty \
        >'/build/disk.repart.json'

  - mkdir -p /build/iso-root

  - mv /build/disk.esp.raw /build/iso-root/esp.img

  - |
    xorrisofs -o "/build/image.iso" /build/iso-root \
      -partition_offset 480 \
      -e /esp.img -no-emul-boot -boot-load-size 4 -efi-boot-part --efi-boot-image \
      -sysid LINUX -publisher GNOME \
      -volid "X13S-GNOMEOS"

  - |
    dd if=/build/image.iso of=/build/disk.raw bs=2048 skip=16 count=496 seek=16 conv=notrunc

  - |
    esp_raw_size=$(jq -r '.[]|select(.type=="esp").raw_size' /build/disk.repart.json)
    esp_offset=$(jq -r '.[]|select(.type=="esp").offset' /build/disk.repart.json)
    skip=$(((${esp_offset}+${esp_raw_size})/512))
    dd if=/build/image.iso of=/build/disk.raw bs=512 skip="${skip}" seek="${skip}" count=608 conv=notrunc

  - mv /build/disk.raw "%{install-root}/disk.iso"
