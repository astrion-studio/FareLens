# Golden Standard Implementation Checklist

**Purpose:** Track all recommended GitHub/code quality standards
**Based on:** User's comprehensive list + industry best practices
**Status:** Updated 2025-10-19

---

## ✅ Already Implemented

### GitHub Repository Setup
- [x] Repository created (astrion-studio/FareLens)
- [x] Branch protection enabled on main
- [x] Auto-merge enabled
- [x] Required status checks configured
- [x] Manual approval requirement removed (for solo workflow)

### CI/CD
- [x] GitHub Actions workflows created
  - [x] `.github/workflows/ci.yml` (iOS code quality)
  - [x] `.github/workflows/review.yml` (automated review)
- [x] iOS code quality checks (SwiftFormat, patterns, force unwraps)
- [x] Codex integration for automated reviews

### Code Quality
- [x] SwiftFormat installed and configured
- [x] `.swiftformat` configuration file
- [x] iOS 26 pattern validation script
- [x] Pre-commit hooks (custom version)

### Documentation
- [x] Comprehensive internal docs (API.md, ARCHITECTURE.md, etc.)
- [x] RETROSPECTIVE.md
- [x] iOS_26_PATTERNS.md
- [x] WORKFLOW.md
- [x] TOOLING_SETUP.md
- [x] CLAUDE_CODE_BEST_PRACTICES.md

---

## 🔴 Critical (Must Do Soon)

### 1. Add Repo Metadata
**Status:** ❌ Not done
**Priority:** HIGH
**Time:** 5 minutes

**What's missing:**
- No description
- No topics/tags
- Makes repo hard to discover/understand

**How to fix:**
1. Go to: https://github.com/astrion-studio/FareLens
2. Click ⚙️ (settings icon) next to "About"
3. Add:
   - **Description:** `iOS flight deal alert app with iOS 26 patterns + FastAPI backend`
   - **Topics:** `ios`, `swift`, `swiftui`, `ios26`, `flight-deals`, `fastapi`, `python`, `travel`
   - **Website:** (if you have one)
4. Save

### 2. Remove .DS_Store from Git
**Status:** ❌ Tracked in repo
**Priority:** HIGH
**Time:** 2 minutes

**Problem:**
- `.DS_Store` is currently committed to git
- Will cause pointless diffs on every Mac operation
- Noise in git history

**How to fix:**
```bash
cd /Users/Parvez/Projects/FareLens

# Remove from git but keep locally
git rm --cached .DS_Store
git rm --cached design-refs/.DS_Store 2>/dev/null || true

# Verify .gitignore has it
echo ".DS_Store" >> .gitignore

# Commit
git add .gitignore
git commit -m "chore: Remove .DS_Store from git tracking

- Removed .DS_Store from repository
- Already in .gitignore to prevent future tracking
- Keeps git history clean"

git push origin main
```

### 3. Require Conversation Resolution
**Status:** ❌ Not configured
**Priority:** HIGH (for agent workflow)
**Time:** 1 minute

**Why important:**
- Makes Codex comments actually block merges
- Ensures agent feedback is addressed
- Creates agent-to-agent review workflow

**How to fix:**
1. Go to: https://github.com/astrion-studio/FareLens/settings/branches
2. Edit main branch protection
3. ✅ Check: **"Require conversation resolution before merging"**
4. Save

### 4. Add Backend CI Workflow
**Status:** ❌ Missing
**Priority:** HIGH (if backend exists)
**Time:** 15 minutes

**What's missing:**
- No pytest CI for backend
- No Python linting/formatting checks
- Backend can break without detection

**How to fix:**
Create `.github/workflows/backend-ci.yml`:
```yaml
name: Backend CI

on:
  pull_request:
    branches: [main]
    paths:
      - 'backend/**'
      - '.github/workflows/backend-ci.yml'
  push:
    branches: [main]
    paths:
      - 'backend/**'

jobs:
  test:
    name: Backend Tests
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          cd backend
          pip install -r requirements.txt
          pip install pytest pytest-cov ruff black

      - name: Run Black (formatting)
        run: |
          cd backend
          black --check .

      - name: Run Ruff (linting)
        run: |
          cd backend
          ruff check .

      - name: Run pytest
        run: |
          cd backend
          pytest --cov=. --cov-report=term-missing
```

