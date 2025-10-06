FARELENS —DRAFT PRD V 1.6
Company: Astrion Studio
App: FareLens
Date: YYYY-MM-DD
Owner: CEO / Head of Product
 
CHANGE LOG
•	v1.6: Added final affiliate ecosystem details (Aviasales, WayAway, AirHelp, Compensair). Clarified “show all providers” transparency policy and GlassSheet ranking. Revised labeling (no “Partner” labels; neutral provider names). Updated booking logic to always display the lowest verified fare even if non-affiliate. Added post-booking compensation notifications, credentials block, infra rationale, security hardening, and detailed affiliate table with payout/cookie details.
•	v1.5: Locked provider stack (Amadeus primary, Travelpayouts fallback, Duffel Phase 3). Embedded Amadeus keys. Defined Pro/Free alert caps. Added “Smarter via Partner,” Transfer Bonus Collector, Card/Status onboarding, data model, infra, and privacy.
•	Earlier: Liquid Glass design system, Live Activities, Siri Shortcuts, fallback logic, baseline scoring, anomaly detection, privacy-first telemetry.
 
DECISION LOG
D1  Provider stack: Amadeus Self-Service (primary) for live fares; Aviasales + WayAway (affiliate booking); Duffel reserved for Phase 3 direct bookings.
D2  Monetization: Affiliate deep links replace Amadeus booking URLs when eligible; Pro removes ads and unlocks instant alerts + advanced nudges.
D3  Display: Always show lowest verified fare (even non-affiliate). Two CTAs max: Book at $XXX (lowest) and Book via [AffiliateName] if within 7 %. GlassSheet reveals all providers ≤ 10 % of lowest fare.
D4  Transparency: No “Partner” labels; provider names only; global disclosure in Terms.
D5  Alerts: Free 3/day + digests; Pro 8/day + instant; 1 exceptional override; quiet hours 10 pm–7 am; dedupe 6–12 h.
D6  Watchlists: Free 2; Pro unlimited.
D7  Personalization: Hybrid = server rules + on-device Foundation Models (embeddings, weighting, dedupe, explainability).
D8  Compensation flow: Post-booking monitoring → email/push if delay ≥ 3 h or cancellation. Integrates AirHelp & Compensair affiliate links.
D9  Security: Keychain + Secure Enclave, TLS pinning, STRIDE-lite, least privilege.
D10 Roadmap: Phase 2 Hotels/Cars + MQD Estimator • Phase 3 Duffel • Phase 4 Luxury Agency Pack.
 
ASSUMPTION LOG
A1 Amadeus 2 k calls/mo + cache suffices for MVP.
A2 Airline-direct ranked higher when price ≤ 2 % or $10 delta.
A3 Exclude Basic sticky per user; default = cheapest.
A4 MQD Estimator deferred → Phase 2.
 
VISION & KPI
“Apple-grade flight intelligence — trustworthy, personalized, transparent.”
KPIs → alert open rate ≥ 60 %, precision@K > 0.5, Pro conversion ≥ 8 %, affiliate CTR > 15 %, churn < 10 %.
North Star → “Time to a great booking” & “Users seeing a truly exceptional deal within 7 days.”
 
FEATURE SET (MVP = P0)
• Live search: Amadeus Flight Offers (verified fares).
• Affiliate Deep Links: Aviasales + WayAway.
• Watchlists: Free 2 · Pro unlimited · quiet hours · digests 9 am / 6 pm.
• Alerts: Free 3/day · Pro 8/day · override 1/day · dedupe 6–12 h · Undo/Mute/Pause.
• Deal Detail: Fare ladder + Upgrade Nudge + “Smarter via Partner.”
• Personalization: Server baselines + on-device FM.
• Points Vault + Transfer Bonus Collector + Card/Status Perks.
• Liquid Glass UI + Widgets + Live Activities + Siri Shortcuts.
• Ads in Free (tasteful banner) removed in Pro.
• Privacy & Compliance per DOT / GDPR / CCPA.
• Metrics via Apple + Firebase (free tiers).
 
BOOKING & COMMISSION STRATEGY v1.6
Goal: show lowest verified fare → earn only when affiliate eligible → never sacrifice trust.
Logic Flow
1.	Query Amadeus for live fares.
2.	Normalize & map providers (airline/OTA).
3.	If affiliate (Aviasales / WayAway) has matching fare ≤ lowest × 1.07 → eligible for dual display.
4.	Else show lowest verified fare only.
5.	Render two CTAs max → (1) Book at lowest (2) Book via affiliate (if eligible).
6.	Tap “Other offers” → GlassSheet (sorted ≤ 10 % delta).
7.	Always rank by user total cost after tax/bag.
GlassSheet Tie-Break Ranking
1️⃣ Airline Direct
2️⃣ Top OTA (Expedia > Booking > Trip.com)
3️⃣ Affiliates (Aviasales > WayAway)
4️⃣ Others by reliability / UX.
Identical price → trust_score > affiliate flag > latency.
Providers > 10 % delta hidden behind “Show all providers (may include higher fares).”
Labeling Policy
Provider names only (“Book on Aviasales,” “Book with Delta”).
Global disclosure in Terms → “FareLens may earn a small commission at no extra cost.”
 
