# FareLens iOS Setup Guide

**Complete guide for setting up FareLens on your iPhone from GitHub**

This is your first iOS project setup. This guide assumes NO prior Xcode experience.

---

## Prerequisites

### Required Software

- **macOS Sonoma or later**
- **Xcode 15.0+** (for iOS 17.0+ support with @Observable pattern)
  - Download from Mac App Store: https://apps.apple.com/us/app/xcode/id497799835
  - **Size:** ~15GB download, ~50GB installed
  - **Time:** 1-2 hours download + install

- **Apple Developer Account**
  - Free account: ✅ Device testing (up to 3 devices)
  - Paid ($99/year): App Store submission
  - Sign up: https://developer.apple.com

### Required Hardware

- **iPhone** running iOS 17.0+
  - Check: Settings → General → About → iOS Version
  - Update if needed: Settings → General → Software Update
- **USB-C or Lightning cable** to connect iPhone to Mac

---

## Part 1: Clone Repository from GitHub

### Step 1.1: Install GitHub CLI (if not installed)

```bash
# Check if already installed
which gh

# If not installed:
brew install gh

# Login to GitHub
gh auth login
# Choose: GitHub.com → HTTPS → Yes (authenticate) → Login with web browser
```

### Step 1.2: Clone FareLens Repository

```bash
# Navigate to Projects folder (NOT Desktop!)
cd ~/Projects

# Clone the repository
gh repo clone astrion-studio/FareLens

# Navigate into project
cd FareLens

# Verify files exist
ls -la
# Should see: ios-app/, backend/, docs/, .github/, README.md, etc.
```

**Why ~/Projects instead of Desktop?**
- Professional standard location
- Avoids iCloud sync issues
- Cleaner workspace organization
- Already configured in your git

### Step 1.3: Verify Project Structure

```bash
# Check iOS app files
ls -la ios-app/FareLens/

# Should see:
# - App/
# - Core/
# - Data/
# - DesignSystem/
# - Features/
```

---

## Part 2: Open Project in Xcode

### Step 2.1: Check for Xcode Project File

```bash
# Look for .xcodeproj file
find ios-app -name "*.xcodeproj"
```

**If file exists:** Skip to Step 2.2
**If file DOESN'T exist:** You need to create it (see Part 3)

### Step 2.2: Open in Xcode

**Option A: From Finder**
1. Open Finder
2. Navigate to `~/Projects/FareLens/ios-app/`
3. Double-click `FareLens.xcodeproj`
4. Xcode opens automatically

**Option B: From Terminal**
```bash
cd ~/Projects/FareLens/ios-app
open FareLens.xcodeproj
```

**Option C: From Xcode**
1. Open Xcode
2. File → Open...
3. Navigate to `~/Projects/FareLens/ios-app/`
4. Select `FareLens.xcodeproj`
5. Click **Open**

---

## Part 3: Create Xcode Project (If Needed)

**Only follow this section if `.xcodeproj` doesn't exist yet.**

### Step 3.1: Create New Project

1. Open Xcode
2. File → New → Project (or Cmd+Shift+N)
3. Select **iOS → App**
4. Click **Next**

### Step 3.2: Configure Project Settings

**Important: Use EXACT values below**

| Setting | Value |
|---------|-------|
| **Product Name** | `FareLens` |
| **Team** | Select your Apple Developer team |
| **Organization Identifier** | `com.farelens` |
| **Bundle Identifier** | `com.farelens.app` |
| **Interface** | SwiftUI |
| **Language** | Swift |
| **Storage** | None *(we use custom persistence)* |
| **Include Tests** | ✅ Yes |

### Step 3.3: Save Project Location

**CRITICAL:** Save to existing cloned repository location

```
Location: /Users/Parvez/Projects/FareLens/ios-app/
```

- ⚠️ **Do NOT** let Xcode create a new folder
- ✅ **Do** save directly into `ios-app/` folder
- Uncheck "Create Git repository" (already have one!)

### Step 3.4: Add Existing Swift Files

Xcode created a basic project. Now add our actual code:

1. **Delete default files:**
   - Right-click `ContentView.swift` in Xcode → Delete → **Move to Trash**
   - Right-click `FareLensApp.swift` in Xcode → Delete → **Move to Trash**