### 5. Security: Enable Dependabot
**Status:** ❌ Not configured
**Priority:** HIGH
**Time:** 3 minutes

**Why important:**
- Auto-detects vulnerable dependencies
- Creates PRs to update them
- Critical for security

**How to fix:**
1. Go to: https://github.com/astrion-studio/FareLens/settings/security_analysis
2. Enable:
   - ✅ **Dependabot alerts**
   - ✅ **Dependabot security updates**
   - ✅ **Grouped security updates**
3. Create `.github/dependabot.yml`:
```yaml
version: 2
updates:
  # Swift Package Manager
  - package-ecosystem: "swift"
    directory: "/ios-app"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5

  # Python
  - package-ecosystem: "pip"
    directory: "/backend"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5

  # GitHub Actions
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

### 6. Security: Enable Secret Scanning
**Status:** ❌ Not configured
**Priority:** HIGH
**Time:** 1 minute

**Why important:**
- Prevents committing API keys, tokens, passwords
- Push protection blocks commits with secrets

**How to fix:**
1. Go to: https://github.com/astrion-studio/FareLens/settings/security_analysis
2. Enable:
   - ✅ **Secret scanning**
   - ✅ **Push protection** (blocks commits with secrets)

### 7. Security: Enable CodeQL
**Status:** ❌ Not configured
**Priority:** MEDIUM
**Time:** 5 minutes

**Why important:**
- Advanced code analysis for security vulnerabilities
- Supports Swift + Python
- Finds bugs automated tools miss

**How to fix:**
1. Go to: https://github.com/astrion-studio/FareLens/security/code-scanning
2. Click "Set up code scanning"
3. Choose "CodeQL Analysis"
4. Configure for Swift and Python
5. Commit the generated workflow

---

## 🟡 Strongly Recommended (Do Soon)

### 8. Add At Least One Test
**Status:** ❌ No tests yet
**Priority:** MEDIUM
**Time:** 30 minutes

**What's missing:**
- CI runs but no tests exist
- Can't verify code actually works
- No test coverage metrics

**iOS Test Example:**
```swift
// ios-app/FareLensTests/FlightDealTests.swift
import XCTest
@testable import FareLens

final class FlightDealTests: XCTestCase {
    func testDealDecoding() throws {
        let json = """
        {
            "id": "123",
            "origin": "LAX",
            "destination": "NYC",
            "price": 199.99
        }
        """
        let data = json.data(using: .utf8)!
        let deal = try JSONDecoder().decode(FlightDeal.self, from: data)

        XCTAssertEqual(deal.origin, "LAX")
        XCTAssertEqual(deal.destination, "NYC")
        XCTAssertEqual(deal.price, 199.99)
    }
}
```

**Backend Test Example:**
```python
# backend/tests/test_health.py
def test_health_endpoint(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}
```

### 9. Create PR Template
**Status:** ❌ Missing
**Priority:** MEDIUM
**Time:** 10 minutes

**Why important:**
- Standardizes PR descriptions
- Ensures testing checklist
- Improves review quality

**How to fix:**
Create `.github/pull_request_template.md`:
```markdown
## Summary
<!-- Brief description of changes -->

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update
- [ ] Refactoring

## Changes Made
<!-- Bullet list of specific changes -->
-

## Testing
- [ ] All existing tests pass
- [ ] Added new tests for new functionality
- [ ] Manually tested in simulator/device
- [ ] Codex review addressed

## Screenshots (if UI changes)
<!-- Add before/after screenshots -->

## Checklist
- [ ] Code follows iOS 26 patterns
- [ ] SwiftFormat applied
- [ ] No force unwraps
- [ ] No print statements (uses OSLog)
- [ ] Documentation updated
```

### 10. Create Issue Templates
**Status:** ❌ Missing
**Priority:** MEDIUM
**Time:** 15 minutes

**Why important:**
- Standardizes bug reports
- Ensures necessary info provided
- Makes issue triage faster

**How to fix:**
Create `.github/ISSUE_TEMPLATE/bug_report.md`:
```markdown
---
name: Bug Report
about: Report a bug or unexpected behavior
title: '[BUG] '
labels: bug
---

