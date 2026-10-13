#!/usr/bin/env bash
# =============================================================================
# verify.sh — checks the Definition of Done of a session on the student project.
# Usage:   ~/mlops-lab/scripts/verify.sh s01        (run inside ~/work/churn-mlops)
#          PROJECT=/path/to/project ~/mlops-lab/scripts/verify.sh s02
# Exit code 0 = all checks passed, 1 = at least one FAIL, 2 = usage error.
# It only reads the project; the single thing it runs is "make train" (s01).
# =============================================================================
set -uo pipefail
SESSION="${1:-}"
PROJECT="${PROJECT:-$PWD}"
PASSES=0; FAILS=0
pass() { printf '[\033[32mPASS\033[0m] %s\n' "$*"; PASSES=$((PASSES+1)); }
fail() { printf '[\033[31mFAIL\033[0m] %s\n' "$1"; [ -n "${2:-}" ] && printf '       -> %s\n' "$2"; FAILS=$((FAILS+1)); }
check() { if "$1"; then pass "$2"; else fail "$2" "${3:-}"; fi; }

usage() { echo "usage: verify.sh s01|s02   (run it inside your project folder, e.g. ~/work/churn-mlops)"; exit 2; }
[ -n "$SESSION" ] || usage
cd "$PROJECT" 2>/dev/null || { echo "project folder not found: $PROJECT"; exit 2; }
if [ ! -f pyproject.toml ] || ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "This is not the course project (no pyproject.toml or not a Git repo): $PWD"
  echo "cd ~/work/churn-mlops   and run verify.sh again."
  exit 2
fi
export GIT_TERMINAL_PROMPT=0   # never hang on a password prompt

# ---------------------------------------------------------------- session 1 --
s01_files()   { for f in src/churn/train.py scripts/make_dataset.py configs/params.yaml Makefile uv.lock README.md; do [ -f "$f" ] || return 1; done; }
s01_commit()  { git rev-parse --verify -q HEAD >/dev/null; }
s01_ignored() { [ -z "$(git ls-files data models metrics.json .env .venv 2>/dev/null)" ]; }
s01_train()   { OUT1=$(make -s train 2>/dev/null | tail -1); OUT2=$(make -s train 2>/dev/null | tail -1)
                echo "$OUT1" | grep -q "roc_auc" && [ "$OUT1" = "$OUT2" ]; }
s01_model()   { [ -f models/model.joblib ] && [ -f metrics.json ] && [ -f data/raw/churn.csv ]; }

verify_s01() {
  check s01_files   "project skeleton: src/ scripts/ configs/ Makefile uv.lock README" "copy the starter files again (s01/README.md, step 3)"
  check s01_commit  "at least one commit exists"                                      "git add . && git commit -m \"feat: project skeleton + baseline training\""
  check s01_ignored "data, model and metrics are NOT tracked by Git"                  "check .gitignore, then: git rm -r --cached data models metrics.json"
  check s01_model   "data/raw/churn.csv, models/model.joblib and metrics.json exist"  "make data && make train"
  check s01_train   "make train runs and two runs give the same metrics"              "run: make train   and read the error"
  [ -n "${OUT1:-}" ] && printf '       metrics: %s\n' "$OUT1"
}

# ---------------------------------------------------------------- session 2 --
s02_remote()  { URL=$(git remote get-url origin 2>/dev/null) || return 1
                echo "$URL" | grep -q "localhost:3000" && git ls-remote --heads origin main 2>/dev/null | grep -q "refs/heads/main"; }
s02_ruff()    { uv run ruff check -q . >/dev/null 2>&1 && uv run ruff format --check -q . >/dev/null 2>&1; }
s02_pytest()  { PYT=$(uv run pytest -q 2>&1 | tail -1); N=$(echo "$PYT" | sed -n 's/^\([0-9][0-9]*\) passed.*/\1/p')
                [ -n "$N" ] && [ "$N" -ge 4 ] && ! echo "$PYT" | grep -q "failed"; }
s02_hooks()   { H=$(git rev-parse --git-path hooks)
                [ -f .pre-commit-config.yaml ] && [ -n "$(git ls-files .pre-commit-config.yaml)" ] \
                  && grep -q "pre-commit" "$H/pre-commit" 2>/dev/null && grep -q "pre-commit" "$H/pre-push" 2>/dev/null; }
s02_tag()     { git rev-parse -q --verify "refs/tags/v0.1.0" >/dev/null && git ls-remote --tags origin v0.1.0 2>/dev/null | grep -q "v0.1.0"; }

verify_s02() {
  check s02_remote "remote origin -> Gitea, branch main is pushed"   "git remote -v ; docker compose ps (is Gitea up?) ; git push -u origin main"
  check s02_ruff   "ruff check + ruff format are clean"              "uv run ruff check --fix . && uv run ruff format ."
  check s02_pytest "pytest: at least 4 tests passed"                 "uv run pytest -q   (did you write the 4th test?)"
  [ -n "${PYT:-}" ] && printf '       pytest: %s\n' "$PYT"
  check s02_hooks  "pre-commit hooks installed (pre-commit + pre-push) and config tracked" "uv run pre-commit install --hook-type pre-commit --hook-type pre-push"
  check s02_tag    "tag v0.1.0 exists locally and on Gitea"          "git tag -a v0.1.0 -m \"...\" && git push origin v0.1.0"
}

case "$SESSION" in
  s01) verify_s01 ;;
  s02) verify_s02 ;;
  *)   echo "no checks defined for '$SESSION' yet (available: s01, s02)"; exit 2 ;;
esac

TOTAL=$((PASSES+FAILS))
echo "$SESSION: $PASSES/$TOTAL checks passed   (commit $(git rev-parse --short HEAD 2>/dev/null), branch $(git branch --show-current 2>/dev/null))"
[ "$FAILS" -eq 0 ]
