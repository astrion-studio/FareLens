#!/bin/bash
# Validates iOS 26 @Observable pattern compliance

set -e

echo "🔍 Checking iOS 26 pattern compliance..."

ERRORS=0

# Check for legacy ObservableObject
echo "  Checking for ObservableObject (legacy)..."
if grep -r "ObservableObject" ios-app/FareLens --include="*.swift" 2>/dev/null; then
    echo "  ❌ ERROR: Found ObservableObject (legacy pattern)"
    echo "     Fix: Use @Observable instead (iOS 26+)"
    ERRORS=$((ERRORS + 1))
fi

# Check for @StateObject with @Observable
echo "  Checking for @StateObject misuse..."
if grep -r "@StateObject" ios-app/FareLens --include="*.swift" 2>/dev/null | grep -v "//" | grep -q "@Observable"; then
    echo "  ❌ ERROR: Found @StateObject with @Observable"
    echo "     Fix: Use @State with @Observable classes"
    ERRORS=$((ERRORS + 1))
fi

# Check for @Published in @Observable classes
echo "  Checking for @Published in @Observable..."
OBSERVABLE_FILES=$(grep -rl "@Observable" ios-app/FareLens --include="*.swift" 2>/dev/null || true)
for file in $OBSERVABLE_FILES; do
    if grep -q "@Published" "$file" 2>/dev/null; then
        echo "  ❌ ERROR: Found @Published in @Observable class: $file"
        echo "     Fix: @Observable classes use plain var properties"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check for force unwraps in production code (warning only)
echo "  Checking for force unwraps (!)..."
FORCE_UNWRAPS=$(grep -r "!" ios-app/FareLens --include="*.swift" --exclude="*Tests.swift" 2>/dev/null | grep -v "//" | grep -v "import " | wc -l | tr -d ' ')
if [ "$FORCE_UNWRAPS" -gt 0 ]; then
    echo "  ⚠️  WARNING: Found $FORCE_UNWRAPS potential force unwraps (!) in production code"
    echo "     Consider using optional binding or nil coalescing"
fi

# Check for @EnvironmentObject (legacy)
echo "  Checking for @EnvironmentObject (legacy)..."
if grep -r "@EnvironmentObject" ios-app/FareLens --include="*.swift" 2>/dev/null | grep -v "//"; then
    echo "  ⚠️  WARNING: Found @EnvironmentObject (legacy pattern)"
    echo "     Consider using @Environment with @Observable"
fi

if [ $ERRORS -eq 0 ]; then
    echo "✅ All iOS 26 patterns valid"
    exit 0
else
    echo "❌ Found $ERRORS pattern violation(s)"
    exit 1
fi
