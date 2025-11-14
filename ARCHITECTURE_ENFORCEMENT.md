# Architecture Decision Enforcement

**Created:** 2025-11-13
**Reason:** FastAPI was built despite Cloudflare Workers being the documented architecture choice

## What Went Wrong

1. **Original Plan:** Cloudflare Workers (FREE, documented in BACKEND_SETUP.md)
2. **What Was Built:** FastAPI backend (requires hosting costs)
3. **Both Exist:** Parallel implementations without deprecation decision
4. **Impact:** Nearly migrated to paid hosting when free solution was already 95% complete

## Immediate Fix

✅ **Cloudflare Workers deployed as canonical backend**
❌ **FastAPI deprecated** (kept for reference only)

## Enforcement Mechanisms

### 1. Pre-Commit Check (Automated)

File: `.git/hooks/pre-commit`

```bash
#!/bin/bash
# Architecture enforcement hook

# Check for new Python API files in backend/
NEW_PY_FILES=$(git diff --cached --name-only --diff-filter=A | grep "^backend/app/api/.*\.py$" || true)

if [ -n "$NEW_PY_FILES" ]; then
    echo "❌ BLOCKED: New FastAPI endpoints detected"
    echo ""
    echo "FastAPI backend is DEPRECATED. Use Cloudflare Workers instead."
    echo ""
    echo "Blocked files:"
    echo "$NEW_PY_FILES"
    echo ""
    echo "See: ARCHITECTURE_ENFORCEMENT.md"
    exit 1
fi
```

### 2. CI Check (GitHub Actions)

File: `.github/workflows/architecture-check.yml`

```yaml
name: Architecture Enforcement

on: [push, pull_request]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check for FastAPI changes
        run: |
          if git diff --name-only origin/main...HEAD | grep -q "^backend/app/api/"; then
            echo "❌ FastAPI endpoints modified. Workers is canonical backend."
            exit 1
          fi
```

### 3. Documentation Marker

File: `backend/README.md`

```markdown
# ⚠️ DEPRECATED - DO NOT USE

This FastAPI backend is **DEPRECATED** as of 2025-11-13.

**Use Cloudflare Workers instead:** `cloudflare-workers/`

This directory is kept for:
- Historical reference
- Data model definitions (may be ported to Workers)
- Test examples

**DO NOT:**
- Add new endpoints here
- Deploy this to production
- Reference this in iOS app

See: [ARCHITECTURE_ENFORCEMENT.md](../ARCHITECTURE_ENFORCEMENT.md)
```

### 4. Agent Instructions (For AI Assistants)

File: `.claude/architecture-rules.md`

```markdown
# Architecture Rules - MUST FOLLOW

## Backend: Cloudflare Workers ONLY

**CANONICAL BACKEND:** `/cloudflare-workers/src/index.ts`

**NEVER:**
- Add new files to `backend/app/api/`
- Suggest deploying FastAPI
- Reference FastAPI in implementation plans

**ALWAYS:**
- Check Workers implementation first
- Propose Workers solutions
- Ask user before architectural changes

## Why This Matters

FastAPI was built despite Workers being documented. Cost: nearly $20/mo unnecessary hosting.

If user asks for backend changes:
1. Check if Workers already implements it
2. Propose Workers solution
3. **Get explicit approval** before creating new backend patterns
```

## Decision Log

### Decision: Cloudflare Workers as Canonical Backend

**Date:** 2025-11-13
**Reason:**
- FREE (100K req/day, $0/month)
- Global edge (low latency)
- Auto-scaling
- Zero maintenance
- **Already 95% implemented**

**FastAPI:**
- Costs $5-20/month minimum
- Single region (higher latency)
- Manual scaling required
- Server maintenance burden
- **Redundant with Workers**

### Why Wasn't This Enforced Before?

**Root Cause:** No automated checks. Documentation was ignored.

**Fix:** Automated enforcement (pre-commit hook + CI) + clear deprecation markers

## Verification

Run these checks:

```bash
# 1. Verify pre-commit hook installed
ls -la .git/hooks/pre-commit

# 2. Verify Workers deployed
cd cloudflare-workers && npx wrangler deployments list

# 3. Verify FastAPI marked deprecated
head -5 backend/README.md | grep DEPRECATED
```

## Future Architectural Decisions

**RULE:** All architectural decisions require:

1. ✅ Documentation in ARCHITECTURE.md
2. ✅ Automated enforcement (pre-commit or CI)
3. ✅ Deprecation markers for old patterns
4. ✅ Explicit user approval for deviations

**NO MORE:**
- Building alternatives without deprecating old ones
- Ignoring documented architecture
- Assuming user knows about parallel implementations
