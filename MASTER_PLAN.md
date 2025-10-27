# FareLens - Master Plan to Production

**Last Updated:** 2025-10-26
**Status:** CRITICAL ISSUES IDENTIFIED - REQUIRES IMMEDIATE ACTION
**Production Target:** 8-12 weeks

---

## EXECUTIVE SUMMARY

### Current State (Brutal Honesty)
- **iOS App:** 80% complete but has critical UX issues (stubs, broken navigation)
- **Backend:** 8% production-ready - security vulnerabilities, no auth, mock implementations
- **Testing:** 15% coverage - CI completely broken
- **Documentation:** 22 files, 18K+ lines, contradictory information

### Critical Blockers (Must Fix Before ANY Deployment)
1. **P0:** Backend has NO authentication - anyone can access/delete any user's data
2. **P0:** CI is broken - cannot run tests, cannot validate PRs
3. **P0:** iOS has stub implementations - Deals tab, Alerts tab, Detail views mostly non-functional
4. **P0:** 22 documentation files are unmanageable - contradictory, outdated, forgotten TODOs

### What We Need to Do
**Recommended: 8-12 week structured plan to production-ready MVP**

Alternative: Ship broken app now → 1-star reviews → death spiral

---

## ISSUE INVENTORY (All Problems Identified)

### Codex-Identified Issues (10 fixed by Codex)
1. ✅ Backend CORS configuration (fixed)
2. ✅ /health endpoint misreporting (fixed)
3. ✅ Paywall view model @Observable (fixed)
4. ✅ Deprecated NavigationView (fixed)
5. ✅ Deals tab interactions stubs (fixed)
6. ✅ Deal detail persistence missing (fixed)
7. ✅ Deal metadata placeholders (fixed)
8. ✅ Alerts tab empty (fixed)
9. ✅ Watchlists can't be edited (fixed)
10. ✅ Notification badges hardcoded (fixed)

### iOS Architect Issues (Critical - Not Fixed)
11. ❌ **P0:** Xcode project file missing/broken (CI blocker)
12. ❌ **P0:** DealDetailView has 4 TODOs (booking URL, city mapping, baggage)
13. ❌ **A1:** WatchlistsViewModel mutable struct pattern
14. ❌ **A2:** No custom error types (using generic errors)
15. ❌ **A4:** No navigation coordinator (deep linking will be hard)

### Backend Architect Issues (CRITICAL SECURITY)
16. ❌ **P0:** NO authentication implemented - anyone can access any data
17. ❌ **P0:** trial_ends_at datetime bug crashes all signups
18. ❌ **P0:** Database schema field mismatch (clicked_through vs was_clicked)
19. ❌ **P0:** Mass-delete operations wipe ALL users' data
20. ❌ **P0:** Zero database migrations - tables don't exist
21. ❌ **P0:** CORS allows ANY origin with credentials (CSRF vulnerability)
22. ❌ **P0:** Connection pool leaks on shutdown
23. ❌ **P0:** Pagination unbounded (DOS vulnerability)
24. ❌ **P0:** Wrong HTTP method for background-refresh (GET instead of POST)
25. ❌ **P0:** No IATA code validation (SQL injection risk)
26. ❌ **P1:** No .env file or .gitignore (secrets at risk)
27. ❌ **P1:** Missing JWT secret configuration
28. ❌ **P1:** Health check always returns "healthy"
29. ❌ **P1:** No subscription tier enforcement (free users get Pro features)
30. ❌ **P1:** Missing timezones in date fields
31. ❌ **P1:** No rate limiting
32. ❌ **P1:** No logging/monitoring

### QA Specialist Issues (Testing Gaps)
33. ❌ **P0:** CI completely broken - Xcode project missing
34. ❌ **P0:** GitHub Actions uses beta macos-26 runner (unstable)
35. ❌ **P0:** Test coverage only 15-20% (target: 80%)
36. ❌ **P0:** Zero ViewModel tests (6 ViewModels untested)
37. ❌ **P1:** Zero AuthService tests
38. ❌ **P1:** Zero NotificationService tests
39. ❌ **P1:** Zero SubscriptionService tests
40. ❌ **P1:** Zero integration tests
41. ❌ **P1:** Zero UI tests

