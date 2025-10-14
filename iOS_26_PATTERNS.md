# iOS 26 Development Patterns for FareLens

**Target:** iOS 26.0+
**Framework:** SwiftUI + Observation
**Pattern:** MVVM with @Observable
**Last Updated:** 2025-10-13

---

## Quick Reference

### ✅ Correct iOS 26 Patterns

```swift
// ViewModel Pattern
import Observation

@Observable
@MainActor
final class MyViewModel {
    var property: String = ""  // NO @Published
    var isLoading = false
    var errorMessage: String?
}

// View Integration
struct MyView: View {
    @State var viewModel: MyViewModel  // NOT @StateObject

    var body: some View {
        Text(viewModel.property)
    }
}

// Environment Pattern
// In App:
.environment(appState)  // NOT .environmentObject

// In View:
@Environment(AppState.self) var appState  // NOT @EnvironmentObject
```

### ❌ Common Mistakes (WILL CRASH!)

```swift
// WRONG - Mixing iOS 26 @Observable with old property wrappers
@StateObject var viewModel: MyViewModel  // ❌ Use @State
@EnvironmentObject var appState: AppState  // ❌ Use @Environment
@Published var property in @Observable class  // ❌ Use plain var
class MyViewModel: ObservableObject  // ❌ Use @Observable
```

---

## Complete iOS 26 Pattern Guide

### 1. ViewModel Pattern (@Observable)

#### Template
```swift
import SwiftUI
import Foundation
import Observation

@Observable
@MainActor
final class FeatureViewModel {
    // MARK: - State Properties (NO @Published)
    var items: [Item] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Dependencies
    private let service: ServiceProtocol
    private let repository: RepositoryProtocol

    // MARK: - Initialization
    init(service: ServiceProtocol = Service.shared,
         repository: RepositoryProtocol = Repository.shared) {
        self.service = service
        self.repository = repository
    }

    // MARK: - Public Methods
    func loadData() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            items = try await repository.fetchItems()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

#### Key Points
1. **`@Observable` macro** - iOS 26's observation system
2. **`@MainActor`** - All UI updates on main thread
3. **`final class`** - Performance optimization, prevents subclassing
4. **NO `@Published`** - Use plain `var` properties
5. **Protocol-based DI** - For testability
6. **Async methods** - Modern concurrency with async/await

---

### 2. View Pattern (@State + @Observable)

#### Template
```swift
import SwiftUI

struct FeatureView: View {
    // MARK: - View Model
    @State var viewModel: FeatureViewModel  // NOT @StateObject!

    // MARK: - Environment
    @Environment(AppState.self) var appState  // NOT @EnvironmentObject!

    // MARK: - Local State
    @State private var showingSheet = false

    // MARK: - Body
    var body: some View {
        NavigationView {
            content
                .navigationTitle("Feature")
        }
        .task {
            await viewModel.loadData()
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
        } else if let error = viewModel.errorMessage {
            ErrorView(message: error) {
                Task {
                    await viewModel.loadData()
                }
            }
        } else {
            list
        }
    }

    private var list: some View {
        List(viewModel.items) { item in
            Text(item.name)
        }
    }
}
```

#### Key Points
1. **`@State var viewModel`** - NOT `@StateObject`
2. **`@Environment(Type.self)`** - NOT `@EnvironmentObject`
3. **SwiftUI automatically observes** `@Observable` properties
4. **`.task {}`** - Lifecycle-aware async work
5. **ViewBuilder pattern** - Clean view composition

---

### 3. Sub-View Pattern (Plain var)

When passing ViewModels to sub-views, use **plain `var`** (NO property wrapper):

```swift
struct ParentView: View {
    @State var viewModel: ParentViewModel  // Parent owns ViewModel

    var body: some View {
        SubView(viewModel: viewModel)  // Pass to child
    }
}

struct SubView: View {
    var viewModel: ParentViewModel  // Plain var, NO wrapper!

