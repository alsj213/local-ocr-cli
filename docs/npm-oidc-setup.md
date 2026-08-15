# Setting up npm OIDC Trusted Publishing (GitHub Actions)

> How to configure a package so pushing a tag publishes it to npm **without
> tokens, without 2FA prompts, with automatic provenance** — and the exact
> failure modes to expect when something is off.

Verified end-to-end on `local-ocr-cli` (2026-08). This is the checklist you
want in front of you when wiring OIDC for any npm package.

## Why OIDC

npm retired classic publish tokens (creation disabled 2025-11-05, existing
ones revoked ~2025-12-09). Trusted Publishing replaces them: npm trusts a
GitHub Actions **OIDC identity** scoped to your exact repo + workflow file +
environment. No secrets in CI at all.

## The three pieces

| piece | where | what it does |
| :-- | :-- | :-- |
| **1. workflow** | `.github/workflows/release.yml` | runs `npm publish` on tag push |
| **2. trust config** | npm registry (per package) | says "this GitHub workflow may publish this package" |
| **3. npm version** | CI runtime | must be `>= 11.15.0` or OIDC code path does not exist |

## 1. Workflow (`.github/workflows/release.yml`)

Minimal working shape — **every line matters**:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: read
  id-token: write          # REQUIRED: without it GitHub mints no OIDC token

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
          # DO NOT set registry-url here. It writes an .npmrc with a
          # placeholder _authToken that npm prefers over OIDC exchange.
      - name: Upgrade npm for OIDC   # CRITICAL: runners ship npm 10.9.8
        run: npm install -g npm@^11.15.0
      - name: Install
        run: pnpm install --frozen-lockfile
      - name: Test
        run: pnpm test
      - name: Build
        run: pnpm build
      - name: Publish
        run: npm publish --provenance --access public
```

## 2. Trust config (npm CLI, one-time per package)

```bash
npm install -g npm@^11.15.0        # trust subcommand needs it too
cd /path/to/package
npm trust github --file=release.yml \
  --repository=owner/repo \
  --allow-publish
```

- `--file` takes the **bare workflow filename** (`release.yml`), not a path.
- `--repository` is `owner/repo`.
- Requires npm >= 11.15, write access to the package, 2FA enabled.
- Runs a browser auth flow (open the printed URL, confirm) — must be run by
  the account owner; it cannot be automated.
- Verify: `npm trust list --package=<name>`.

(Equivalent web UI, if reachable: package → Settings → Trusted publishing.)

## 3. npm version in CI

GitHub-hosted runners currently ship **npm 10.9.8** with Node 22 — that
version has **no `lib/utils/oidc.js`**, so `npm publish` never attempts OIDC
and fails `ENEEDAUTH`. Always upgrade npm before publishing:

```yaml
- name: Upgrade npm for OIDC
  run: npm install -g npm@^11.15.0
```

## Failure modes (all surface as bare `E404` or `ENEEDAUTH`)

npm gives no hint which of these is wrong. Check in this order:

| # | cause | symptom | fix |
| :-- | :-- | :-- | :-- |
| 1 | reusable workflow (`workflow_call`) | 404 | trust config must name the workflow that **executes** the publish, not the caller |
| 2 | missing `permissions: id-token: write` | ENEEDAUTH | add the permissions block |
| 3 | `NODE_AUTH_TOKEN` set (even dummy) | 404 after provenance signs | don't set it; don't set `registry-url` on setup-node |
| 4 | npm < 11.15 / Node < 22.14 | ENEEDAUTH | upgrade npm in the workflow |
| 5 | scoped package without `--access public` | 404 on first publish | add `--access public` / `publishConfig.access: public` |
| 6 | another workflow also runs `npm publish` | 404 | trust config names one workflow; keep only that one publishing |

The two error strings are indistinguishable — check the raw YAML for the
filename match, permissions block, stray env vars, pinned versions,
`--access`, and workflow count.

## Verify after wiring

```bash
git tag v0.1.0 && git push origin v0.1.0
# workflow runs; watch it:
gh run list --workflow=Release
# npm side:
npm view <pkg> versions
npm view <pkg> dist-tags.latest
```

Success logs show:

```
npm notice publish Signed provenance statement with source and build information from GitHub Actions
npm notice publish Provenance statement published to transparency log: https://search.sigstore.dev/?logIndex=...
```

## Useful references

- npm docs: [Trusted publishing](https://docs.npmjs.com/trusted-publishers),
  [Provenance](https://docs.npmjs.com/generating-provenance-statements),
  [npm-trust CLI](https://docs.npmjs.com/cli/v11/commands/npm-trust)
- [npm/cli#8730](https://github.com/npm/cli/issues/8730) — registry-url vs OIDC
- [actions/setup-node#1477](https://github.com/actions/setup-node/pull/1477) — dummy NODE_AUTH_TOKEN
- The six failure causes article: https://dev.to/fernforge/why-your-npm-trusted-publishing-setup-404s-at-release-time-six-causes-checked-before-you-push-361g
