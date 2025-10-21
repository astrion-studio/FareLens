# Pull Request Review Checklist

This document defines the mandatory checklist for ALL pull requests to prevent premature merges and ensure code quality.

## ⚠️ CRITICAL: Never Merge Until ALL Items Complete

**Auto-merge should ONLY be enabled after ALL checklist items are verified.**

---

## Pre-Merge Checklist

### 1. Codex Review Status ✅

- [ ] **Wait for Codex review** - Do NOT merge immediately after creating PR
- [ ] **Read ALL Codex comments** - Every comment must be addressed
- [ ] **Resolve ALL conversations** - No unresolved threads allowed
- [ ] **Address blocking (P0) issues** - Critical issues must be fixed before merge
- [ ] **Address high-priority (P1) issues** - Important issues should be fixed or documented
- [ ] **Respond to medium-priority (P2) suggestions** - Accept, reject with reason, or create follow-up issue

**Verification Command:**
```bash
gh pr view <PR_NUMBER> --json reviews,comments
```

### 2. CI/CD Pipeline Status ✅

- [ ] **All GitHub Actions passing** - Green checkmarks required
- [ ] **iOS build succeeds** - Xcode project compiles without errors
- [ ] **All tests pass** - Unit tests, integration tests green
- [ ] **Code quality checks pass** - SwiftFormat, SwiftLint, iOS 26 patterns
- [ ] **No new force unwraps** - Safe optional handling required
- [ ] **No print statements** - Use OSLog for logging

**Verification Command:**
```bash
gh pr checks <PR_NUMBER>
```

### 3. Manual Testing ✅

**If Xcode project exists:**
- [ ] **Build on Xcode** - Verify local build succeeds
- [ ] **Run on simulator** - Test feature on iPhone simulator
- [ ] **Run on device** - Test on physical iPhone (if applicable)
- [ ] **No runtime crashes** - App runs without crashing
- [ ] **Feature works as expected** - Manual testing confirms fix/feature

**If Xcode project does NOT exist yet:**
- [ ] **Syntax validation** - Run `swiftc -typecheck` on modified files
- [ ] **Code review only** - Focus on logic, patterns, architecture

### 4. Code Quality Standards ✅

- [ ] **Follows iOS 26 patterns** - @Observable, @State, @Bindable correctly used
- [ ] **No compilation errors** - All type mismatches resolved
- [ ] **No breaking changes** - Existing APIs remain compatible
- [ ] **Tests updated** - Tests reflect code changes
- [ ] **Documentation updated** - README, inline comments current

### 5. Issue Tracking ✅

- [ ] **PR links to issue** - `Fixes #XX` in PR description
- [ ] **Issue describes problem** - Clear problem statement exists
- [ ] **Solution matches issue** - PR addresses exact issue raised
- [ ] **Acceptance criteria met** - All checklist items in issue completed

---

## When to Enable Auto-Merge

**ONLY enable auto-merge (`gh pr merge --auto --squash`) when:**

1. ✅ All 5 checklist sections above are complete
2. ✅ Codex review is APPROVED or all comments addressed
3. ✅ CI/CD pipeline is GREEN
4. ✅ Manual testing confirms no regressions
5. ✅ At least 1 hour has passed since PR creation (allows time for thorough review)

---

## Process Violations: What Went Wrong

### Incident: PR #62 Merged Too Early

**What happened:**
- PR #62 created and auto-merge enabled immediately
- Codex posted review comments AFTER auto-merge was enabled
- PR merged before Codex comments were addressed
- Required follow-up PR to fix issues

**Root cause:**
- Auto-merge enabled in same command as PR creation
- Did not wait for Codex review
- Did not verify all comments addressed

**Prevention:**
1. **Never run `gh pr merge --auto` immediately after `gh pr create`**
2. **Always wait for Codex review: minimum 5-10 minutes**
3. **Check for comments: `gh pr view <PR> --json reviews`**
4. **Only enable auto-merge after ALL checklist items verified**

---

## Correct PR Workflow

### Step 1: Create PR
```bash
# Create branch
git checkout -b fix/my-feature

# Make changes, commit
git add .
git commit -m "fix: Description"
git push -u origin fix/my-feature

# Create PR
gh pr create --title "fix: Description" --fill
```

### Step 2: Wait for Codex Review (5-10 minutes)
```bash
# Check review status
gh pr view <PR_NUMBER>

# View comments
gh pr view <PR_NUMBER> --json reviews,comments
```

### Step 3: Address All Codex Feedback
```bash
# Make fixes
git add .
git commit -m "fix: Address Codex feedback - <description>"
git push

# Resolve conversations on GitHub
# Reply to each comment with fix confirmation
```

### Step 4: Verify CI/CD Green
```bash
# Check all actions passing
gh pr checks <PR_NUMBER>

# Wait for all checks to complete
```

### Step 5: Manual Testing
```bash
# If Xcode project exists:
cd ios-app
open FareLens.xcodeproj

# Build: Cmd+B
# Run: Cmd+R on simulator
# Test feature manually
```

### Step 6: Enable Auto-Merge (ONLY AFTER STEPS 1-5)
```bash
# ONLY run this after ALL checklist items complete
gh pr merge <PR_NUMBER> --auto --squash
```

---

## Monitoring Commands

### Check PR Status
```bash
# View PR summary
gh pr view <PR_NUMBER>

# Check if Codex reviewed
gh pr view <PR_NUMBER> --json reviews

# Check CI/CD status
gh pr checks <PR_NUMBER>

# View all conversations
gh pr view <PR_NUMBER> --comments
```

### Check Open PRs
```bash
# List all open PRs
gh pr list --state open

# Check which PRs have auto-merge enabled
gh pr list --state open --json number,title,autoMergeRequest
```

---

## Red Flags 🚩

**STOP and investigate if:**
- ⛔ PR merged in <5 minutes after creation
- ⛔ Codex has unresolved conversation threads
- ⛔ CI/CD shows red X or yellow ⚠️
- ⛔ Build fails on local Xcode
- ⛔ Any compilation errors exist
- ⛔ Tests are failing
- ⛔ Force unwraps added without justification
- ⛔ Breaking changes without migration plan

---

## Emergency: PR Merged Too Early

**If a PR merges before checklist complete:**

1. **Immediately create follow-up issue**
   ```bash
   gh issue create --title "CRITICAL: Address missed review feedback from PR #XX" --label critical
   ```

2. **Create follow-up PR**
   ```bash
   git checkout main
   git pull
   git checkout -b fix/pr-XX-followup
   # Make fixes
   # Follow FULL checklist this time
   ```

3. **Document in incident log**
   - Add to this file under "Process Violations"
   - Explain what went wrong
   - Document prevention steps

---

## Success Metrics

**Quality indicators:**
- ✅ Zero PRs merged with unresolved Codex comments
- ✅ Zero post-merge compilation errors
- ✅ Zero post-merge test failures
- ✅ All PRs have linked issues
- ✅ All PRs pass CI/CD before merge
- ✅ Average time from PR creation to merge: >2 hours (shows proper review)

**Warning indicators:**
- ⚠️ PRs merging in <10 minutes (too fast, likely skipped review)
- ⚠️ Multiple follow-up PRs fixing same issue (incomplete initial review)
- ⚠️ Build failures on main branch (merge without testing)
- ⚠️ Codex comments ignored (quality degradation)

---

## Version History

| Date | Change | Reason |
|------|--------|--------|
| 2025-10-21 | Created document | PR #62 merged before Codex review complete |

---

**Remember: Taking 1 extra hour to review properly prevents 10 hours of debugging later.**
