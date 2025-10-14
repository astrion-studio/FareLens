# Claude Code Best Practices for FareLens Development

**Purpose:** Strategies for managing Claude Code session limits and preserving context
**Problem:** Hit usage limits 3 times during 8-cycle review, lost nuanced context
**Solution:** Progressive documentation and strategic session management

---

## Table of Contents

1. [Understanding Session Limits](#understanding-session-limits)
2. [Session Log Template](#session-log-template)
3. [Context Preservation Strategies](#context-preservation-strategies)
4. [Starting a New Session](#starting-a-new-session)
5. [Subagent Orchestration](#subagent-orchestration)
6. [Decision Documentation](#decision-documentation)
7. [When to Stop and Document](#when-to-stop-and-document)

---

## Understanding Session Limits

### What Happens When You Hit Limits

**Symptoms:**
- "You've reached your usage limit for Claude Code"
- Need to start new conversation
- Previous context not automatically carried over
- Subagents lose memory of earlier decisions

**Impact on FareLens Development:**
- Had to re-explain architecture decisions 3 times
- Lost context about why certain patterns were chosen
- Repeated questions about iOS 26 vs iOS 17
- Slowed down 8-cycle review process

### Why This Happened

```
Session 1 (Day 1-3): PRD, DESIGN, ARCHITECTURE docs
  → Hit limit after 6,500 lines of generated code
  → Lost: Initial requirements discussions

Session 2 (Day 4-6): Implemented 48 files (6,500 lines)
  → Hit limit during Cycle 3 of review
  → Lost: Context about duplicate definitions, pattern decisions

Session 3 (Day 7-8): Review Cycles 4-8
  → Completed successfully with documentation
  → Context preserved via RETROSPECTIVE.md
```

**Lesson:** Should have documented progressively, not just in memory.

---

## Session Log Template

### Create SESSION_LOG.md

```bash
# Create file at project root
cat > SESSION_LOG.md <<'EOF'
# FareLens Development Session Log

**Purpose:** Preserve context across Claude Code sessions
**Update:** After every session
**Read:** At start of new session

---

<!-- TEMPLATE FOR NEW SESSION -->
<!--
## Session YYYY-MM-DD-N (HH:MM AM/PM - HH:MM AM/PM)

**Context:** [What was the state when starting this session]

**Continued From:** [Previous session reference, or "Fresh start"]

**Goal:** [What you wanted to accomplish]

**What We Built:**
- Feature 1 (files)
- Feature 2 (files)
- Component 3 (files)

**Commits:**
- `abc123` - feat(feature): Description
- `def456` - fix(issue): Description
- `ghi789` - test(feature): Description

**Issues Found:**
- P0-1: Description (file:line)
- P1-2: Description (file:line)

**Issues Fixed:**
- P0-1: Solution applied (commit abc123)
- P1-2: Solution applied (commit def456)

**Key Decisions:**
- Decision 1: Why we chose X over Y
- Decision 2: Pattern we established
- Decision 3: Trade-off we accepted

**Screenshots Taken:**
- ViewName (status: ✅ matches mockups / ⚠️ needs adjustment)

**Tests Added:**
- Feature1Tests (15 tests, 98% coverage)
- Feature2Tests (12 tests, 95% coverage)

**Next Session:**
- [ ] Task 1 to continue
- [ ] Task 2 to start
- [ ] Issue 3 to resolve

**Files Modified:**
[Full paths to all files touched]

**Claude Code Stats:**
- Messages sent: ~50
- Code generated: ~1,200 lines
- Review cycles: 2
- Session duration: 2 hours

**Notes:**
[Any important context for next session]

---
-->

EOF
```

### Example Session Entry

```markdown
## Session 2025-10-13-1 (11:00 AM - 1:30 PM)

**Context:** Starting UI implementation after completing ARCHITECTURE.md. Zero code written yet. Fresh Xcode project.

**Continued From:** Session 2025-10-12-2 (completed documentation phase)

**Goal:** Implement Alerts and Deals features with iOS 26 @Observable pattern

**What We Built:**
- AlertsView (AlertsView.swift, 150 lines)
- AlertsViewModel (AlertsViewModel.swift, 80 lines)
- DealsView (DealsView.swift, 200 lines)
- DealsViewModel (DealsViewModel.swift, 120 lines)
- 5 reusable components (FLButton, FLCard, FLBadge, etc.)

**Commits:**
- `a1b2c3d` - feat(alerts): Implement AlertsViewModel with @Observable pattern
- `e4f5g6h` - feat(alerts): Implement AlertsView SwiftUI layout
- `i7j8k9l` - feat(deals): Implement DealsViewModel with smart queue
- `m1n2o3p` - feat(deals): Implement DealsView with filter controls
- `q4r5s6t` - feat(design): Add 5 reusable components to design system

**Issues Found:**
- P0-1: Duplicate DealDetailViewModel in 2 files (DealDetailView.swift:1, DealsView.swift:200)
- P0-2: @StateObject used with @Observable in MainTabView.swift:4
- P1-3: Missing error handling in AlertsViewModel.loadAlerts() (AlertsViewModel.swift:24)

**Issues Fixed:**
(None this session - will fix in next cycle)

**Key Decisions:**
- **ViewModel Extraction**: Moved all ViewModels to separate files for testability
  - Reason: Easier to test in isolation, cleaner file structure
  - Trade-off: More files, but better maintainability

- **@Observable Pattern**: Used @Observable (iOS 26) instead of ObservableObject
  - Reason: Modern pattern, simpler syntax, better performance
  - Impact: Requires iOS 17.0+ minimum deployment target

- **Dependency Injection**: Inject services via init() instead of singletons
  - Reason: Enables mocking for tests, clearer dependencies
  - Example: `init(user: User, alertService: AlertServiceProtocol = AlertService.shared)`

- **Smart Queue in DealsViewModel**: Implemented priority queue with filtering
  - Reason: Performance optimization for 1000+ deals
  - Complexity: +50 lines but saves 2s load time

**Screenshots Taken:**
- AlertsView (⚠️ spacing 2px off from mockups)
- DealsView (⚠️ filter button color should be brandBlue, currently gray)

**Tests Added:**
- AlertsViewModelTests (15 tests, 98% coverage)
  - testLoadAlerts_Success
  - testLoadAlerts_Error
  - testApplyFilter_All/Today/Week/Month

- DealsViewModelTests (12 tests, 95% coverage)
  - testLoadDeals_Success
  - testLoadDeals_EmptyState
  - testPriorityQueue_Sorting

**Next Session:**
- [ ] Fix P0-1, P0-2, P1-3 from code review
- [ ] Fix AlertsView spacing (mockups show 16pt, we have 18pt)
- [ ] Fix DealsView filter button color
- [ ] Implement WatchlistsView
- [ ] Run code-reviewer Cycle 2

**Files Modified:**
- `/Users/Parvez/Desktop/FareLensApp/ios-app/FareLens/Features/Alerts/AlertsView.swift`
- `/Users/Parvez/Desktop/FareLensApp/ios-app/FareLens/Features/Alerts/AlertsViewModel.swift`
- `/Users/Parvez/Desktop/FareLensApp/ios-app/FareLens/Features/Deals/DealsView.swift`
- `/Users/Parvez/Desktop/FareLensApp/ios-app/FareLens/Features/Deals/DealsViewModel.swift`
- `/Users/Parvez/Desktop/FareLensApp/ios-app/FareLens/DesignSystem/Components/FLButton.swift`
- `/Users/Parvez/Desktop/FareLensApp/ios-app/FareLens/DesignSystem/Components/FLCard.swift`
- `/Users/Parvez/Desktop/FareLensApp/ios-app/FareLens/DesignSystem/Components/FLBadge.swift`
- `/Users/Parvez/Desktop/FareLensApp/ios-app/FareLens/App/MainTabView.swift`

**Claude Code Stats:**
- Messages sent: ~45
- Code generated: ~1,100 lines
- Review cycles: 1 (Cycle 1 completed, found 3 issues)
- Session duration: 2.5 hours

**Notes:**
- Session ended because approaching usage limit (saw warning)
- All code compiles but issues need fixing before merge
- Screenshot comparisons saved in design-refs/comparison-notes.md
- Remember: DealsViewModel priority queue is complex, document thoroughly

---

## Session 2025-10-13-2 (3:00 PM - 5:00 PM)

**Context:** Continuing from Session 1, fixing 3 issues found in Cycle 1

**Continued From:** Session 2025-10-13-1 (see above for full context)

**Goal:** Fix P0-1, P0-2, P1-3, then implement WatchlistsView

**What We Built:**
- Fixed 3 issues from Cycle 1
- WatchlistsView (WatchlistsView.swift, 180 lines)
- WatchlistsViewModel (WatchlistsViewModel.swift, 100 lines)

**Commits:**
- `t1u2v3w` - fix: Remove duplicate DealDetailViewModel definition (P0-1)
- `x4y5z6a` - fix: Replace @StateObject with @State in MainTabView (P0-2)
- `b7c8d9e` - fix: Add error handling to AlertsViewModel.loadAlerts (P1-3)
- `f1g2h3i` - feat(watchlists): Implement WatchlistsViewModel
- `j4k5l6m` - feat(watchlists): Implement WatchlistsView UI

**Issues Fixed:**
- P0-1: Removed duplicate DealDetailViewModel from DealsView.swift
  - Root cause: Copy-paste error during implementation
  - Solution: Kept only the version in DealDetailView.swift

- P0-2: Changed @StateObject to @State in MainTabView.swift:4
  - Root cause: Pattern confusion (legacy vs modern)
  - Solution: @Observable classes use @State, not @StateObject

- P1-3: Added do-catch error handling in AlertsViewModel.loadAlerts()
  - Root cause: Async/await error not caught
  - Solution: Wrapped in do-catch, set errorMessage property

**Key Decisions:**
- **Watchlist Matching Logic**: Implemented in FlightDeal.matches(Watchlist)
  - Reason: Single source of truth, easier to test
  - Trade-off: Deal model knows about Watchlist (coupling)
  - Alternative considered: Separate MatchingService (rejected as over-engineering)

**Next Session:**
- [ ] Implement SettingsView
- [ ] Implement OnboardingView
- [ ] Run code-reviewer Cycle 2
- [ ] Take screenshots of all new views

**Notes:**
- No usage limit warning yet, session ended due to time constraint
- All 3 P0/P1 issues resolved and verified
- Next cycle should find fewer issues (maybe 0-2?)

---
```

---

## Context Preservation Strategies

### 1. Progressive Documentation (Not Batch)

**❌ What We Did Wrong:**
- Documented nothing during implementation
- Tried to remember 8 cycles worth of decisions
- Created RETROSPECTIVE.md only at the end

**✅ What To Do Instead:**
- Update SESSION_LOG.md after every session (5 minutes)
- Document key decisions immediately in ARCHITECTURE.md
- Commit documentation changes with code changes

```bash
# After every session:
cat >> SESSION_LOG.md <<EOF
## Session $(date +%Y-%m-%d-%H%M)
**Goal:** [What you did]
**Commits:** [List commits]
**Decisions:** [What you decided and why]
**Next:** [What to do next]
EOF

git add SESSION_LOG.md
git commit -m "docs: Update session log ($(date +%Y-%m-%d))"
```

### 2. Commit Messages as Documentation

**✅ Good Commit Messages (Context-Preserving):**

```bash
# Explains WHY, not just WHAT
git commit -m "feat(alerts): Use @Observable instead of ObservableObject

iOS 26 introduces @Observable macro which simplifies state management.
Benefits:
- No @Published wrappers needed
- Better performance (fine-grained observation)
- Simpler syntax for views (@State instead of @StateObject)

Trade-off: Requires iOS 17.0+ minimum deployment target.

Decision made after reviewing ARCHITECTURE.md Section 3.2."

# Links to issues and documents
git commit -m "fix: Remove duplicate DealDetailViewModel (LIN-23)

Duplicate definition caused compilation error.
Root cause: Copy-paste during initial implementation.
Prevention: Added SwiftLint rule to catch duplicates.

See RETROSPECTIVE.md Section 2 for process improvement."
```

**❌ Bad Commit Messages (Context-Lost):**

```bash
git commit -m "fixed stuff"
git commit -m "updates"
git commit -m "WIP"
```

### 3. Decision Log in ARCHITECTURE.md

**Maintain "Decision History" Section:**

```markdown
## Decision History

### 2025-10-13: @Observable Pattern (iOS 26)

**Decision:** Use @Observable instead of ObservableObject for all ViewModels

**Context:** iOS 26 introduces @Observable macro as modern replacement for ObservableObject

**Alternatives Considered:**
1. ❌ ObservableObject (legacy) - More verbose, worse performance
2. ❌ Mix both patterns - Inconsistent, confusing
3. ✅ @Observable only - Modern, simpler, better performance

**Trade-offs:**
- ✅ Simpler syntax (@State instead of @StateObject)
- ✅ Better performance (fine-grained observation)
- ✅ No @Published wrappers needed
- ⚠️ Requires iOS 17.0+ minimum (acceptable for 2025 app)

**Participants:** Claude Code ios-architect subagent, user approval

**References:**
- iOS_26_PATTERNS.md Section 2
- Apple WWDC 2023 Session 10149

---

### 2025-10-13: Dependency Injection via Init

**Decision:** Inject services via init() instead of singletons

**Context:** Needed testability for ViewModels

**Alternatives Considered:**
1. ❌ Singleton everywhere - Hard to test, global state
2. ❌ SwiftUI Environment - Overkill for simple services
3. ✅ Init injection with default parameter - Testable, simple

**Implementation:**
```swift
init(user: User, alertService: AlertServiceProtocol = AlertService.shared) {
    self.user = user
    self.alertService = alertService
}
```

**Trade-offs:**
- ✅ Easy to mock in tests
- ✅ Clear dependencies
- ⚠️ More boilerplate (acceptable)

---
```

### 4. Screenshot Comparison Notes

**Create design-refs/comparison-notes.md:**

```markdown
# Screenshot Comparison Notes

## AlertsView

**Date:** 2025-10-13
**Mockup:** design-refs/mockups/AlertsView.png
**Actual:** design-refs/actual/AlertsView-20251013.png

**Discrepancies:**
- ⚠️ Spacing between cards: Mockup shows 16pt, actual is 18pt
  - Fix: Change `Spacing.md` (currently 18) to match mockup (16)
- ⚠️ Badge color: Mockup uses `brandBlue`, actual uses `systemBlue`
  - Fix: Update FLBadge default color
- ✅ Typography: Matches correctly
- ✅ Card shadow: Matches correctly

**Status:** Needs 2 adjustments before approval

---

## DealsView

**Date:** 2025-10-13
**Mockup:** design-refs/mockups/DealsView.png
**Actual:** design-refs/actual/DealsView-20251013.png

**Discrepancies:**
- ⚠️ Filter button color: Should be `brandBlue` (mockup), currently gray
  - Fix: Update FLButton style in DealsView.swift:42
- ✅ Deal card layout: Perfect match
- ✅ Price formatting: Correct

**Status:** Needs 1 adjustment

---
```

### 5. Code Review Findings Log

**Create REVIEW_FINDINGS.md:**

```markdown
# Code Review Findings Log

## Cycle 1 (2025-10-13)

**Files Reviewed:** 48 files, 6,500 lines

**Issues Found:**
- P0: 5 issues (compilation blockers)
- P1: 11 issues (pattern violations)
- P2: 6 issues (code quality)

**Total:** 22 issues

### P0 Issues (Critical)

1. **Duplicate DealDetailViewModel**
   - **Location:** DealDetailView.swift:1, DealsView.swift:200
   - **Impact:** Compilation error
   - **Root Cause:** Copy-paste during implementation
   - **Fix:** Remove from DealsView.swift
   - **Commit:** t1u2v3w
   - **Prevention:** SwiftLint rule to detect duplicate class names

2. **@StateObject with @Observable**
   - **Location:** MainTabView.swift:4
   - **Impact:** Crashes at runtime
   - **Root Cause:** Pattern confusion
   - **Fix:** Change to @State
   - **Commit:** x4y5z6a
   - **Prevention:** Pre-commit hook checks iOS 26 patterns

[... continue for all 22 issues ...]

## Cycle 2 (2025-10-14)

**Files Reviewed:** 48 files (after fixes)

**Issues Found:**
- P0: 0 issues ✅
- P1: 2 issues
- P2: 3 issues

**Total:** 5 issues

[... and so on ...]
```

---

## Starting a New Session

### Checklist for Context Recovery

When starting a new Claude Code session after hitting limits:

```markdown
1. [ ] Read SESSION_LOG.md (last 2-3 sessions)
2. [ ] Read ARCHITECTURE.md Decision History section
3. [ ] Run `git log --oneline -20` (recent commits)
4. [ ] Run `git status` (current state)
5. [ ] Check Linear issues: `linear issue list --assignee @me`
6. [ ] Review REVIEW_FINDINGS.md (if in review phase)
7. [ ] Check design-refs/comparison-notes.md (if doing UI)
8. [ ] Open relevant files in Cursor/VS Code
```

### Context Handoff Message

**Start new session with:**

```
Hi Claude, continuing FareLens development. Here's the context:

**Project:** FareLens iOS app (flight deal alerts)
**State:** [Current milestone, e.g., "Mid-implementation, fixing Cycle 2 issues"]

**Last Session:** 2025-10-13-2
- Implemented WatchlistsView
- Fixed 3 P0/P1 issues from Cycle 1
- Commits: t1u2v3w through j4k5l6m

**Current Goal:** [What you want to accomplish this session]

**Key Context:**
- Using iOS 26 @Observable pattern (see iOS_26_PATTERNS.md)
- All ViewModels use @State, not @StateObject
- Dependency injection via init() with default parameters
- See SESSION_LOG.md for full history

**Next Tasks:** [From last session's "Next Session" section]

**Questions:**
[Any specific questions or blockers]

Please confirm you have this context before we proceed.
```

### Files to Share with New Session

If Claude asks for files, provide in this order:

1. **SESSION_LOG.md** (last 2-3 sessions) - Overview of recent work
2. **ARCHITECTURE.md** - Technical decisions
3. **PRD.md** - Requirements (if relevant to current task)
4. **iOS_26_PATTERNS.md** - Pattern reference (if doing ViewModels)
5. **Specific files** you're working on

---

## Subagent Orchestration

### Use Subagents to Preserve Context

**Problem:** Main conversation hits limits, loses context

**Solution:** Use specialized subagents for isolated tasks

### When to Use Each Subagent

```markdown
**product-manager**
- Creating/updating PRD.md
- Defining acceptance criteria
- Prioritizing features
- Use when: Business requirements unclear

**product-designer**
- Creating/updating DESIGN.md
- Designing UI components
- Defining brand identity
- Use when: Visual design needed

**ios-architect**
- Creating/updating ARCHITECTURE.md
- Technical decision making
- Pattern selection
- Use when: Architecture questions arise

**code-reviewer**
- Reviewing code quality
- Finding P0/P1/P2 issues
- Pattern compliance
- Use when: After implementing feature (incremental) or before merge

**qa-specialist**
- Creating TEST_PLAN.md
- Defining test strategy
- Test coverage requirements
- Use when: Planning testing approach

**backend-architect**
- Creating/updating API.md
- API contract design
- Data modeling
- Use when: Backend integration needed
```

### Subagent Chain Example

```bash
# Scenario: Adding new feature (e.g., "Price Alerts")

# 1. Product Manager: Define requirements
"Use product-manager to add 'Price Alerts' feature to PRD.md"
# Output: PRD.md updated with acceptance criteria

# 2. Product Designer: Design UI
"Use product-designer to design Price Alerts UI in DESIGN.md"
# Output: DESIGN.md updated with mockups, components

# 3. iOS Architect: Plan implementation
"Use ios-architect to plan Price Alerts implementation"
# Output: Architecture decisions, file structure

# 4. Implement code yourself (or with Claude's help)
git checkout -b feature/price-alerts
# ... write code ...

# 5. Code Reviewer: Review immediately
"Use code-reviewer to review Price Alerts implementation"
# Output: List of P0/P1/P2 issues

# 6. Fix issues, then merge
git commit -m "fix: Resolve code review issues"
git push
```

**Benefit:** Each subagent maintains specialized context, doesn't clutter main conversation

---

## Decision Documentation

### DECISIONS.md Template

Create a dedicated decisions log:

```markdown
# FareLens Development Decisions

## Template

### YYYY-MM-DD: Decision Title

**Decision:** [One sentence summary]

**Context:** [Why this decision was needed]

**Options Considered:**
1. Option A - Pros/Cons
2. Option B - Pros/Cons
3. Option C - Pros/Cons (CHOSEN)

**Trade-offs:**
- ✅ Benefit 1
- ✅ Benefit 2
- ⚠️ Drawback 1 (acceptable because...)

**Implementation Details:**
[Code example or reference]

**Participants:** [Who made decision]

**References:** [Links to docs, issues, discussions]

**Review Date:** [When to revisit, if applicable]

---

## Actual Decisions

### 2025-10-13: ViewModels in Separate Files

**Decision:** Extract all ViewModels to separate files from Views

**Context:** Initial implementation had ViewModels inline with Views (e.g., `struct MyView { @Observable class ViewModel { } }`)

**Options Considered:**
1. ❌ Keep inline - Simpler initially, but hard to test
2. ❌ One file per feature (View + ViewModel together) - Still hard to isolate for tests
3. ✅ Separate files - View.swift and ViewModel.swift

**Trade-offs:**
- ✅ Easier to test ViewModels in isolation
- ✅ Cleaner file structure
- ✅ Better code organization
- ⚠️ More files (48 instead of 24) - Acceptable, industry standard

**Implementation:**
```
Features/
  Alerts/
    AlertsView.swift      # UI only
    AlertsViewModel.swift # Logic only
  Deals/
    DealsView.swift
    DealsViewModel.swift
```

**Participants:** ios-architect subagent, user approval

**References:** ARCHITECTURE.md Section 4.1

---

### 2025-10-13: Smart Queue in DealsViewModel

**Decision:** Implement priority queue with filtering in DealsViewModel

**Context:** App needs to handle 1000+ deals efficiently, show best deals first

**Options Considered:**
1. ❌ Array.sorted() every time - O(n log n), too slow for 1000+ items
2. ❌ Server-side sorting only - Network latency, doesn't work offline
3. ✅ Client-side priority queue + caching - Fast, works offline

**Trade-offs:**
- ✅ 2 second improvement (load 1000 deals in <1s instead of 3s)
- ✅ Works offline after initial fetch
- ✅ Better user experience
- ⚠️ +50 lines of complexity - Acceptable, well-documented

**Implementation:**
```swift
struct SmartDealQueue {
    private var heap: [FlightDeal] = []

    mutating func insert(_ deal: FlightDeal) {
        // Priority queue implementation
    }
}
```

**Participants:** Main Claude session, user approval

**References:** DealsViewModel.swift:120-170

**Review Date:** 2025-11-01 (after performance profiling)

---
```

### When to Document Decisions

**Document immediately when:**
- Choosing between 2+ alternatives
- Making architectural change
- Accepting a trade-off
- Deviating from standard pattern
- User asks "why did we do X?"

**Don't document:**
- Obvious choices (e.g., "use Swift for iOS app")
- Trivial implementation details (e.g., "use guard let instead of if let")
- Temporary debugging code

---

## When to Stop and Document

### Warning Signs You Need to Document

**🚨 Stop and document if:**
- Claude asks "why did we choose X?" for the 2nd time
- You can't remember why you made a decision 2 days ago
- Subagent suggests something contradicting earlier decision
- You've implemented 500+ lines without committing
- Session is about to hit usage limit (you see warning)

### End-of-Session Documentation Routine

**Before closing Claude Code (5 minutes):**

```bash
# 1. Update SESSION_LOG.md
cat >> SESSION_LOG.md <<EOF
## Session $(date +%Y-%m-%d-%H%M)
**Goal:** [accomplished]
**Commits:** $(git log --oneline --since="4 hours ago")
**Next:** [tasks for next session]
EOF

# 2. Document any key decisions
# Add to DECISIONS.md if you made architectural choice

# 3. Update comparison notes if UI changed
# Add to design-refs/comparison-notes.md

# 4. Commit session log
git add SESSION_LOG.md DECISIONS.md design-refs/comparison-notes.md
git commit -m "docs: Update session log ($(date +%Y-%m-%d))"
git push

# 5. Update Linear issues
linear issue update LIN-123 --state "In Progress" --comment "Completed ViewModel, next: View implementation"
```

---

## Summary: Context Preservation Checklist

### During Every Session

- [x] **Commit frequently** - Every logical change
- [x] **Write good commit messages** - Explain WHY, not just WHAT
- [x] **Document decisions immediately** - Don't rely on memory
- [x] **Use subagents for isolation** - Keep main conversation focused
- [x] **Take screenshots** - Visual verification + documentation

### End of Every Session

- [x] **Update SESSION_LOG.md** - 5 minutes, huge value
- [x] **Update DECISIONS.md** - If architectural choice made
- [x] **Update comparison-notes.md** - If UI work done
- [x] **Commit documentation** - Documentation is code
- [x] **Update Linear issues** - Track progress

### Start of New Session

- [x] **Read last 2-3 session logs** - Full context in 5 minutes
- [x] **Check git log** - See what changed
- [x] **Review open issues** - What needs doing
- [x] **Provide context to Claude** - Don't assume it remembers

---

## Real Example: How This Would Have Helped

### What Actually Happened (Without These Practices)

```
Day 1-3: Implement 6,500 lines
  → Hit session limit
  → Lost context about duplicate definitions

Day 4-6: Review Cycle 1-3
  → Hit session limit again
  → Had to re-explain why @Observable chosen
  → Repeated questions about iOS 26 vs iOS 17

Day 7-8: Review Cycle 4-8
  → Finally documented in RETROSPECTIVE.md
  → But too late, context already lost
```

**Total Time:** 8 days, 8 cycles, 22 issues

### What Would Have Happened (With These Practices)

```
Day 1: Setup + Documentation
  → SESSION_LOG.md created
  → DECISIONS.md started
  → All tools configured

Day 2: Implement AlertsView
  → 150 lines, committed immediately
  → Updated SESSION_LOG.md (5 min)
  → Code review found 1 issue, fixed immediately
  → Session ends with documentation committed

Day 3: Implement DealsView
  → New session starts
  → Read SESSION_LOG.md (3 min) - full context restored
  → Continue without re-explaining decisions
  → Commit + document as you go

Day 4-7: Continue incrementally
  → Each feature: implement → review → fix → document
  → No context loss across sessions
  → Total issues: 5-8 (vs 22)

Day 8: Final integration review
  → 2 cycles (vs 8)
  → Zero-defect achieved
```

**Total Time:** 8 days (same), 10 incremental reviews + 2 final (vs 8 massive), 5-8 issues (vs 22)
**Benefit:** No context loss, smoother workflow, fewer repeated questions

---

## Next Steps

1. **Create SESSION_LOG.md** from template in this guide
2. **Create DECISIONS.md** from template above
3. **Read WORKFLOW.md** for daily process
4. **Start next session** with proper context handoff

**Time Investment:** 5 minutes per session
**ROI:** Prevents 30+ minutes of context re-explanation per session
**Result:** Smooth transitions between sessions, no lost context
