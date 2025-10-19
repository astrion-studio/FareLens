# FareLens ✈️

> iOS flight deal alert app with iOS 26 @Observable patterns + FastAPI backend

[![CI](https://github.com/astrion-studio/FareLens/actions/workflows/ci.yml/badge.svg)](https://github.com/astrion-studio/FareLens/actions/workflows/ci.yml)
[![CodeQL](https://github.com/astrion-studio/FareLens/actions/workflows/codeql.yml/badge.svg)](https://github.com/astrion-studio/FareLens/actions/workflows/codeql.yml)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://www.apple.com/ios/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

FareLens is a modern iOS application that helps travelers discover and track flight deals in real-time. Built with SwiftUI and iOS 26's new `@Observable` macro, it demonstrates cutting-edge iOS development patterns and best practices.

## Features

- **Real-time Flight Deal Alerts** - Get notified when prices drop on your favorite routes
- **Smart Queue System** - Intelligent background processing for deal updates
- **Beautiful UI** - Modern design system with liquid glass aesthetics
- **iOS 26 Patterns** - Built with `@Observable`, `@Bindable`, and `@Environment`
- **Type-Safe Architecture** - Leverages Swift's type system for robust code
- **Comprehensive Testing** - Unit tests with high coverage

## Screenshots

_Coming soon_

## Requirements

- **iOS 17.0+**
- **Xcode 15.0+**
- **Swift 5.9+**
- **macOS 14.0+** (for development)

## Getting Started

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/astrion-studio/FareLens.git
   cd FareLens
   ```

2. **Open in Xcode**
   ```bash
   open ios-app/FareLens.xcodeproj
   ```

3. **Build and Run**
   - Select your target device or simulator
   - Press `Cmd + R` to build and run

### Running Tests

```bash
cd ios-app
xcodebuild test -scheme FareLens -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

Or use Xcode's Test Navigator (`Cmd + 6`) and click the play button.

## Architecture

FareLens follows a clean, modular architecture:

```
ios-app/FareLens/
├── App/              # App entry point and configuration
├── Core/             # Core utilities, networking, storage
├── Data/             # Data layer (repositories, models)
├── DesignSystem/     # Reusable UI components and theme
├── Features/         # Feature modules (Deals, Alerts, etc.)
└── Resources/        # Assets, localization
```

### Key Architectural Principles

- **iOS 26 @Observable Pattern** - Modern state management without `ObservableObject`
- **Dependency Injection** - Via `@Environment` for testability
- **Repository Pattern** - Abstracted data access layer
- **Smart Queue Service** - Background task processing
- **Type-Safe Networking** - Async/await with structured concurrency

For detailed architecture documentation, see [ARCHITECTURE.md](ARCHITECTURE.md).

## iOS 26 @Observable Patterns

This project uses iOS 26's new observation framework:

```swift
@Observable
final class DealsViewModel {
    var deals: [Deal] = []
    var isLoading = false

    func fetchDeals() async {
        isLoading = true
        // Automatic UI updates, no @Published needed!
        deals = await repository.fetchDeals()
        isLoading = false
    }
}
```

**Key Differences from ObservableObject:**
- ✅ Use `@Observable` instead of `ObservableObject`
- ✅ Use `@Bindable` for two-way bindings
- ✅ Use `@State` for local state
- ❌ No `@Published` properties
- ❌ No `@StateObject` or `@ObservedObject`

See [iOS_26_PATTERNS.md](iOS_26_PATTERNS.md) for comprehensive examples.

## Code Quality

We maintain high code quality standards:

- **SwiftLint** - Enforces Swift style guidelines
- **SwiftFormat** - Automatic code formatting
- **CI/CD** - Automated checks on every PR
  - No force unwraps (`!`) in production code
  - No print statements (use OSLog)
  - No SwiftUI previews with hardcoded data
- **Code Review** - Automated review via Codex
- **Security Scanning** - Dependabot, secret scanning, CodeQL

### Local Development

```bash
# Format code
swiftformat ios-app/FareLens/

# Lint code
swiftlint lint --path ios-app/FareLens/

# Run tests
xcodebuild test -scheme FareLens -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## Contributing

We welcome contributions! Please follow these guidelines:

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Follow code style** - Use SwiftFormat and SwiftLint
4. **Write tests** - Maintain or improve code coverage
5. **Follow iOS 26 patterns** - See [iOS_26_PATTERNS.md](iOS_26_PATTERNS.md)
6. **Commit with conventional commits** - See [Conventional Commits](#conventional-commits)
7. **Open a Pull Request** - Fill out the PR template completely

### Conventional Commits

We use [Conventional Commits](https://www.conventionalcommits.org/) for clear commit history:

```
feat: Add price alert notifications
fix: Resolve deal refresh crash
docs: Update architecture documentation
test: Add tests for SmartQueueService
refactor: Simplify DealsRepository
chore: Update dependencies
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Detailed architecture overview
- **[iOS_26_PATTERNS.md](iOS_26_PATTERNS.md)** - iOS 26 @Observable patterns
- **[WORKFLOW.md](WORKFLOW.md)** - Development workflow guide
- **[API.md](API.md)** - Backend API documentation
- **[TOOLING_SETUP.md](TOOLING_SETUP.md)** - Development tools setup
- **[GOLDEN_STANDARD_TODO.md](GOLDEN_STANDARD_TODO.md)** - GitHub best practices checklist

## Tech Stack

### iOS App
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **State Management**: @Observable (iOS 26)
- **Networking**: URLSession + async/await
- **Testing**: XCTest
- **Code Quality**: SwiftLint, SwiftFormat

### Backend (Planned)
- **Framework**: FastAPI (Python)
- **Database**: PostgreSQL
- **Cache**: Redis
- **APIs**: Flight search APIs

## Roadmap

- [x] iOS app core architecture
- [x] Deal listing and detail views
- [x] Smart queue background processing
- [x] Unit tests
- [x] CI/CD pipeline
- [ ] Backend API integration
- [ ] Push notifications
- [ ] Price tracking and alerts
- [ ] User authentication
- [ ] Favorites and saved searches
- [ ] App Store release

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with iOS 26 @Observable patterns
- Inspired by modern flight deal tracking services
- Designed with Apple's Human Interface Guidelines

## Contact

- **GitHub**: [@astrion-studio](https://github.com/astrion-studio)
- **Issues**: [GitHub Issues](https://github.com/astrion-studio/FareLens/issues)

---

**Made with ❤️ by Astrion Studio**