    var body: some View {
        Text(viewModel.property)  // Auto-observed
    }
}
```

#### Why?
- Parent owns the ViewModel with `@State`
- Child just accesses it (no ownership)
- SwiftUI automatically observes changes
- Using `@ObservedObject` or `@StateObject` here is WRONG

---

### 4. Environment Injection Pattern

#### App Level (Injection)
```swift
@main
struct MyApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)  // NOT .environmentObject!
        }
    }
}
```

#### View Level (Access)
```swift
struct MyView: View {
    @Environment(AppState.self) var appState  // NOT @EnvironmentObject

    var body: some View {
        Text(appState.user.name)
    }
}
```

#### Key Differences from Legacy Pattern

| iOS 26 (@Observable) | Legacy (ObservableObject) |
|---------------------|---------------------------|
| `.environment(appState)` | `.environmentObject(appState)` |
| `@Environment(AppState.self)` | `@EnvironmentObject var appState` |
| `@State var viewModel` | `@StateObject var viewModel` |
| Plain `var` in sub-views | `@ObservedObject` in sub-views |

---

### 5. Actor Pattern (Services)

All services and repositories should be **actors** for thread safety:

```swift
protocol ServiceProtocol {
    func fetchData() async throws -> [Item]
}

actor MyService: ServiceProtocol {
    static let shared = MyService()

    // MARK: - Private State (thread-safe)
    private var cache: [String: Item] = [:]
    private let apiClient: APIClient

    // MARK: - Initialization
    private init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - Public Methods (async)
    func fetchData() async throws -> [Item] {
        // Actor-isolated, thread-safe
        if let cached = getCachedData() {
            return cached
        }

        let data = try await apiClient.request(.getData)
        updateCache(data)
        return data
    }

    // MARK: - Private Methods
    private func getCachedData() -> [Item]? {
        // Thread-safe access
        cache.isEmpty ? nil : Array(cache.values)
    }

    private func updateCache(_ items: [Item]) {
        items.forEach { cache[$0.id] = $0 }
    }
}
```

#### Key Points
1. **`actor` keyword** - Thread-safe by default
2. **`.shared` singleton** - Accessed via `await Service.shared.method()`
3. **All methods are `async`** - Actor isolation requirement
4. **No data races possible** - Swift compiler enforces safety
5. **ViewModel accesses via `await`** - Cross-actor calls

---

### 6. Safety Patterns

#### ❌ Force Unwrap (NEVER)
```swift
// WRONG
let url = URL(string: "https://example.com")!
let user = appState.currentUser!
let first = array.first!
```

#### ✅ Safe Unwrap (ALWAYS)
```swift
// RIGHT
guard let url = URL(string: "https://example.com") else {
    errorMessage = "Invalid URL"
    return
}

if let user = appState.currentUser {
    // Use user safely
}

guard let first = array.first else { return }
```

#### ❌ Array Subscript (UNSAFE)
```swift
// WRONG - Crashes if index out of bounds
let item = array[index]
```

#### ✅ Safe Array Access (SAFE)
```swift
// RIGHT
guard index >= 0 && index < array.count else { return }
let item = array[index]

// OR use optional pattern
guard let item = array.indices.contains(index) ? array[index] : nil else {
    return
}
```

#### ❌ Force Cast (NEVER)
```swift
// WRONG
let view = obj as! UIView
```

#### ✅ Safe Cast (ALWAYS)
```swift
// RIGHT
guard let view = obj as? UIView else { return }
```

---

### 7. Common Pitfalls & Solutions

#### Pitfall 1: Mixing Property Wrappers
```swift
// ❌ WRONG - Crashes at runtime
@Observable
@MainActor
final class MyViewModel {
    @Published var data: [Item] = []  // Don't mix @Published with @Observable!
}

