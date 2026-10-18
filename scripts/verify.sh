#!/usr/bin/env bash
# =============================================================================
# verify.sh — checks the Definition of Done of a session on the student project.
# Usage:   ~/mlops-lab/scripts/verify.sh s01        (run inside ~/work/churn-mlops)
#          PROJECT=/path/to/project ~/mlops-lab/scripts/verify.sh s02
#          S3_ENDPOINT_URL=http://localhost:8333 ~/mlops-lab/scripts/verify.sh s03   (s03 reads the keys from the project .env)
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

usage() { echo "usage: verify.sh s01|s02|s03|s04   (run it inside your project folder, e.g. ~/work/churn-mlops)"; exit 2; }
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

# ---------------------------------------------------------------- session 3 --
# Docker basics + SeaweedFS S3. Read-only: only "docker info", "aws s3 ls" and git reads.
# Keys come from the project's .env (never printed). S3_ENDPOINT_URL: env var > .env > default.
envval() { sed -n "s/^$1=//p" .env 2>/dev/null | tail -1 | tr -d '\r'; }
S3_URL="${S3_ENDPOINT_URL:-$(envval S3_ENDPOINT_URL)}"; S3_URL="${S3_URL:-http://localhost:8333}"; S3_URL="${S3_URL%/}"
# awscli is a dev dependency of the project (uv add --dev awscli): prefer its binary, else uv run
s3aws() { local B R; R=$(envval AWS_DEFAULT_REGION); if [ -x .venv/bin/aws ]; then B=.venv/bin/aws; else B="uv run aws"; fi
          AWS_ACCESS_KEY_ID="$(envval AWS_ACCESS_KEY_ID)" AWS_SECRET_ACCESS_KEY="$(envval AWS_SECRET_ACCESS_KEY)" \
          AWS_DEFAULT_REGION="${R:-us-east-1}" \
          $B --cli-connect-timeout 5 --cli-read-timeout 15 --endpoint-url "$S3_URL" s3 "$@"; }