AFFILIATE ECOSYSTEM (2025)
Provider	Status	Category	Payout	Cookie	Notes
Amadeus	Approved	Data only	–	–	2 k calls/mo free tier anchor
Aviasales	Approved	Flights	1.1–1.3 %	30 d	API + affiliate live
WayAway	Approved	Flights	1.1–1.3 %	30 d	Fallback deep link
AirHelp	Approved	Compensation	15–16.6 % of fee	45 d	Post-delay emails
Compensair	Approved	Compensation	€5–€14 / lead	30 d	Post-delay emails
Trip.com	Pending	Hotels/Cars	5 % avg	30 d	Phase 2
Booking.com	Declined	Hotels/Cars	4 %	1 session	Phase 2 resubmit
Omio / 12Go / Expedia / Traveloka / CheapOair / Kiwi.com	Pending/Declined	Various	≤ 6 %	varies	Reapply post-launch
Affiliate Deep-Link Template
https://tp.media/r?campaign_id=<ID>&marker=676763&sub_id=farelens-app&u=<encoded_URL>
Sub-ID Schema
ios-fl-{dealId}-{wl}-{placement}-{ab}-{tier}
 
COMPENSATION FLOW
During booking → info line “Flight protection available from trusted providers.”
After booking → monitor calendar/email receipts → if delay ≥ 3 h or cancelled → trigger email/push to AirHelp or Compensair affiliate URL.
Future → “Claims & Delays” tab (history + eligibility check).
 
PERSONALIZATION & FEEDBACK
On-device FM embeddings adapt DealScore weights per user (route, alliance, price tolerance).
Feedback buttons (4 reasons + Other).
Mute route/airline 30 d · Undo toast.
 
UX / DESIGN
Liquid Glass (iOS 26) → GlassList, GlassCard, GlassPillFilters, GlassCalendar, GlassSheet, GlassHUD.
Widgets: Today’s Top Deal, Transfer Bonus Live.
Live Activities: deal expiry countdown.
Accessibility: Dynamic Type, VoiceOver, ≥ 4.5 contrast, haptics.
Performance: 60 fps, cold start < 2 s, TTFI < 1.5 s.
 
INFRASTRUCTURE RATIONALE
Cloudflare Workers = edge API proxy ($0).
Supabase = Postgres + Auth free (≤ 500 MB).
Redis = Upstash or Fly.io queue (free tier).
Firebase = analytics / Remote Config / A/B.
All tiers $0 until subscription revenue.
Expected usage ≈ 1 GB DB ≈ 10 k users.
 
SECURITY & PRIVACY
All auth tokens hashed; device IDs anonymized; no 3rd-party PII.
Vault = Keychain + Secure Enclave.
TLS + HSTS + pinned certs for providers.
STRIDE-lite threat model stored in repo.
Privacy Manifest and Nutrition Label maintained.
 
PERFORMANCE & QA
Cold start < 2 s · p95 search < 1.2 s · scroll 60 fps · battery drain ≈ 0.
Test matrix → low storage/memory, offline, quiet hours, dark/light, locales.
Automated unit + UI tests · affiliate link validation · receipt tests.
Manual App Review checklist · privacy validation · pricing accuracy.
 
ACCEPTANCE CRITERIA (MVP)
✅ Amadeus live fares (≤ quota) + Aviasales affiliate replacement.
✅ WayAway fallback tested.
✅ Alert caps + quiet hours + dedupe + Undo.
✅ Personalization (serverside + on-device FM).
✅ Liquid Glass UI + Widgets + Live Activities + Siri Shortcuts.
✅ Compensation push/email flow (AirHelp + Compensair).
✅ Privacy manifest + secure vault.
✅ Free infra deploy live.
 
ROADMAP
Phase 2 → Hotels · Cars · Activities · MQD Estimator.
Phase 3 → Duffel direct bookings + walleted receipts.
Phase 4 → Astrion Luxury Agency Pack (concierge trips + service fees).
 
TERMS / PRIVACY / DISCLAIMER
Terms: FareLens aggregates public & affiliate flight data and redirects to providers. Prices subject to change.
Privacy: Minimal data only; some links may yield commission at no cost to user.
Disclaimer: FareLens not liable for airline changes or OTA fulfillment; bookings handled by provider.