2. **Add our folders:**
   - In Finder, navigate to `~/Projects/FareLens/ios-app/FareLens/`
   - Drag these folders into Xcode's `FareLens` group:
     - `App/`
     - `Core/`
     - `Data/`
     - `DesignSystem/`
     - `Features/`

3. **In the import dialog:**
   - ❌ **Copy items if needed** (UNCHECK this - files already in repo!)
   - ✅ **Create groups** (NOT folder references)
   - ✅ **Add to targets: FareLens** (check this)
   - Click **Finish**

**⚠️ IMPORTANT:** Do NOT check "Copy items if needed"! The files already exist in the cloned repository. Copying them would duplicate every file and cause build errors.

### Step 3.5: Verify File Structure in Xcode

Your Project Navigator should look like:

```
FareLens/
├── App/
│   ├── FareLensApp.swift
│   ├── AppState.swift
│   └── MainTabView.swift
├── Features/
│   ├── Onboarding/
│   ├── Deals/
│   ├── Watchlists/
│   ├── Alerts/
│   ├── Settings/
│   └── Subscription/
├── Core/
│   ├── Models/
│   └── Services/
├── Data/
│   ├── Networking/
│   ├── Repositories/
│   └── Persistence/
├── DesignSystem/
│   ├── Theme/
│   └── Components/
├── Assets.xcassets
├── Preview Content/
└── FareLensTests/
```

---

## Part 4: Configure Code Signing

**Required to run on your iPhone**

### Step 4.1: Select Project Settings

1. In Xcode, click **FareLens** (blue icon) at top of Project Navigator
2. Select **FareLens** target (under TARGETS, not PROJECT)
3. Click **Signing & Capabilities** tab

### Step 4.2: Enable Automatic Signing

1. ✅ Check **Automatically manage signing**
2. **Team:** Select your Apple Developer account
   - If no team shows: Click "Add Account..." and sign in
   - Free account works for device testing!

3. **Bundle Identifier:** Should be `com.farelens.app`
   - If conflict: Change to `com.farelens.app.YOURNAME`

### Step 4.3: Leave Capabilities Default (Free Account)

- **Skip adding new capabilities if you're on the free Apple Developer account.**
  - Push Notifications, Background Modes, and In-App Purchase require a paid Apple Developer Program membership and will trigger signing errors on free accounts.
  - We'll enable them later once the paid program is active and the features are implemented.

If you already have a paid Apple Developer Program membership, you can add them now so Xcode matches production signing:

1. **Push Notifications** – Needed for flight deal alerts when we ship them
2. **Background Modes** – Check ✅ Background fetch and ✅ Remote notifications
3. **In-App Purchase** – Needed for the Pro subscription flow

### Step 4.4: Configure Deployment Target

1. Still in **General** tab
2. **Minimum Deployments:** Change to **iOS 17.0**
   - iOS 26.0 doesn't exist yet (Xcode uses iOS 17.0 for latest features)
   - Our code uses iOS 17+ features (@Observable pattern)

---

## Part 5: Build and Fix Errors

### Step 5.1: First Build Attempt

1. Select target: **FareLens** (top left, next to play button)
2. Select device: **Any iOS Device (arm64)**
3. Press **Cmd + B** to build

**Expected:** Build will FAIL with errors. This is normal! We need to fix critical bugs first.

### Step 5.2: View Build Errors

1. Click **⚠️** icon in top toolbar (shows error count)
2. Or press **Cmd + 5** to open Issue Navigator

You should see errors like:
- "Actor 'NotificationService' cannot inherit from NSObject"
- "Cannot find 'normalPrice' in scope"
- "@ObservedObject should be @Bindable"
- etc.

**Do NOT try to fix these manually!** These are tracked issues that will be fixed systematically.

---

## Part 6: Prepare for Testing on iPhone

### Step 6.1: Connect iPhone

1. **Connect iPhone to Mac** via USB cable
2. **Unlock iPhone**
3. **Trust Computer:**
   - iPhone shows: "Trust This Computer?"
   - Tap **Trust**
   - Enter iPhone passcode

### Step 6.2: Select iPhone as Target

1. In Xcode top toolbar, click device selector (says "Any iOS Device")
2. Select your iPhone from list
   - Shows as: "YourName's iPhone"
   - May show iOS version: "iPhone (17.5)"

### Step 6.3: Wait for Device Preparation

First time connecting:
- Xcode shows: "Preparing YourName's iPhone..."
- **Time:** 2-5 minutes
- Copies debug symbols from iPhone to Mac
- **Do not disconnect during this process!**

