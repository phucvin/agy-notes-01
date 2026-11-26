#!/usr/bin/env bash
# Strictly read-only disk usage, cache, package, and git repository audit.
set -uo pipefail

echo "=== 1. DISK USAGE BASELINE ==="
df -h -x tmpfs -x devtmpfs -x squashfs 2>/dev/null || df -h

echo ""
echo "=== 2. TOP DIRECTORIES IN ~ (apparent size) ==="
du -sh --apparent-size ~/* ~/.[!.]* 2>/dev/null | sort -hr | head -n 20

echo ""
echo "=== 3. LARGE FILES (>20M) IN ~, /tmp, /var/tmp ==="
find ~ /tmp /var/tmp -xdev -type f -size +20M -exec ls -lh {} + 2>/dev/null | sort -k5 -hr | head -n 20

echo ""
echo "=== 4. TEMP, LOGS & TOOL CACHES ==="
du -sh /tmp /var/tmp /var/log /var/cache /var/cache/apt ~/.cache ~/.npm ~/.cargo ~/.rustup ~/go 2>/dev/null | sort -hr

if command -v go >/dev/null 2>&1; then
  gocache=$(go env GOCACHE 2>/dev/null || true)
  gomodcache=$(go env GOMODCACHE 2>/dev/null || true)
  [ -n "$gocache" ] && [ -d "$gocache" ] && du -sh "$gocache" 2>/dev/null
  [ -n "$gomodcache" ] && [ -d "$gomodcache" ] && du -sh "$gomodcache" 2>/dev/null
fi

if command -v uv >/dev/null 2>&1; then
  uvcache=$(uv cache dir 2>/dev/null || true)
  [ -n "$uvcache" ] && [ -d "$uvcache" ] && du -sh "$uvcache" 2>/dev/null
fi

if command -v journalctl >/dev/null 2>&1; then
  journalctl --disk-usage 2>&1 || true
fi

# Only inspect Docker if dockerd is already running (avoids auto-installer wrappers).
if pgrep -x dockerd >/dev/null 2>&1 && [ -x /usr/bin/docker ]; then
  echo "--- Docker ---"
  /usr/bin/docker system df 2>&1 || true
else
  echo "Docker: daemon not running (skipped)"
fi

echo ""
echo "=== 5. INSTALLED PACKAGES (TOP 25 BY SIZE) ==="
if command -v dpkg-query >/dev/null 2>&1; then
  dpkg-query -Wf '${Installed-Size}\t${Package}\t${Status}\n' 2>/dev/null \
    | awk -F'\t' '$3 ~ /installed/ {printf "%8.1f MB\t%s\n", $1/1024, $2}' \
    | sort -nr | head -n 25
  echo "--- apt-get autoremove --purge --dry-run ---"
  apt-get autoremove --purge --dry-run 2>&1 | tail -n 15
fi

echo ""
echo "=== 6. GIT REPOSITORY AUDIT ==="
find ~ /tmp /var/tmp /opt /srv -xdev -name ".git" -type d -prune 2>/dev/null | sort -u | while read -r gitdir; do
  repo=$(dirname "$gitdir")
  size=$(du -sh "$repo" 2>/dev/null | cut -f1)
  has_remote=$(git -C "$repo" remote 2>/dev/null | tr '\n' ',' | sed 's/,$//')
  branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)
  dirty=$(git -C "$repo" status --porcelain 2>/dev/null)
  stashes=$(git -C "$repo" stash list 2>/dev/null)
  unpushed=$(git -C "$repo" log --branches --not --remotes --oneline 2>/dev/null)
  detached=""
  [ "$branch" = "HEAD" ] && detached="yes"

  if [ -n "$has_remote" ] && [ -z "$dirty" ] && [ -z "$stashes" ] && [ -z "$unpushed" ] && [ -z "$detached" ]; then
    echo "SAFE   [$size] $repo (branch:$branch remote:$has_remote)"
  else
    reasons=""
    [ -z "$has_remote" ] && reasons="${reasons}no-remote "
    [ -n "$dirty" ] && reasons="${reasons}dirty "
    [ -n "$stashes" ] && reasons="${reasons}stash "
    [ -n "$unpushed" ] && reasons="${reasons}unpushed "
    [ -n "$detached" ] && reasons="${reasons}detached-HEAD "
    echo "KEEP   [$size] $repo (reasons: ${reasons% })"
  fi
done