// ✅ RIGHT
@Observable
@MainActor
final class MyViewModel {
    var data: [Item] = []  // Plain var property
}
```

#### Pitfall 2: Wrong View Property Wrapper
```swift
// ❌ WRONG - Runtime issues
struct MyView: View {
    @StateObject var viewModel: MyViewModel  // Old pattern!

// ✅ RIGHT
struct MyView: View {
    @State var viewModel: MyViewModel  // iOS 26 pattern
```

#### Pitfall 3: Sub-View Property Wrapper
```swift
// ❌ WRONG
struct SubView: View {
    @ObservedObject var viewModel: MyViewModel  // Unnecessary!

// ✅ RIGHT
struct SubView: View {
    var viewModel: MyViewModel  // Plain var, auto-observed
```

#### Pitfall 4: Environment Pattern
```swift
// ❌ WRONG
@main
struct MyApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)  // Old pattern!
        }
    }
}

struct MyView: View {
    @EnvironmentObject var appState: AppState  // Old pattern!
}

// ✅ RIGHT
@main
struct MyApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)  // New pattern
        }
    }
}

struct MyView: View {
    @Environment(AppState.self) var appState  // New pattern
}
```

---

## Migration Checklist

### Converting ObservableObject → @Observable

- [ ] Remove `import Combine`
- [ ] Add `import Observation`
- [ ] Replace `class X: ObservableObject` → `@Observable @MainActor final class X`
- [ ] Remove all `@Published` (use plain `var`)
- [ ] Update Views: `@StateObject` → `@State`
- [ ] Update Sub-Views: `@ObservedObject` → plain `var`
- [ ] Update Environment: `@EnvironmentObject` → `@Environment(Type.self)`
- [ ] Update App: `.environmentObject()` → `.environment()`

---

## Testing Patterns

### Testing @Observable ViewModels
```swift
@MainActor
class MyViewModelTests: XCTestCase {
    var sut: MyViewModel!
    var mockService: MockService!

    override func setUp() {
        super.setUp()
        mockService = MockService()
        sut = MyViewModel(service: mockService)
    }

    func testLoadData_Success_PopulatesItems() async {
        // Given
        let expected = [Item(id: "1", name: "Test")]
        mockService.itemsToReturn = expected

        // When
        await sut.loadData()

        // Then
        XCTAssertEqual(sut.items, expected)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }
}
```

---

## Performance Considerations

### @Observable Benefits
1. **Automatic tracking** - Only observes accessed properties
2. **No Combine overhead** - Direct SwiftUI integration
3. **Better memory** - No published subjects
4. **Faster updates** - Optimized observation

### Best Practices
- Use `final class` (5-10% performance gain)
- Mark ViewModels `@MainActor` (thread safety)
- Avoid heavy computation in `var` (use `func` instead)
- Cache expensive computations

---

## Quick Decision Tree

**Creating a ViewModel?**
→ Use `@Observable @MainActor final class`

**Using ViewModel in View?**
→ Parent: `@State var viewModel`
→ Child: Plain `var viewModel`

**Global State?**
→ App: `.environment(state)`
→ View: `@Environment(Type.self) var state`

**Service/Repository?**
→ Use `actor` with `.shared` singleton

**Unwrapping Optional?**
→ Use `guard let` or `if let` (NEVER force unwrap `!`)

---

## Resources

- Apple Docs: https://developer.apple.com/documentation/observation
- WWDC 2024: "What's new in SwiftUI"
- ARCHITECTURE.md: Lines 85-114 (Pattern decisions)
- RETROSPECTIVE.md: Common mistakes to avoid

---

## Validation Script

Run this to check iOS 26 pattern compliance:

```bash
./scripts/check-ios26-patterns.sh

# Checks:
# ✅ All ViewModels use @Observable
# ✅ No @StateObject with ViewModels
# ✅ No @EnvironmentObject
# ✅ No @Published in @Observable classes
# ✅ No force unwraps in production code
```

---

**Last Updated:** 2025-10-13
**Status:** Production-Ready
**Compliance:** 100% iOS 26 Patterns
