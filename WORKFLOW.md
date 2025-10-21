# FareLens Development Workflow

**Purpose:** Ideal development process to prevent the issues that caused 8 review cycles
**Target:** 2-3 review cycles maximum with incremental quality gates
**Philosophy:** Review early, commit often, automate everything

---

## Table of Contents

1. [Project Initialization](#project-initialization)
2. [Daily Development Workflow](#daily-development-workflow)
3. [Feature Development Cycle](#feature-development-cycle)
4. [Review and Quality Gates](#review-and-quality-gates)
5. [Git Workflow](#git-workflow)
6. [Screenshot Verification](#screenshot-verification)
7. [Session Management](#session-management)
8. [Issue Tracking](#issue-tracking)

---

## Project Initialization

### Day 1: Professional Setup (1 hour)

**Before writing any code:**

```bash
# 1. Create project in proper location (NOT Desktop)
mkdir -p ~/Projects/FareLens
cd ~/Projects/FareLens

# 2. Initialize git immediately
git init
git config user.name "Your Name"
git config user.email "your.email@example.com"

# 3. Create .gitignore
cat > .gitignore <<'EOF'
# Xcode
*.xcodeproj/*
!*.xcodeproj/project.pbxproj
*.xcworkspace/*
!*.xcworkspace/contents.xcworkspacedata
xcuserdata/
DerivedData/
.build/
*.ipa
*.dSYM.zip

# Swift Package Manager
.swiftpm/

# CocoaPods
Pods/

# Mac
.DS_Store

# Secrets
.env
credentials.json
secrets/
EOF

# 4. Initial commit
git add .gitignore
git commit -m "chore: Initialize project with .gitignore"

# 5. Create GitHub repo and push
gh repo create farelens-ios --private --source=. --push

# 6. Create branch protection rules
gh api repos/:owner/farelens-ios/branches/main/protection \
  -X PUT \
  -f required_status_checks[strict]=true \
  -f required_status_checks[contexts][]=quality-gate \
  -f enforce_admins=false \
  -f required_pull_request_reviews[dismiss_stale_reviews]=true
```

### Day 1: Install Tooling

```bash
# 1. Install development tools
brew install swiftlint swiftformat gh

# 2. Install Linear CLI (for issue tracking)
npm install -g @linear/cli
linear auth

# 3. Configure SwiftLint
cat > .swiftlint.yml <<'EOF'
opt_in_rules:
  - force_unwrapping  # Error on !
  - force_cast        # Error on as!
  - explicit_init     # Avoid .init()
  - trailing_closure  # Prefer trailing closure syntax

disabled_rules:
  - line_length  # Handled by formatter

custom_rules:
  observable_pattern:
    regex: 'ObservableObject'
    message: "Use @Observable (iOS 26) instead of ObservableObject"
    severity: error

  stateobject_pattern:
    regex: '@StateObject.*@Observable'
    message: "Use @State with @Observable, not @StateObject"
    severity: error

  published_pattern:
    regex: '@Published.*@Observable'
    message: "@Observable classes use plain var, not @Published"
    severity: error

excluded:
  - Pods
  - DerivedData
  - .build
EOF

git add .swiftlint.yml
git commit -m "chore: Configure SwiftLint with iOS 26 pattern checks"

# 4. Configure SwiftFormat
cat > .swiftformat <<'EOF'
--indent 4
--maxwidth 120
--wraparguments before-first
--wrapcollections before-first
--closingparen same-line
--header "// FareLens\n// Copyright © {year} FareLens. All rights reserved."
EOF

git add .swiftformat
git commit -m "chore: Configure SwiftFormat"
```

### Day 1: Create Automation Scripts

```bash
mkdir -p scripts

# 1. iOS 26 Pattern Validator
cat > scripts/check-ios26-patterns.sh <<'EOF'
#!/bin/bash
# Validates iOS 26 @Observable pattern compliance

set -e

echo "🔍 Checking iOS 26 pattern compliance..."

# Check for legacy ObservableObject
if grep -r "ObservableObject" ios-app/ 2>/dev/null; then
    echo "❌ ERROR: Found ObservableObject (legacy pattern)"
    echo "   Use @Observable instead (iOS 26+)"
    exit 1
fi

# Check for @StateObject with @Observable
if grep -r "@StateObject" ios-app/ | grep -q "@Observable"; then
    echo "❌ ERROR: Found @StateObject with @Observable"
    echo "   Use @State with @Observable classes"
    exit 1
fi

# Check for @Published in @Observable classes
if grep -r "@Published" ios-app/ | grep -q "@Observable"; then
    echo "❌ ERROR: Found @Published in @Observable class"
    echo "   @Observable classes use plain var properties"
    exit 1
fi

# Check for force unwraps (!) in production code (exclude tests)
if grep -r "!" ios-app/ --include="*.swift" --exclude="*Tests.swift" | grep -v "//" | grep -q "!"; then
    echo "⚠️  WARNING: Found force unwraps (!) in production code"
    echo "   Consider using optional binding or nil coalescing"
fi

echo "✅ All iOS 26 patterns valid"
EOF

chmod +x scripts/check-ios26-patterns.sh
git add scripts/
git commit -m "chore: Add iOS 26 pattern validation script"

# 2. Pre-commit Hook
cat > .git/hooks/pre-commit <<'EOF'
#!/bin/bash
# Pre-commit quality gate

set -e

echo "🔒 Running pre-commit checks..."

# 1. Check iOS 26 patterns
./scripts/check-ios26-patterns.sh

# 2. Run SwiftLint
echo "🔍 Running SwiftLint..."
swiftlint --strict

# 3. Run SwiftFormat (check only, don't fix)
echo "🎨 Checking formatting..."
swiftformat --lint .

echo "✅ Pre-commit checks passed"
EOF

chmod +x .git/hooks/pre-commit
```

### Day 2-3: Requirements Documentation

```bash
git checkout -b docs/requirements

# 1. Use product-manager to create PRD.md
# (Claude Code subagent workflow)

# 2. Use product-designer to create DESIGN.md
# (Claude Code subagent workflow)

# 3. Use ios-architect to create ARCHITECTURE.md
# (Claude Code subagent workflow)

# 4. Use backend-architect to create API.md (if needed)
# (Claude Code subagent workflow)

# Commit each document as it's created
git add PRD.md
git commit -m "docs: Add Product Requirements Document (v1.0)"

git add DESIGN.md
git commit -m "docs: Add Design System specification (v1.0)"

git add ARCHITECTURE.md
git commit -m "docs: Add iOS architecture decisions (v1.0)"

git add API.md
git commit -m "docs: Add API contracts (v1.0)"

# Merge to main
git checkout main
git merge docs/requirements --no-ff
git push
```

**Result:** Clear roadmap before writing code

---

## Daily Development Workflow

### Morning Routine

```bash
# 1. Pull latest changes
git checkout main
git pull

# 2. Check for updates from team
gh pr list --state open

# 3. Review Linear issues assigned to you
linear issue list --assignee @me --state "In Progress"

# 4. Create SESSION_LOG.md entry
cat >> SESSION_LOG.md <<EOF

## Session $(date +%Y-%m-%d) ($(date +%I%p))
**Goal:** [Your goal for today]
**Branch:** feature/[feature-name]
**Linear Issues:** LIN-123, LIN-124
**Last Session:** [Reference previous session if continuing work]

### Plan
- [ ] Task 1
- [ ] Task 2
- [ ] Task 3

### Commits
(Will be filled as you commit)

### Decisions Made
(Will be filled as you code)

### Next Session
(Will be filled at end of session)

EOF
```

### During Development

**For EVERY feature you build:**

```bash
# 1. Create feature branch
git checkout -b feature/alerts-view

# 2. Write test first (TDD)
# Create test file, write failing tests
git add ios-app/FareLensTests/AlertsViewModelTests.swift
git commit -m "test: Add AlertsViewModel tests (TDD)"

# 3. Implement minimal code
# Write implementation to pass tests
git add ios-app/FareLens/Features/Alerts/AlertsViewModel.swift
git commit -m "feat(alerts): Implement AlertsViewModel with @Observable"

# 4. Run code-reviewer IMMEDIATELY (not at end!)
# Use Claude Code: "Run code-reviewer on AlertsViewModel"
# Fix any P0/P1 issues found (should be 0-2, not 5+)

# 5. Commit fixes
git add .
git commit -m "fix: Resolve code review issues in AlertsViewModel"

# 6. Take screenshot (if UI change)
./scripts/take-screenshots.sh AlertsView
git add design-refs/actual/AlertsView-$(date +%Y%m%d).png
git commit -m "docs: Add AlertsView screenshot"

# 7. Run automated checks
swiftlint
./scripts/check-ios26-patterns.sh

# 8. Push and create PR
git push -u origin feature/alerts-view
gh pr create --title "feat(alerts): Implement AlertsView" --body "$(cat <<'PRBODY'
## Summary
Implements AlertsView with @Observable ViewModel pattern.

## Changes
- ✅ AlertsViewModel with iOS 26 @Observable
- ✅ AlertsView SwiftUI implementation
- ✅ Tests with 95% coverage
- ✅ Screenshot verification

## Testing
- All tests pass
- Code reviewer approved (0 P0 issues)
- Screenshot matches mockups

## References
- Linear: LIN-123
- Design: DESIGN.md Section 4.3
PRBODY
)"
```

**Key Difference from Old Workflow:**
- OLD: Write 10 features → Review all at once → Find 22 issues
- NEW: Write 1 feature → Review immediately → Find 0-2 issues → Repeat

### End of Session

```bash
# 1. Update SESSION_LOG.md
cat >> SESSION_LOG.md <<EOF

### Session Complete
**Commits:** $(git log --oneline --since="today" | wc -l) commits
**Issues Fixed:** P0: 1, P1: 2
**Tests Added:** 15 tests (98% coverage)
**Next Session:** Continue with DealsView implementation

EOF

# 2. Commit session log
git add SESSION_LOG.md
git commit -m "docs: Update session log ($(date +%Y-%m-%d))"

# 3. Push all work
git push
```

---

## Feature Development Cycle

### Incremental Implementation Pattern

```bash
# For each feature (Alerts, Deals, Watchlists, Settings, Onboarding):

for feature in "alerts" "deals" "watchlists" "settings" "onboarding"; do
  echo "===== Building $feature ====="

  # 1. Create feature branch
  git checkout -b feature/$feature

  # 2. TDD: Tests first
  # Create test file with comprehensive tests
  git add ios-app/FareLensTests/${feature}Tests.swift
  git commit -m "test: Add ${feature} tests (TDD approach)"

  # 3. Implement ViewModel
  # Use iOS_26_PATTERNS.md as reference
  git add ios-app/FareLens/Features/${feature}ViewModel.swift
  git commit -m "feat(${feature}): Implement ViewModel with @Observable"

  # 4. Implement View
  git add ios-app/FareLens/Features/${feature}View.swift
  git commit -m "feat(${feature}): Implement SwiftUI View"

  # 5. Run code-reviewer IMMEDIATELY
  # Claude Code: "Run code-reviewer on $feature"
  # Should find 0-2 issues (not 5+)

  # 6. Fix issues found
  git add .
  git commit -m "fix(${feature}): Resolve code review issues"

  # 7. Take screenshot
  ./scripts/take-screenshots.sh ${feature}View
  git add design-refs/actual/${feature}-$(date +%Y%m%d).png
  git commit -m "docs: Add ${feature} screenshot"

  # 8. Compare screenshot vs mockups
  open design-refs/mockups/${feature}.png
  open design-refs/actual/${feature}-$(date +%Y%m%d).png
  # Fix any UI discrepancies

  # 9. Push and create PR
  git push -u origin feature/$feature
  gh pr create --title "feat(${feature}): Implement feature" --fill

  # 10. Wait for CI to pass, then merge
  gh pr merge --auto --squash

  # 11. Move to next feature
  git checkout main
  git pull
done
```

**Result:**
- 5 features × 3-4 commits each = 15-20 commits (vs 1 massive commit)
- 5 screenshots (vs 0)
- 0-10 total issues (vs 22)
- 1 review cycle per feature (vs 8 at end)

---

## Review and Quality Gates

### Layer 1: Automated Pre-Commit (Runs on Every Commit)

```bash
# Automatically runs via .git/hooks/pre-commit
# - SwiftLint (style, patterns)
# - SwiftFormat (formatting)
# - iOS 26 pattern checks
# - Basic compilation check

# If fails: Commit blocked until fixed
```

### Layer 2: Incremental Code Review (After Each Feature)

```bash
# After implementing each feature:
# Use Claude Code code-reviewer subagent

# Expected results per feature:
# - P0 issues: 0-1 (not 5)
# - P1 issues: 0-2 (not 11)
# - P2 issues: 0-1 (not 6)

# Fix immediately before moving to next feature
```

### Layer 3: Codex AI Review (Automated PR Review)

**Workflow:**
```bash
# 1. Create PR
gh pr create --title "feat: Add new feature" --fill

# 2. Codex automatically reviews (triggered by PR creation)
# Wait ~30 seconds for Codex to comment

# 3. If Codex leaves comments:
#    - Read the feedback
#    - Make necessary changes
#    - Commit and push

# 4. Request re-review from Codex
gh pr comment <PR#> --body "@codex review

Addressed your feedback:
- Fixed X issue
- Updated Y implementation
- Resolved Z concern

Please re-review and resolve if satisfied."

# 5. Codex re-reviews
# - If satisfied: Resolves conversation thread
# - If not: Leaves more comments

# 6. Once all threads resolved: PR auto-merges
```

**Configuration:**
- **Branch Protection:** Require conversation resolution before merging
- **Auto-merge:** Enabled on PRs
- **Codex Setup:** Trigger on all PRs to `main` branch

### Layer 4: PR Automated Checks (Before Merge)

```yaml
# GitHub Actions (.github/workflows/pr-quality-gate.yml)
name: PR Quality Gate

on:
  pull_request:
    branches: [main]

jobs:
  quality-gate:
    runs-on: macos-latest

    steps:
      - uses: actions/checkout@v4

      - name: Run SwiftLint
        run: swiftlint --strict

      - name: Check iOS 26 Patterns
        run: ./scripts/check-ios26-patterns.sh

      - name: Run Tests
        run: xcodebuild test -scheme FareLens -destination 'platform=iOS Simulator,name=iPhone 15'

      - name: Build
        run: xcodebuild build -scheme FareLens -destination 'platform=iOS Simulator,name=iPhone 15'

      - name: Check Test Coverage
        run: |
          xcrun llvm-cov report --instr-profile=*.profdata *.xctest/Contents/MacOS/* | \
          awk '/TOTAL/{if ($NF < 80.00) exit 1}'

      - name: Comment PR with Results
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '✅ Quality gate passed'
            })
```

**PR cannot merge unless:**
- All tests pass
- SwiftLint clean
- iOS 26 patterns valid
- Coverage ≥80% (≥95% for critical paths)
- Build succeeds

### Layer 5: Integration Review (After All Features)

```bash
# After all features merged:
# Run comprehensive 5-layer review (from CLAUDE.md)

# Use Claude Code: "Run comprehensive zero-defect review"

# Should find:
# - Cycle 1: 0-3 integration issues (not 22)
# - Cycle 2: 0 issues (validation cycle)

# Tag release
git tag v1.0-production-ready
git push --tags
```

---

## Git Workflow

### Branch Strategy

```
main (protected)
├── docs/requirements (PRD, DESIGN, ARCHITECTURE)
├── feature/alerts (AlertsView + ViewModel + Tests)
├── feature/deals (DealsView + ViewModel + Tests)
├── feature/watchlists (WatchlistsView + ViewModel + Tests)
├── feature/settings (SettingsView + ViewModel + Tests)
├── feature/onboarding (OnboardingView + Tests)
├── fix/lin-123 (Bug fix)
└── refactor/extract-service (Code improvement)
```

### Commit Message Convention

```bash
# Format: <type>(<scope>): <description>

# Types:
feat: New feature
fix: Bug fix
refactor: Code restructuring (no behavior change)
test: Add/update tests
docs: Documentation changes
chore: Tooling, dependencies, config
perf: Performance improvement
style: Formatting (no code change)

# Examples:
git commit -m "feat(alerts): Implement AlertsViewModel with @Observable"
git commit -m "fix(cycle-1): Remove duplicate DealDetailViewModel"
git commit -m "test(deals): Add DealsViewModel integration tests"
git commit -m "docs: Update iOS 26 pattern guide"
git commit -m "chore: Configure SwiftLint rules"

# Link to Linear issues:
git commit -m "fix: Resolve race condition in deal fetching (LIN-123)"
```

### Commit Frequency

**Golden Rule: Commit after every logical change**

```bash
# ✅ GOOD (incremental commits):
git commit -m "feat(alerts): Add AlertsViewModel"
git commit -m "feat(alerts): Add AlertsView UI"
git commit -m "test(alerts): Add ViewModel tests"
git commit -m "fix: Resolve code review issues"
git commit -m "docs: Add alerts screenshot"

# Result: 5 commits, clear history, can rollback any step

# ❌ BAD (batch commit):
git add .
git commit -m "Implement alerts feature"

# Result: 1 commit, unclear what changed, can't rollback partially
```

### Daily Push Cadence

```bash
# Push at least:
# - End of each feature (even if incomplete)
# - End of each session
# - Before closing laptop

# Why:
# - Backup to GitHub (safety)
# - Team visibility
# - Can continue from different machine
```

---

## Screenshot Verification

### Setup (One-Time)

```bash
# Create screenshot script
cat > scripts/take-screenshots.sh <<'EOF'
#!/bin/bash
# Takes screenshots of specified view in iOS Simulator

VIEW_NAME=$1
OUTPUT_DIR="design-refs/actual"
SCHEME="FareLens"
SIMULATOR="iPhone 15"

if [ -z "$VIEW_NAME" ]; then
    echo "Usage: ./take-screenshots.sh <ViewName>"
    exit 1
fi

mkdir -p $OUTPUT_DIR

echo "📸 Taking screenshot of $VIEW_NAME..."

# 1. Boot simulator if not running
xcrun simctl boot "$SIMULATOR" 2>/dev/null || true

# 2. Build and run UI tests
xcodebuild test \
    -scheme $SCHEME \
    -destination "platform=iOS Simulator,name=$SIMULATOR" \
    -only-testing:FareLensUITests/ScreenshotTests/test_${VIEW_NAME}

# 3. Copy screenshot from DerivedData
SCREENSHOT_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Attachment_*.png" | head -1)
if [ -f "$SCREENSHOT_PATH" ]; then
    cp "$SCREENSHOT_PATH" "$OUTPUT_DIR/${VIEW_NAME}-$(date +%Y%m%d-%H%M%S).png"
    echo "✅ Screenshot saved to $OUTPUT_DIR/${VIEW_NAME}-$(date +%Y%m%d-%H%M%S).png"
else
    echo "❌ Screenshot not found"
    exit 1
fi
EOF

chmod +x scripts/take-screenshots.sh
```

### Workflow: After Every UI Change

```bash
# 1. Implement view
git commit -m "feat(alerts): Implement AlertsView UI"

# 2. Take screenshot
./scripts/take-screenshots.sh AlertsView

# 3. Compare vs mockups
open design-refs/mockups/AlertsView.png  # Expected
open design-refs/actual/AlertsView-*.png  # Actual

# 4. Fix UI discrepancies
# Adjust colors, spacing, alignment
git commit -m "fix(alerts): Adjust spacing to match mockups"

# 5. Take new screenshot
./scripts/take-screenshots.sh AlertsView

# 6. Commit screenshot with code
git add design-refs/actual/AlertsView-*.png
git commit -m "docs: Add AlertsView screenshot (verified vs mockups)"
```

### Automated Visual Regression Testing

```swift
// FareLensUITests/ScreenshotTests.swift
import XCTest

final class ScreenshotTests: XCTestCase {
    func test_AlertsView() {
        let app = XCUIApplication()
        app.launch()

        // Navigate to AlertsView
        app.tabBars.buttons["Alerts"].tap()

        // Wait for content
        sleep(2)

        // Take screenshot
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "AlertsView"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func test_DealsView() {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Deals"].tap()
        sleep(2)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "DealsView"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

---

## Session Management

### Handling Claude Code Session Limits

**Problem:** Hit session limits → Lost context → Repeated explanations

**Solution:** Progressive documentation in SESSION_LOG.md

### Template: SESSION_LOG.md

```markdown
# FareLens Session Log

Purpose: Preserve context across Claude Code sessions

---

## Session 2025-10-13-1 (11am-1pm)

**Context:** Starting UI implementation after completing ARCHITECTURE.md

**What We Built:**
- AlertsView (AlertsView.swift, AlertsViewModel.swift)
- DealsView (DealsView.swift, DealsViewModel.swift)
- 5 reusable components (FLButton, FLCard, etc.)

**Commits:**
- abc123: feat(alerts): Implement AlertsViewModel with @Observable
- def456: feat(alerts): Implement AlertsView UI
- ghi789: feat(deals): Implement DealsViewModel
- jkl012: test(alerts): Add comprehensive ViewModel tests

**Issues Fixed:**
- P0-1: Duplicate DealDetailViewModel definition
- P0-2: @StateObject used with @Observable
- P1-3: Missing error handling in loadAlerts()

**Key Decisions:**
- Extract ViewModels to separate files (maintainability)
- Use @Observable pattern for all ViewModels (iOS 26)
- Inject dependencies via init (testability)

**Screenshots Taken:**
- AlertsView (matches mockups ✅)
- DealsView (needs spacing adjustment ⚠️)

**Next Session:**
- Fix DealsView spacing issue
- Implement WatchlistsView
- Run code-reviewer Cycle 2

**Files Modified:**
- ios-app/FareLens/Features/Alerts/AlertsViewModel.swift
- ios-app/FareLens/Features/Alerts/AlertsView.swift
- ios-app/FareLens/Features/Deals/DealsViewModel.swift
- ios-app/FareLens/Features/Deals/DealsView.swift

---

## Session 2025-10-13-2 (3pm-5pm)

**Continued From:** Session 2025-10-13-1 (see above)

**Context:** Just completed Cycle 1 fixes, ready for WatchlistsView

**What We Built:**
[Fill as you work...]

**Commits:**
[Fill as you commit...]

**Issues Fixed:**
[Fill as issues arise...]

**Key Decisions:**
[Fill as decisions made...]

**Next Session:**
[Fill at end of session...]

---
```

### Starting New Session

```markdown
When starting new Claude Code session:

1. Read SESSION_LOG.md (last 2 sessions)
2. Read ARCHITECTURE.md (decisions)
3. Read PRD.md (requirements)
4. git log --oneline -20 (recent commits)
5. git status (current state)
6. linear issue list --assignee @me (your issues)

This provides full context in <2 minutes.
```

---

## Issue Tracking

### Use Linear or GitHub Issues

```bash
# Create issue for each P0/P1/P2 found
linear issue create \
  --title "P0: Duplicate DealDetailViewModel causes compilation error" \
  --priority urgent \
  --project FareLens \
  --estimate 1

# Link commits to issues
git commit -m "fix: Remove duplicate DealDetailViewModel (LIN-23)"

# Close issue when fixed
linear issue close LIN-23
```

### Issue Hierarchy

```
Epic: FareLens v1.0
├── Feature: Alerts System (LIN-10)
│   ├── Task: Implement AlertsViewModel (LIN-11) ✅
│   ├── Task: Implement AlertsView UI (LIN-12) ✅
│   └── Bug: P0 - @StateObject mixing (LIN-13) ✅
├── Feature: Deals Feed (LIN-20)
│   ├── Task: Implement DealsViewModel (LIN-21) ✅
│   ├── Task: Implement DealsView UI (LIN-22) ⏳
│   └── Bug: P1 - Missing error handling (LIN-23) ⏳
└── Feature: Watchlists (LIN-30)
    └── Task: Implement WatchlistsView (LIN-31) 🔜
```

### Velocity Tracking

```bash
# Generate sprint report
linear issue list --state closed --updated-after "2025-10-01" | \
  awk '/P0/{p0++} /P1/{p1++} /P2/{p2++} END{print "Closed: P0=" p0 ", P1=" p1 ", P2=" p2}'

# Result:
# Closed: P0=5, P1=11, P2=6
# Velocity: 22 issues/week
```

---

## Automation and Issue Tracking

### Automated PR-to-Issue Linking

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

**Best Practices:**
1. **One PR, One Issue**: Link PRs to specific issues
2. **Use Keywords**: Always use `Fixes #X` or `Closes #X`
3. **Describe What Fixed It**: Help future developers understand the fix

### Dependabot Security Alert Workflow

Dependabot automatically:
1. **Detects** vulnerabilities in dependencies
2. **Creates alerts** in Security tab
3. **Opens PRs** to fix vulnerabilities
4. **Re-checks** after PRs merge

**Current Setup:**
- Enabled for `backend/requirements.txt` (Python dependencies)
- Enabled for `.github/workflows/*.yml` (GitHub Actions)
- Future: Swift Package Manager (when added)

**Security Alert Priority:**

| Severity | Response Time | Action |
|----------|---------------|--------|
| **Critical** | Immediate (same day) | Create PR, review, merge ASAP |
| **High** | 1-2 days | Create PR, schedule merge |
| **Medium** | 1 week | Bundle with other updates |
| **Low** | 1 month | Defer to quarterly maintenance |

**Manual Intervention Required When:**
1. **Breaking Changes** - Major version jumps
2. **No Auto-Fix** - Dependabot can't create PR
3. **Multiple Alternatives** - Need to choose replacement package

### Deferred Dependency Tracking

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

**Review Schedule:**
- **Monthly**: Check tracking issue, decide if ready to apply
- **Quarterly**: Force review all deferred updates
- **Before v1.0 launch**: Must resolve all deferred updates

### Automation Checklist

**✅ Currently Automated:**
- PR-to-issue linking (via keywords)
- Dependabot security alerts
- Dependabot dependency PRs
- CI/CD on all PRs
- Codex AI code review
- Auto-merge when checks pass
- Pre-commit hooks (local)

**🔄 Partially Automated:**
- Security vulnerability response (Dependabot creates PR, human reviews)
- Deferred dependency tracking (manual issue creation)
- Issue closure (requires PR merge)

**⏳ Not Yet Automated (Future Enhancements):**
- Auto-create issues from CI failures
- Stale issue management
- Auto-label issues based on content
- Auto-assign issues to developers
- Release note generation
- Changelog updates

---

## Summary: Old vs New Workflow

### Old Workflow (8 Cycles)

```
Day 1-10: Write ALL features (6,500 lines)
Day 11: Run comprehensive review
  → Find 22 issues (5 P0, 11 P1, 6 P2)
Day 12: Fix all 22 issues
Day 13: Run Cycle 2
  → Find 8 more issues
Day 14: Fix issues
Day 15: Run Cycle 3
  → Find 5 more issues
...
Day 18: Run Cycle 8
  → Find 0 issues ✅

Result: 8 cycles, 22 issues, 6+ hours wasted
```

### New Workflow (2-3 Cycles)

```
Day 1: Setup (git, tools, automation)
Day 2: Write AlertsView
  → Run code-reviewer immediately
  → Fix 1 P0 issue
  → Take screenshot
  → Commit ✅
Day 3: Write DealsView
  → Run code-reviewer immediately
  → Fix 0 issues
  → Take screenshot
  → Commit ✅
Day 4: Write WatchlistsView
  → Run code-reviewer immediately
  → Fix 1 P1 issue
  → Take screenshot
  → Commit ✅
...
Day 10: All features complete
Day 11: Run comprehensive integration review
  → Find 2 integration issues
Day 12: Fix issues
Day 13: Run validation cycle
  → Find 0 issues ✅

Result: 10 incremental + 2 final cycles, 5 total issues, 2 hours review time
```

**Time Saved:** 6 hours
**Issues Prevented:** 17 issues
**Git History:** 30+ commits (vs 1)
**Screenshots:** 15+ (vs 0)
**Automation:** Full CI/CD (vs manual)

---

## Next Steps

1. **Read TOOLING_SETUP.md** for technical setup commands
2. **Read iOS_26_PATTERNS.md** for pattern reference
3. **Read CLAUDE_CODE_BEST_PRACTICES.md** for session management
4. **Use SESSION_LOG.md template** for every session

**Remember:** Setup properly BEFORE coding, review incrementally NOT in batch, commit after EVERY feature.
