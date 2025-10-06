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

## Project-Specific Notes

[Add as you discover:]
- Build quirks
- Known issues
- Team conventions
- Environment setup