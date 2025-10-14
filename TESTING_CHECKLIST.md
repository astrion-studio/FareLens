# Testing Checklist - Before iPhone Deployment

## Prerequisites to Test on iPhone

### 1. ⚠️ Xcode Project Setup (CRITICAL - Must Do First)
**Status**: Not Started
**Time**: 30 minutes

**What's Missing**:
- No `.xcodeproj` file exists - you need to create an Xcode project
- All Swift files are created but not linked to a project

**How to Fix**:
1. Open Xcode
2. File → New → Project
3. Choose "iOS App" template
4. Name: FareLens
5. Organization Identifier: `com.farelens` (or your own)
6. Interface: SwiftUI
7. Language: Swift
8. Save to: `/Users/Parvez/Desktop/FareLensApp/ios-app/`
9. **IMPORTANT**: When prompted, do NOT create a git repo (already exists)
10. Drag all existing Swift files into the Xcode project navigator

---

### 2. ⚠️ Info.plist Configuration (REQUIRED)
**Status**: Not Started
**Time**: 10 minutes

**Required Keys**:
```xml
<key>NSUserNotificationsUsageDescription</key>
<string>FareLens needs notifications to alert you about great flight deals.</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>FareLens uses your location to show deals from nearby airports.</string>

<key>CFBundleDisplayName</key>
<string>FareLens</string>

<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

**How to Add**:
1. In Xcode, select `FareLens` target
2. Go to "Info" tab
3. Add custom iOS target properties
4. Or edit `Info.plist` directly in the project

---

### 3. ⚠️ Missing Imports (COMPILATION BLOCKER)
**Status**: Not Started
**Time**: 5 minutes

**Files That Need Fixes**:

#### NotificationService.swift
```swift
import UserNotifications
import Foundation
import OSLog
import UIKit  // ADD THIS - needed for UIApplication
```

#### AppState.swift
```swift
import Foundation
import Combine
import UIKit  // ADD THIS - needed for UIApplication
```

---

### 4. ⚠️ Backend API Configuration (FUNCTIONAL BLOCKER)
**Status**: Not Started
**Time**: 5 minutes

**Current Issue**:
- `APIClient.swift` line 18 has placeholder URL: `"https://api.farelens.com"`
- This endpoint doesn't exist yet

**Options**:
- **Option A (Mock)**: Create a mock endpoint that returns dummy data for testing UI
- **Option B (Backend)**: Deploy backend first (see backend TODO)
- **Option C (Localhost)**: Run backend locally on your Mac and use `http://localhost:8787`

**Recommended**: Option C for initial testing

---

### 5. ⚠️ Supabase Auth Configuration (FUNCTIONAL BLOCKER)
**Status**: Not Started
**Time**: 20 minutes

**Current Issue**:
- `AuthService.swift` is completely mocked (lines 29-79)
- No actual Supabase integration

**What You Need**:
1. Supabase project URL
2. Supabase anon key
3. Install Supabase Swift SDK: `https://github.com/supabase/supabase-swift`

**How to Add**:
```swift
// In Package Dependencies
.package(url: "https://github.com/supabase/supabase-swift", from: "1.0.0")
```

Then update `AuthService.swift` to use real Supabase client.

**Alternative for Testing**: Skip for now, use mock auth (already implemented)

---

### 6. ✅ App Signing & Provisioning (REQUIRED FOR DEVICE)
**Status**: Not Started
**Time**: 15 minutes

**Steps**:
1. In Xcode, select FareLens target
2. Go to "Signing & Capabilities" tab
3. Check "Automatically manage signing"
4. Select your Team (personal or organization)
5. Xcode will create provisioning profile automatically

**If you don't have an Apple Developer account**:
- You can still test on your iPhone using a free Apple ID
- Go to Xcode → Settings → Accounts → Add Apple ID
- Limitations: 7-day app expiry, no push notifications in production

---

### 7. ⚠️ StoreKit Configuration (REQUIRED FOR SUBSCRIPTION)
**Status**: Not Started
**Time**: 10 minutes

**What's Missing**:
- No `.storekit` configuration file for testing subscriptions

**How to Create**:
1. In Xcode: File → New → File
2. Choose "StoreKit Configuration File"
3. Name it `FareLens.storekit`
4. Add In-App Purchase:
   - Type: Auto-Renewable Subscription
   - Product ID: `com.farelens.pro.monthly`
   - Price: $9.99/month
   - Subscription Duration: 1 month
   - Free Trial: 14 days

**In Xcode Scheme**:
1. Edit Scheme → Run → Options
2. StoreKit Configuration: Select `FareLens.storekit`

---

### 8. ⚠️ Push Notification Entitlements (REQUIRED FOR ALERTS)
**Status**: Not Started
**Time**: 5 minutes

**How to Add**:
1. Select FareLens target → Signing & Capabilities
2. Click "+ Capability"
3. Add "Push Notifications"
4. Add "Background Modes"
   - Check "Remote notifications"
   - Check "Background fetch"