s03_docker()   { docker info >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; }
s03_s3()       { CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$S3_URL" 2>/dev/null); [ -n "$CODE" ] && [ "$CODE" != "000" ]; }
s03_keys()     { [ -f .env ] && for k in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY; do V=$(envval $k); [ -n "$V" ] && [ "$V" != "CHANGE_ME" ] || return 1; done; }
s03_awscli()   { grep -q 'awscli==' pyproject.toml && git ls-files --error-unmatch pyproject.toml uv.lock >/dev/null 2>&1; }
s03_buckets()  { LS=$(s3aws ls 2>/dev/null) && echo "$LS" | grep -qE '[[:space:]]dvc$' && echo "$LS" | grep -qE '[[:space:]]mlflow$'; }
s03_object()   { OBJ=$(s3aws ls s3://dvc/raw/churn.csv 2>/dev/null | awk '{print $3}') && [ -n "$OBJ" ] && [ "$OBJ" -gt 0 ] \
                   && { [ ! -f data/raw/churn.csv ] || [ "$OBJ" = "$(wc -c < data/raw/churn.csv | tr -d ' ')" ]; }; }
s03_envfiles() { git ls-files --error-unmatch .env.example >/dev/null 2>&1 && grep -q 'CHANGE_ME' .env.example \
                   && [ -z "$(git ls-files .env)" ] && git check-ignore -q .env; }
s03_nosecret() { SEC=$(envval AWS_SECRET_ACCESS_KEY); [ -n "$SEC" ] && [ "$SEC" != "CHANGE_ME" ] || return 1
                 ! git grep -qF -e "$SEC" -- . 2>/dev/null && [ -z "$(git log --all --oneline -S"$SEC" 2>/dev/null)" ]; }
s03_pushed()   { URL=$(git config --get remote.origin.url 2>/dev/null) && echo "$URL" | grep -q "localhost:3000" \
                   && git show main:.env.example >/dev/null 2>&1 \
                   && REMOTE=$(git ls-remote --heads origin main 2>/dev/null | cut -f1) && [ -n "$REMOTE" ] \
                   && [ "$REMOTE" = "$(git rev-parse main 2>/dev/null)" ]; }

verify_s03() {
  check s03_docker   "Docker engine and Compose v2 answer"                              "start Docker Desktop (or: colima start), then: docker ps"
  check s03_s3       "SeaweedFS S3 answers at $S3_URL"                                  "cd ~/mlops-lab/compose && docker compose up -d seaweedfs ; docker compose ps (wait for healthy)"
  check s03_keys     ".env exists and holds real lab keys (not CHANGE_ME)"              "cp .env.example .env, then set AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY to the S3_ACCESS_KEY / S3_SECRET_KEY values of ~/mlops-lab/compose/.env"
  check s03_awscli   "awscli pinned in pyproject.toml; pyproject.toml and uv.lock tracked" "uv add --dev awscli==1.46.1"
  check s03_buckets  "buckets dvc and mlflow exist"                                     "set -a; source .env; set +a ; uv run aws --endpoint-url \$S3_ENDPOINT_URL s3 mb s3://dvc   (and s3://mlflow; README step 4)"
  check s03_object   "s3://dvc/raw/churn.csv exists and its size equals data/raw/churn.csv" "uv run aws --endpoint-url \$S3_ENDPOINT_URL s3 cp data/raw/churn.csv s3://dvc/raw/churn.csv   (make data first if the file is missing)"
  [ -n "${OBJ:-}" ] && printf '       churn.csv in S3: %s bytes\n' "$OBJ"
  check s03_envfiles ".env.example is tracked (CHANGE_ME), .env is NOT tracked and is ignored" "git rm --cached .env ; echo .env >> .gitignore ; git add .env.example"
  check s03_nosecret "the lab secret is in no tracked file and in no commit"            "real keys belong only in .env (ignored); .env.example keeps CHANGE_ME; if a key is already in a commit, tell the instructor"
  check s03_pushed   "Pull Request merged: local main == origin main (Gitea) and has .env.example" "merge the PR on Gitea, then: git switch main && git pull"
}

# ---------------------------------------------------------------- session 4 --
# Read-only: no dvc pull/checkout/push. The "in the remote" check asks DVC (python API) whether an object exists in remote 'storage'.
s04_pointer() { git ls-files --error-unmatch data/raw/churn.csv.dvc >/dev/null 2>&1 \
                  && git ls-files --error-unmatch data/raw/.gitignore >/dev/null 2>&1 \
                  && [ -z "$(git ls-files data/raw/churn.csv)" ] && git check-ignore -q data/raw/churn.csv \
                  && git diff --quiet HEAD -- data/raw/churn.csv.dvc data/raw/.gitignore; }
s04_dep()     { grep -q '"dvc\[s3\]==3.67.1"' pyproject.toml && uv run dvc --version 2>/dev/null | grep -q "^3.67.1" \
                  && git ls-files --error-unmatch .dvc/config .dvcignore pyproject.toml uv.lock >/dev/null 2>&1; }
s04_config()  { C=$(git show HEAD:.dvc/config 2>/dev/null) && [ -n "$C" ] \
                  && echo "$C" | grep -q "remote = storage" && echo "$C" | grep -q 'remote "storage"' \
                  && echo "$C" | grep -q "url = s3://dvc" && echo "$C" | grep -q "endpointurl = http" \
                  && git diff --quiet HEAD -- .dvc/config; }
s04_secret()  { SECRET=$(sed -n 's/^[[:space:]]*secret_access_key[[:space:]]*=[[:space:]]*//p' .dvc/config.local 2>/dev/null | head -1)
                [ -n "$SECRET" ] && grep -q "access_key_id" .dvc/config.local \
                  && git check-ignore -q .dvc/config.local && [ -z "$(git ls-files .dvc/config.local)" ] \
                  && ! grep -qE "secret_access_key|access_key_id" .dvc/config \
                  && ! git show HEAD:.dvc/config | grep -qE "secret_access_key|access_key_id" \
                  && [ -z "$(git grep -lF -e "$SECRET" HEAD -- 2>/dev/null)" ] \
                  && [ -z "$(git log --all --oneline -S"$SECRET" 2>/dev/null)" ]; }
s04_md5s()    { MD5_V1=$(git show data-v1:data/raw/churn.csv.dvc 2>/dev/null | sed -n 's/^- md5: //p')
                MD5_V2=$(git show data-v2:data/raw/churn.csv.dvc 2>/dev/null | sed -n 's/^- md5: //p'); }
s04_tags()    { s04_md5s; [ -n "$MD5_V1" ] && [ -n "$MD5_V2" ] && [ "$MD5_V1" != "$MD5_V2" ] \
                  && R=$(git ls-remote --tags origin data-v1 data-v2 2>/dev/null) \
                  && echo "$R" | grep -q "refs/tags/data-v1" && echo "$R" | grep -q "refs/tags/data-v2"; }
s04_inremote(){ s04_md5s; [ -n "${MD5_V1:-}" ] && [ -n "${MD5_V2:-}" ] \
                  && [ "$(uv run python - "$MD5_V1" "$MD5_V2" 2>/dev/null <<'PY'
import sys
from dvc.repo import Repo
with Repo(".") as r:
    odb = r.cloud.get_remote_odb("storage")
    print(sum(1 for m in sys.argv[1:] if odb.fs.exists(odb.oid_to_path(m))))
PY
)" = "2" ]; }
s04_sync()    { uv run dvc status 2>&1 | grep -q "Data and pipelines are up to date" \
                  && uv run dvc status -c 2>&1 | grep -q "in sync"; }
s04_merged()  { s04_md5s; RM=$(git ls-remote origin refs/heads/main 2>/dev/null | cut -f1) && [ -n "$RM" ] \
                  && git cat-file -e "$RM^{commit}" 2>/dev/null \
                  && [ "$(git show "$RM:data/raw/churn.csv.dvc" 2>/dev/null | sed -n 's/^- md5: //p')" = "${MD5_V2:-x}" ] \
                  && git show "$RM:.dvc/config" 2>/dev/null | grep -q 'remote "storage"'; }
s04_tag()     { git rev-parse -q --verify "refs/tags/v0.2.0" >/dev/null && git ls-remote --tags origin v0.2.0 2>/dev/null | grep -q "v0.2.0"; }

verify_s04() {
  check s04_pointer  "data/raw/churn.csv.dvc and data/raw/.gitignore are committed; churn.csv itself is NOT in Git" "uv run dvc add data/raw/churn.csv ; git add data/raw/.gitignore data/raw/churn.csv.dvc ; (if dvc add fails: remove the 'data/' line from .gitignore)"
  check s04_dep      "dvc[s3]==3.67.1 pinned in pyproject.toml; .dvc/config and uv.lock committed" "uv add --dev \"dvc[s3]==3.67.1\" ; uv run dvc init ; git add .dvc .dvcignore pyproject.toml uv.lock && git commit"
  check s04_config   ".dvc/config (committed): default remote 'storage' -> s3://dvc/..., with endpointurl" "uv run dvc remote add -d storage s3://dvc/store ; uv run dvc remote modify storage endpointurl \"\$S3_ENDPOINT_URL\" ; git add .dvc/config && git commit"
  check s04_secret   "keys only in .dvc/config.local (ignored); no secret in tracked files or in Git history" "uv run dvc remote modify --local storage access_key_id \"\$AWS_ACCESS_KEY_ID\" (and secret_access_key) ; if a key is in .dvc/config: uv run dvc remote modify storage --unset secret_access_key"
  check s04_tags     "tags data-v1 and data-v2 exist, point to different data, and are on Gitea" "git tag -a data-v1 -m \"dataset v1 (5000 rows)\" <commit> ; git push origin --tags   (find the commit: git log --oneline)"
  [ -n "${MD5_V1:-}" ] && printf '       data-v1 md5 %s\n       data-v2 md5 %s\n' "$MD5_V1" "${MD5_V2:-?}"
  check s04_inremote "both data versions (data-v1 and data-v2) exist in the remote 'storage'" "checkout the missing version and push it: git checkout data-v1 ; uv run dvc push ; git checkout feature/dvc-data  (or main). Is SeaweedFS up and .dvc/config.local filled in?"
  check s04_sync     "dvc status: data matches the pointer; dvc status -c: cache and remote are in sync" "uv run dvc checkout   (on the branch you want) ; uv run dvc push"
  check s04_merged   "Gitea 'main' contains the pointer of data-v2 and the remote config (PR merged)" "merge the Pull Request in Gitea, then: git switch main && git pull"
  check s04_tag      "tag v0.2.0 exists locally and on Gitea"                      "git switch main && git pull && git tag -a v0.2.0 -m \"Session 4: DVC\" && git push origin --tags"
}

case "$SESSION" in
  s01) verify_s01 ;;
  s02) verify_s02 ;;
  s03) verify_s03 ;;
  s04) verify_s04 ;;
  *)   echo "no checks defined for '$SESSION' yet (available: s01 to s04)"; exit 2 ;;
esac

TOTAL=$((PASSES+FAILS))
echo "$SESSION: $PASSES/$TOTAL checks passed   (commit $(git rev-parse --short HEAD 2>/dev/null), branch $(git branch --show-current 2>/dev/null))"
[ "$FAILS" -eq 0 ]