## Description
<!-- Clear description of the bug -->

## Steps to Reproduce
1.
2.
3.

## Expected Behavior
<!-- What should happen -->

## Actual Behavior
<!-- What actually happens -->

## Environment
- Device: [iPhone 15, iPad Pro, etc.]
- iOS Version: [17.0, 18.0, etc.]
- App Version: [1.0.0]

## Screenshots
<!-- If applicable -->

## Additional Context
<!-- Any other relevant information -->
```

### 11. Add Labels
**Status:** ❌ No labels
**Priority:** MEDIUM
**Time:** 5 minutes

**Why important:**
- Categorizes issues/PRs
- Enables filtering and organization
- Clarifies priorities

**Recommended labels:**
```
bug - Something isn't working
enhancement - New feature or request
documentation - Documentation improvements
ios - iOS app related
backend - Backend API related
P0 - Critical (blocking)
P1 - High priority
P2 - Medium priority
P3 - Low priority
good first issue - Easy for newcomers
```

**How to create:**
1. Go to: https://github.com/astrion-studio/FareLens/labels
2. Click "New label"
3. Add each label with color and description

### 12. Add CODEOWNERS
**Status:** ❌ Missing
**Priority:** LOW (solo project)
**Time:** 3 minutes

**Why important:**
- Auto-assigns reviewers
- Only useful with team (not solo)

**How to fix (when you have team):**
Create `.github/CODEOWNERS`:
```
# iOS code
/ios-app/ @astrion-studio

# Backend code
/backend/ @astrion-studio

# CI/CD workflows
/.github/workflows/ @astrion-studio

# Documentation
*.md @astrion-studio
```

### 13. Pre-commit Hooks for Backend
**Status:** ❌ Backend hooks missing
**Priority:** MEDIUM (if backend exists)
**Time:** 10 minutes

**What's missing:**
- No black/ruff pre-commit for Python
- Backend code can be unformatted

**How to fix:**
Create `.pre-commit-config.yaml`:
```yaml
repos:
  - repo: https://github.com/psf/black
    rev: 23.11.0
    hooks:
      - id: black
        language_version: python3.11

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.1.6
    hooks:
      - id: ruff
        args: [--fix]

  - repo: local
    hooks:
      - id: pytest-check
        name: pytest
        entry: bash -c 'cd backend && pytest'
        language: system
        pass_filenames: false
        always_run: true
```

Then install:
```bash
pip install pre-commit
pre-commit install
```

### 14. Conventional Commits
**Status:** ❌ Not enforced
**Priority:** MEDIUM
**Time:** 5 minutes

**Why important:**
- Standardized commit messages
- Enables automatic changelog
- Makes git history readable

**Examples:**
```
feat(ios): Add price alert notifications
fix(backend): Resolve database connection timeout
docs: Update README with setup instructions
refactor(deals): Extract DealService protocol
test(ios): Add unit tests for AlertsViewModel
chore: Update dependencies
```

**How to enforce:**
Create `.github/workflows/commitlint.yml`:
```yaml
name: Commit Lint

on: [pull_request]

jobs:
  commitlint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: wagoid/commitlint-github-action@v5
```

### 15. CHANGELOG
**Status:** ❌ Missing
**Priority:** MEDIUM
**Time:** 5 minutes

**Why important:**
- Documents version history
- Helps users understand changes
- Required for releases

**How to fix:**
Create `CHANGELOG.md`:
```markdown
# Changelog

All notable changes to FareLens will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- GitHub Actions CI/CD workflows
- Automated code quality checks
- Codex integration for code review
- iOS 26 @Observable pattern implementation

### Changed
- Branch protection to support auto-merge

### Fixed
- Force unwrap detection false positives

## [0.1.0] - 2025-10-12

