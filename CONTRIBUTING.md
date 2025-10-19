# Contributing to FareLens

Thank you for your interest in contributing to FareLens! This document provides guidelines and best practices for contributing.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and collaborative environment.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally
   ```bash
   git clone https://github.com/YOUR_USERNAME/FareLens.git
   cd FareLens
   ```
3. **Create a branch** for your feature or fix
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Setup

### Requirements
- macOS 14.0+
- Xcode 15.0+
- Swift 5.9+
- iOS 17.0+ (for testing)

### Initial Setup
1. Open the project in Xcode:
   ```bash
   open ios-app/FareLens.xcodeproj
   ```

2. Install development tools (optional but recommended):
   ```bash
   brew install swiftlint swiftformat
   ```

3. Build and run tests:
   - Press `Cmd + U` in Xcode, or
   - Run `xcodebuild test -scheme FareLens -destination 'platform=iOS Simulator,name=iPhone 15 Pro'`

## Coding Standards

### Swift Style Guide

We follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/) and enforce them with SwiftLint and SwiftFormat.

**Key rules:**
- Use 4 spaces for indentation (no tabs)
- Maximum line length: 120 characters
- Follow naming conventions: `lowerCamelCase` for properties/functions, `UpperCamelCase` for types
- Use meaningful, descriptive names
- Prefer `let` over `var` when possible
- Use explicit types for public APIs, inference for private implementation

### iOS 26 @Observable Pattern

**CRITICAL:** This project uses iOS 26's new `@Observable` macro. Do NOT use the old `ObservableObject` pattern.

**✅ DO:**
```swift
@Observable
final class MyViewModel {
    var items: [Item] = []
    var isLoading = false
}

struct MyView: View {
    @State private var viewModel = MyViewModel()
    @Bindable var editableModel: EditableModel
}
```

**❌ DON'T:**
```swift
// OLD PATTERN - Don't use this!
class MyViewModel: ObservableObject {
    @Published var items: [Item] = []
    @StateObject private var viewModel = MyViewModel()
}
```

See [iOS_26_PATTERNS.md](iOS_26_PATTERNS.md) for comprehensive examples.

### Code Quality Rules

**Enforced by CI:**
- ❌ No force unwraps (`!`) in production code
- ❌ No print statements (use `OSLog` instead)
- ❌ No SwiftUI previews with hardcoded data
- ✅ All code must be formatted with SwiftFormat
- ✅ All code must pass SwiftLint checks
- ✅ All tests must pass

**Before submitting:**
```bash
# Format code
swiftformat ios-app/FareLens/

# Lint code
swiftlint lint --path ios-app/FareLens/

# Run tests
xcodebuild test -scheme FareLens -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## Commit Guidelines

We use [Conventional Commits](https://www.conventionalcommits.org/) for clear, semantic commit history.

### Commit Format
```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types
- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation only changes
- **style**: Code style changes (formatting, missing semicolons, etc)
- **refactor**: Code change that neither fixes a bug nor adds a feature
- **perf**: Performance improvement
- **test**: Adding or updating tests
- **chore**: Changes to build process, dependencies, or tooling
- **ci**: CI/CD changes

### Examples
```bash
feat(deals): Add price drop notifications

Implement push notifications when flight prices drop below user threshold.
Includes new NotificationService and integration with existing AlertService.

Closes #123

---

fix(queue): Prevent duplicate task execution

The SmartQueueService was executing tasks multiple times when
app returned from background. Added task deduplication logic.

Fixes #456

---

docs: Update iOS 26 pattern examples

Added more examples of @Bindable usage and environment injection.

---

chore(deps): Update Swift dependencies

Update all Swift packages to latest versions.
```

## Pull Request Process

1. **Update documentation** if you're changing functionality
2. **Add tests** for new features or bug fixes
3. **Run all tests** and ensure they pass
4. **Format code** with SwiftFormat and SwiftLint
5. **Fill out the PR template** completely
6. **Link related issues** using "Closes #123" or "Fixes #456"
7. **Request review** - PRs will be automatically reviewed by Codex
8. **Address feedback** from automated reviews
9. **Resolve all conversations** before merging

### PR Checklist
- [ ] Code follows style guidelines (SwiftLint, SwiftFormat)
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] Tests added/updated and passing
- [ ] No force unwraps in production code
- [ ] No print statements (uses OSLog)
- [ ] iOS 26 @Observable patterns followed
- [ ] No breaking changes (or documented in PR)
- [ ] Linked to related issues

## Testing

### Writing Tests

- Write unit tests for all new functionality
- Test edge cases and error conditions
- Use descriptive test names: `testFetchDeals_whenNetworkFails_shouldReturnError()`
- Mock dependencies using protocols
- Aim for high code coverage

### Test Structure
```swift
final class MyServiceTests: XCTestCase {
    var sut: MyService!
    var mockDependency: MockDependency!

    override func setUp() {
        super.setUp()
        mockDependency = MockDependency()
        sut = MyService(dependency: mockDependency)
    }

    override func tearDown() {
        sut = nil
        mockDependency = nil
        super.tearDown()
    }

    func testFeature_whenCondition_shouldExpectedBehavior() async {
        // Given
        let input = "test"

        // When
        let result = await sut.performAction(input)

        // Then
        XCTAssertEqual(result, expectedValue)
    }
}
```

## Project Structure

Follow the existing project structure:

```
ios-app/FareLens/
├── App/              # App entry point, configuration
├── Core/             # Core utilities, extensions, networking
├── Data/             # Data layer (repositories, models, DTOs)
├── DesignSystem/     # Reusable UI components, theme
├── Features/         # Feature modules (one folder per feature)
│   ├── Deals/
│   ├── Alerts/
│   └── Settings/
└── Resources/        # Assets, localization, Info.plist
```

### Adding a New Feature

1. Create a new folder in `Features/`
2. Follow this structure:
   ```
   Features/MyFeature/
   ├── Models/         # Feature-specific models
   ├── ViewModels/     # @Observable view models
   ├── Views/          # SwiftUI views
   ├── Services/       # Feature-specific services
   └── README.md       # Feature documentation
   ```

## Documentation

- Update `README.md` for user-facing changes
- Update `ARCHITECTURE.md` for architectural changes
- Update `iOS_26_PATTERNS.md` for new pattern examples
- Add inline documentation for public APIs
- Use `///` for documentation comments
- Include code examples in documentation

## Issue Reporting

### Bug Reports
Use the bug report template and include:
- Clear description of the bug
- Steps to reproduce
- Expected vs actual behavior
- iOS version, device, app version
- Screenshots/logs if applicable

### Feature Requests
Use the feature request template and include:
- Clear description of the feature
- Problem it solves
- Proposed solution
- User stories
- Acceptance criteria

## Questions?

- Check existing [documentation](README.md)
- Search [existing issues](https://github.com/astrion-studio/FareLens/issues)
- Create a new issue if needed

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for contributing to FareLens!** 🚀
