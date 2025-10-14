# iOS App Development with Subagents

## Build Commands
- open ios-app/*.xcodeproj: Open in Xcode
- xcodebuild test -scheme FareLens: Run all tests
- xcodebuild test -only-testing:FareLensTests/[TestClass]: Run specific test
- swiftlint: Lint Swift code
- swiftformat .: Format Swift code

## Subagent Orchestration Workflow

### Starting Any Project
1. Use product-manager to create/refine PRD.md
2. Use product-designer to create DESIGN.md (will need user approval on brand identity)
3. Use ios-architect to create ARCHITECTURE.md (may challenge design feasibility)
4. Use backend-architect to create API.md (if backend needed)
5. Implement following architecture docs
6. Use code-reviewer before every commit (blocks on P0 issues)
7. Use qa-specialist to create TEST_PLAN.md
8. Use platform-engineer when ready to deploy

### For Complex Decisions
Use extended thinking: "think hard" or "ultrathink" for architectural decisions

### Chaining Agents
First use [agent1], then [agent2]. If they conflict, stop and resolve before continuing.

Example: "Use ios-architect to plan feature, then code-reviewer to validate approach"

## Key Files Generated

PRD.md - Product requirements (product-manager)
DESIGN.md - Design system, brand, components (product-designer)  
ARCHITECTURE.md - iOS technical architecture (ios-architect)
API.md - Backend API contracts (backend-architect)
TEST_PLAN.md - Testing strategy (qa-specialist)

## Code Style Preferences

- SwiftUI over UIKit (unless UIKit-specific feature needed)
- async/await over completion handlers
- Protocol-based dependency injection (for testability)
- No force unwraps (!) in production code
- Test naming: test[Method]_[Scenario]_[Expected]

## Workflow

- Run tests before committing (no exceptions)
- Code-reviewer must approve before merge (zero P0 issues)
- Subagents make technical decisions autonomously
- User decides: brand identity, business priorities, product trade-offs
- On conflicts between agents: Stop, present options, let user decide

## Quality Gates

Can merge:
- All tests pass
- Code-reviewer approved
- Coverage ≥80% (≥95% for critical paths)

Can ship:
- Crash-free ≥99.5%
- Launch <2s on iPhone SE
- No P0 bugs

## Project Structure

ios-app/
  FareLens/
    App/ - Entry point, configuration
    Features/ - User-facing features
    Core/ - Models, services, utilities
    Data/ - Networking, persistence
    DesignSystem/ - Reusable UI components

## Common Patterns

Adding a feature:
1. product-manager adds to PRD.md
2. product-designer designs UI in DESIGN.md
3. ios-architect plans implementation
4. Implement + code-reviewer reviews
5. qa-specialist verifies tests

Fixing a bug:
1. Write failing test
2. Fix bug
3. code-reviewer reviews fix
4. Verify test passes

## Design References

- Competitor UX screenshots in design-refs/competitors/
- product-designer should review these before creating DESIGN.md

## Project-Specific Notes

### FareLens Confirmed Decisions (DO NOT QUESTION)
- **iOS 26.0+ target** - Confirmed with release notes (https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-26-release-notes). Uses year-based versioning (2026 = iOS 26). Liquid Glass redesign.
- **Cloudflare KV + Durable Objects** - NO Redis/Upstash. $0 cost vs $5/mo.
- **Pricing:** $6.99/month, $49.99/year (NOT $4.99/$39.99)
- **Brand color:** #0A84FF → #1E96FF gradient (NOT #0077ED)
- **Alert strategy:** Both Free (3/day) and Pro (6/day) get IMMEDIATE alerts when deals found. Smart queue formula: `finalScore = dealScore × (1 + watchlistBoost) × (1 + airportWeight)` with tiebreaker (price ASC, date ASC). 12h deduplication. Watchlist-only mode for Pro.
- **14-day free trial:** ALL new users get full Pro access for 14 days (standard iOS StoreKit 2)
- **Watchlists:** Free 5 cap, Pro unlimited (top 6/day alerted if cap reached)
- **Preferred airports:** Free 1 airport (weight=1.0), Pro 3 airports (weights must sum to 1.0, e.g., LAX 0.6, JFK 0.3, ORD 0.1)
- **Deals visibility:** Free sees 20 deals (≥80 score, remove LOWEST scores if >20, ≥70 backfill if <20), Pro sees ALL deals
- **Background refresh:** Free 1x/day (9am local), Pro 2x/day (9am+6pm local), 30-min cache TTL for watchlists
- **Device tiers:** A15+ gets blur/liquid glass, older gets flat design
- **Deal scoring:** Rule-based MVP (no ML), collect data for Phase 2

### Error Prevention Protocol
**BEFORE making changes:**
1. Read the ENTIRE section you're modifying (not just the line)
2. Use Grep to find ALL instances of what you're changing (e.g., all pricing, all Redis refs)
3. Make a checklist of every location that needs updating
4. Update systematically, checking off each location
5. AFTER changes: Grep again to verify NO old references remain

**AFTER agent reviews:**
1. NEVER claim work is complete without validation
2. When user requests "review after fixes", actually DO the review
3. Use Grep to verify each critical fix (pricing, colors, tech stack, etc.)
4. If approaching context limits, TELL USER instead of rushing

**Agent review workflow:**
1. Run agents ONE AT A TIME (never parallel for final reviews)
2. Wait for each agent's full report before proceeding
3. If agents find issues, fix ALL instances (not just examples)
4. After fixes, ALWAYS run targeted validation (Grep key terms)
5. Present validation results to user, not just "work complete"

**What "Apple-quality" means:**
- Liquid glass design (blur, depth, materials) on A15+ devices
- Flat design graceful fallback for older devices
- Silent push notifications (not BGTaskScheduler delays)
- Instant feedback, optimistic UI updates
- Privacy-first (on-device ML, minimal server data)
- Polished animations (spring curves, natural motion)

### Zero-Defect Review Protocol (Comprehensive Methodology)

**BEFORE claiming code is production-ready:**
1. Run comprehensive 5-layer review until 2 consecutive cycles find zero P0/P1 issues
2. Each cycle must verify ALL layers:
   - **Layer 1:** Static Analysis (syntax, types, imports, property wrappers, compilation readiness)
   - **Layer 2:** Architecture (pattern consistency, model organization, dependency structure)
   - **Layer 3:** Runtime Safety (force operations, error handling, actor isolation, optional safety)
   - **Layer 4:** Cross-File Dependencies (imports resolve, integration points work, no circular deps)
   - **Layer 5:** Compilation Simulation (mental compilation succeeds, all references valid)

**iOS 26 Pattern Checklist (verify EVERY ViewModel):**
- ✅ Uses `@Observable` (NOT `ObservableObject`)
- ✅ Uses `@MainActor` for UI thread safety
- ✅ Marked as `final class` for performance
- ✅ NO `@Published` properties (use plain `var`)
- ✅ Imports `Observation` framework
- ✅ Protocol-based dependency injection

**iOS 26 View Pattern Checklist (verify EVERY View):**
- ✅ Parent views use `@State` for ViewModels (NOT `@StateObject`)
- ✅ Uses `@Environment(Type.self)` for environment (NOT `@EnvironmentObject`)
- ✅ Sub-views use plain `var` for passed ViewModels (NO property wrappers)
- ✅ App uses `.environment()` for injection (NOT `.environmentObject()`)

**Common Issues to Check (from 22 issues found across 8 cycles):**
1. **Duplicate definitions:** Check for embedded ViewModels in View files, duplicate components
2. **Missing properties:** After extracting ViewModels, verify all properties present
3. **Force unwraps:** URLs, optionals, arrays - must use guard/if let (ZERO tolerance)
4. **Array subscripting:** Always bounds-check before accessing
5. **Pattern mixing:** @StateObject with @Observable crashes! @EnvironmentObject wrong pattern
6. **Actor isolation:** Services/repositories must be actors, ViewModels must be @MainActor

**Review Cycle Requirements:**
- Fix ALL issues found (P0, P1, P2) before next cycle - partial fixes cause regression
- Continue cycles until 2 consecutive show zero P0/P1 issues
- Only acceptable P2 remaining: test-only issues, documentation suggestions
- Use agents (code-reviewer, ios-architect, qa-specialist) for comprehensive coverage
- Document all fixes with clear commit messages

**When Review is Complete:**
- 2 consecutive cycles with zero P0/P1 issues achieved
- Only P2 issues remaining (test-only, documentation)
- All files mentally compile successfully
- 100% pattern consistency verified across all ViewModels/Views
- Automation scripts pass (see scripts/check-ios26-patterns.sh)

**See Also:**
- iOS_26_PATTERNS.md - Complete pattern reference guide
- RETROSPECTIVE.md - Why 8 cycles were needed and how to prevent it
- WORKFLOW.md - Ideal development process with incremental review

## Important Instructions

Do what has been asked; nothing more, nothing less.
NEVER create files unless explicitly requested OR part of the standard subagent workflow (PRD.md, DESIGN.md, ARCHITECTURE.md, API.md, TEST_PLAN.md).
ALWAYS prefer editing an existing file to creating a new one.
NEVER rush work when approaching context limits - inform user and ask to continue in new session.
ALWAYS validate changes after making them (use Grep, Read to verify).
When user says "do a review", actually DO the review - don't skip it.