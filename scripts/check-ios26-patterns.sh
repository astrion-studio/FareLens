#!/bin/bash
# iOS 26 Pattern Validation Script
# Checks for compliance with iOS 26 @Observable patterns

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 Checking iOS 26 pattern compliance..."

# Find all Swift files
SWIFT_FILES=$(find ios-app/FareLens -name "*.swift" -type f)

# Track issues
ISSUES=0

# Check 1: ViewModels should use @Observable
echo -e "\n${YELLOW}Checking ViewModels use @Observable...${NC}"
for file in $SWIFT_FILES; do
    if grep -q "class.*ViewModel" "$file" && ! grep -q "@Observable" "$file"; then
        echo -e "${RED}❌ $file uses ObservableObject instead of @Observable${NC}"
        ISSUES=$((ISSUES + 1))
    fi
done

# Check 2: Views should use @State with ViewModels
echo -e "\n${YELLOW}Checking Views use @State with ViewModels...${NC}"
for file in $SWIFT_FILES; do
    if grep -q "@StateObject.*ViewModel" "$file"; then
        echo -e "${RED}❌ $file uses @StateObject with ViewModel (should use @State)${NC}"
        ISSUES=$((ISSUES + 1))
    fi
done

# Check 3: Services should be actors
echo -e "\n${YELLOW}Checking Services are actors...${NC}"
for file in $SWIFT_FILES; do
    if grep -q "class.*Service" "$file" && ! grep -q "actor.*Service" "$file"; then
        echo -e "${RED}❌ $file uses 'class' for Service (should use 'actor')${NC}"
        ISSUES=$((ISSUES + 1))
    fi
done

# Check 4: No force unwraps in production code
echo -e "\n${YELLOW}Checking for force unwraps...${NC}"
for file in $SWIFT_FILES; do
    if [[ "$file" != *"Tests.swift" ]]; then
        # Look for actual force unwraps (variable! or function()!) but not logical NOT (!variable)
        if grep -q "[a-zA-Z0-9_]!" "$file" || grep -q "()!" "$file"; then
            echo -e "${YELLOW}⚠️  $file contains force unwraps (review manually)${NC}"
        fi
    fi
done

# Check 5: ViewModels should be @MainActor
echo -e "\n${YELLOW}Checking ViewModels have @MainActor...${NC}"
for file in $SWIFT_FILES; do
    if grep -q "class.*ViewModel.*@Observable" "$file" && ! grep -q "@MainActor" "$file"; then
        echo -e "${YELLOW}⚠️  $file ViewModel missing @MainActor${NC}"
    fi
done

# Summary
echo -e "\n${GREEN}========================================${NC}"
if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✅ All iOS 26 patterns valid${NC}"
    exit 0
else
    echo -e "${RED}❌ Found $ISSUES iOS 26 pattern violations${NC}"
    exit 1
fi
