# Xcode Project Setup Guide

This guide walks through creating the Xcode project and integrating all Swift files.

## Prerequisites

- Xcode 15.0+ (for iOS 26.0+ support)
- macOS Sonoma or later
- Apple Developer account (for device testing and App Store submission)

## Step 1: Create New Xcode Project

1. Open Xcode
2. File → New → Project
3. Select **iOS → App**
4. Configure project:
   - **Product Name:** FareLens
   - **Team:** Select your Apple Developer team
   - **Organization Identifier:** com.farelens
   - **Bundle Identifier:** com.farelens.app
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Storage:** None (we're using custom persistence)
   - **Include Tests:** Yes
5. Save to: `/Users/Parvez/Desktop/FareLensApp/ios-app/`

## Step 2: Project Structure

Organize files in Xcode to match this structure:

```
FareLens/
├── App/
│   ├── FareLensApp.swift
│   ├── AppState.swift
│   ├── ContentView.swift
│   └── MainTabView.swift
├── Features/
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   └── OnboardingViewModel.swift
│   ├── Deals/
│   │   ├── DealsView.swift
│   │   ├── DealsViewModel.swift
│   │   └── DealDetailView.swift
│   ├── Watchlists/
│   │   ├── WatchlistsView.swift
│   │   ├── CreateWatchlistView.swift
│   │   └── WatchlistsViewModel.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── AlertPreferencesView.swift
│   │   ├── PreferredAirportsView.swift
│   │   ├── NotificationSettingsView.swift
│   │   └── SettingsViewModel.swift
│   ├── Alerts/
│   │   ├── AlertsView.swift
│   │   └── AlertsViewModel.swift
│   └── Subscription/
│       └── PaywallView.swift
├── Core/
│   ├── Models/
│   │   ├── User.swift
│   │   ├── FlightDeal.swift
│   │   ├── Watchlist.swift
│   │   ├── AlertPreferences.swift
│   │   └── PreferredAirport.swift
│   └── Services/
│       ├── AlertService.swift
│       ├── SmartQueueService.swift
│       ├── NotificationService.swift
│       └── SubscriptionService.swift
├── Data/
│   ├── Repositories/
│   │   ├── DealsRepository.swift
│   │   └── WatchlistsRepository.swift
│   ├── Network/
│   │   └── APIClient.swift
│   └── Persistence/
│       └── PersistenceService.swift
├── DesignSystem/
│   ├── Theme/
│   │   ├── Colors.swift
│   │   ├── Typography.swift
│   │   └── Spacing.swift
│   └── Components/
│       ├── FLButton.swift
│       ├── FLCard.swift
│       ├── FLBadge.swift
│       ├── FLCompactButton.swift
│       ├── FLIconButton.swift
│       └── InfoBox.swift
├── Resources/
│   ├── Assets.xcassets
│   ├── Info.plist
│   └── FareLens.entitlements
└── Preview Content/
    └── Preview Assets.xcassets
```

## Step 3: Add Files to Xcode

**Option A: Drag and Drop (Recommended)**

1. In Finder, navigate to `ios-app/FareLens/`
2. Drag each folder (App, Features, Core, Data, DesignSystem) into Xcode
3. In the dialog:
   - ✅ Copy items if needed
   - ✅ Create groups
   - ✅ Add to target: FareLens
   - Click **Finish**

**Option B: Manual Import**

1. Right-click on FareLens folder in Xcode
2. **Add Files to "FareLens"...**
3. Select all `.swift` files
4. Ensure "Add to targets: FareLens" is checked

## Step 4: Configure Info.plist

Add these keys to `Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Required for notifications -->
    <key>UIBackgroundModes</key>
    <array>
        <string>fetch</string>
        <string>remote-notification</string>
    </array>

    <!-- Privacy descriptions -->
    <key>NSUserTrackingUsageDescription</key>
    <string>We use this to provide personalized flight deal alerts based on your preferences.</string>

    <key>NSLocationWhenInUseUsageDescription</key>
    <string>We use your location to find deals from nearby airports.</string>

    <!-- Dark/Light mode support -->
    <key>UIUserInterfaceStyle</key>
    <string>Automatic</string>

    <!-- Launch screen -->
    <key>UILaunchScreen</key>
    <dict>
        <key>UIImageName</key>
        <string>LaunchIcon</string>
        <key>UIColorName</key>
        <string>brandBlue</string>
    </dict>
</dict>
</plist>
```

## Step 5: Create Entitlements File

Create `FareLens.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Push Notifications -->
    <key>aps-environment</key>
    <string>development</string>

    <!-- In-App Purchase -->
    <key>com.apple.developer.in-app-payments</key>
    <array/>

    <!-- App Groups (for share extension in future) -->
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.farelens.app</string>
    </array>
</dict>
</plist>
```

## Step 6: Configure Build Settings

### General Tab

- **Display Name:** FareLens
- **Bundle Identifier:** com.farelens.app
- **Version:** 1.0.0
- **Build:** 1
- **Minimum Deployments:** iOS 26.0

### Signing & Capabilities

1. **Automatic signing:** Enable
2. **Team:** Select your Apple Developer team
3. Add capabilities:
   - ✅ Push Notifications
   - ✅ In-App Purchase
   - ✅ Background Modes (Remote notifications, Background fetch)
   - ✅ App Groups: `group.com.farelens.app`

### Build Settings

Search for these settings and configure:

- **Swift Language Version:** Swift 5
- **Enable Strict Concurrency Checking:** Minimal
- **Deployment Target:** iOS 26.0

## Step 7: Configure StoreKit

1. File → New → File → StoreKit Configuration File
2. Name: `Products.storekit`
3. Add products:

**Product 1: Monthly Subscription**
- Type: Auto-Renewable Subscription
- Reference Name: FareLens Pro Monthly
- Product ID: `com.farelens.pro.monthly`
- Price: $4.99 (USD)
- Subscription Duration: 1 Month
- Free Trial: 14 Days
- Family Sharing: No

**Product 2: Annual Subscription**
- Type: Auto-Renewable Subscription
- Reference Name: FareLens Pro Annual
- Product ID: `com.farelens.pro.annual`
- Price: $49.99 (USD)
- Subscription Duration: 1 Year
- Free Trial: 14 Days
- Family Sharing: No

4. In scheme editor: Edit Scheme → Run → Options
   - StoreKit Configuration: Select `Products.storekit`

## Step 8: Add App Icons

1. Open `Assets.xcassets`
2. Select **AppIcon**
3. Add icon images for all required sizes:
   - 1024×1024 (App Store)
   - 180×180 (iPhone App iOS 14+)
   - 120×120 (iPhone App iOS 7-13)
   - 167×167 (iPad Pro)
   - etc.

**Temporary Solution:** Use SF Symbol as placeholder:
- Create a simple blue airplane icon using SF Symbols
- Export at required sizes using Icon Generator tool

## Step 9: Build and Run

### Build for Simulator

```bash
# Clean build
xcodebuild clean \
  -project FareLens.xcodeproj \
  -scheme FareLens

# Build
xcodebuild build \
  -project FareLens.xcodeproj \
  -scheme FareLens \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Run in Xcode

1. Select target device: iPhone 15 Pro simulator
2. Press **Cmd + R** to build and run
3. App should launch and show onboarding flow

## Step 10: Fix Common Build Errors

### Error: "Cannot find type 'User' in scope"

**Solution:** Ensure all model files are added to target membership
1. Select each `.swift` file in Project Navigator
2. File Inspector → Target Membership → Check "FareLens"

### Error: "Module compiled with Swift X cannot be imported by Swift Y"

**Solution:** Clean build folder
1. Product → Clean Build Folder (Shift + Cmd + K)
2. Quit Xcode
3. Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`
4. Reopen Xcode and rebuild

### Error: Missing Design System files

**Solution:** Verify all DesignSystem files are imported
- Colors.swift
- Typography.swift
- Spacing.swift
- All component files

## Step 11: Test on Physical Device

1. Connect iPhone via USB
2. Trust computer on iPhone
3. In Xcode, select your iPhone from device list
4. Press **Cmd + R** to build and run
5. On first launch, go to Settings → General → Device Management
6. Trust your developer certificate

## Step 12: Configure Push Notifications

### Apple Developer Portal

1. Go to [developer.apple.com](https://developer.apple.com)
2. Certificates, Identifiers & Profiles
3. Keys → Create new key
4. Enable: Apple Push Notifications service (APNs)
5. Download `.p8` file
6. Note: Key ID and Team ID

### Backend Setup (Later)

You'll need these for backend APNs integration:
- Key ID
- Team ID
- `.p8` authentication key file
- Bundle ID: `com.farelens.app`

## Step 13: Verify All Features Work

### Checklist

- [ ] App launches successfully
- [ ] Onboarding flow completes (all 3 screens)
- [ ] Sign up creates user
- [ ] Tab bar shows all 4 tabs
- [ ] Deals view displays (empty state OK)
- [ ] Watchlists view displays
- [ ] Create watchlist form works
- [ ] Alerts view displays
- [ ] Settings view displays
- [ ] All settings sub-screens navigate correctly
- [ ] Notification permission request works
- [ ] Paywall displays correctly
- [ ] StoreKit purchase flow initiates (will fail without backend)

## Next Steps

After successful Xcode setup:

1. **Backend Development**
   - Set up Cloudflare Workers
   - Configure Supabase database
   - Implement API endpoints
   - Set up Amadeus API integration

2. **API Integration**
   - Update APIClient.swift with real endpoints
   - Wire up repositories to real backend
   - Test end-to-end data flow

3. **Testing**
   - Write unit tests for ViewModels
   - Write unit tests for Services
   - Add UI tests for critical flows
   - Test on multiple device sizes

4. **App Store Preparation**
   - Create App Store Connect listing
   - Prepare screenshots
   - Write app description
   - Submit for review

## Troubleshooting

### Build fails with "Command SwiftCompile failed"

1. Clean build folder
2. Close Xcode
3. Delete DerivedData
4. Reopen and rebuild

### App crashes on launch

1. Check Console.app for crash logs
2. Look for force unwraps (!) causing nil crashes
3. Verify all dependencies are properly injected

### Simulator shows blank screen

1. Check ContentView routing logic
2. Verify AppState initializes correctly
3. Add breakpoints to debug flow

### Notifications don't work

1. Simulator doesn't support real push notifications
2. Test on physical device
3. Verify entitlements are configured
4. Check notification permission status

## Resources

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [StoreKit Documentation](https://developer.apple.com/documentation/storekit)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
