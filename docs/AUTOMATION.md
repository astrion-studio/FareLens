# FareLens Automation Guide

**Purpose:** Automated workflows for issue tracking, PR management, and security alerts
**Goal:** Zero manual intervention for routine tasks

---

## Table of Contents

1. [Automated PR-to-Issue Linking](#automated-pr-to-issue-linking)
2. [Dependabot Security Alert Workflow](#dependabot-security-alert-workflow)
3. [Deferred Dependency Tracking](#deferred-dependency-tracking)
4. [GitHub Actions Automation](#github-actions-automation)
5. [Codex AI Review Integration](#codex-ai-review-integration)

---

## Automated PR-to-Issue Linking

### How It Works

When creating a PR, use keywords in the description to auto-close issues:

```bash
# Automatically closes issue #123 when PR merges
gh pr create --title "fix: Date serialization bug" --body "Fixes #123

Changes:
- Convert Date to ISO8601 strings
- Update tests

Closes #123"
```

**Keywords that auto-close issues:**
- `Fixes #123`
- `Closes #123`
- `Resolves #123`
- `Fix #123`
- `Close #123`
- `Resolve #123`

### Workflow

```mermaid
Issue Created → PR Created with "Fixes #X" → PR Merged → Issue Auto-Closed
```

### Example

```bash
# 1. Issue exists: #11 "Implement watchlist TODOs"

# 2. Create PR that fixes it:
gh pr create \
  --title "feat: Implement watchlist creation and price history" \
  --body "Implements watchlist saving and price history API integration.

Fixes #11

## Changes
- Added watchlist creation endpoint
- Integrated price history API
- Updated DealDetailViewModel

Closes #11"

# 3. When PR merges → Issue #11 automatically closes ✅
```

### Best Practices

1. **One PR, One Issue**: Link PRs to specific issues
2. **Use Keywords**: Always use `Fixes #X` or `Closes #X`
3. **Describe What Fixed It**: Help future developers understand the fix

---

## Dependabot Security Alert Workflow

### How It Works

Dependabot automatically:
1. **Detects** vulnerabilities in dependencies
2. **Creates alerts** in Security tab
3. **Opens PRs** to fix vulnerabilities
4. **Re-checks** after PRs merge

### Current Setup

**Enabled for:**
- `backend/requirements.txt` (Python dependencies)
- `.github/workflows/*.yml` (GitHub Actions)
- Future: Swift Package Manager (when added)

### Automated Response Process

```mermaid
Security Alert Created → Dependabot Opens PR → CI Passes → Auto-Merge → Alert Closes
```

### Manual Intervention Required When:

1. **Breaking Changes** - Major version jumps
2. **No Auto-Fix** - Dependabot can't create PR
3. **Multiple Alternatives** - Need to choose replacement package

### Example: python-jose Vulnerability

**Alert Received:**
- CVE-2024-33664 (Critical): Algorithm confusion vulnerability
- CVE-2024-33663 (Medium): DoS vulnerability

**Automated Action:**
- Dependabot created alert #2 and #1
- No auto-fix available (package has fundamental issues)

**Manual Action (Claude Code):**
1. Researched secure alternatives (PyJWT)
2. Created PR #29 to replace python-jose
3. Enabled auto-merge on PR #29
4. PR merges → Alerts auto-close ✅

### Configuration

File: `.github/dependabot.yml`

```yaml
version: 2
updates:
  # Python dependencies (backend)
  - package-ecosystem: "pip"
    directory: "/backend"
    schedule:
      interval: "weekly"      # Check every Monday
      day: "monday"
      time: "09:00"
    open-pull-requests-limit: 5
    reviewers:
      - "astrion-studio"
    labels:
      - "dependencies"
      - "backend"

  # GitHub Actions
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
    labels:
      - "dependencies"
      - "ci"
```

### Security Alert Priority

| Severity | Response Time | Action |
|----------|---------------|--------|
| **Critical** | Immediate (same day) | Create PR, review, merge ASAP |
| **High** | 1-2 days | Create PR, schedule merge |
| **Medium** | 1 week | Bundle with other updates |
| **Low** | 1 month | Defer to quarterly maintenance |

### Automated Security Workflow

```bash
# When Dependabot creates security PR:

# 1. Check severity
gh api /repos/astrion-studio/FareLens/dependabot/alerts --jq '.[] | select(.state == "open")'

# 2. If Critical/High:
#    - Review PR immediately
#    - Enable auto-merge
gh pr merge <PR#> --auto --squash

# 3. If Medium/Low:
#    - Label as "deferred"
#    - Create tracking issue
gh issue create --title "Security: Update <package>" --label "security,dependencies"
```

---

## Deferred Dependency Tracking

### Problem

Some dependency updates can't be applied immediately due to:
- Breaking changes
- Lack of test coverage
- Unstable codebase

### Solution: Tracking Issue

When deferring a dependency update:

```bash
# 1. Close the Dependabot PR with reason
gh pr close <PR#> --comment "Deferring due to breaking changes. Tracked in #28"

# 2. Create or update tracking issue
gh issue create \
  --title "Update deferred dependencies (mypy, pydantic-settings, etc.)" \
  --body "## Deferred Updates

- [ ] mypy: 1.13.0 → 1.18.2 (from #23)
- [ ] pydantic-settings: 2.6.1 → 2.11.0 (from #24)

## When to Address
After backend API is stable and fully tested.

## Checklist
- [ ] Backend has >80% test coverage
- [ ] All endpoints implemented
- [ ] Create feature branch
- [ ] Update dependencies one-by-one
- [ ] Run full test suite
- [ ] Check changelogs for breaking changes
" \
  --label "dependencies"
```

### Current Tracking Issue

**Issue #28** tracks all deferred dependency updates:
- Python deps: mypy, pydantic-settings, flake8
- GitHub Actions: actions/checkout, swift-actions/setup-swift

### Review Schedule

- **Monthly**: Check tracking issue, decide if ready to apply
- **Quarterly**: Force review all deferred updates
- **Before v1.0 launch**: Must resolve all deferred updates

---

## GitHub Actions Automation

### Automated Issue Creation from CI Failures

**Future Enhancement** - Create issues automatically when CI fails:

```yaml
# .github/workflows/create-issue-on-failure.yml
name: Create Issue on CI Failure

on:
  workflow_run:
    workflows: ["Backend CI", "iOS CI"]
    types: [completed]

jobs:
  create-issue:
    if: ${{ github.event.workflow_run.conclusion == 'failure' }}
    runs-on: ubuntu-latest
    steps:
      - name: Create Issue
        uses: actions/github-script@v6
        with:
          script: |
            const title = `CI Failure: ${context.payload.workflow_run.name}`;
            const body = `Workflow \`${context.payload.workflow_run.name}\` failed.

            **Run:** ${context.payload.workflow_run.html_url}
            **Branch:** ${context.payload.workflow_run.head_branch}
            **Commit:** ${context.payload.workflow_run.head_sha}

            Please investigate and fix.`;

            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: title,
              body: body,
              labels: ['ci', 'bug', 'automated']
            });
```

### Automated Stale Issue Management

Close issues that haven't been updated in 60 days:

```yaml
# .github/workflows/stale.yml
name: Close Stale Issues

on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday

jobs:
  stale:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/stale@v8
        with:
          stale-issue-message: 'This issue has been inactive for 45 days. It will close in 15 days if no activity.'
          close-issue-message: 'Closed due to inactivity.'
          days-before-stale: 45
          days-before-close: 15
          exempt-issue-labels: 'pinned,security,critical'
```

---

## Codex AI Review Integration

### Automated Review Process

```mermaid
PR Created → Codex Reviews (30s) → Leaves Comments → Claude Fixes → @codex review → Codex Resolves → Auto-Merge
```

### Workflow

```bash
# 1. Create PR
gh pr create --title "feat: Add new feature" --fill

# 2. Codex automatically reviews (triggered by PR event)
# Wait ~30 seconds

# 3. If Codex leaves comments:
#    - Read feedback
#    - Make changes
#    - Commit and push

# 4. Request re-review
gh pr comment <PR#> --body "@codex review

Addressed your feedback:
- Fixed X
- Updated Y

Please re-review and resolve if satisfied."

# 5. Codex resolves conversation threads
# 6. PR auto-merges when all threads resolved
```

### Configuration

**Branch Protection:**
- ✅ Require conversation resolution before merging
- ✅ Require status checks to pass
- ❌ Do NOT require approvals (Codex uses comments, not approvals)
- ✅ Enable auto-merge on PRs

**Codex Setup:**
- URL: https://developers.openai.com/codex/cloud/code-review/
- Trigger: All PRs to `main` branch
- Comment format: Inline code review

---

## Complete Automation Checklist

### ✅ Currently Automated

- [x] PR-to-issue linking (via keywords)
- [x] Dependabot security alerts
- [x] Dependabot dependency PRs
- [x] CI/CD on all PRs
- [x] Codex AI code review
- [x] Auto-merge when checks pass
- [x] Pre-commit hooks (local)

### 🔄 Partially Automated

- [~] Security vulnerability response (Dependabot creates PR, human reviews)
- [~] Deferred dependency tracking (manual issue creation)
- [~] Issue closure (requires PR merge)

### ⏳ Not Yet Automated (Future Enhancements)

- [ ] Auto-create issues from CI failures
- [ ] Stale issue management
- [ ] Auto-label issues based on content
- [ ] Auto-assign issues to developers
- [ ] Release note generation
- [ ] Changelog updates

---

## FAQ

### Q: Do I need to manually close issues when PRs merge?

**A:** No, if you use `Fixes #X` in the PR description, the issue closes automatically when the PR merges.

### Q: How do I know when a security alert needs attention?

**A:** Check GitHub Security tab. Critical/High alerts should be addressed immediately. You'll also receive email notifications.

### Q: What happens to deferred Dependabot PRs?

**A:** They're tracked in issue #28. Review monthly and apply when safe.

### Q: Can Codex approve PRs?

**A:** No, Codex leaves comments and resolves conversations. It doesn't provide formal GitHub approvals. Auto-merge triggers when all conversations are resolved + CI passes.

### Q: How do I prevent auto-merge on a specific PR?

**A:** Don't enable auto-merge on that PR, or disable it with:
```bash
gh pr merge <PR#> --disable-auto
```

### Q: What if CI fails after auto-merge is enabled?

**A:** The PR won't merge until CI passes. Auto-merge waits for all requirements.

---

## Maintenance Tasks

### Weekly

- [ ] Review open Dependabot PRs
- [ ] Check Security tab for new alerts
- [ ] Review stale issues (>30 days old)

### Monthly

- [ ] Review issue #28 (deferred dependencies)
- [ ] Check if any deferred updates can be applied
- [ ] Review automation effectiveness

### Quarterly

- [ ] Force review all deferred dependencies
- [ ] Update automation workflows
- [ ] Review and prune old issues

---

## Next Steps

1. **Enable Stale Issue Bot** - Add `.github/workflows/stale.yml`
2. **Add CI Failure → Issue automation** - Add `.github/workflows/create-issue-on-failure.yml`
3. **Set up release automation** - Auto-generate changelogs and release notes
4. **Add auto-labeling** - Label issues based on keywords in title/body

**Related Documentation:**
- [WORKFLOW.md](../WORKFLOW.md) - Development workflow
- [CONTRIBUTING.md](../CONTRIBUTING.md) - Contribution guidelines
- [.github/dependabot.yml](../.github/dependabot.yml) - Dependabot configuration
