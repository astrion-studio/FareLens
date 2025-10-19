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

---
**Reviewer Guidelines:**
- Check for iOS 26 @Observable pattern compliance
- Verify no force unwraps or print statements
- Ensure tests are comprehensive
- Validate architectural decisions align with ARCHITECTURE.md
