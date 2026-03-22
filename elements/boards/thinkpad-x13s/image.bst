kind: script

build-depends:
- boards/thinkpad-x13s/image-deps.bst
- filename: boards/thinkpad-x13s/repo.bst
  config:
    location: '/source-repo'
- filename: freedesktop-sdk.bst:components/linux.bst
  config:
    location: '/kernel'

variables:
  # Linux Root Partition GUID (ARM64)
  linux-root: B921B045-1DF0-41C3-AF44-4C6F280D3FAE
  ostree-branch: gnome-os/aarch64/thinkpad-x13s
  dtb-path: qcom/sc8280xp-lenovo-thinkpad-x13s.dtb

  sysroot: "/sysroot"

environment:
  OSTREE_REPO: "%{sysroot}/ostree/repo"
  XZFLAGS: -T%{max-jobs}

environment-nocache:
- XZFLAGS

config:
  commands:
  - mkdir -p "${OSTREE_REPO}"
  - ostree init --repo="${OSTREE_REPO}" --mode=bare

  - ostree config --group sysroot set bootloader auto
  - ostree pull-local "/source-repo" %{ostree-branch}

  - mkdir -p "%{sysroot}/boot"

  - ostree admin init-fs "%{sysroot}"
  - ostree admin os-init --sysroot="%{sysroot}" gnome-os

  # Deploy with X13s required kernel arguments.
  # modprobe.blacklist=qcom_q6v5_pas ensures pd-mapper registers
  # power domains before the remoteproc driver loads them.
  - |
    ostree admin deploy --os="gnome-os" \
         --sysroot="%{sysroot}" %{ostree-branch} \
         --karg="rw" \
         --karg="root=LABEL=root" \
         --karg="console=tty0" \
         --karg="arm64.nopauth" \
         --karg="clk_ignore_unused" \
         --karg="pd_ignore_unused" \
         --karg="efi=noruntime" \
         --karg="modprobe.blacklist=qcom_q6v5_pas"

  - |
    mkdir -p "%{sysroot}/etc/ostree"
    cp -r "%{sysroot}"/ostree/boot.1/gnome-os/*/*/etc/ostree/remotes.d "%{sysroot}/etc/ostree/remotes.d"

  - |
    ostree admin set-origin --sysroot="%{sysroot}" \
           --index=0 \
           gnome-os dummy \
           %{ostree-branch}

  # Copy EFI binaries (systemd-boot, keys) from the deployed OS
  - cp -r "%{sysroot}"/ostree/boot.1/gnome-os/*/*/boot/EFI/ "%{sysroot}/boot/"

  # Copy the X13s DTB from the kernel build into the EFI partition.
  # BLS entries reference it as /dtb/<dtb-path>.
  - |
    DTB_SRC="/kernel/boot/dtbs/%{dtb-path}"
    if [ ! -f "${DTB_SRC}" ]; then
      echo "ERROR: X13s DTB not found at ${DTB_SRC}"
      echo "Available Qualcomm DTBs:"
      find /kernel/boot/dtbs/qcom -name "*x13s*" -o -name "*sc8280*" 2>/dev/null || true
      exit 1
    fi
    mkdir -p "%{sysroot}/boot/dtb/qcom"
    cp "${DTB_SRC}" "%{sysroot}/boot/dtb/%{dtb-path}"

  # Patch BLS entries to add the devicetree directive so systemd-boot
  # passes the DTB to the kernel on the X13s.
  - |
    for entry in "%{sysroot}"/boot/loader/entries/*.conf; do
      [ -f "${entry}" ] || continue
      if ! grep -q "^devicetree " "${entry}"; then
        echo "devicetree /dtb/%{dtb-path}" >> "${entry}"
      fi
    done

  # Build the disk image: GPT with EFI (FAT) + root (ext4) partitions.
  - |
    size=$(($(du -s -B 4K "%{sysroot}" | cut -f1)*4+200*1024))
    mkdir /genimage
    cat >/genimage/genimage.cfg <<EOF
    image efi.img {
        vfat {
            extraargs = "-F32 -n EFI"
        }
        mountpoint = "/boot"
        size = 512M
    }
    image root.img {
        ext4 {
            label = "root"
            use-mke2fs = true
        }
        size = ${size}K
    }
    image disk.img {
        hdimage {
            partition-table-type = "gpt"
            gpt-location = 1M
        }
        partition efi {
            image = "efi.img"
            partition-type-uuid = "U"
        }
        partition root {
            image = "root.img"
            partition-type-uuid = "%{linux-root}"
        }
    }
    EOF

  - |
    cd /genimage
    genimage --rootpath "%{sysroot}"
    mv /genimage/images/disk.img %{install-root}/disk.img
    xz ${XZFLAGS} %{install-root}/disk.img