---

## Part 7: Understanding Current State

### What Works ✅
- Repository cloned from GitHub
- Project opens in Xcode
- Code signing configured
- Device connected

### What Doesn't Work Yet ❌
- **Build fails** - 5 critical bugs to fix
- **Can't run on device** - needs compilation
- **No backend** - APIs not implemented yet

### Critical Bugs to Fix (Before Testing)

These must be fixed before the app compiles:

1. **NotificationService actor issue**
   - File: `ios-app/FareLens/Core/Services/NotificationService.swift:15`
   - Error: Actors can't inherit from NSObject
   - Impact: Won't compile

2. **Duplicate normalPrice**
   - Files: `FlightDeal.swift:16` & `DealDetailView.swift:455`
   - Error: Duplicate definition
   - Impact: Compilation error

3. **@ObservedObject with @Observable**
   - Files: `AlertPreferencesView.swift`, `CreateWatchlistView.swift`, etc.
   - Error: Wrong property wrapper
   - Impact: UI won't update

4. **DealsRepository filter bug**
   - File: `DealsRepository.swift:45`
   - Error: Origin filter not applied
   - Impact: Wrong deals shown

5. **Onboarding auth flow**
   - File: `OnboardingViewModel.swift:25`
   - Error: AppState not notified
   - Impact: Stuck on onboarding

---

## Part 8: Testing After Bugs Fixed

**Once critical bugs are fixed, you can test:**

### Step 8.1: Build for Device

1. Make sure iPhone is selected (not simulator)
2. Press **Cmd + B** to build
3. Build should succeed ✅

### Step 8.2: Run on Device

1. Press **Cmd + R** (or click ▶️ Play button)
2. Xcode installs app on iPhone
3. **First time only:** iPhone shows "Untrusted Developer"

### Step 8.3: Trust Developer Certificate

**On iPhone:**
1. Settings → General → VPN & Device Management
2. Under "Developer App", tap your Apple ID
3. Tap **Trust "[Your Name]"**
4. Tap **Trust** in confirmation dialog

### Step 8.4: Launch App

1. Return to Xcode
2. Press **Cmd + R** again
3. App launches on iPhone! 🎉

---

## Part 9: What to Test

### Onboarding Flow
- [ ] Welcome screen appears
- [ ] Can swipe through 3 onboarding screens
- [ ] "Get Started" button works
- [ ] Sign up form accepts input
- [ ] Terms & Privacy links work (even if blank)

### Main App
- [ ] Tab bar shows 4 tabs (Deals, Watchlists, Alerts, Settings)
- [ ] Can switch between tabs
- [ ] Each screen loads without crashing

### Expected Issues
- ⚠️ **No real data** - Backend not built yet, will show empty states
- ⚠️ **Some features incomplete** - TODOs in DealDetailView, AlertsView
- ⚠️ **Authentication doesn't persist** - Need to sign in every launch

**This is NORMAL for current development stage.**

---

## Part 10: Keeping Code Updated

### Pull Latest Changes from GitHub

```bash
# Navigate to project
cd ~/Projects/FareLens

# Check current status
git status

# Pull latest changes
git pull origin main

# If Xcode is open: File → Close Project
# Then reopen: open ios-app/FareLens.xcodeproj
```

### After Pulling Changes

1. Clean build: **Cmd + Shift + K**
2. Build: **Cmd + B**
3. Run: **Cmd + R**

---

## Part 11: Common Issues & Solutions

### Error: "Developer Mode Required"

**On iOS 16+ devices:**

1. iPhone → Settings → Privacy & Security
2. Scroll down to **Developer Mode**
3. Toggle **ON**
4. iPhone will restart
5. Unlock and allow Developer Mode

### Error: "Could not launch app"

**Solution 1: Clean and rebuild**
```bash
# In terminal
cd ~/Projects/FareLens/ios-app
rm -rf ~/Library/Developer/Xcode/DerivedData/FareLens-*
```

**Solution 2: In Xcode**
1. Product → Clean Build Folder (Cmd + Shift + K)
2. Restart Xcode
3. Build again (Cmd + B)

### Error: "Provisioning profile doesn't include signing certificate"

1. Xcode → Settings → Accounts
2. Select your Apple ID
3. Click **Download Manual Profiles**
4. Try building again

### Error: "iPhone is locked"

