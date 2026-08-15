# CIVILWATCH — Master Reference Document

> **Full-Stack Capstone | Flutter + Laravel + HTML/JS**
> **System:** Geotagged Community Incident Reporting System
> **Location:** Digos City, Davao del Sur
> **University:** University of Mindanao — Digos Branch | BS Information Technology
> **Proponents:** Renz Justine Y. Borinaga · Jhon Carlo Mag-Usara · Lawrence Roy P. Sereno
> **Adviser:** Cyvil Dave Dasargo, MIT
> **Last Updated:** August 14, 2026

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Architecture](#2-architecture)
3. [Current Build Status](#3-current-build-status)
4. [Flutter App — Complete Reference](#4-flutter-app--complete-reference)
5. [Laravel Backend — Complete Reference](#5-laravel-backend--complete-reference)
6. [Admin Web Dashboard — Complete Reference](#6-admin-web-dashboard--complete-reference)
7. [Database Schema](#7-database-schema)
8. [API Endpoints](#8-api-endpoints)
9. [Recent Fixes & Updates (Kiro Session Log)](#9-recent-fixes--updates-kiro-session-log)
10. [Known Issues & Pending Tasks](#10-known-issues--pending-tasks)
11. [How to Run](#11-how-to-run)
12. [Credentials Reference](#12-credentials-reference)
13. [Design Tokens](#13-design-tokens)
14. [Report Categories & Status Flow](#14-report-categories--status-flow)

---

## 1. System Overview

CIVILWATCH is a three-component full-stack capstone system:

| Component | Technology | Status |
|---|---|---|
| **Citizen Mobile App** | Flutter / Dart | ✅ Built + Wired to Laravel |
| **Laravel Backend API** | PHP / Laravel 12 / MySQL | ✅ Running |
| **Admin Web Dashboard** | HTML / CSS / Vanilla JS | ✅ UI Complete (static prototype) |

The system allows citizens of Digos City to report infrastructure and environmental concerns via a mobile app. Government offices (CEO, CENRO) manage and resolve these reports through a web dashboard, with all data persisted in MySQL via a Laravel REST API.

---

## 2. Architecture

```
Flutter App (Chrome / Android)     Web Admin (HTML/JS)
         ↓                                ↓
  /api/mobile/*                  / and /*.html + /api/*
         └──────────────┬────────────────┘
                        ↓
            Laravel (php artisan serve)
            http://127.0.0.1:8000
                        ↓
                MySQL (XAMPP)
             Database: civilwatch
```

### Key Architectural Decisions

- **Community map endpoint is public** — `/api/mobile/reports/community` requires no auth token so both logged-in citizens and guest/visitor users see the same pins.
- **AppState is a singleton ChangeNotifier** — all screens `ListenableBuilder` on `AppState()` and rebuild when data changes.
- **DummyData fallback** — if the API is unreachable, all lists fall back to `DummyData` so the app still renders.
- **`CitizenReport::transitionTo()`** — every status change automatically creates a `ReportActivity` entry and a `CitizenNotification`.

---

## 3. Current Build Status

### Component Overview

| Component | Build | Integration |
|---|---|---|
| Admin Web Dashboard | ✅ 100% UI | 🔲 Static prototype (no real API calls) |
| Flutter Mobile App | ✅ All screens | ✅ Wired to Laravel |
| Laravel Backend | ✅ All routes/controllers | ✅ Running on XAMPP MySQL |

### Flutter Integration Checklist

| Feature | Status |
|---|---|
| Community reports (public map) loaded from DB | ✅ Done |
| My Reports loaded from DB | ✅ Done |
| Notifications loaded from DB | ✅ Done |
| Announcements loaded from DB | ✅ Done |
| Login (phone + PIN, no OTP) | ✅ Done |
| Session restore on app start | ✅ Done |
| Report submission → API | ✅ Done |
| CitizenReportSeeder (sample data) | ✅ Done |
| Before/After photo modal on pin tap | ✅ Done |
| Track Report layout (PT + IL / AO + AL) | ✅ Done |
| Overflow fixes (map screen, track report) | ✅ Done |
| Photo upload (image_picker) | ⚠️ Pending |
| Real GPS (geolocator) | ⚠️ Pending |
| SMS OTP (real provider) | ⚠️ Pending |
| After photo upload (admin web) | ⚠️ Pending |

---

## 4. Flutter App — Complete Reference

**Root:** `prc/civ-main/`
**Entry:** `lib/main.dart` → `AppState().init()` → `runApp(CivilWatchApp())`

### 4.1 File Structure

```
lib/
├── main.dart                          App entry point
├── app.dart                           MaterialApp, theme, routes
├── core/
│   ├── constants/
│   │   ├── api_constants.dart         All API endpoint URLs
│   │   ├── app_colors.dart            Design tokens (colors)
│   │   └── app_strings.dart           String constants
│   ├── network/
│   │   └── api_client.dart            Shared HTTP client (Bearer token, error parsing)
│   ├── routes/
│   │   ├── app_routes.dart            Route name constants
│   │   └── route_generator.dart       Named route factory
│   ├── state/
│   │   └── app_state.dart             Singleton ChangeNotifier (all app data)
│   ├── theme/
│   │   └── app_theme.dart             Flutter ThemeData
│   └── utils/
│       ├── dummy_data.dart            Fallback data + MapPin/Announcement models
│       └── helpers.dart               Color/icon/date helpers
├── models/
│   ├── report.dart                    IncidentReport + ActivityEntry
│   ├── notification_model.dart        AppNotification
│   └── user.dart                      AppUser (citizen profile)
├── screens/
│   ├── splash/                        App loading screen
│   ├── auth/                          Login, OTP, Register
│   ├── landing/                       Landing / welcome screen
│   ├── home/                          Home dashboard
│   ├── report/                        5-step report wizard
│   ├── my_reports/                    My reports list
│   ├── track_report/                  Report detail + timeline
│   ├── community_map/                 Community map (all public reports)
│   ├── map_preview/                   Report Location screen (private map)
│   ├── notifications/                 Notifications list
│   ├── profile/                       Profile + settings
│   └── visitor/                       Visitor/guest mode screens
├── services/
│   ├── auth_service.dart              Login, register, session restore
│   ├── report_service.dart            CRUD for reports
│   ├── notification_service.dart      Notifications
│   ├── announcement_service.dart      City announcements
│   └── semaphore_service.dart         OTP via Semaphore SMS (stub)
└── widgets/
    ├── buttons/                       PrimaryButton, SecondaryButton, AppIconButton
    ├── cards/                         ReportCard, ActivityCard, NotificationCard, StatusCard
    ├── common/                        EmptyState, AppLoading, SectionTitle
    ├── inputs/                        CustomTextField, SearchField, OtpBox
    ├── map/                           MapFilterChip, MapMarker
    ├── navigation/                    BottomNav
    └── timeline/                      ProgressTimeline (5-step)
```

### 4.2 Screens Reference

| Screen | File | Route | Description |
|---|---|---|---|
| Splash | `splash/splash_screen.dart` | `/splash` | Loading + auth check |
| Landing | `landing/landing_screen.dart` | `/` | Welcome page, guest/login entry |
| Login | `auth/login_screen.dart` | `/login` | Phone + PIN login |
| OTP | `auth/otp_screen.dart` | `/otp` | 6-digit OTP verification |
| Register | `auth/register_screen.dart` | `/register` | New citizen registration |
| Home | `home/home_screen.dart` | `/home` | Dashboard + bottom nav host |
| Report Category | `report/report_category.dart` | `/report/category` | Step 1: Infra or Environment |
| Report Concern | `report/report_concern.dart` | `/report/concern` | Step 2: Concern type |
| Report Photo | `report/report_photo.dart` | `/report/photo` | Step 3: Photo capture |
| Report Location | `report/report_location.dart` | `/report/location` | Step 4: GPS + address |
| Report Review | `report/report_review.dart` | `/report/review` | Step 5: Summary + submit |
| Report Submitted | `report/report_submitted.dart` | `/report/submitted` | Reference number |
| My Reports | `my_reports/my_reports_screen.dart` | `/my-reports` | Citizen's report list |
| Track Report | `track_report/track_report_screen.dart` | `/track-report` | Report detail + timeline |
| Status Update | `track_report/status_update_screen.dart` | `/status-update` | Activity log detail |
| Private Map | `map_preview/private_map_screen.dart` | `/private-map` | Report GPS location |
| Community Map | `community_map/community_map_screen.dart` | `/community-map` | All public validated reports |
| Notifications | `notifications/notification_screen.dart` | `/notifications` | Notification list |
| Profile | `profile/profile_screen.dart` | `/profile` | User info + menu |

### 4.3 Core State — `app_state.dart`

Singleton `ChangeNotifier`. All screens read from and write to it.

**Key methods:**
- `init()` — Called once at app start. Loads community reports (always public), then restores session if token exists.
- `onLoginSuccess(user)` — Loads all personal data (reports, notifications, announcements) after login.
- `logout()` — Clears token, resets personal data to DummyData fallback.
- `refresh()` — Reloads all data (pull-to-refresh).
- `submitReport(data)` — Posts to API, inserts into local cache optimistically.
- `fetchReport(id)` — Fetches fresh copy of a single report.
- `getById(id)` / `getByReference(ref)` — Local lookup across both lists.
- `markAllRead()` / `markRead(id)` — Updates notifications via API + local state.

**Data flow:**
```
AppState.init()
  ├─ _loadCommunityReports()  → auth:false → always loads for guests too
  └─ AuthService.restoreSession()
       ├─ token found → _loadMyReports(), _loadNotifications(), _loadAnnouncements()
       └─ no token   → DummyData fallback for personal lists
```

### 4.4 API Client — `api_client.dart`

Shared HTTP client used by all services.

- Auto-injects `Bearer` token from `SharedPreferences` on every request
- Parses Laravel JSON: `{ success, data, message, errors }`
- Throws `ApiException(message, statusCode, errors)` on non-2xx
- Debug logging in `kDebugMode`: `🌐 GET [200] /api/...`
- Token persistence: `saveToken()`, `getToken()`, `deleteToken()`, `hasToken`

### 4.5 Key Recent Changes to Flutter Screens

#### `track_report_screen.dart`
- Layout: **Row 1** = Progress Timeline + Incident Location (with real `FlutterMap`) | **Row 2** = Assigned Office + Activity Log
- IL box uses `_RealMiniMap` widget (real OSM tiles, 260px tall, non-interactive)
- AL box shows "No activity yet." when `activityLog` is empty
- Barangay text in `_BeforeAfterPhotos` header wrapped in `Flexible` to fix overflow
- Compare arrow in before/after row changed from `Column` to flat `Container` to fix bottom overflow

#### `community_map_screen.dart`
- **Before:** Hardcoded `DummyData.communityPins`
- **After:** `ListenableBuilder(AppState())` → converts `IncidentReport` → `MapPin` on the fly
- Community reports loaded without auth (`auth: false`) so guests see pins
- Pin bottom sheet: `ConstrainedBox(maxHeight: 65%)` + `Flexible + SingleChildScrollView` to prevent overflow
- Before/After photos **removed** from pin sheet (moved to Report Location screen)

#### `private_map_screen.dart` (Report Location)
- Map (`FlutterMap`) sits directly in `Expanded` — no `Stack`, no `ClipRect`, no overflow
- Info sheet (Barangay, Coordinates, Submitted) is a sibling `Container` below the map
- **Tapping the pin** on a resolved report opens `_BeforeAfterDialog` — a `Dialog` showing Before/After photos side by side
- Non-resolved reports: pin tap does nothing
- `_BeforeAfterDialog` includes: issue name, barangay, Before/After tiles, tappable fullscreen viewer

#### `home_screen.dart`
- Fixed missing import for `Announcement` class (`dummy_data.dart`)

#### `report_service.dart`
- `getCommunityReports()` changed to `auth: false` (public endpoint)

---

## 5. Laravel Backend — Complete Reference

**Root:** `prc/laravel/`
**Running at:** `http://127.0.0.1:8000` via `php artisan serve`

### 5.1 File Structure

```
laravel/
├── app/
│   ├── Http/Controllers/
│   │   ├── Mobile/
│   │   │   ├── MobileAuthController.php
│   │   │   ├── MobileReportController.php
│   │   │   ├── MobileNotificationController.php
│   │   │   └── MobileAnnouncementController.php
│   │   ├── Admin/
│   │   │   ├── AdminCitizenReportController.php
│   │   │   ├── AdminOfficeController.php
│   │   │   ├── AdminAnnouncementController.php
│   │   │   └── AdminWebController.php
│   │   └── Api/
│   │       └── (legacy admin API controllers)
│   └── Models/
│       ├── User.php              Admin staff
│       ├── Citizen.php           Mobile app users
│       ├── OtpCode.php
│       ├── GovernmentOffice.php
│       ├── CitizenReport.php     Main report model
│       ├── ReportActivity.php
│       ├── CitizenNotification.php
│       └── Announcement.php
├── database/
│   ├── migrations/               All 7+ table migrations
│   └── seeders/
│       ├── DatabaseSeeder.php    Super admin + calls all seeders
│       ├── GovernmentOfficeSeeder.php
│       ├── AnnouncementSeeder.php
│       └── CitizenReportSeeder.php   ← Added in Kiro session
├── routes/
│   ├── api.php                   All API routes
│   └── web.php                   Serves index.html + catch-all for .html files
├── civilwatch.sql                 DB schema (old, for reference)
└── civilwatch_seed.sql            Seed data (old format, for reference)
```

### 5.2 `CitizenReportSeeder.php` — Added by Kiro

Seeds 10 sample citizen reports:
- 8 with `is_public = true` (show on community map) — mix of Resolved, In Progress, Assigned
- 2 with `is_public = false` (citizen's private pending reports)
- 3 sample citizens created with PIN `123456`
- Each report gets full activity log entries matching its status

Run with: `php artisan db:seed --class=CitizenReportSeeder`

### 5.3 Route Changes — `api.php`

`/api/mobile/reports/community` moved **outside** the `auth:citizen` middleware group — now a **public endpoint** (no token required). This allows guests and the community map to load pins without login.

```php
// Public — no auth required
Route::get('reports/community', [MobileReportController::class, 'community']);

// Protected — requires citizen token
Route::middleware('auth:citizen')->group(function () {
    // ... all other mobile routes
});
```

---

## 6. Admin Web Dashboard — Complete Reference

**Root:** `prc/laravel/public/` (served by Laravel catch-all route)
**Access:** `http://127.0.0.1:8000`

### 6.1 Pages

**Super Admin (11 pages)** — `public/`

| File | Description |
|---|---|
| `index.html` | Login with 3-role routing |
| `dashboard.html` | Stats, recent reports, Leaflet map, activity feed |
| `pending-reports.html` | Validation queue, search + filters |
| `report-details.html` | Full detail, approve/reject modals, timeline |
| `assign-office.html` | Office cards, priority pills, notes |
| `monitoring.html` | Tab filters, progress tracking, update modal |
| `gis-map.html` | Leaflet map with filter chips |
| `analytics.html` | 5 Chart.js charts, weekly/monthly toggle |
| `resolved-reports.html` | Resolved archive with search |
| `users.html` | User table, slide-in details, Add User modal |
| `settings.html` | 7 sections (General, Categories, Offices, etc.) |

**CEO Office — `public/offices/ceo/`** (Blue theme, 8 pages)
**CENRO Office — `public/offices/cenro/`** (Green theme, 8 pages)

Both offices have: `dashboard.html`, `reports.html`, `inprogress.html`, `resolved.html`, `map.html`, `analytics.html`, `report-details.html`, `settings.html` (placeholder)

### 6.2 Before/After Photo Section (Web)

The "Upload After Photo" button in both CEO and CENRO `report-details.html` currently shows a toast: `'Photo upload coming in next update'`. The UI shell is built — actual upload logic is pending.

---

## 7. Database Schema

**Database name:** `civilwatch`
**Engine:** MySQL (XAMPP)

### Tables (Laravel Migrations)

| Table | Purpose | Key Columns |
|---|---|---|
| `users` | Admin staff accounts | `email`, `password_hash`, `role` (super_admin/ceo/cenro) |
| `citizens` | Mobile app users | `phone` (unique), `pin_hash`, `barangay`, `full_name` |
| `otp_codes` | OTP verification | `phone`, `code`, `expires_at`, `used_at` |
| `government_offices` | Office records | `name`, `abbreviation`, `handles` (Infrastructure/Environment/Both) |
| `citizen_reports` | Reports from Flutter | `reference_number`, `citizen_id`, `category`, `concern`, `status`, `is_public`, `lat`, `lng`, `photo_url`, `after_image_url` |
| `report_activities` | Status change log | `citizen_report_id`, `title`, `description`, `status` |
| `citizen_notifications` | Per-citizen notifications | `citizen_id`, `citizen_report_id`, `title`, `body`, `read_at` |
| `announcements` | City announcements | `title`, `body`, `is_published`, `published_at` |

### Reference Number Format

```
CW-{YEAR}-{5-digit-padded-sequence}
Example: CW-2026-00125
```

### Seeded Data (after `php artisan db:seed`)

| Data | Count |
|---|---|
| Admin users | 1 (super_admin) |
| Government offices | 5 (CEO, CENRO, CPWD, CDRRMO, CVO) |
| Announcements | 2 |
| Citizens (sample) | 3 |
| Citizen reports | 10 (8 public, 2 private) |

---

## 8. API Endpoints

**Base URL:** `http://127.0.0.1:8000/api`

### Public (no auth)

| Method | Endpoint | Description |
|---|---|---|
| GET | `/ping` | Health check |
| GET | `/mobile/announcements` | City announcements |
| GET | `/mobile/reports/community` | All public validated reports (map pins) |
| POST | `/mobile/auth/send-otp` | Send OTP to phone |
| POST | `/mobile/auth/verify-otp` | Verify OTP → token |
| POST | `/mobile/auth/register` | Register citizen → token |
| POST | `/mobile/auth/login` | Phone + PIN login → token |

### Citizen (requires `Bearer` token)

| Method | Endpoint | Description |
|---|---|---|
| GET | `/mobile/auth/me` | Current citizen profile |
| POST | `/mobile/auth/logout` | Revoke token |
| GET | `/mobile/reports` | Citizen's own reports (`?status=` filter) |
| POST | `/mobile/reports` | Submit new report (multipart) |
| GET | `/mobile/reports/{id}` | Report detail + activity log |
| GET | `/mobile/notifications` | Notifications + unread count |
| POST | `/mobile/notifications/mark-all-read` | Mark all read |
| POST | `/mobile/notifications/{id}/read` | Mark one read |

### Admin (requires admin Sanctum token)

| Method | Endpoint | Description |
|---|---|---|
| GET | `/admin/citizen-reports` | List all reports with filters |
| GET | `/admin/citizen-reports/{id}` | Report detail |
| POST | `/admin/citizen-reports/{id}/validate` | Approve → makes public |
| POST | `/admin/citizen-reports/{id}/assign` | Assign to office |
| POST | `/admin/citizen-reports/{id}/status` | Update status |
| GET | `/admin/offices` | List offices |
| GET/POST | `/admin/announcements` | Announcements CRUD |

---

## 9. Recent Fixes & Updates (Kiro Session Log)

This section documents every change made in the Kiro AI sessions. Most recent first.

---

### Session: Report Location Screen & Overflow Fixes

**Files changed:** `private_map_screen.dart`

**What was done:**
- Removed `Stack` + `ClipRect` wrapper around `FlutterMap` — map now sits directly in `Expanded`
- Moved info sheet (Barangay, Coordinates, Submitted) out of `Positioned`/`Stack` — now a direct `Column` sibling below the map
- **Result:** Zero overflow. Map fills `Expanded`, info sheet stacks below naturally, "Back to Report" button at bottom.
- Tapping the **pin** on a resolved report opens `_BeforeAfterDialog` modal
- Non-resolved reports: pin tap does nothing (no modal)
- `_BeforeAfterDialog` shows: issue name, barangay, "Resolved" badge, Before/After photo tiles side by side, tappable fullscreen viewer (`_FullscreenPhotoViewer`)
- `_MapPhotoTile` widget handles image display + "No photo" placeholder

---

### Session: Before/After — Community Map vs Report Location

**Files changed:** `private_map_screen.dart`, `community_map_screen.dart`

**What was done:**
- Removed Before/After section from community map pin sheet — it was showing there incorrectly
- Confirmed Before/After is only on `private_map_screen.dart` (Report Location)
- Removed dead code: `_PinPhotoTile`, `_MapPhotoViewer`, `_openPhoto` from `community_map_screen.dart`
- Cleaned `_PinDetailSheet` — removed `isResolved`, `beforeUrl`, `afterUrl` variables

---

### Session: Community Map Pin Sheet Overflow Fix

**Files changed:** `community_map_screen.dart`

**What was done:**
- Wrapped `_PinDetailSheet` in `ConstrainedBox(maxHeight: 65% screen height)` — prevents sheet from exceeding screen
- Wrapped sheet content in `Flexible + SingleChildScrollView` — content scrolls if tall
- Added `Flexible` + `TextOverflow.ellipsis` to barangay text row

---

### Session: Track Report Layout

**Files changed:** `track_report_screen.dart`

**What was done:**
- Layout fixed to match reference screenshot:
  - **Row 1:** Progress Timeline (left) | Incident Location (right, 260px map)
  - **Row 2:** Assigned Office (left) | Activity Log (right)
- `_MiniStaticMap` (fake painted map) replaced with `_RealMiniMap` (live OSM `FlutterMap`)
- Added imports: `flutter_map`, `latlong2`
- Activity Log shows "No activity yet." when empty
- Fixed `Row` overflow (right, 41px) in `_BeforeAfterPhotos` header: barangay text wrapped in `Flexible`
- Fixed `Column` overflow (bottom, 33px): middle arrow changed from `Column(children:[Container])` to direct `Container`

---

### Session: Wire Community Map to Real DB Data

**Files changed:** `community_map_screen.dart`, `app_state.dart`, `report_service.dart`
**New files:** `prc/laravel/database/seeders/CitizenReportSeeder.php`
**Modified:** `prc/laravel/database/seeders/DatabaseSeeder.php`, `prc/laravel/routes/api.php`

**What was done:**
- `CommunityMapScreen` rewired from `DummyData.communityPins` → `ListenableBuilder(AppState())`
- Converts `IncidentReport` list → `MapPin` list on the fly via `_toPins()`
- `AppState.init()` now always calls `_loadCommunityReports()` first — even before auth check
- `report_service.dart` `getCommunityReports()` changed to `auth: false`
- `/api/mobile/reports/community` moved outside `auth:citizen` middleware — public endpoint
- `CitizenReportSeeder` created — 10 sample reports (8 public, 2 private), 3 sample citizens
- API confirmed returning 8 public records after seed

---

### Session: Before/After on Report Location Screen (Private Map)

**Files changed:** `map_preview/private_map_screen.dart`

**Before:** Before/After section was in the `private_map_screen.dart` info sheet (always visible).
**After:** Before/After only shows as a **modal dialog** when user taps the pin.

Changes:
- Removed Before/After from info sheet scroll content
- `Marker` child wrapped in `GestureDetector`
- On tap: `showDialog(builder: (_) => _BeforeAfterDialog(report: report))` — only if `report.isResolved`
- `_BeforeAfterDialog` widget added at bottom of file

---

### Session: Fix `Announcement` Undefined Class Error

**File:** `home_screen.dart`
**Fix:** Added `import '../../core/utils/dummy_data.dart'` — `Announcement` class defined there.

---

### Session: Flutter ↔ Laravel Integration

**New files:**
- `lib/core/constants/api_constants.dart`
- `lib/core/network/api_client.dart`

**Rewritten services:**
- `auth_service.dart` — real HTTP calls (OTP, register, login, session restore, logout)
- `report_service.dart` — real HTTP calls (submit, list, community, show)
- `notification_service.dart` — real HTTP calls (list, mark read)
- `announcement_service.dart` — real HTTP calls

**Updated:**
- `app_state.dart` — `init()` method, `onLoginSuccess()`, `logout()`, `refresh()`, `fetchReport()`, `submitReport()`
- `main.dart` — async, calls `AppState().init()` before `runApp()`

**Packages added to `pubspec.yaml`:**
- `shared_preferences: ^2.3.2`
- `flutter_secure_storage: ^9.2.2`

---

### Session: Laravel Backend Setup

**What was done:**
- Created `.env` from `.env.example`, set MySQL credentials
- Fixed `App\Models\User.php` — removed `'password_hash' => 'hashed'` cast (was double-hashing)
- Created `config/cors.php` — `allowed_origins = ['*']`
- Updated `bootstrap/app.php` — `HandleCors` middleware on API routes
- Updated `routes/web.php` — root `/` serves `public/index.html`, catch-all for all `.html` files
- Imported `civilwatch.sql` + `civilwatch_seed.sql` into MySQL

---

## 10. Known Issues & Pending Tasks

### HIGH — Must complete for defense

| # | Task | Component | File |
|---|---|---|---|
| 1 | Real photo upload (`image_picker`) | Flutter | `report/report_photo.dart` |
| 2 | Real GPS (`geolocator` + `permission_handler`) | Flutter | `report/report_location.dart` |
| 3 | After photo upload in web admin | Web | `offices/ceo/report-details.html`, `offices/cenro/report-details.html` |
| 4 | CEO + CENRO Settings pages | Web | `offices/ceo/settings.html`, `offices/cenro/settings.html` |

### MEDIUM — Should complete

| # | Task | Component |
|---|---|---|
| 5 | Wire web admin to real Laravel API (replace static JSON) | Web + Laravel |
| 6 | SMS OTP via real provider (Semaphore) | Laravel |
| 7 | Analytics from live DB data | Web + Laravel |
| 8 | Resolved rows → report-details link in web admin | Web |

### LOW — Polish / Future

| # | Task |
|---|---|
| 9 | Functional pagination on all list pages |
| 10 | Export Reports (CSV/PDF) |
| 11 | Push notifications (FCM) |
| 12 | Mobile responsive polish for office pages |
| 13 | Real-time map pin refresh |

### ⚠️ Prototype Limitations (By Design — Do Not "Fix")

- **Flutter app** — Photo upload = UI only. GPS = simulated at `6.7498, 125.3572`.
- **Web admin** — All data is static JSON / inline JS arrays. Auth = `localStorage` only.
- **OTP** — Returned in API response for dev. No real SMS sent.

---

## 11. How to Run

### Start Laravel Backend

```powershell
# Navigate to Laravel folder
Set-Location "C:\Users\User\Downloads\SERENO\APP-WITH-WEB\prc\laravel"

# First time only
copy .env.example .env     # then edit DB credentials if needed
composer install
php artisan key:generate
php artisan migrate
php artisan db:seed        # seeds admin + offices + announcements
php artisan db:seed --class=CitizenReportSeeder   # seeds 10 sample reports
php artisan storage:link

# Every time
php artisan serve
# → http://127.0.0.1:8000
```

### Start Flutter App (Chrome)

```powershell
Set-Location "C:\Users\User\Downloads\SERENO\APP-WITH-WEB\prc\civ-main"
flutter run -d chrome
```

### Test API

```
GET  http://127.0.0.1:8000/api/ping
→ { "success": true, "message": "CivilWatch API is running." }

GET  http://127.0.0.1:8000/api/mobile/reports/community
→ { "success": true, "data": [...8 reports...] }
```

### Access Web Admin

```
http://127.0.0.1:8000                     → HTML/JS admin login
http://127.0.0.1:8000/admin/login         → Blade admin panel
```

### Test on Real Android Device

Change `baseUrl` in `lib/core/constants/api_constants.dart`:
```dart
static const String baseUrl = 'http://10.10.10.87:8000/api'; // your machine's local IP
```

---

## 12. Credentials Reference

### Web Prototype (static localStorage)

| Role | Username | Password |
|---|---|---|
| Super Admin | `admin` | `admin123` |
| CEO | `ceo` | `ceo123` |
| CENRO | `cenro` | `cenro123` |

### Laravel Admin (Blade panel + API)

| Email | Password | Role |
|---|---|---|
| `admin@civilwatch.ph` | `Admin@2026!` | super_admin |

### Legacy MySQL seed credentials (civilwatch_seed.sql admin users)

| Email | Password | Role |
|---|---|---|
| `admin@civilwatch.gov.ph` | `admin123` | super_admin |
| `ceo@civilwatch.gov.ph` | `ceo123` | ceo |
| `cenro@civilwatch.gov.ph` | `cenro123` | cenro |

### Sample Citizens (CitizenReportSeeder)

| Phone | PIN | Name |
|---|---|---|
| `639123456789` | `123456` | Juan Dela Cruz |
| `639234567890` | `123456` | Maria Santos |
| `639345678901` | `123456` | Pedro Reyes |

---

## 13. Design Tokens

### Flutter App Colors — `app_colors.dart`

| Token | Value | Usage |
|---|---|---|
| `primary` | `#1B5E20` | Primary green |
| `navy` | `#0D2137` | Buttons, dark areas |
| `white` | `#FFFFFF` | Card backgrounds |
| `background` | `#F8FAFC` | Screen background |
| `divider` | `#E2E8F0` | Dividers, borders |
| `textPrimary` | `#0F172A` | Headings |
| `textSecondary` | `#64748B` | Subtitles |
| `textHint` | `#94A3B8` | Placeholder text |
| `statusPending` | `#F59E0B` | Pending Validation |
| `statusAssigned` | `#2563EB` | Assigned to Office |
| `statusInProgress` | `#EA580C` | In Progress |
| `statusResolved` | `#16A34A` | Resolved |
| `statusSubmitted` | `#7C3AED` | Submitted |
| `infrastructure` | `#D97706` | Infrastructure category |
| `environment` | `#16A34A` | Environment category |
| `cardShadow` | `rgba(0,0,0,0.06)` | Card box shadows |

### Web Admin Colors

| Token | Value | Usage |
|---|---|---|
| CEO primary | `#1A56DB` | Blue accent |
| CENRO primary | `#10B981` | Green accent |
| Page background | `#F9FAFB` | Light mode |
| Dark page bg | `#161B27` | Dark mode |
| Dark card bg | `#1E2330` | Dark mode cards |
| Pending | `#F59E0B` | Status badges |
| In Progress | `#F97316` | Status badges |
| Resolved | `#10B981` | Status badges |

---

## 14. Report Categories & Status Flow

### Categories

**Infrastructure → City Engineering Office (CEO)**

| Label | Icon | Description |
|---|---|---|
| Road Repair | `add_road_rounded` | Potholes, damaged road surface |
| Road Graveling | `terrain_rounded` | Unpaved roads need improvement |
| Broken Street Light | `light_rounded` | Broken or missing streetlight |
| Blocked Canal | `water_damage_rounded` | Canal clogged with debris |
| Others | `more_horiz_rounded` | Other infrastructure concerns |

**Environmental → CENRO**

| Label | Icon | Description |
|---|---|---|
| Illegal Dumping | `delete_sweep_rounded` | Waste illegally dumped |
| Garbage Collection | `recycling_rounded` | Missed garbage pickup |

### Status Flow

```
Citizen Submits
      ↓
Submitted (auto)
      ↓
Pending Validation  ← Admin reviews + approves → makes is_public = true
      ↓
Assigned to Office  ← Admin assigns to CEO or CENRO
      ↓
In Progress         ← Office updates status
      ↓
Resolved            ← Office marks resolved (uploads after photo)
```

### Status Colors

| Status | Flutter Color | Web Color | Who Sets |
|---|---|---|---|
| Submitted | `#7C3AED` purple | — | Auto on submit |
| Pending Validation | `#F59E0B` amber | `#F59E0B` | Auto on submit |
| Assigned to Office | `#2563EB` blue | `#1A56DB` | Super Admin |
| In Progress | `#EA580C` orange | `#F97316` | CEO / CENRO |
| Resolved | `#16A34A` green | `#10B981` | CEO / CENRO |

### Government Offices

| Abbreviation | Full Name | Handles |
|---|---|---|
| CEO | City Engineering Office | Infrastructure |
| CENRO | City Environment and Natural Resources Office | Environment |
| CPWD | City Public Works Department | Both |
| CDRRMO | City Disaster Risk Reduction and Management Office | Both |
| CVO | City Veterinary Office | Both (Others) |

---

## Old MD Files to Delete

The following files are now superseded by this master document and can be deleted:

- `FEATURES.md`
- `FINAL_STATUS.md`
- `PROJECT_STATUS.md`
- `RECENT_CHANGES.md`
- `SESSION_PROGRESS.md`
- `SYSTEM_DESIGN.md`
- `PRODUCTION_PROMPT.md`
- `PROMPT_REFERENCE.md`
- `prc/laravel/DEVLOG.md`
- `prc/laravel/README.md`

---

*CIVILWATCH — University of Mindanao Digos Branch | BS Information Technology Capstone 2026*
*Proponents: Renz Justine Y. Borinaga · Jhon Carlo Mag-Usara · Lawrence Roy P. Sereno*
*Adviser: Cyvil Dave Dasargo, MIT*
