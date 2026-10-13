#!/usr/bin/env bash
# =============================================================================
# install-from-bundle.sh — STUDENT. Installs the lab toolchain from the offline bundle.
# Run from inside the bundle folder:   ./scripts/install-from-bundle.sh
# Works on: Linux, macOS, Windows (inside WSL2 Ubuntu). Docker must already run.
# =============================================================================
set -euo pipefail
B="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$B/versions.env"
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$(uname -m)" in x86_64|amd64) ARCH=amd64 ;; arm64|aarch64) ARCH=arm64 ;; *) echo "Unsupported CPU"; exit 1 ;; esac
log() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }

[ -d "$B/bin/$OS-$ARCH" ] || { echo "This bundle has no binaries for $OS-$ARCH. Use the bundle for your laptop."; exit 1; }

log "Verifying bundle checksums"
( cd "$B" && shasum -a 256 -c SHA256SUMS --quiet ) || { echo "Bundle is corrupted — copy it again."; exit 1; }

log "Installing CLI tools to ~/.local/bin"
mkdir -p "$HOME/.local/bin"
cp "$B/bin/$OS-$ARCH"/* "$HOME/.local/bin/"
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *)
  for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do [ -f "$RC" ] && echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RC"; done
  export PATH="$HOME/.local/bin:$PATH" ;;
esac

log "Configuring uv for offline use (Python + wheels from the bundle)"
mkdir -p "$HOME/.config/uv"
cat > "$HOME/.config/uv/uv.toml" <<EOF
# Written by install-from-bundle.sh — classroom offline mode
python-install-mirror = "file://$B/python"
find-links = ["$B/wheelhouse/$OS-$ARCH"]
no-index = true
EOF
uv python install "$PYTHON_VERSION"

log "Installing Trivy offline DB (dated $(cat "$B/trivy-cache/DB_DATE" 2>/dev/null || echo unknown))"
mkdir -p "$HOME/.cache/trivy" && cp -r "$B/trivy-cache/"* "$HOME/.cache/trivy/"

log "Loading container images into Docker (this takes a few minutes)"
gunzip -c "$B/images/all-images.tar.gz" | docker load

log "Copying lab files to ~/mlops-lab"
mkdir -p "$HOME/mlops-lab"
cp -r "$B/compose" "$B/k8s" "$B/scripts" "$B/versions.env" "$HOME/mlops-lab/"
cp -r "$B/charts" "$HOME/mlops-lab/"
mkdir -p "$HOME/mlops-lab/images" && cp "$B/images/kind-preload.tar.gz" "$HOME/mlops-lab/images/"
mkdir -p "$HOME/mlops-lab/vm" && cp "$B/vm/"*.img "$HOME/mlops-lab/vm/" 2>/dev/null || true
[ -f "$HOME/mlops-lab/compose/.env" ] || cp "$HOME/mlops-lab/compose/.env.example" "$HOME/mlops-lab/compose/.env"

log "Done. Next:  cd ~/mlops-lab && ./scripts/preflight.sh"
