# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive README with project overview, architecture, and setup instructions
- GitHub issue templates (bug report, feature request)
- Pull request template with iOS 26 compliance checklist
- Contributing guidelines with conventional commits and coding standards
- CodeQL security scanning workflow
- Dependabot configuration for Swift, Python, and GitHub Actions
- Standard GitHub labels (bug, enhancement, documentation, dependencies, ios, backend, ci)
- Repository metadata (description and 8 topic tags)
- CODEOWNERS file for automatic review assignment
- This CHANGELOG file

### Changed
- Removed .DS_Store from git tracking
- Updated branch protection to require conversation resolution
- Enabled secret scanning with push protection

### Fixed
- CI workflow now handles BSD grep compatibility (macOS)
- Force unwrap detection excludes false positives (strings, comments, operators)
- Tests skip gracefully when Xcode project file is missing

## [0.1.0] - 2024-10-XX (Upcoming)

### Added
- iOS 26 @Observable pattern implementation
- SwiftUI views for flight deals listing and details
- Smart queue service for background task processing
- Alert service for deal notifications
- Deals repository with data layer
- Unit tests for core services
- SwiftLint and SwiftFormat configuration
- CI/CD pipeline with code quality checks
- Automated code review workflow
- Comprehensive project documentation

### Technical Details
- **iOS Target**: iOS 17.0+
- **Swift Version**: 5.9+
- **Architecture**: Clean architecture with repository pattern
- **State Management**: iOS 26 @Observable macro
- **Networking**: URLSession with async/await
- **Testing**: XCTest with mock dependencies

---

## Version History

- **[Unreleased]** - Current development
- **[0.1.0]** - Initial release (upcoming)

## How to Update This File

When making changes, add entries under `[Unreleased]` in the appropriate section:

- **Added** - New features
- **Changed** - Changes in existing functionality
- **Deprecated** - Soon-to-be removed features
- **Removed** - Removed features
- **Fixed** - Bug fixes
- **Security** - Security fixes

When releasing a new version:
1. Change `[Unreleased]` to `[X.Y.Z] - YYYY-MM-DD`
2. Add a new `[Unreleased]` section at the top
3. Update version links at the bottom
4. Create a git tag: `git tag -a vX.Y.Z -m "Version X.Y.Z"`
