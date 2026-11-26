#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${AGY_NOTES_DIR:-$HOME/.gemini/antigravity-cli/scratch/agy-notes-01}"
REPO_URL="${AGY_NOTES_REPO:-https://github.com/phucvin/agy-notes-01.git}"
BRANCH="${AGY_NOTES_BRANCH:-main}"

usage() {
  cat <<'EOF'
Usage:
  notes-git.sh sync
  notes-git.sh push "<commit-message>" <repo-relative-path> [more-paths...]
EOF
  exit 1
}

ensure_repo() {
  if [[ ! -d "$REPO_DIR/.git" ]]; then
    mkdir -p "$(dirname "$REPO_DIR")"
    git clone "$REPO_URL" "$REPO_DIR"
  fi
}

cmd_sync() {
  ensure_repo
  cd "$REPO_DIR"
  git fetch origin "$BRANCH"
  local current_branch
  current_branch="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "$current_branch" != "$BRANCH" ]]; then
    git checkout "$BRANCH"
  fi
  git pull --rebase --autostash origin "$BRANCH"
  echo "Repo ready: $REPO_DIR"
  echo "Existing notes:"
  if [[ -d "$REPO_DIR/notes" ]]; then
    find "$REPO_DIR/notes" -maxdepth 2 -type f -name '*.md' | sed "s|^$REPO_DIR/||" | sort
  else
    echo "  (none)"
  fi
}

cmd_push() {
  if [[ $# -lt 2 ]]; then
    usage
  fi
  local msg="$1"
  shift
  local files=("$@")

  ensure_repo
  cd "$REPO_DIR"

  for f in "${files[@]}"; do
    if [[ ! -e "$REPO_DIR/$f" ]]; then
      echo "Error: path does not exist in repo: $f" >&2
      exit 1
    fi
  done

  git add -- "${files[@]}"

  if git diff --cached --quiet; then
    echo "No staged changes to commit."
    git status -sb
    exit 0
  fi

  git commit -m "$msg"

  if ! git push origin "$BRANCH"; then
    echo "Push rejected; rebasing onto origin/$BRANCH and retrying once..."
    git pull --rebase --autostash origin "$BRANCH"
    git push origin "$BRANCH"
  fi

  local sha
  sha="$(git rev-parse --short HEAD)"
  echo "Pushed commit: $sha"
  git status -sb
  for f in "${files[@]}"; do
    echo "URL: https://github.com/phucvin/agy-notes-01/blob/${BRANCH}/${f}"
  done
}

if [[ $# -lt 1 ]]; then
  usage
fi

subcmd="$1"
shift
case "$subcmd" in
  sync) cmd_sync "$@" ;;
  push) cmd_push "$@" ;;
  *) usage ;;
esac