---

### 9. ⚠️ Assets & App Icon (OPTIONAL BUT RECOMMENDED)
**Status**: Not Started
**Time**: 10 minutes

**What's Missing**:
- No app icon (will show blank on home screen)
- No Assets.xcassets folder

**How to Add**:
1. Create `Assets.xcassets` folder
2. Add `AppIcon.appiconset` with icon sizes:
   - 40x40, 60x60, 58x58, 87x87, 80x80, 120x120, 180x180
3. Or use a placeholder from SF Symbols for now

---

### 10. ✅ Build & Run
**Status**: Not Started
**Time**: 5 minutes (if no errors)

**Steps**:
1. Connect iPhone via USB
2. Trust computer on iPhone (prompt will appear)
3. In Xcode, select your iPhone from device dropdown
4. Click ▶️ Run (Cmd+R)
5. First time: Settings → General → VPN & Device Management → Trust Developer

---

## Backend Requirements (Separate Checklist)

Before the app can fetch real data, you need to deploy:

### Backend TODO:
- [ ] Deploy Cloudflare Workers for API endpoints
- [ ] Set up Supabase database (users, deals, watchlists tables)
- [ ] Integrate Amadeus API (2K calls/month free tier)
- [ ] Configure APNs for push notifications
- [ ] Set up KV storage for caching

**Estimated Time**: 4-6 hours

**Note**: You can test the app WITHOUT backend by:
1. Using mock data in ViewModels
2. Skipping network calls
3. Testing UI/UX flows only

---

## Testing Priorities

### Phase 1: Basic UI (No Backend)
**Time**: 1 hour
**Goal**: See screens, navigate, test UI

1. ✅ Create Xcode project
2. ✅ Add missing imports
3. ✅ Add Info.plist keys
4. ✅ Build and fix compilation errors
5. ✅ Run on Simulator
6. ✅ Deploy to iPhone

**What You Can Test**:
- Onboarding flow (UI only)
- Tab navigation
- Settings screens
- Subscription paywall (StoreKit Sandbox)

---

### Phase 2: With Mock Backend (Localhost)
**Time**: 2 hours
**Goal**: Test with dummy data

1. ✅ Run backend locally
2. ✅ Update API URL to localhost
3. ✅ Add mock deals data
4. ✅ Test deals fetching
5. ✅ Test watchlist CRUD
6. ✅ Test alert preferences

**What You Can Test**:
- Deals list with real data structure
- Smart queue ranking
- 20-deal algorithm
- Alert delivery (local notifications only)

---

### Phase 3: Full Production (Cloud Backend)
**Time**: 4-6 hours
**Goal**: End-to-end testing

1. ✅ Deploy Cloudflare Workers
2. ✅ Configure Supabase
3. ✅ Set up APNs certificates
4. ✅ Deploy to TestFlight
5. ✅ Test on iPhone with real push notifications

**What You Can Test**:
- Everything (production-ready)
- Real flight deals from Amadeus
- Push notifications
- Subscription payments
- Background refresh

---

## Critical Path (Minimum to Test on iPhone)

**Total Time: ~1.5 hours**

1. Create Xcode project (30 min)
2. Add missing imports (5 min)
3. Add Info.plist (10 min)
4. Configure signing (15 min)
5. Add StoreKit config (10 min)
6. Build and fix errors (15 min)
7. Deploy to iPhone (5 min)

**After this, you'll have**:
- App running on your iPhone
- UI fully functional
- Mock data for testing flows
- StoreKit sandbox for subscription testing

**What Won't Work Yet**:
- Real flight deals (needs backend)
- Push notifications (needs APNs + backend)
- Auth (needs Supabase)
- Watchlist sync (needs backend)

---

## Quick Start (Absolute Minimum)

If you want to see SOMETHING on your iPhone in 30 minutes:

1. Open Xcode → New Project → iOS App
2. Name: FareLens
3. Drag all Swift files into project
4. Add `import UIKit` to files that need it
5. Select your iPhone
6. Click Run

**This will give you**: A working app with UI, but no backend functionality.

---

## Next Steps After iPhone Deployment

Once you have the app on your iPhone:

1. **Test UI flows** - Navigate through all screens
2. **Test StoreKit** - Try subscribing to Pro (sandbox)
3. **Fix any crashes** - Debug on device
4. **Start backend** - Follow backend deployment guide
5. **Integrate APIs** - Connect to real data
6. **Test push notifications** - Set up APNs
7. **TestFlight beta** - Share with friends

---

## Questions?

- **"Can I skip backend?"** - Yes, for UI testing only
- **"Do I need paid developer account?"** - No, free Apple ID works for testing
- **"How long until production?"** - 6-8 hours total (UI done, backend 4-6h)
- **"Can I test subscriptions?"** - Yes, with StoreKit sandbox (no real charges)

---

**Status**: Ready for Xcode project creation
**Blocker**: No .xcodeproj file yet
**Next Step**: Open Xcode and create project
