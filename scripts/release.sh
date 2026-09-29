#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Usage: scripts/release.sh MAJOR.MINOR.PATCH (without v)" >&2
  exit 1
fi

version="$1"
tag="v$version"
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

if [[ "$(git branch --show-current)" != main ]]; then
  echo "Release from main, not a detached HEAD or another branch." >&2
  exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Commit or remove working tree changes before releasing." >&2
  git status --short >&2
  exit 1
fi

git fetch origin main --tags
if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
  echo "Local main must match origin/main before releasing." >&2
  exit 1
fi
if git show-ref --verify --quiet "refs/tags/$tag"; then
  echo "Tag $tag already exists." >&2
  exit 1
fi

latest_tag="$(git tag --list 'v[0-9]*' --sort=-version:refname | sed -n '1p')"
if [[ -n "$latest_tag" ]]; then
  python3 - "$version" "${latest_tag#v}" <<'PY'
import sys

new = tuple(map(int, sys.argv[1].split(".")))
previous = tuple(map(int, sys.argv[2].split(".")))
if new <= previous:
    raise SystemExit(f"Release version {sys.argv[1]} must exceed {sys.argv[2]}.")
PY
fi

python3 scripts/release-notes.py "$version" >/dev/null

git tag "$tag"
git push origin "$tag"
echo "Pushed $tag; CI will set the app version to $version, build, test, sign, notarize, and publish."
echo "CI will update appcast.xml, then Publish website will refresh the download links automatically."
echo "Verify both workflows and https://kzahel.github.io/lid-awake/ before reporting the release complete."
echo "After CI publishes the feed, run git pull --ff-only to bring main up to date."
