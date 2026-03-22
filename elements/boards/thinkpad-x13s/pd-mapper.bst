kind: make
description: Qualcomm PD mapper daemon — required for power domain management on SC8280XP (ThinkPad X13s)

sources:
- kind: git_repo
  url: github:linux-msm/pd-mapper.git
  track: main
  ref: 5ecd2fe926aca7abfe40724177f63b942cff3947

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- gnomeos-deps/qrtr.bst
- freedesktop-sdk.bst:components/xz.bst

config:
  build-commands:
  - make prefix=%{prefix}

  install-commands:
  - make install prefix=%{prefix} DESTDIR=%{install-root}
  # Enable pd-mapper at boot via systemd preset
  - |
    install -Dm644 /dev/stdin \
      %{install-root}%{datadir}/systemd/system-preset/75-thinkpad-x13s.preset << 'PRESET'
    enable pd-mapper.service
    PRESET
