#!/usr/bin/env bash
# =============================================================================
# preflight.sh — checks a student laptop is ready for the MLOps Fundamentals labs.
# Run BEFORE session 1 (Session 0) and whenever something feels wrong.
# Exit code 0 = ready (warnings allowed), 1 = at least one FAIL.
# =============================================================================
set -uo pipefail
FAILS=0; WARNS=0
pass() { printf '  \033[32mPASS\033[0m  %s\n' "$*"; }
warn() { printf '  \033[33mWARN\033[0m  %s\n' "$*"; WARNS=$((WARNS+1)); }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$*"; FAILS=$((FAILS+1)); }
need() { command -v "$1" >/dev/null 2>&1; }

OS=$(uname -s); ARCH=$(uname -m)
WSL=$(grep -qi microsoft /proc/version 2>/dev/null && echo yes || echo no)
echo "MLOps Fundamentals — lab pre-flight   ($OS/$ARCH, WSL=$WSL)"

echo "[Hardware]"
if [ "$OS" = Darwin ]; then CPUS=$(sysctl -n hw.ncpu); MEM_GB=$(( $(sysctl -n hw.memsize) / 1073741824 ))
else CPUS=$(nproc); MEM_GB=$(( $(awk '/MemTotal/{print $2}' /proc/meminfo) / 1048576 )); fi
[ "$CPUS" -ge 4 ] && pass "CPU cores: $CPUS" || fail "CPU cores: $CPUS (need >= 4)"
if   [ "$MEM_GB" -ge 15 ]; then pass "RAM: ${MEM_GB}GB"
elif [ "$MEM_GB" -ge 7 ];  then warn "RAM: ${MEM_GB}GB — works, but stop unused services between labs (see BOM 'low-RAM mode')"
else fail "RAM: ${MEM_GB}GB (need >= 8GB, 16GB recommended)"; fi
DISK_GB=$(df -Pk "$HOME" | awk 'NR==2{print int($4/1048576)}')
[ "$DISK_GB" -ge 40 ] && pass "Free disk in \$HOME: ${DISK_GB}GB" || { [ "$DISK_GB" -ge 25 ] && warn "Free disk: ${DISK_GB}GB (40GB recommended)" || fail "Free disk: ${DISK_GB}GB (need >= 25GB)"; }

echo "[Container runtime]"
if need docker && docker info >/dev/null 2>&1; then
  pass "Docker engine reachable ($(docker version -f '{{.Server.Version}}' 2>/dev/null))"
  DMEM=$(( $(docker info -f '{{.MemTotal}}') / 1073741824 ))
  [ "$DMEM" -ge 7 ] && pass "Memory available to Docker: ${DMEM}GB" || warn "Docker only has ${DMEM}GB — raise it to >= 8GB (Colima: colima start --memory 8; Docker Desktop: Settings > Resources)"
  docker compose version >/dev/null 2>&1 && pass "docker compose v2" || fail "docker compose v2 plugin missing"
  docker buildx version >/dev/null 2>&1 && pass "docker buildx" || warn "docker buildx missing (needed in session 9)"
else fail "Docker is not installed or not running"; fi

echo "[Lab CLI tools]"
for T in git uv kind kubectl helm trivy; do
  if need "$T"; then pass "$T: $($T --version 2>/dev/null | head -1 || $T version --client 2>/dev/null | head -1)"
  else fail "$T not found (run scripts/install-from-bundle.sh)"; fi
done
need syft && pass "syft (optional)" || warn "syft not found (optional, session 9)"
need multipass && pass "multipass" || warn "multipass not found (needed in session 10 — see BOM for Windows/WSL notes)"
uv python find 3.12 >/dev/null 2>&1 && pass "Python 3.12 (uv-managed)" || fail "Python 3.12 not installed (uv python install 3.12)"

echo "[Ports on 127.0.0.1]"
for P in 3000 2222 5001 5050 8080 8333 8443 8888 9333; do
  if (exec 3<>/dev/tcp/127.0.0.1/$P) 2>/dev/null; then
    docker ps --format '{{.Ports}}' 2>/dev/null | grep -q ":$P->" && pass "port $P used by a lab container" || warn "port $P is busy (another program uses it)"
  else pass "port $P free"; fi
done

echo "[Lab images loaded]"
if need docker && [ -f "$(dirname "$0")/../versions.env" ]; then
  # shellcheck source=/dev/null
  source "$(dirname "$0")/../versions.env"
  for IMG in "$SEAWEEDFS_IMAGE" "$MLFLOW_SERVER_IMAGE" "$GITEA_IMAGE" "$REGISTRY_IMAGE" "${KIND_NODE_IMAGE%@*}"; do
    docker image inspect "$IMG" >/dev/null 2>&1 && pass "$IMG" || fail "image missing: $IMG"
  done
fi

echo
if [ "$FAILS" -eq 0 ]; then printf '\033[32mREADY\033[0m (%d warnings)\n' "$WARNS"; exit 0
else printf '\033[31mNOT READY\033[0m: %d failures, %d warnings — fix FAIL items or ask the trainer\n' "$FAILS" "$WARNS"; exit 1; fi