### Documentation Issues (Organizational Chaos)
42. ❌ **P1:** 22 markdown files (18K+ lines) - unmanageable
43. ❌ **P1:** Contradictory information across files
44. ❌ **P1:** Multiple "TODO" files with different tasks
45. ❌ **P1:** No single source of truth for project status
46. ❌ **P2:** Forgotten open tasks in old documentation

### User-Identified Issues (Critical User Experience)
47. ❌ **P0:** Cannot set up app on iPhone (no clear guide)
48. ❌ **P0:** Cannot set up backend (no clear step-by-step)
49. ❌ **P0:** iPhone testing should be iPhone 16 Pro (not iPhone 17 which doesn't exist)
50. ❌ **P1:** Architecture strategy unclear after many files created

**TOTAL ISSUES: 50 (10 fixed, 40 remaining)**

---

## PRIORITIZED FIX PLAN

### PHASE 1: STOP THE BLEEDING (Week 1) - CRITICAL

**Goal:** Make the project manageable and testable

#### 1.1 Documentation Consolidation (2 days)
- **Action:** Consolidate 22 files → 6 essential files
- **Delete:** SETUP_STATUS.md, GOLDEN_STANDARD_TODO.md, LESSONS_LEARNED.md, TESTING_CHECKLIST.md, SESSION_LOG.md, CONTRIBUTING.md, CHANGELOG.md
- **Keep & Update:** README.md, MASTER_PLAN.md (this file), ARCHITECTURE.md, PRD.md, QUICK_START.md (new)
- **Archive:** Move RETROSPECTIVE.md, WORKFLOW.md, TOOLING_SETUP.md to /docs/archive/
- **Result:** Single source of truth = MASTER_PLAN.md

#### 1.2 Fix CI/CD (2 days)
- **Action:** Recreate Xcode project from 48 Swift files
- **Action:** Change GitHub Actions from macos-26 → macos-15 (stable)
- **Action:** Update device: iPhone 15 Pro → iPhone 16 Pro
- **Result:** CI passes, can run tests
- **GitHub Issues:** #70, #73

#### 1.3 Create Simple Setup Guides (1 day)
- **Action:** Create QUICK_START.md with:
  - iPhone setup (5 clear steps)
  - Backend setup (Supabase approach - 1-2 weeks faster than FastAPI)
- **Result:** User can test app on phone, start backend

**Week 1 Deliverables:**
- ✅ 6 documentation files (down from 22)
- ✅ CI passing (green checkmarks)
- ✅ Clear setup instructions
- **Estimated effort:** 5 days

---

### PHASE 2: MAKE IT FUNCTIONAL (Weeks 2-4) - HIGH PRIORITY

**Goal:** iOS app works end-to-end with basic backend

#### 2.1 Fix iOS Critical TODOs (Week 2)
- Fix DealDetailView: booking URL, city mapping, baggage info
- Implement price history in DealDetailViewModel
- Add proper error types (not generic errors)
- **Result:** iOS app has no broken features
- **GitHub Issues:** Create detailed issue for each

#### 2.2 Implement Backend MVP - Supabase Approach (Weeks 2-3)
**Why Supabase instead of fixing FastAPI:**
- Supabase Auth = built-in, zero code (fixes issues #16, #17, #26, #27)
- Row-Level Security = built-in authorization (fixes #19, #29)
- Supabase Edge Functions = serverless (fixes #20, #22, #24)
- Free tier matches Cloudflare ($0 until 50K users)
- **Production in 1-2 weeks vs 5 weeks for FastAPI**

**Supabase Implementation:**
1. Database schema (2 days)
   - Create tables matching API.md
   - Set up Row-Level Security policies
   - Fixes issues #20, #19, #29

2. Authentication (2 days)
   - Enable Supabase Auth
   - iOS integration with supabase-swift SDK
   - Fixes issues #16, #17, #26, #27

3. Edge Functions (5 days)
   - Deals endpoint
   - Watchlists CRUD
   - Alerts history
   - Background refresh (Supabase Cron)
   - Fixes issues #18, #21, #23, #24, #25, #30, #31, #32

4. Push notifications (3 days)
   - APNs integration
   - Alert delivery logic

**Result:** Secure, functional backend

#### 2.3 iOS-Backend Integration (Week 4)
- Update APIClient to use Supabase endpoints
- Test all flows end-to-end
- **Result:** App works with real data

**Weeks 2-4 Deliverables:**
- ✅ iOS app fully functional (no stubs/TODOs)
- ✅ Secure backend with authentication
- ✅ End-to-end integration working
- **Estimated effort:** 15 days

---

### PHASE 3: MAKE IT RELIABLE (Weeks 5-7) - MEDIUM PRIORITY

**Goal:** Production-quality testing

#### 3.1 Critical Unit Tests (Week 5)
- 21 ViewModel tests (issues #36-39)
- AuthService tests
- NotificationService tests
- Target: 50% coverage
- **Result:** Core functionality tested

#### 3.2 Integration & UI Tests (Week 6)
- 4 end-to-end flow tests (issue #40)
- Critical UI tests (issue #41)
- Target: 75% coverage
- **Result:** User flows validated

#### 3.3 Performance & Accessibility (Week 7)
- Launch time: <2.0s target
- Memory: <150MB target
- VoiceOver navigation
- Dynamic Type support
- **Result:** Competitive performance

**Weeks 5-7 Deliverables:**
- ✅ 75-80% test coverage
- ✅ <2.0s launch time
- ✅ Accessibility compliant
- **Estimated effort:** 15 days

---

### PHASE 4: PRODUCTION HARDENING (Weeks 8-10)

**Goal:** Beta testing and polish

#### 4.1 TestFlight Beta (Weeks 8-9)
- Deploy to TestFlight
- 50-100 beta testers
- Fix critical bugs
- **Result:** 99.5%+ crash-free rate

#### 4.2 App Store Preparation (Week 10)
- Screenshots (all device sizes)
- App description
- Privacy policy
- Terms of service
- **Result:** Ready to submit

#### 4.3 Production Backend (Week 10)
- Supabase Production project
- Configure APNs production certificates
- Set up monitoring (Sentry)
- **Result:** Backend deployed

**Weeks 8-10 Deliverables:**
- ✅ Beta tested (50+ users)
- ✅ 99.5%+ crash-free
- ✅ App Store assets ready
- ✅ Backend in production
- **Estimated effort:** 15 days

---

### PHASE 5: LAUNCH (Weeks 11-12)

**Goal:** Public release

#### 5.1 App Store Review (Week 11)
- Submit 1.0
- Respond to App Review
- **Result:** Approved

#### 5.2 Public Launch (Week 12)
- Soft launch (limited availability)
- Monitor metrics
- Fix critical issues
- **Result:** Live in App Store

**Weeks 11-12 Deliverables:**
- ✅ App Store approved
- ✅ Public launch
- **Estimated effort:** 10 days

---

## TIMELINE SUMMARY

| Phase | Duration | Key Deliverable | Risk |
|-------|----------|-----------------|------|
| **1: Stop Bleeding** | Week 1 | CI working, docs clean | Low |
| **2: Make Functional** | Weeks 2-4 | iOS + Backend working | Medium |
| **3: Make Reliable** | Weeks 5-7 | 80% test coverage | Low |
| **4: Production Hardening** | Weeks 8-10 | Beta tested, polished | Medium |
| **5: Launch** | Weeks 11-12 | Live in App Store | High |

**Total Timeline: 8-12 weeks to production**

**Critical Path:**
1. Week 1: Fix CI → Can develop
2. Weeks 2-4: Build backend → Can integrate
3. Weeks 5-7: Test thoroughly → Can beta
4. Weeks 8-10: Beta test → Can submit
5. Weeks 11-12: App Review → Can launch

---

## ALTERNATIVE APPROACHES (COMPARED)

### Option A: Fix FastAPI Backend (Not Recommended)
- **Effort:** 5 weeks backend + 3 weeks integration = 8 weeks
- **Cost:** Higher (server hosting vs serverless)
- **Risk:** High (32 backend issues to fix)
- **When to use:** If you need full control, custom architecture

### Option B: Supabase Backend (RECOMMENDED)
- **Effort:** 2 weeks backend + 1 week integration = 3 weeks
- **Cost:** $0 until 50K users (same as Cloudflare)
- **Risk:** Low (built-in auth, RLS, Edge Functions)
- **When to use:** MVP launch, fast to market

### Option C: Cloudflare Workers (Future Migration)
- **Effort:** 6 weeks from scratch
- **Cost:** $0 until 100K requests/day
- **Risk:** Medium (TypeScript, learning curve)
- **When to use:** After validating product-market fit, need edge performance

**Recommendation:** Start with Option B (Supabase), migrate to Option C (Cloudflare) later if needed

---

## SUCCESS CRITERIA

### Must Have (Cannot Ship Without)
- ✅ 80%+ test coverage
- ✅ Zero P0 bugs
- ✅ Authentication working securely
- ✅ All core flows functional (no stubs)
- ✅ 99%+ crash-free rate in beta
- ✅ <2.0s launch time
- ✅ CI passing

### Should Have (Defer if Needed)
- 90%+ test coverage
- Zero P1 bugs
- Accessibility (VoiceOver, Dynamic Type)
- Analytics integration
- A/B testing framework

### Nice to Have (Post-1.0)
- iPad support
- Apple Watch app
- Widgets
- Siri shortcuts
- Share extension

---

## RISK ASSESSMENT

### High Risk Items
1. **App Store Review Rejection** (30% probability)
   - Mitigation: Follow all guidelines, clear privacy policy, functional demo

2. **Beta Crashes** (50% probability if <80% coverage)
   - Mitigation: Hit 80% test coverage, thorough manual testing

3. **Backend Performance Issues** (20% probability)
   - Mitigation: Load testing, caching strategy, monitor metrics

### Medium Risk Items
4. **Integration Issues** (40% probability)
   - Mitigation: Integration tests, staging environment

5. **Schedule Slip** (60% probability for 12-week target)
   - Mitigation: Weekly checkpoints, cut scope if needed

### Accepted Risks
- Launching without iPad optimization
- Launching without Apple Watch
- Limited test coverage (80% vs 90%)

---

## RESOURCE REQUIREMENTS

### Development Time
- **iOS Development:** 6-8 weeks (1 developer)
- **Backend Development:** 2-3 weeks (1 developer) with Supabase
- **Testing/QA:** 3 weeks (1 QA or shared)
- **Total:** 8-12 weeks (can parallelize iOS + Backend)

### External Dependencies
- **Supabase:** Free tier (50K users, 500MB DB, 2GB bandwidth)
- **Amadeus API:** Free tier (2K calls/month)
- **Apple APNs:** Free (unlimited)
- **Apple Developer Account:** $99/year (required)

### Cost Estimate
- **Development:** 8-12 weeks @ $0 (if you're doing it)
- **Services:** $99/year (Apple Developer)
- **Total MVP Cost:** $99/year

---

## DECISION POINTS

### Week 1 Decision: Backend Approach
**Question:** Supabase vs Fix FastAPI vs Cloudflare Workers?

**Recommendation:** Supabase
- **Pros:** Fastest to production (2 weeks vs 5 weeks)
- **Cons:** Vendor lock-in (but can migrate later)

### Week 4 Decision: Launch Date
**Question:** Ship in 8 weeks (minimal testing) or 12 weeks (thorough testing)?

**Recommendation:** 12 weeks
- **Reason:** 1-star reviews from crashes kill the app permanently
- **Data:** 99.5% crash-free rate requires 75-80% test coverage

### Week 8 Decision: Beta Size
**Question:** Small beta (10 users) or large beta (100 users)?

**Recommendation:** Medium beta (50 users)
- **Reason:** Enough data to find crashes, small enough to manage feedback

---

## COMMUNICATION PLAN

### Weekly Status Updates
- **What:** Email update every Monday
- **Contents:** Progress, blockers, decisions needed
- **Recipients:** Stakeholders

### Milestone Reviews
- **Week 1:** CI fixed, docs consolidated
- **Week 4:** Backend integrated, app functional
- **Week 7:** Testing complete, beta ready
- **Week 10:** Beta complete, launch ready
- **Week 12:** Public launch

---

## ROLLBACK PLAN

### If Things Go Wrong

**Scenario 1: CI Still Broken After Week 1**
- **Action:** Manually test on local Xcode, skip automated CI temporarily
- **Risk:** High (no safety net for merges)

**Scenario 2: Backend Takes >3 Weeks**
- **Action:** Ship iOS with mock data, backend later
- **Risk:** Medium (no real functionality)

**Scenario 3: Test Coverage <50% After Week 7**
- **Action:** Delay beta, add critical tests only
- **Timeline Impact:** +2 weeks

**Scenario 4: App Store Rejection**
- **Action:** Fix issues, resubmit (usually 2-3 days)
- **Timeline Impact:** +1 week

---

## NEXT IMMEDIATE ACTIONS (This Week)

### Monday (Day 1)
1. ✅ Read this MASTER_PLAN.md
2. ✅ Decide on backend approach (Supabase recommended)
3. ✅ Review GitHub issues I'll create

### Tuesday (Day 2)
4. Fix CI: Recreate Xcode project
5. Update GitHub Actions workflow
6. Test: `xcodebuild test -scheme FareLens` passes locally

### Wednesday (Day 3)
7. Consolidate documentation (22 files → 6 files)
8. Create QUICK_START.md

### Thursday (Day 4)
9. Start Supabase backend setup
10. Create database schema

### Friday (Day 5)
11. Review progress
12. Adjust plan if needed

**Week 1 Goal: CI passing, docs consolidated, backend started**

---

## FILES TO READ (Priority Order)

1. **MASTER_PLAN.md** (this file) - Single source of truth
2. **QUICK_START.md** (I'll create) - How to set up iPhone & backend
3. **ARCHITECTURE.md** - Technical decisions
4. **PRD.md** - Product requirements
5. **README.md** - Project overview

**Ignore the other 17 .md files** (contradictory, outdated)

---

## FILES TO DELETE (After Archiving)

- SETUP_STATUS.md (outdated)
- GOLDEN_STANDARD_TODO.md (contradicts this plan)
- LESSONS_LEARNED.md (merged into RETROSPECTIVE.md)
- TESTING_CHECKLIST.md (superseded by MASTER_PLAN.md)
- SESSION_LOG.md (no longer maintained)
- CONTRIBUTING.md (no contributors yet)
- CHANGELOG.md (empty)

**Move to /docs/archive/:**
- RETROSPECTIVE.md (historical, not current)
- WORKFLOW.md (too detailed, archived for reference)
- TOOLING_SETUP.md (archived, superseded by QUICK_START.md)
- CLAUDE_CODE_BEST_PRACTICES.md (internal notes)
- iOS_26_PATTERNS.md (reference, not critical path)
- XCODE_SETUP.md (superseded by QUICK_START.md)
- BACKEND_SETUP.md (superseded by QUICK_START.md)
- TEST_PLAN.md (archived, specific tasks in GitHub Issues)
- API.md (reference documentation)
- DESIGN.md (reference documentation)

**Result: 22 files → 6 active files + 13 archived**

---

## VERSION HISTORY

- **v1.0** (2025-10-26): Initial master plan created
  - Consolidated information from 22 documentation files
  - Incorporated findings from iOS architect, backend architect, QA specialist
  - Created 8-12 week timeline to production

---

**This is your single source of truth. All other .md files are either archived or deleted. Start with Week 1 tasks above.**
