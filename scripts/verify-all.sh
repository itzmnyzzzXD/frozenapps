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
grep -rnE 'TODO|FIXME|rest unchanged|// \.\.\.|fatalError\("(TODO|not implemented)' \
  --include='*.swift' --include='*.metal' . --exclude-dir=Vendor --exclude-dir=.git
grep_status=$?
if [[ "$grep_status" -eq 0 ]]; then
  fail_step "source stubs remain (see matches above)"
elif [[ "$grep_status" -eq 1 ]]; then
  printf 'PASS: no forbidden Swift/Metal stubs found.\n'
else
  fail_step "stub scan failed with grep exit code $grep_status"
fi

step monochrome
if [[ -f scripts/check-monochrome.sh ]]; then
  bash scripts/check-monochrome.sh || fail_step "monochrome check failed"
else
  fail_step "scripts/check-monochrome.sh missing"
fi

step icons
python3 scripts/check-icon-usage.py || fail_step "AppIcon usage check failed"
grep -rnE 'Image\(systemName:|Label\([^)]*systemImage:|Button\([^)]*systemImage:' \
  --include='*.swift' FrozenApps InstallerIntegration --exclude='AppIcon.swift'
icon_grep_status=$?
if [[ "$icon_grep_status" -eq 0 ]]; then
  fail_step "raw system icon call sites remain outside AppIcon.swift"
elif [[ "$icon_grep_status" -eq 1 ]]; then
  printf 'PASS: no raw literal SF Symbol call sites in FrozenApps/ or InstallerIntegration/.\n'
else
  fail_step "raw icon grep failed with exit code $icon_grep_status"
fi

step ledger
if [[ ! -f REDESIGN_LEDGER.md ]]; then
  fail_step "REDESIGN_LEDGER.md missing"
else
  python3 - REDESIGN_LEDGER.md <<'PY'
from pathlib import Path
import re
import subprocess
import sys

ledger = Path(sys.argv[1])
failures = []
for line_number, line in enumerate(ledger.read_text(encoding="utf-8").splitlines(), 1):
    if not line.startswith("| R"):
        continue
    cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
    if len(cells) < 5:
        failures.append(f"line {line_number}: malformed ledger row")
        continue
    for column_name, cell in (("commit SHA", cells[2]), ("last verified SHA", cells[4])):
        shas = re.findall(r"\b[0-9a-f]{40}\b", cell)
        if not shas:
            failures.append(f"line {line_number}: missing {column_name}")
        for sha in shas:
            result = subprocess.run(
                ["git", "cat-file", "-e", f"{sha}^{{commit}}"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
            if result.returncode:
                failures.append(f"line {line_number}: {column_name} {sha} is not a Git commit")

if failures:
    for failure in failures:
        print("FAIL: " + failure)
    raise SystemExit(f"FAIL: {len(failures)} ledger issue(s).")
print("PASS: requirement/check SHAs resolve to Git commits; blob hashes in evidence cells are ignored.")
PY
  [[ "$?" -eq 0 ]] || fail_step "ledger commit SHA validation failed"
fi

step screen-coverage
python3 scripts/check-screen-coverage.py || fail_step "screen coverage check failed"

step LiquidChrome-contract
python3 scripts/check-liquidchrome-contract.py || fail_step "LiquidChrome contract check failed"

step build
if [[ "${SKIP_BUILD:-0}" == "1" ]]; then
  printf 'SKIP: build omitted because SKIP_BUILD=1; use the Actions build result for this commit.\n'
else
  bash scripts/validate-build.sh || fail_step "validate-build.sh failed"
fi

if [[ "$fail" -eq 0 ]]; then
  printf '\nVERIFY-ALL: PASS\n'
else
  printf '\nVERIFY-ALL: FAIL\n'
  exit 1
fi