### Added
- Initial iOS app structure
- 15+ SwiftUI views
- MVVM architecture with @Observable
- Liquid Glass design system
- Backend API contracts
```

### 16. Upgrade README
**Status:** ⚠️ Basic README exists
**Priority:** HIGH
**Time:** 20 minutes

**What's missing:**
- No "how to run iOS" instructions
- No "how to run backend" instructions
- No architecture diagram
- No contribution guide
- Doesn't link to internal docs

**How to fix:**
Create comprehensive README (see next section for template)

---

## 🟢 Nice to Have (When Ready)

### 17. GitHub Container Registry (GHCR)
**Status:** ❌ Not configured
**Priority:** LOW
**Time:** 30 minutes

**When needed:** When you want to deploy backend

**How to implement:**
Add to `.github/workflows/backend-ci.yml`:
```yaml
- name: Build and push Docker image
  if: github.ref == 'refs/heads/main'
  run: |
    echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
    docker build -t ghcr.io/astrion-studio/farelens-backend:${{ github.sha }} backend/
    docker push ghcr.io/astrion-studio/farelens-backend:${{ github.sha }}
```

### 18. Release Tags & Versioning
**Status:** ❌ No releases
**Priority:** LOW
**Time:** 10 minutes

**When needed:** When you have stable versions

**How to create:**
```bash
git tag -a v0.1.0 -m "Initial release"
git push origin v0.1.0
```

Then create GitHub Release:
1. Go to: https://github.com/astrion-studio/FareLens/releases/new
2. Choose tag v0.1.0
3. Add release notes from CHANGELOG
4. Publish

### 19. GitHub Projects/Boards
**Status:** ❌ Not using projects
**Priority:** LOW (solo)
**Time:** 15 minutes

**When needed:** When you want kanban board

**How to set up:**
1. Go to: https://github.com/astrion-studio/FareLens/projects
2. Click "New project"
3. Choose "Board" template
4. Add columns: Todo, In Progress, Done
5. Link issues to board

### 20. Environments & Secrets
**Status:** ❌ Not configured
**Priority:** LOW (until deployment)
**Time:** 10 minutes

**When needed:** When deploying to staging/prod

**How to set up:**
1. Go to: https://github.com/astrion-studio/FareLens/settings/environments
2. Create environments: `dev`, `staging`, `production`
3. Add secrets for each:
   - `API_BASE_URL`
   - `DATABASE_URL`
   - `STRIPE_API_KEY`
   - etc.
4. Configure deployment protection rules

---

## 📋 Priority Order for Implementation

### Phase 1: Critical (Do Now - 30 minutes)
1. ✅ Add repo metadata (description + topics)
2. ✅ Remove .DS_Store from git
3. ✅ Enable "Require conversation resolution"
4. ✅ Enable Dependabot
5. ✅ Enable secret scanning + push protection

### Phase 2: Quality Gates (Next Session - 1 hour)
6. ✅ Add backend CI workflow (if backend exists)
7. ✅ Enable CodeQL
8. ✅ Create PR template
9. ✅ Add issue templates
10. ✅ Create comprehensive README

### Phase 3: Standards (When Convenient - 1 hour)
11. ✅ Add at least one test (iOS + backend)
12. ✅ Add labels
13. ✅ Set up conventional commits
14. ✅ Create CHANGELOG
15. ✅ Backend pre-commit hooks

### Phase 4: Optional (Future)
16. ✅ CODEOWNERS (when team grows)
17. ✅ GHCR images (when deploying)
18. ✅ Release tags (when stable)
19. ✅ Projects board (when needed)
20. ✅ Environments (when deploying)

---

## README Template (for Item #16)

```markdown
# FareLens ✈️

> iOS 26 flight deal alert app with FastAPI backend