1. Unlock your iPhone
2. Keep iPhone unlocked during build/install
3. App only needs unlock during install, not while debugging

### Error: Build succeeds but app crashes immediately

1. Open Console.app (Mac application)
2. Select your iPhone in sidebar
3. Filter: "FareLens"
4. Look for crash log showing error
5. Report to Claude Code with exact error

### App builds but screen is blank

1. In Xcode debugger (bottom panel):
   - Look for errors in console
   - Check if ContentView is being created
2. Add breakpoint in `FareLensApp.swift` body
3. Run again and check execution flow

---

## Part 12: Development Workflow

### Daily Workflow

```bash
# 1. Pull latest code
cd ~/Projects/FareLens
git pull origin main

# 2. Open in Xcode
open ios-app/FareLens.xcodeproj

# 3. Build and run
# Cmd + B (build)
# Cmd + R (run)

# 4. Make changes (if needed)
# Edit files in Xcode

# 5. Test on device
# Cmd + R
```

### When You Make Changes

```bash
# Create feature branch
git checkout -b fix/my-bug-fix

# Add files
git add .

# Commit
git commit -m "fix: Description of your fix"

# Push to feature branch
git push -u origin fix/my-bug-fix

# Create pull request (main branch is protected!)
gh pr create --title "fix: Description of your fix" --fill

# Enable auto-merge after Codex review
gh pr merge --auto --squash
```

**Note:** The `main` branch is protected - you cannot push directly to it. Always use feature branches and pull requests as described in [WORKFLOW.md](WORKFLOW.md).

---

## Part 13: Next Steps After Setup

### Immediate (Critical Bugs Fixed)
1. ✅ Test core navigation (tabs, screens)
2. ✅ Test onboarding flow
3. ✅ Verify UI looks correct

### Short Term (Backend Integration)
4. Backend API implementation
5. Wire up real data flows
6. Test end-to-end functionality

### Before Launch
7. Add app icon
8. Create screenshots
9. Write App Store description
10. TestFlight beta testing

---

## Part 14: Getting Help

### Build Errors

1. Copy **exact error message**
2. Note **file name and line number**
3. Provide to Claude Code: "Xcode error in [file]:[line]: [error message]"

### Runtime Crashes

1. Open Console.app
2. Find crash log for FareLens
3. Copy **full stack trace**
4. Provide to Claude Code

### Feature Not Working

1. Describe **what you expected**
2. Describe **what actually happened**
3. Note **which screen** you're on
4. Include **screenshot** if possible

---

## Resources

### Apple Documentation
- **Xcode Help:** Help → Xcode Help (in Xcode menu)
- **SwiftUI Tutorials:** https://developer.apple.com/tutorials/swiftui
- **Developer Forums:** https://developer.apple.com/forums/

### FareLens Documentation
- **[WORKFLOW.md](WORKFLOW.md)** - Development workflow
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - App architecture
- **[API.md](API.md)** - Backend API contracts
- **[DESIGN.md](DESIGN.md)** - UI/UX guidelines

### Tools
- **Xcode:** Apple's IDE for iOS development
- **Simulator:** Test iOS apps without device (slower than real device)
- **Instruments:** Profiling and debugging tool
- **Console.app:** View device logs and crashes

---

## Appendix: Xcode Keyboard Shortcuts

### Essential Shortcuts

| Action | Shortcut |
|--------|----------|
| **Build** | Cmd + B |
| **Run** | Cmd + R |
| **Stop** | Cmd + . |
| **Clean Build** | Cmd + Shift + K |
| **Open Quickly** | Cmd + Shift + O |
| **Jump to Definition** | Cmd + Click |
| **Show/Hide Debug Area** | Cmd + Shift + Y |
| **Show/Hide Navigator** | Cmd + 0 |
| **Issue Navigator** | Cmd + 5 |

### Navigation

| Action | Shortcut |
|--------|----------|
| **Next Issue** | Cmd + ' |
| **Previous Issue** | Cmd + " |
| **Jump to Line** | Cmd + L |
| **Open File** | Cmd + Shift + O |

### Debugging

| Action | Shortcut |
|--------|----------|
| **Toggle Breakpoint** | Cmd + \ |
| **Step Over** | F6 |
| **Step Into** | F7 |
| **Continue** | Cmd + Ctrl + Y |

---

**You're ready to test FareLens on your iPhone once critical bugs are fixed!** 🚀
