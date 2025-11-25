# FareLens Tooling Setup Guide

**Purpose:** Technical setup for automation, quality gates, and development tools
**Time Required:** 2 hours one-time setup
**ROI:** Prevents 6+ hours of manual review cycles

---

## Table of Contents

1. [Git & GitHub Setup](#git--github-setup)
2. [SwiftLint Configuration](#swiftlint-configuration)
3. [SwiftFormat Configuration](#swiftformat-configuration)
4. [Pre-Commit Hooks](#pre-commit-hooks)
5. [GitHub Actions CI/CD](#github-actions-cicd)
6. [Screenshot Testing](#screenshot-testing)
7. [Linear Issue Tracking](#linear-issue-tracking)
8. [Xcode Project Setup](#xcode-project-setup)
9. [Verification](#verification)

---

## Git & GitHub Setup

### 1. Move Project from Desktop to ~/Projects

```bash
# Current location: ~/Desktop/FareLensApp (risky!)
# Target location: ~/Projects/FareLens (professional)

# Create ~/Projects directory if it doesn't exist
mkdir -p ~/Projects

# Move project (preserves .git directory)
mv ~/Desktop/FareLensApp ~/Projects/FareLens

# Update references
cd ~/Projects/FareLens
```

### 2. Initialize Proper Git Workflow

```bash
# Current state: Only 1 commit "Initial commit"
# Goal: Set up proper branching and history

# Verify git status
git status

# Commit current changes (all 22 fixes from 8 cycles)
git add .
git commit -m "feat: Complete UI implementation with iOS 26 patterns

- Implemented 15+ SwiftUI views (Alerts, Deals, Watchlists, Settings, Onboarding)
- All ViewModels use @Observable pattern (iOS 26)
- Resolved 22 issues across 8 review cycles (5 P0, 11 P1, 6 P2)
- Achieved zero-defect status in Cycles 7-8
- 6,500+ lines of Swift code
- Design system components (FLButton, FLCard, etc.)

References:
- RETROSPECTIVE.md for lessons learned
- iOS_26_PATTERNS.md for pattern compliance
- ARCHITECTURE.md for technical decisions"
```

### 3. Create GitHub Repository

```bash
# Install GitHub CLI if not installed
brew install gh

# Authenticate
gh auth login

# Create private repository
gh repo create farelens-ios \
  --private \
  --source=. \
  --remote=origin \
  --push \
  --description "FareLens iOS app - Flight deal alerts with iOS 26+ patterns"

# Verify remote
git remote -v
# Output:
# origin  git@github.com:yourusername/farelens-ios.git (fetch)
# origin  git@github.com:yourusername/farelens-ios.git (push)
```

### 4. Set Up Branch Protection

```bash
# Protect main branch from direct pushes
gh api repos/:owner/farelens-ios/branches/main/protection \
  -X PUT \
  --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["quality-gate", "build", "test"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF

echo "✅ Branch protection enabled on main"
```

### 5. Create .gitignore (if not exists)

```bash
cat > .gitignore <<'EOF'
# Xcode
*.xcodeproj/*
!*.xcodeproj/project.pbxproj
!*.xcodeproj/xcshareddata/
*.xcworkspace/*
!*.xcworkspace/contents.xcworkspacedata
!*.xcworkspace/xcshareddata/
xcuserdata/
DerivedData/
.build/
*.ipa
*.dSYM.zip
*.dSYM

# Swift Package Manager
.swiftpm/
Package.resolved

# CocoaPods
Pods/
*.podspec

# Carthage
Carthage/Build/

# Accio
Dependencies/

# fastlane
fastlane/report.xml
fastlane/Preview.html
fastlane/screenshots/**/*.png
fastlane/test_output

# Mac
.DS_Store

# Secrets & Environment
.env
.env.local
credentials.json
secrets/
*.pem
*.p12

# IDEs
.vscode/
.idea/
*.swp
*.swo
*~

# Testing
*.gcov
*.gcno
*.gcda
coverage/

# Documentation Build
docs/build/

# Temporary
tmp/
temp/
EOF

git add .gitignore
git commit -m "chore: Add comprehensive .gitignore"
git push
```

---

## SwiftLint Configuration

### 1. Install SwiftLint

```bash
# Using Homebrew (recommended)
brew install swiftlint

# Verify installation
swiftlint version
# Output: 0.54.0 (or later)
```

### 2. Create .swiftlint.yml

```bash
cat > .swiftlint.yml <<'EOF'
# SwiftLint Configuration for FareLens (iOS 26+)

# Disable rules
disabled_rules:
  - line_length  # Handled by SwiftFormat
  - type_body_length  # Some ViewModels are legitimately long
  - file_length  # Some files need to be comprehensive

# Opt-in rules
opt_in_rules:
  - force_unwrapping              # Error on !
  - force_cast                    # Error on as!
  - explicit_init                 # Prefer Type() over Type.init()
  - trailing_closure              # Prefer trailing closure syntax
  - empty_count                   # Prefer isEmpty over count == 0
  - first_where                   # Prefer first(where:) over filter().first
  - contains_over_first_not_nil   # Prefer contains over first != nil
  - redundant_nil_coalescing      # Avoid foo ?? nil
  - closure_spacing               # Space inside closure braces
  - unneeded_parentheses_in_closure_argument  # Clean closure syntax

# Custom rules for iOS 26 patterns
custom_rules:
  # Prevent legacy ObservableObject
  observable_object_legacy:
    name: "ObservableObject is legacy"
    regex: '\bObservableObject\b'
    message: "Use @Observable (iOS 26+) instead of ObservableObject (legacy)"
    severity: error

  # Prevent @StateObject with @Observable
  stateobject_with_observable:
    name: "@StateObject with @Observable"
    regex: '@StateObject.*@Observable'
    message: "Use @State with @Observable classes, not @StateObject"
    severity: error

  # Prevent @Published in @Observable classes
  published_in_observable:
    name: "@Published in @Observable class"
    regex: '@Observable[^}]*@Published'
    message: "@Observable classes use plain var properties, not @Published"
    severity: error

  # Prevent @EnvironmentObject (legacy)
  environment_object_legacy:
    name: "@EnvironmentObject is legacy"
    regex: '@EnvironmentObject'
    message: "Use @Environment with @Observable, not @EnvironmentObject"
    severity: warning

  # Warn on force unwraps in production code
  force_unwrap_warning:
    name: "Force unwrap detected"
    regex: '(?<!// )!\s*(?!is\b|as\b)'
    message: "Avoid force unwraps (!). Use optional binding or nil coalescing"
    severity: warning
    excluded: ".*Tests\\.swift"  # Allow in tests

# Excluded paths
excluded:
  - Pods
  - DerivedData
  - .build
  - fastlane
  - ios-app/FareLensTests  # Tests have different standards

# Included paths
included:
  - ios-app/FareLens

# Severity overrides
force_unwrapping:
  severity: error  # Never allow in production

force_cast:
  severity: error  # Never allow anywhere

# Analyzer rules (slower but more thorough)
analyzer_rules:
  - unused_declaration
  - unused_import

# Reporter
reporter: "xcode"  # Xcode-friendly format
EOF

git add .swiftlint.yml
git commit -m "chore: Configure SwiftLint with iOS 26 pattern checks"
git push
```

### 3. Integrate SwiftLint with Xcode

```bash
# Add Run Script Phase to Xcode project
# Open Xcode:
open ios-app/FareLens.xcodeproj

# In Xcode:
# 1. Select project in navigator
# 2. Select FareLens target
# 3. Build Phases tab
# 4. Click + → New Run Script Phase
# 5. Rename to "SwiftLint"
# 6. Add script:

if which swiftlint >/dev/null; then
  swiftlint --config ../.swiftlint.yml
else
  echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi

# 7. Move "SwiftLint" phase BEFORE "Compile Sources"
# 8. Build project to verify (Cmd+B)
```

### 4. Run SwiftLint Manually

```bash
# Run on entire project
cd ~/Projects/FareLens
swiftlint

# Run with auto-fix
swiftlint --fix

# Run in strict mode (treat warnings as errors)
swiftlint --strict

# Expected output (after 8 cycles):
# Done linting! Found 0 violations, 0 serious in 48 files.
```

---

## SwiftFormat Configuration

### 1. Install SwiftFormat

```bash
# Using Homebrew
brew install swiftformat

# Verify installation
swiftformat --version
# Output: 0.52.0 (or later)
```

### 2. Create .swiftformat Configuration

```bash
cat > .swiftformat <<'EOF'
# SwiftFormat Configuration for FareLens

# File options
--swiftversion 5.9

# Indentation
--indent 4
--tabwidth 4
--maxwidth 120
--smarttabs enabled

# Wrapping
--wraparguments before-first
--wrapcollections before-first
--wrapparameters before-first
--wrapconditions before-first
--wrapreturntype if-multiline
--closingparen same-line
--wrapternary before-operators

# Spacing
--trimwhitespace always
--nospaceoperators ..<,...
--ranges spaced

# Braces
--allman false
--elseposition same-line
--guardelse same-line

# Parentheses
--stripunusedargs closure-only

# Type inference
--redundanttype inferred

# Header
--header "// FareLens\n// Copyright © {year} FareLens. All rights reserved."

# Excluded paths
--exclude Pods,DerivedData,.build,fastlane

# Rules
--enable isEmpty
--enable hoistPatternLet
--enable redundantReturn
--enable sortedImports
--enable sortedSwitchCases
--enable wrapMultilineStatementBraces
EOF

git add .swiftformat
git commit -m "chore: Configure SwiftFormat"
git push
```

### 3. Run SwiftFormat

```bash
# Format entire project
swiftformat .

# Check formatting without changing files
swiftformat --lint .

# Format specific file
swiftformat ios-app/FareLens/Features/Alerts/AlertsView.swift

# Expected output:
# ✔ Formatted 48 files in 2.3 seconds
```

### 4. Integrate with Xcode (Optional)

```bash
# Add Run Script Phase in Xcode (after SwiftLint phase)
if which swiftformat >/dev/null; then
  swiftformat --config ../.swiftformat ios-app/FareLens
else
  echo "warning: SwiftFormat not installed"
fi
```

---

## Pre-Commit Hooks

### 1. Create iOS 26 Pattern Checker

```bash
mkdir -p scripts

cat > scripts/check-ios26-patterns.sh <<'EOF'
#!/bin/bash
# Validates iOS 26 @Observable pattern compliance

set -e

echo "🔍 Checking iOS 26 pattern compliance..."

ERRORS=0

# Check for legacy ObservableObject
echo "  Checking for ObservableObject (legacy)..."
if grep -r "ObservableObject" ios-app/FareLens --include="*.swift" 2>/dev/null; then
    echo "  ❌ ERROR: Found ObservableObject (legacy pattern)"
    echo "     Fix: Use @Observable instead (iOS 26+)"
    ERRORS=$((ERRORS + 1))
fi

# Check for @StateObject with @Observable
echo "  Checking for @StateObject misuse..."
if grep -r "@StateObject" ios-app/FareLens --include="*.swift" | grep -v "//" | grep -q "@Observable"; then
    echo "  ❌ ERROR: Found @StateObject with @Observable"
    echo "     Fix: Use @State with @Observable classes"
    ERRORS=$((ERRORS + 1))
fi

# Check for @Published in @Observable classes
echo "  Checking for @Published in @Observable..."
OBSERVABLE_FILES=$(grep -rl "@Observable" ios-app/FareLens --include="*.swift" 2>/dev/null || true)
for file in $OBSERVABLE_FILES; do
    if grep -q "@Published" "$file"; then
        echo "  ❌ ERROR: Found @Published in @Observable class: $file"
        echo "     Fix: @Observable classes use plain var properties"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check for force unwraps in production code (warning only)
echo "  Checking for force unwraps (!)..."
FORCE_UNWRAPS=$(grep -r "!" ios-app/FareLens --include="*.swift" --exclude="*Tests.swift" | grep -v "//" | wc -l)
if [ "$FORCE_UNWRAPS" -gt 0 ]; then
    echo "  ⚠️  WARNING: Found $FORCE_UNWRAPS force unwraps (!) in production code"
    echo "     Consider using optional binding or nil coalescing"
fi

# Check for @EnvironmentObject (legacy)
echo "  Checking for @EnvironmentObject (legacy)..."
if grep -r "@EnvironmentObject" ios-app/FareLens --include="*.swift" 2>/dev/null; then
    echo "  ⚠️  WARNING: Found @EnvironmentObject (legacy pattern)"
    echo "     Consider using @Environment with @Observable"
fi

if [ $ERRORS -eq 0 ]; then
    echo "✅ All iOS 26 patterns valid"
    exit 0
else
    echo "❌ Found $ERRORS pattern violation(s)"
    exit 1
fi
EOF

chmod +x scripts/check-ios26-patterns.sh
git add scripts/
git commit -m "chore: Add iOS 26 pattern validation script"
git push
```

### 2. Test Pattern Checker

```bash
# Should pass (we fixed all issues in 8 cycles)
./scripts/check-ios26-patterns.sh

# Expected output:
# 🔍 Checking iOS 26 pattern compliance...
#   Checking for ObservableObject (legacy)...
#   Checking for @StateObject misuse...
#   Checking for @Published in @Observable...
#   Checking for force unwraps (!)...
#   Checking for @EnvironmentObject (legacy)...
# ✅ All iOS 26 patterns valid
```

### 3. Create Pre-Commit Hook

```bash
cat > .git/hooks/pre-commit <<'EOF'
#!/bin/bash
# Pre-commit quality gate

set -e

echo "🔒 Running pre-commit checks..."
echo ""

# 1. Check iOS 26 patterns
echo "1️⃣ iOS 26 Pattern Validation"
./scripts/check-ios26-patterns.sh
echo ""

# 2. Run SwiftLint
echo "2️⃣ SwiftLint"
if which swiftlint >/dev/null; then
    swiftlint --strict
    echo "✅ SwiftLint passed"
else
    echo "⚠️  SwiftLint not installed"
fi
echo ""

# 3. Run SwiftFormat check
echo "3️⃣ SwiftFormat"
if which swiftformat >/dev/null; then
    swiftformat --lint . > /dev/null
    echo "✅ SwiftFormat passed"
else
    echo "⚠️  SwiftFormat not installed"
fi
echo ""

# 4. Verify no large files (>5MB)
echo "4️⃣ Large File Check"
LARGE_FILES=$(find . -type f -size +5M | grep -v ".git" | grep -v "DerivedData" | grep -v "Pods" || true)
if [ -n "$LARGE_FILES" ]; then
    echo "❌ ERROR: Large files detected (>5MB):"
    echo "$LARGE_FILES"
    exit 1
else
    echo "✅ No large files"
fi
echo ""

# 5. Verify no secrets
echo "5️⃣ Secrets Detection"
if git diff --cached --name-only | grep -qE '\.(env|pem|p12|key|credentials)$'; then
    echo "❌ ERROR: Attempting to commit secret files"
    echo "Files with secrets extension detected"
    exit 1
else
    echo "✅ No secrets detected"
fi
echo ""

echo "✅ All pre-commit checks passed"
EOF

chmod +x .git/hooks/pre-commit
```

### 4. Test Pre-Commit Hook

```bash
# Make a trivial change
echo "# Test" >> README.md

# Try to commit (should run all checks)
git add README.md
git commit -m "test: Verify pre-commit hook"

# Expected output:
# 🔒 Running pre-commit checks...
# 1️⃣ iOS 26 Pattern Validation
# ✅ All iOS 26 patterns valid
# 2️⃣ SwiftLint
# ✅ SwiftLint passed
# 3️⃣ SwiftFormat
# ✅ SwiftFormat passed
# 4️⃣ Large File Check
# ✅ No large files
# 5️⃣ Secrets Detection
# ✅ No secrets detected
# ✅ All pre-commit checks passed
# [main abc123] test: Verify pre-commit hook

# Cleanup test
git reset HEAD~1
git checkout README.md
```

---

## GitHub Actions CI/CD

### 1. Create Workflow Directory

```bash
mkdir -p .github/workflows
```

### 2. Create PR Quality Gate Workflow

```bash
cat > .github/workflows/pr-quality-gate.yml <<'EOF'
name: PR Quality Gate

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main]

jobs:
  quality-gate:
    name: Quality Gate
    runs-on: macos-14  # macOS Sonoma with Xcode 15

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '15.2'

      - name: Install SwiftLint
        run: brew install swiftlint

      - name: Install SwiftFormat
        run: brew install swiftformat

      - name: Run SwiftLint
        run: |
          cd ios-app
          swiftlint --strict --reporter github-actions-logging

      - name: Check SwiftFormat
        run: |
          swiftformat --lint . --reporter github-actions-logging

      - name: Check iOS 26 Patterns
        run: ./scripts/check-ios26-patterns.sh

      - name: Build Xcode Project
        run: |
          cd ios-app
          xcodebuild clean build \
            -scheme FareLens \
            -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.2' \
            -configuration Debug \
            CODE_SIGNING_ALLOWED=NO

      - name: Run Tests
        run: |
          cd ios-app
          xcodebuild test \
            -scheme FareLens \
            -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.2' \
            -enableCodeCoverage YES \
            -resultBundlePath TestResults.xcresult

      - name: Check Code Coverage
        run: |
          cd ios-app
          xcrun xccov view --report TestResults.xcresult > coverage.txt
          COVERAGE=$(grep "FareLens.app" coverage.txt | awk '{print $4}' | sed 's/%//')
          echo "Coverage: $COVERAGE%"
          if (( $(echo "$COVERAGE < 80.0" | bc -l) )); then
            echo "❌ Coverage below 80% threshold"
            exit 1
          fi
          echo "✅ Coverage above 80%"

      - name: Comment PR with Results
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const coverage = require('fs').readFileSync('ios-app/coverage.txt', 'utf8');
            const body = `## Quality Gate Results\n\n✅ All checks passed\n\n### Coverage\n\`\`\`\n${coverage}\n\`\`\``;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: body
            });

      - name: Upload Test Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: ios-app/TestResults.xcresult
EOF

git add .github/
git commit -m "ci: Add PR quality gate workflow"
git push
```

### 3. Create Nightly Build Workflow

```bash
cat > .github/workflows/nightly-build.yml <<'EOF'
name: Nightly Build

on:
  schedule:
    - cron: '0 2 * * *'  # 2 AM UTC daily
  workflow_dispatch:  # Allow manual trigger

jobs:
  build:
    name: Nightly Build
    runs-on: macos-14

    steps:
      - uses: actions/checkout@v4

      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '15.2'

      - name: Build & Archive
        run: |
          cd ios-app
          xcodebuild archive \
            -scheme FareLens \
            -archivePath FareLens.xcarchive \
            -configuration Release \
            CODE_SIGNING_ALLOWED=NO

      - name: Upload Build Artifacts
        uses: actions/upload-artifact@v4
        with:
          name: nightly-build-${{ github.run_number }}
          path: ios-app/FareLens.xcarchive

      - name: Notify on Failure
        if: failure()
        run: echo "Nightly build failed!"
EOF

git add .github/workflows/nightly-build.yml
git commit -m "ci: Add nightly build workflow"
git push
```

### 4. Verify GitHub Actions

```bash
# Check workflows are registered
gh workflow list

# Expected output:
# PR Quality Gate  active  12345
# Nightly Build    active  12346

# Run workflow manually
gh workflow run pr-quality-gate.yml

# Check status
gh run list --limit 5
```

---

## Screenshot Testing

### 1. Create Screenshot Tests in Xcode

```bash
# Open Xcode
open ios-app/FareLens.xcodeproj

# In Xcode:
# 1. File → New → Target
# 2. Select "UI Testing Bundle"
# 3. Product Name: "FareLensUITests"
# 4. Create
```

### 2. Create ScreenshotTests.swift

Create file in Xcode at `ios-app/FareLensUITests/ScreenshotTests.swift`:

```swift
// FareLens
// Copyright © 2025 FareLens. All rights reserved.

import XCTest

final class ScreenshotTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }

    func test_AlertsView() throws {
        // Navigate to Alerts tab
        app.tabBars.buttons["Alerts"].tap()

        // Wait for content to load
        sleep(2)

        // Take screenshot
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "AlertsView-\(Date().ISO8601Format())"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func test_DealsView() throws {
        // Deals tab is default, already visible
        sleep(2)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "DealsView-\(Date().ISO8601Format())"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func test_WatchlistsView() throws {
        app.tabBars.buttons["Watchlists"].tap()
        sleep(2)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "WatchlistsView-\(Date().ISO8601Format())"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func test_SettingsView() throws {
        app.tabBars.buttons["Settings"].tap()
        sleep(2)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "SettingsView-\(Date().ISO8601Format())"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

### 3. Create Screenshot Automation Script

```bash
cat > scripts/take-screenshots.sh <<'EOF'
#!/bin/bash
# Takes screenshots of all views in iOS Simulator

set -e

SCHEME="FareLens"
DESTINATION="platform=iOS Simulator,name=iPhone 15,OS=17.2"
OUTPUT_DIR="design-refs/actual"

mkdir -p "$OUTPUT_DIR"

echo "📸 Taking screenshots..."

# Run UI tests (generates screenshots)
cd ios-app
xcodebuild test \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -only-testing:FareLensUITests/ScreenshotTests \
    -quiet

# Find screenshots in DerivedData
DERIVED_DATA=$(xcodebuild -showBuildSettings -scheme "$SCHEME" | grep -m 1 "BUILD_DIR" | awk '{print $3}' | sed 's/Build\/Products//')
SCREENSHOTS=$(find "$DERIVED_DATA" -name "*.png" -path "*/Attachments/*" -mtime -1m)

# Copy to output directory
COUNT=0
for screenshot in $SCREENSHOTS; do
    FILENAME=$(basename "$screenshot")
    cp "$screenshot" "../$OUTPUT_DIR/$FILENAME"
    echo "  ✅ $FILENAME"
    COUNT=$((COUNT + 1))
done

echo ""
echo "📸 Captured $COUNT screenshots in $OUTPUT_DIR"
EOF

chmod +x scripts/take-screenshots.sh
git add scripts/take-screenshots.sh
git commit -m "chore: Add screenshot automation script"
git push
```

### 4. Test Screenshot Script

```bash
# Run screenshot tests
./scripts/take-screenshots.sh

# Expected output:
# 📸 Taking screenshots...
#   ✅ AlertsView-2025-10-13T14:30:00Z.png
#   ✅ DealsView-2025-10-13T14:30:05Z.png
#   ✅ WatchlistsView-2025-10-13T14:30:10Z.png
#   ✅ SettingsView-2025-10-13T14:30:15Z.png
# 📸 Captured 4 screenshots in design-refs/actual

# View screenshots
open design-refs/actual/
```

---

## Linear Issue Tracking

### 1. Install Linear CLI

```bash
# Install via npm
npm install -g @linear/cli

# Authenticate
linear auth

# Follow browser prompt to authorize
```

### 2. Configure Linear Team

```bash
# List teams
linear team list

# Set default team
linear team set <TEAM_ID>

# Example:
# linear team set FARE
```

### 3. Create Linear Project

```bash
# Create project
linear project create \
  --name "FareLens iOS" \
  --description "iOS 26+ flight deal alerts app" \
  --state "started"

# Example output:
# ✅ Created project FARE-1
```

### 4. Create Issues from Review Cycles

```bash
# Example: Create issues for common patterns

# P0: Compilation error
linear issue create \
  --title "P0: Duplicate DealDetailViewModel definition" \
  --description "Two files define DealDetailViewModel, causing compilation error" \
  --priority urgent \
  --project "FareLens iOS" \
  --estimate 1

# P1: Pattern violation
linear issue create \
  --title "P1: @StateObject used with @Observable in MainTabView" \
  --description "MainTabView:4 uses @StateObject with @Observable, should use @State" \
  --priority high \
  --project "FareLens iOS" \
  --estimate 1

# P2: Code quality
linear issue create \
  --title "P2: Inconsistent error handling in DealsViewModel" \
  --description "DealsViewModel has 3 different error handling patterns" \
  --priority medium \
  --project "FareLens iOS" \
  --estimate 2
```

### 5. Link Commits to Issues

```bash
# When fixing an issue, reference in commit message
git commit -m "fix: Remove duplicate DealDetailViewModel (FARE-123)"

# Linear automatically links commit to issue
# Issue status can auto-transition based on commit
```

### 6. Generate Sprint Reports

```bash
# View completed issues this week
linear issue list \
  --state "completed" \
  --completed-after "2025-10-07"

# View velocity (issues closed per week)
linear issue list \
  --state "completed" \
  --completed-after "2025-10-01" \
  --completed-before "2025-10-08" \
  | wc -l

# Output: 22 (issues fixed in 8 cycles)
```

---

## Xcode Project Setup

### 1. Open Xcode Project

```bash
cd ~/Projects/FareLens
open ios-app/FareLens.xcodeproj
```

### 2. Configure Build Settings

In Xcode:

1. **Select Project** → FareLens target → Build Settings
2. **Search "Swift Language Version"** → Set to **Swift 5.9**
3. **Search "iOS Deployment Target"** → Set to **iOS 26.0** (minimum for @Observable)
4. **Search "Enable Testability"** → Set to **YES** (Debug only)
5. **Search "Code Coverage"** → Set to **YES**

### 3. Add SwiftLint Build Phase (if not done earlier)

1. Select FareLens target
2. Build Phases tab
3. Click + → New Run Script Phase
4. Rename to "SwiftLint"
5. Add script:

```bash
if which swiftlint >/dev/null; then
  swiftlint --config ../.swiftlint.yml
else
  echo "warning: SwiftLint not installed"
fi
```

6. Move "SwiftLint" phase BEFORE "Compile Sources"

### 4. Configure Schemes

1. Product → Scheme → Edit Scheme (Cmd+<)
2. **Test** action:
   - Check "Code Coverage" → Check all targets
   - Options → Language: English, Region: US
3. **Run** action:
   - Info → Build Configuration: Debug
   - Arguments → Launch Arguments: Add `UI-Testing` (for screenshot tests)

---

## Verification

### 1. Verify Git Setup

```bash
cd ~/Projects/FareLens

# Check location
pwd
# Expected: /Users/YourName/Projects/FareLens

# Check remote
git remote -v
# Expected: origin git@github.com:yourusername/farelens-ios.git

# Check branch protection
gh api repos/:owner/farelens-ios/branches/main/protection
# Expected: JSON with required_status_checks, etc.
```

### 2. Verify SwiftLint

```bash
# Run SwiftLint
swiftlint

# Expected output:
# Done linting! Found 0 violations, 0 serious in 48 files.
```

### 3. Verify SwiftFormat

```bash
# Check formatting
swiftformat --lint .

# Expected output:
# ✔ All files formatted correctly
```

### 4. Verify Pre-Commit Hook

```bash
# Make test change
echo "# Test" >> TEST.md

# Try to commit
git add TEST.md
git commit -m "test: Verify hooks"

# Expected: All 5 checks run and pass

# Cleanup
git reset HEAD~1
rm TEST.md
```

### 5. Verify GitHub Actions

```bash
# List workflows
gh workflow list

# Expected:
# PR Quality Gate  active
# Nightly Build    active
```

### 6. Verify Screenshot Testing

```bash
# Run screenshot script
./scripts/take-screenshots.sh

# Expected: 4 screenshots in design-refs/actual/
ls -l design-refs/actual/

# Should see:
# AlertsView-*.png
# DealsView-*.png
# WatchlistsView-*.png
# SettingsView-*.png
```

### 7. Verify Linear Integration

```bash
# Check authentication
linear auth --whoami

# Expected: Your Linear account info

# List projects
linear project list

# Expected: FareLens iOS project visible
```

### 8. Build & Test in Xcode

```bash
# Build project
cd ios-app
xcodebuild clean build \
  -scheme FareLens \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Expected: BUILD SUCCEEDED

# Run tests
xcodebuild test \
  -scheme FareLens \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Expected: Test Succeeded
```

---

## Summary Checklist

### Git & GitHub
- [x] Project moved from Desktop to ~/Projects
- [x] Git repository initialized with proper .gitignore
- [x] GitHub remote configured
- [x] Branch protection enabled on main
- [x] All changes committed and pushed

### Code Quality Tools
- [x] SwiftLint installed and configured (.swiftlint.yml)
- [x] SwiftFormat installed and configured (.swiftformat)
- [x] iOS 26 pattern checker script created
- [x] Pre-commit hooks installed and tested
- [x] All tools verified with test run

### CI/CD
- [x] GitHub Actions workflow created (pr-quality-gate.yml)
- [x] Nightly build workflow created (nightly-build.yml)
- [x] Workflows verified in GitHub UI

### Screenshot Testing
- [x] UI test target created in Xcode
- [x] ScreenshotTests.swift implemented
- [x] Screenshot automation script created
- [x] Screenshots taken and verified

### Issue Tracking
- [x] Linear CLI installed and authenticated
- [x] Linear project created
- [x] Example issues created
- [x] Commit linking tested

### Xcode Configuration
- [x] Build settings configured
- [x] SwiftLint build phase added
- [x] Schemes configured for testing
- [x] Code coverage enabled

---

## Next Steps

1. **Read WORKFLOW.md** for daily development process
2. **Read iOS_26_PATTERNS.md** for pattern reference
3. **Read CLAUDE_CODE_BEST_PRACTICES.md** for session management
4. **Start developing** with incremental review workflow

**Time Investment:** 2 hours setup
**ROI:** Prevents 6+ hours of manual review cycles
**Result:** Professional workflow from Day 1
