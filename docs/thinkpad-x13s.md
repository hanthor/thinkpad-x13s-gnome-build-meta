# ThinkPad X13s Board for GNOME OS

This repository is a fork of [GNOME/gnome-build-meta](https://gitlab.gnome.org/GNOME/gnome-build-meta)
that adds board support for the **Lenovo ThinkPad X13s** (Qualcomm SC8280XP, aarch64).

## Board files

All X13s-specific files live under `elements/boards/thinkpad-x13s/`:

| File | Purpose |
|------|---------|
| `deps.bst` | Board dependency stack (GNOME OS + pd-mapper + rmtfs + qcom preset) |
| `filesystem.bst` | Compose element that filters out devel/debug packages |
| `repo.bst` | OSTree repository commit (`gnome-os/aarch64/thinkpad-x13s`) |
| `image.bst` | Raw disk image (GPT: EFI + ext4 root via ostree deploy) |
| `live-image.bst` | Bootable live ISO (systemd-repart + xorrisofs, same as upstream GNOME OS) |
| `image-deps.bst` | Build-time tools for image.bst (ostree, genimage, mtab) |
| `initial-scripts.bst` | Initial setup scripts collection |
| `qcom-services-preset.bst` | systemd preset enabling pd-mapper.service + rmtfs.service |

### Required kernel arguments

The X13s needs these kargs for stable operation:

```
arm64.nopauth          # disable pointer authentication (hardware issue)
clk_ignore_unused      # prevent unused clock gating lockups
pd_ignore_unused       # prevent power domain shutdown (DSP deps)
modprobe.blacklist=qcom_q6v5_pas  # defer DSP loading until after boot
efi=noruntime          # disable EFI runtime services (aarch64 stability)
```

### Live ISO boot

`live-image.bst` produces `disk.iso` using the same pipeline as upstream GNOME OS
(`systemd-repart` + `xorrisofs`). It adds an **X13s addon EFI** (via `ukify`) that:
- Appends the X13s kernel args listed above
- Embeds `sc8280xp-lenovo-thinkpad-x13s.dtb` so the correct device tree is always used

Boot is activated by `root=live:gnomeos` (the standard GNOME OS live mechanism).

## Staying in sync with upstream

This fork tracks [GNOME/gnome-build-meta on GitLab](https://gitlab.gnome.org/GNOME/gnome-build-meta).
Our X13s commits are rebased on top of upstream `main`.

### Automated sync

A [weekly GitHub Actions workflow](.github/workflows/sync-upstream.yml) runs every Monday.
It fetches upstream `main`, rebases our X13s commits on top, and force-pushes the branch.
If rebase conflicts arise, it opens a GitHub issue with `upstream-sync` label instead of pushing.

### Manual sync

```bash
git remote add upstream https://gitlab.gnome.org/GNOME/gnome-build-meta.git
git fetch upstream main
git checkout feat/thinkpad-x13s-arm-build

# Rebase our commits onto latest upstream
git rebase upstream/main

# Resolve any conflicts (most likely in):
#   files/gnomeos/qrtr/condition.conf  (we added one ConditionFirmware line)
#   .github/scripts/ci-build-matrix.py (we modified build-plan.txt reading)

git push origin feat/thinkpad-x13s-arm-build --force-with-lease
```

### What we changed vs upstream

| File | Change |
|------|--------|
| `elements/boards/thinkpad-x13s/*` | **New** — all board files |
| `.github/workflows/build-thinkpad-x13s.yml` | **New** — GitHub CI workflow |
| `.github/workflows/sync-upstream.yml` | **New** — upstream sync workflow |
| `files/gnomeos/qrtr/condition.conf` | **One line added** — `ConditionFirmware` for lenovo,thinkpad-x13s |
| `.github/scripts/ci-build-matrix.py` | **Minor mod** — reads pre-generated build-plan.txt |

The goal is to keep this diff as small as possible. Candidates for upstreaming:
- The board definition itself (`elements/boards/thinkpad-x13s/`)
- The `condition.conf` addition (non-breaking for other boards)
