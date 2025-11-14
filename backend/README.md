# ⚠️ DEPRECATED - DO NOT USE

**This FastAPI backend is DEPRECATED as of 2025-11-13.**

## Use Cloudflare Workers Instead

**Canonical backend:** [`cloudflare-workers/src/index.ts`](../cloudflare-workers/src/index.ts)
**Live deployment:** https://farelens-api.woodcut-rabbles5e.workers.dev

## Why Deprecated?

1. **Cost:** FastAPI requires hosting ($5-20/month). Workers is FREE (100K req/day).
2. **Scalability:** FastAPI requires manual scaling. Workers auto-scales globally.
3. **Maintenance:** FastAPI needs server management. Workers is serverless.
4. **Architecture:** Workers was the documented plan (see BACKEND_SETUP.md).

## Enforcement

Automated checks prevent FastAPI additions:
- Pre-commit hook blocks new endpoints
- CI check blocks PRs with FastAPI changes

See: [ARCHITECTURE_ENFORCEMENT.md](../ARCHITECTURE_ENFORCEMENT.md)
