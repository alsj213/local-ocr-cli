#!/usr/bin/env bash
# setup-npm-oidc.sh — one command to wire npm OIDC Trusted Publishing for a
# package in the current directory: upgrade npm, generate the release
# workflow, and (with user consent) configure the npm trust relationship.
#
# Usage:
#   ./setup-npm-oidc.sh                     # auto-detect repo from git remote
#   ./setup-npm-oidc.sh --repo owner/repo   # explicit repository
#   ./setup-npm-oidc.sh --workflow release.yml   # custom workflow filename
#
# The npm trust step opens a browser auth flow (2FA) — run this on a machine
# where you are logged into npmjs.com. Everything else is non-interactive.
set -euo pipefail

# --- defaults ---------------------------------------------------------------
REPO=""
WORKFLOW="release.yml"
MIN_NPM="11.15.0"

# --- parse args --------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo|--repository) REPO="$2"; shift 2 ;;
    --workflow|--file)   WORKFLOW="$2"; shift 2 ;;
    -h|--help)
      echo "usage: $0 [--repo owner/repo] [--workflow release.yml]"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

# --- detect repo from git remote if not given ---------------------------------
if [[ -z "$REPO" ]]; then
  REPO="$(git remote get-url origin 2>/dev/null | sed -E 's#.*github\.com[:/]([^/]+/[^/.]+)(\.git)?$#\1#' || true)"
  if [[ -z "$REPO" ]]; then
    echo "error: cannot detect repository. Pass --repo owner/repo." >&2
    exit 1
  fi
  echo "detected repository: $REPO"
fi

PKG="$(node -p "require('./package.json').name" 2>/dev/null || echo '')"
if [[ -z "$PKG" ]]; then
  echo "error: no package.json in current directory" >&2
  exit 1
fi

echo "package:     $PKG"
echo "repository:  $REPO"
echo "workflow:    $WORKFLOW"

# --- 1. npm version -----------------------------------------------------------
NPM_VER="$(npm --version)"
echo ""
echo "==> 1. npm version: $NPM_VER (need >= $MIN_NPM)"
if [[ "$(printf '%s\n' "$MIN_NPM" "$NPM_VER" | sort -V | head -1)" != "$MIN_NPM" ]]; then
  echo "    upgrading npm..."
  npm install -g "npm@^$MIN_NPM"
  echo "    now: $(npm --version)"
else
  echo "    ok"
fi

# --- 2. release workflow -------------------------------------------------------
if [[ ! -f ".github/workflows/$WORKFLOW" ]]; then
  echo ""
  echo "==> 2. generating .github/workflows/$WORKFLOW ..."
  mkdir -p .github/workflows
  cat > ".github/workflows/$WORKFLOW" <<'YAML'
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: read
  id-token: write

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with:
          version: 11.7.0
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: pnpm
      # GitHub runners ship npm 10.9.8 (no OIDC support) — always upgrade.
      - name: Upgrade npm for OIDC
        run: npm install -g npm@^11.15.0
      - name: Install
        run: pnpm install --frozen-lockfile
      - name: Typecheck
        run: pnpm typecheck
      - name: Test
        run: pnpm test
      - name: Build
        run: pnpm build
      - name: Publish
        run: npm publish --provenance --access public
YAML
  echo "    written. Review it, commit, and push before the trust step."
else
  echo "==> 2. workflow already exists: .github/workflows/$WORKFLOW (skipping)"
fi

# --- 3. npm trust --------------------------------------------------------------
echo ""
echo "==> 3. configuring npm trust relationship"
echo "    (opens a browser auth flow — complete the 2FA confirmation)"
echo ""
read -r -p "    proceed? [y/N] " ans
if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
  echo "    skipped. Run manually later:"
  echo "      npm trust github --file=$WORKFLOW --repository=$REPO --allow-publish"
  exit 0
fi

npm trust github --file="$WORKFLOW" --repository="$REPO" --allow-publish

echo ""
echo "==> done. Verify with:"
echo "      npm trust list --package=$PKG"
echo "      git tag v0.1.0 && git push origin v0.1.0   # triggers publish"
