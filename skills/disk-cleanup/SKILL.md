---
name: disk-cleanup
description: >-
  Audit disk usage and safely free up space on Linux machines by identifying
  temporary files, tool/package caches, unused installed packages, large
  directories, and clean git repositories with no unpushed changes. Use this
  skill when the user asks to free up disk space, clean up the machine, audit
  disk usage, or remove old caches, packages, or checked-out git repos.
---

# Disk Cleanup

Follow a strict **read-only audit first → user approval → execute & verify**
workflow. Never delete files, purge packages, or trigger auto-installing
wrappers before the user reviews the audit report and approves specific items.

## Steps

### 1. Run the Read-Only Audit

Execute the bundled audit script:
[audit.sh](./scripts/audit.sh)

```bash
bash ~/.gemini/config/skills/disk-cleanup/scripts/audit.sh
```

The script is strictly read-only and reports:
1. Baseline disk usage (`df -h`), largest directories in `~` (using both
   apparent size and block size to handle overlayfs), and files >20 MB.
2. Temp directories (`/tmp`, `/var/tmp`), logs (`/var/log`, `journalctl`), and
   dev caches (`go`, `npm`, `uv`, `pip`, `cargo`, `apt`).
   - **Docker safety check:** Only queries `docker system df` if `dockerd` is
     already running, avoiding auto-installer wrappers (e.g., `unkernel`).
3. Largest installed packages and `autoremove --dry-run` output.
4. Every local `.git` repository classified as `SAFE` (has remote, clean
   working tree, no untracked files, no stashes, no unpushed commits, not
   detached `HEAD`) or `KEEP` (with reasons).

### 2. Present a Grouped Cleanup Plan

Summarize findings in three risk tiers with exact sizes and total estimated
savings, then ask the user which tiers or individual items to remove:

1. **Safe Caches & Temp Files** (zero data loss; regenerates on demand):
   - Go: `go clean -modcache && go clean -cache`
   - npm: `npm cache clean --force`
   - uv / pip: `uv cache clean` / `pip cache purge`
   - Cargo: `rm -rf ~/.cargo/registry/cache ~/.cargo/registry/src`
   - APT: `sudo apt-get clean`
   - Temp & logs: stale `/tmp/*` build dirs, `sudo journalctl --vacuum-size=100M`
   - Docker (only if running and approved): `docker system prune -af`
2. **Clean, Fully-Pushed Git Repositories**:
   - List every `SAFE` repo with its size, branch, and remote.
   - Never recommend `KEEP` repos for deletion without highlighting why they
     were flagged.
3. **Optional Toolchains & Installed Packages**:
   - Orphaned dependencies: `sudo apt-get autoremove --purge -y`
   - Large optional packages/toolchains (e.g., `~/.rustup`, `golang-*`,
     `gcc-*`, `gh`, GUI libs) — always call out core tools to keep (e.g.,
     `agy`, `node`, `git`, `openssh-client`).

### 3. Execute Approved Cleanups & Verify

1. Record `df -h /` before running approved removals.
2. Run only the commands/items the user explicitly approved.
3. Re-run `df -h /` and check remaining cache sizes to report exact space
   reclaimed.