[![CI](https://github.com/astrion-studio/FareLens/actions/workflows/ci.yml/badge.svg)](https://github.com/astrion-studio/FareLens/actions/workflows/ci.yml)
[![Code Review](https://github.com/astrion-studio/FareLens/actions/workflows/review.yml/badge.svg)](https://github.com/astrion-studio/FareLens/actions/workflows/review.yml)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![iOS 26+](https://img.shields.io/badge/iOS-26+-blue.svg)](https://www.apple.com/ios)

FareLens helps travelers find the best flight deals through smart alerts and price tracking.

## ✨ Features

- 📱 **iOS 26 Native** - Built with latest @Observable patterns
- 🎨 **Liquid Glass Design** - Modern, beautiful UI
- 🔔 **Smart Alerts** - Customizable deal notifications
- 📊 **Price Tracking** - Watchlists with price drop alerts
- ⚡ **FastAPI Backend** - High-performance API

## 🏗️ Architecture

```
FareLens/
├── ios-app/           # iOS SwiftUI app (iOS 26+)
│   ├── FareLens/      # App source
│   └── FareLensTests/ # Unit tests
├── backend/           # FastAPI Python backend
├── docs/              # Documentation
└── .github/           # CI/CD workflows
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed architecture decisions.

## 🚀 Quick Start

### iOS App

**Requirements:**
- Xcode 15.2+
- iOS 17.0+ (for @Observable)
- Swift 5.9+

**Run:**
1. Open `ios-app/FareLens.xcodeproj` in Xcode
2. Select iPhone simulator
3. Press Cmd+R to build and run

**Switch Mock/Live Data:**
```swift
// In AppState.swift
let useMockData = true  // false for live API
```

### Backend API

**Requirements:**
- Python 3.11+
- pip

**Run:**
```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload
```

API available at: http://localhost:8000

**Docs:** http://localhost:8000/docs (Swagger UI)

## 📖 Documentation

- [PRD.md](PRD.md) - Product requirements
- [DESIGN.md](DESIGN.md) - Design system
- [ARCHITECTURE.md](ARCHITECTURE.md) - Technical architecture
- [API.md](API.md) - API contracts
- [iOS_26_PATTERNS.md](iOS_26_PATTERNS.md) - iOS 26 pattern guide
- [WORKFLOW.md](WORKFLOW.md) - Development workflow
- [TOOLING_SETUP.md](TOOLING_SETUP.md) - Tool setup guide

## 🧪 Testing

**iOS Tests:**
```bash
cd ios-app
xcodebuild test -scheme FareLens -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

**Backend Tests:**
```bash
cd backend
pytest
```

## 🔧 Troubleshooting

**Issue:** Build fails with "Cannot find FareLens in scope"
**Fix:** Clean build folder (Cmd+Shift+K) and rebuild

**Issue:** Backend connection refused
**Fix:** Ensure backend is running on port 8000

**Issue:** SwiftFormat errors
**Fix:** Run `swiftformat .` from project root

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for more.

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Follow [WORKFLOW.md](WORKFLOW.md) for development process
4. Commit using [conventional commits](https://www.conventionalcommits.org/)
5. Push and create Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## 📝 Code Quality

- ✅ iOS 26 @Observable patterns enforced
- ✅ SwiftFormat for consistent styling
- ✅ Automated Codex reviews
- ✅ Pre-commit hooks for quality gates
- ✅ GitHub Actions CI/CD

See [.swiftformat](.swiftformat) and [.github/workflows/](.github/workflows/) for configuration.

## 📜 License

MIT License - see [LICENSE](LICENSE) for details

## 👤 Author

**Astrion Studio**
- GitHub: [@astrion-studio](https://github.com/astrion-studio)

## 🙏 Acknowledgments

- Built with Claude Code
- Automated reviews by Codex
- Design inspired by iOS design guidelines

---

**Need help?** Open an issue or check the [documentation](docs/).
```

---

## Summary Checklist

### Critical (Do Now)
- [ ] Add repo metadata
- [ ] Remove .DS_Store
- [ ] Require conversation resolution
- [ ] Enable Dependabot
- [ ] Enable secret scanning

### Important (Soon)
- [ ] Backend CI workflow
- [ ] CodeQL scanning
- [ ] PR template
- [ ] Issue templates
- [ ] Comprehensive README

### Optional (Later)
- [ ] Add tests
- [ ] Labels
- [ ] Conventional commits
- [ ] CHANGELOG
- [ ] CODEOWNERS

---

**Next Action:** Start with Phase 1 (Critical items) - takes 30 minutes total.
