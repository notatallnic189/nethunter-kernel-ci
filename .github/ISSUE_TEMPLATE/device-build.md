---
name: Device build report
about: Report a build failure or success for a device in devices/
title: "[device] <your-device>: one-line summary"
labels: device
assignees: ""
---

**Device**

- Device directory: `devices/<your-device>` (does it exist yet, or are you proposing it?)
- Kernel: repo + branch
- SoC and kernel version (e.g. sdm660, 4.4.302)

**What happened**

Paste the failing step and the last ~30 log lines before it. The log is
written to be read: the first `ERROR:` line is usually the real cause.

**If it succeeded**

Even better: open a PR adding the device directory instead, see
docs/ADD-A-DEVICE.md. An issue is for when you are stuck.
