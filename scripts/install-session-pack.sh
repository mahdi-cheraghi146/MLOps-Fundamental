#!/usr/bin/env bash
# =============================================================================
# install-session-pack.sh — STUDENT. Downloads the session pack that the trainer
# shared on OneDrive and installs it: Docker images + Python packages.
# Use it when PyPI or Docker Hub is slow or blocked.
#
# Usage:   ~/mlops-lab/scripts/install-session-pack.sh s02
#          ~/mlops-lab/scripts/install-session-pack.sh s02 "https://1drv.ms/..."     (a share link)
#          ~/mlops-lab/scripts/install-session-pack.sh s02 ~/Downloads/mlops-s02-linux-amd64.tar.gz
#
# Works on Linux, macOS and Windows (inside WSL2 Ubuntu). Docker must be running.
# Nothing is installed system-wide: files go to ~/mlops-packs.
# =============================================================================
set -euo pipefail

SESSION="${1:-}"; SRC="${2:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PACKS="${PACK_HOME:-$HOME/mlops-packs}"
log() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
die() { printf '\033[31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
[ -n "$SESSION" ] || die "usage: install-session-pack.sh s02 [share-link | downloaded-file]"

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$(uname -m)" in x86_64|amd64) ARCH=amd64 ;; arm64|aarch64) ARCH=arm64 ;; *) die "unsupported CPU: $(uname -m)" ;; esac
PLAT="$OS-$ARCH"
NAME="mlops-$SESSION-$PLAT.tar.gz"
log "Your platform: $PLAT   (pack file: $NAME)"

# 1) Where does the pack come from?  argument > packs.env (filled in by the trainer)
if [ -z "$SRC" ] && [ -f "$HERE/packs.env" ]; then
  KEY=$(printf '%s_%s' "$SESSION" "$PLAT" | tr '[:lower:]-' '[:upper:]_')      # e.g. S02_LINUX_AMD64
  SRC=$(sed -n "s/^${KEY}=//p" "$HERE/packs.env" | tr -d '"' | head -1)
fi
[ -n "$SRC" ] || die "no link for $PLAT in scripts/packs.env. Ask the trainer for the link, or download $NAME in the browser and pass the file path."

mkdir -p "$PACKS/downloads" "$PACKS/wheels"
FILE="$PACKS/downloads/$NAME"

is_pack() { [ -s "$1" ] && gzip -t "$1" 2>/dev/null; }

if [ -f "$SRC" ]; then
  log "Using the downloaded file: $SRC"
  [ "$SRC" = "$FILE" ] || cp "$SRC" "$FILE"
else
  log "Downloading from OneDrive (this can take a few minutes)"
  SEP='?'; case "$SRC" in *\?*) SEP='&' ;; esac
  OK=no
  for URL in "${SRC}${SEP}download=1" "$SRC"; do
    if curl -fL --retry 3 --progress-bar -o "$FILE" "$URL" && is_pack "$FILE"; then OK=yes; break; fi
  done
  if [ "$OK" != yes ]; then
    rm -f "$FILE"
    die "the link did not return the pack file (OneDrive may need a browser).
       Open this link in your browser, download '$NAME', then run:
       $0 $SESSION ~/Downloads/$NAME
       Link: $SRC"
  fi
fi
is_pack "$FILE" || die "$FILE is not a valid pack (download it again)."

# 2) Unpack
log "Unpacking"
rm -rf "$PACKS/mlops-$SESSION"
tar -xzf "$FILE" -C "$PACKS"
P="$PACKS/mlops-$SESSION"
[ -f "$P/PACK_INFO" ] || die "unexpected pack contents"
grep -q "^platform=$PLAT$" "$P/PACK_INFO" || die "this pack is for $(sed -n 's/^platform=//p' "$P/PACK_INFO"), but your laptop is $PLAT. Download $NAME."
cp "$P"/wheels/*.whl "$PACKS/wheels/"

# 3) Docker images
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  log "Loading Docker images"
  gunzip -c "$P/images.tar.gz" | docker load
else
  printf '\033[33mWARN:\033[0m Docker is not running, images were NOT loaded. Start Docker and run:\n    gunzip -c %s/images.tar.gz | docker load\n' "$P"
fi

# 4) Optional offline mode for uv (only needed when PyPI itself is blocked)
case "$PLAT" in
  linux-amd64)  MARK="sys_platform == 'linux' and platform_machine == 'x86_64'" ;;
  linux-arm64)  MARK="sys_platform == 'linux' and platform_machine == 'aarch64'" ;;
  darwin-arm64) MARK="sys_platform == 'darwin' and platform_machine == 'arm64'" ;;
  darwin-amd64) MARK="sys_platform == 'darwin' and platform_machine == 'x86_64'" ;;
esac
printf 'no-index = true\nfind-links = ["%s"]\n' "$PACKS/wheels" > "$PACKS/uv.toml"
printf '\n# added for offline installs from ~/mlops-packs (this laptop only)\n[tool.uv]\nenvironments = ["python_version == %s3.12%s and %s"]\n' "'" "'" "$MARK" > "$PACKS/pyproject-offline-snippet.toml"
cat > "$PACKS/offline.sh" <<EOF
# source this file to make uv install from the course packs instead of PyPI:
#     source ~/mlops-packs/offline.sh
# To go back to PyPI, open a new terminal (or: unset UV_CONFIG_FILE).
export UV_CONFIG_FILE="$PACKS/uv.toml"
EOF

log "Done: $(ls "$PACKS/wheels" | wc -l | tr -d ' ') Python packages in $PACKS/wheels"
cat <<EOF

Docker images are loaded. For Python packages you have two choices:

  A) PyPI works for you (normal case): nothing else to do, follow the lab as written.

  B) PyPI is blocked or too slow: install from the pack instead. Once per project:
         cd ~/work/churn-mlops && cat $PACKS/pyproject-offline-snippet.toml >> pyproject.toml
     and in every new terminal, before 'uv add' / 'uv sync':
         source $PACKS/offline.sh
EOF
