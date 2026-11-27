#!/usr/bin/env bash
set -uo pipefail

fail=0
step() { printf '\n== %s\n' "$1"; }
fail_step() { printf 'FAIL: %s\n' "$1"; fail=1; }

step branch
branch="$(git rev-parse --abbrev-ref HEAD 2>&1)" || fail_step "could not read current branch"
head="$(git rev-parse HEAD 2>&1)" || fail_step "could not read HEAD"
printf 'branch: %s\nHEAD: %s\n' "$branch" "$head"
if [[ "$branch" == "main" || "$branch" == "design/phase-1-liquid-metal" ]]; then
  fail_step "running on a forbidden branch: $branch"
fi

step stubs
if grep -rnE 'TODO|FIXME|rest unchanged|// \.\.\.|fatalError\("(TODO|not implemented)' \
  --include='*.swift' --include='*.metal' . --exclude-dir=Vendor --exclude-dir=.git; then
  fail_step "source stubs remain"
else
  printf 'PASS: no forbidden Swift/Metal stubs found.\n'
fi

step monochrome
if [[ -x scripts/check-monochrome.sh ]]; then
  bash scripts/check-monochrome.sh || fail_step "monochrome check failed"
else
  fail_step "scripts/check-monochrome.sh missing or not executable"
fi

step icons
if python3 scripts/check-icon-usage.py; then
  printf 'PASS: AppIcon migration check.\n'
else
  fail_step "AppIcon usage check failed"
fi
if grep -rnE 'Image\(systemName:|Label\([^)]*systemImage:|Button\([^)]*systemImage:' \
  --include='*.swift' FrozenApps InstallerIntegration --exclude='AppIcon.swift'; then
  fail_step "raw system icon call sites remain outside AppIcon.swift"
else
  printf 'PASS: no raw literal SF Symbol call sites in FrozenApps/ or InstallerIntegration/.\n'
fi

step ledger
if [[ ! -f REDESIGN_LEDGER.md ]]; then
  fail_step "REDESIGN_LEDGER.md missing"
else
  while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue
    git cat-file -e "${sha}^{commit}" 2>/dev/null || fail_step "ledger SHA $sha not in git"
  done < <(grep -oE '\b[0-9a-f]{7,40}\b' REDESIGN_LEDGER.md | sort -u)
  printf 'PASS: every recorded ledger commit SHA resolves in Git.\n'
fi

step screen-coverage
python3 scripts/check-screen-coverage.py || fail_step "screen coverage check failed"

step LiquidChrome-contract
python3 scripts/check-liquidchrome-contract.py || fail_step "LiquidChrome contract check failed"

step build
if [[ "${SKIP_BUILD:-0}" == "1" ]]; then
  printf 'SKIP: build omitted because SKIP_BUILD=1.\n'
else
  bash scripts/validate-build.sh || fail_step "validate-build.sh failed"
fi

if [[ "$fail" -eq 0 ]]; then
  printf '\nVERIFY-ALL: PASS\n'
else
  printf '\nVERIFY-ALL: FAIL\n'
  exit 1
fi
