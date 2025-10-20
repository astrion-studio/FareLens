## Summary
<!-- Provide a brief description of the changes in this PR -->

## Type of Change
<!-- Mark the relevant option with an "x" -->
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Refactoring (no functional changes)
- [ ] Performance improvement
- [ ] Dependency update

## Related Issues
<!-- Link to related issues using #issue-number -->
Closes #

## Changes Made
<!-- List the specific changes made in this PR -->
-
-
-

## Testing
<!-- Describe the tests you ran and how to reproduce them -->
- [ ] Unit tests pass locally
- [ ] CI checks pass
- [ ] Manual testing completed
- [ ] Tested on iOS Simulator
- [ ] Tested on physical device

### Test Configuration
- **iOS Version**:
- **Device**:
- **Xcode Version**:

## Screenshots/Videos
<!-- If applicable, add screenshots or videos to help explain your changes -->

## iOS 26 @Observable Compliance
<!-- For Swift/iOS changes only -->
- [ ] Uses `@Observable` instead of `ObservableObject`
- [ ] Uses `@Bindable` for two-way bindings
- [ ] Uses `@State` for local state
- [ ] Uses `@Environment` for dependency injection
- [ ] No `@Published` or `@StateObject` used
- [ ] Follows iOS 26 patterns from iOS_26_PATTERNS.md

## Code Quality Checklist
- [ ] Code follows the project's style guidelines (.swiftformat, .swiftlint.yml)
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] No force unwraps (`!`) in production code
- [ ] No print statements (uses OSLog instead)
- [ ] Documentation updated (if needed)
- [ ] No new warnings introduced

## Security Checklist
- [ ] No hardcoded secrets or API keys
- [ ] Sensitive data properly handled
- [ ] Input validation implemented (if applicable)
- [ ] No exposed credentials

## Breaking Changes
<!-- If this PR includes breaking changes, describe them and the migration path -->

## Additional Notes
<!-- Any additional information that reviewers should know -->

## Cross-Agent Review
<!-- Indicate which specialized agents should review this PR -->
**Recommended Reviewers:**
- [ ] **code-reviewer** - All PRs (runs automatically via CI)
- [ ] **ios-architect** - iOS architecture, ViewModels, state management
- [ ] **backend-architect** - API endpoints, database models, backend architecture
- [ ] **qa-specialist** - Test coverage, edge cases, quality assurance
- [ ] **platform-engineer** - CI/CD, workflows, deployment, infrastructure
- [ ] **product-designer** - UI/UX changes, design system, user experience
- [ ] **ml-engineer** - ML models, on-device inference, recommendation logic

**Agent Review Status:**
<!-- Update as agents review -->
- [ ] code-reviewer completed (check CI workflow)
- [ ] Recommended agents have reviewed
- [ ] All agent feedback addressed
- [ ] Conversation threads resolved

---
**Reviewer Guidelines:**
- **Human (@astrion-studio)**: Final decision maker, business logic, product direction
- **AI Agents**: Specialized technical review (see Cross-Agent Review section above)
- **Automated CI**: Code quality, patterns, security (code-reviewer agent)

**What to Check:**
- iOS 26 @Observable pattern compliance (ios-architect)
- No force unwraps or print statements (code-reviewer)
- Test coverage ≥80% for critical paths (qa-specialist)
- Architectural decisions align with ARCHITECTURE.md (ios-architect/backend-architect)
- API contracts match API.md (backend-architect)
- UI follows DESIGN.md guidelines (product-designer)
