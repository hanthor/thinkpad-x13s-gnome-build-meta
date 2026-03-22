kind: manual
description: Enable Qualcomm system services (pd-mapper, rmtfs) on the ThinkPad X13s

build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  strip-binaries: ''

config:
  install-commands:
  - |
    install -Dm644 /dev/stdin \
      "%{install-root}%{prefix}/lib/systemd/system-preset/75-thinkpad-x13s.preset" << 'EOF'
    enable pd-mapper.service
    enable rmtfs.service
    EOF
