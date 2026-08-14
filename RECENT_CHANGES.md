# CIVILWATCH — Recent Changes Log

> Last Updated: August 14, 2026
> Session: Backend Setup + Flutter ↔ Laravel Integration

---

## Summary

This session covered two major milestones:

1. **Laravel backend fully running** — `.env` configured, database imported from `civilwatch.sql`, all credentials fixed, web admin HTML/JS files now served correctly through `php artisan serve`.
2. **Flutter app wired to Laravel API** — All three service files (`auth_service`, `report_service`, `notification_service`) now make real HTTP calls to the Laravel backend instead of using dummy data.

---

## Part 1 — Laravel Backend Setup

### Problem Fixed: 500 Internal Server Error

**Root cause:** No `.env` file existed — Laravel had no `APP_KEY` set.

**Fix:**
- Copied `.env.example` → `.env`
- Ran `php artisan key:generate` → key set successfully
- Switched DB from SQLite → MySQL (XAMPP)

---

### Database Setup

**Problem:** The `.env` defaulted to SQLite. You already have XAMPP + MySQL running with phpMyAdmin.

**Fix:**
- Updated `.env` to use MySQL:
```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=civilwatch
DB_USERNAME=root
DB_PASSWORD=
```
- Created `civilwatch` database in MySQL
- Imported `civilwatch.sql` (your actual schema) — **not** the Laravel migrations
- Imported `civilwatch_seed.sql` — 20 reports, 26 photos, full timeline, notifications

**Tables now in MySQL:**

| Table | Records |
|---|---|
| `users` | 3 (admin, ceo, cenro) |
| `reports` | 20 |
| `report_photos` | 26 (before + after for resolved) |
| `report_assignments` | 14 |
| `report_timeline` | 63 entries |
| `notifications` | 16 |
| `personal_access_tokens` | - |

---

### Login Credentials Fixed

**Problem:** CEO and CENRO accounts had `$2b$` bcrypt hashes (Node.js format) — PHP only accepts `$2y$`.

**Fix:** Imported `civilwatch_seed.sql` which regenerated all three users with correct `$2y$12$` PHP bcrypt hashes.

**Also fixed:** `User` model had `'password_hash' => 'hashed'` cast which was double-hashing on read — removed that cast.

**Working admin credentials:**

| Role | Email | Password |
|---|---|---|
| Super Admin | `admin@civilwatch.gov.ph` | `admin123` |
| CEO | `ceo@civilwatch.gov.ph` | `ceo123` |
| CENRO | `cenro@civilwatch.gov.ph` | `cenro123` |

---

### Web Admin Now Served from Laravel

**Problem:** Visiting `127.0.0.1:8000` showed the Laravel Blade admin login instead of your HTML/JS `index.html`.

**Root cause:** `routes/web.php` had `Route::get('/', fn() => redirect()->route('admin.login'))` — redirecting root to the Blade panel.

**Fix:** Updated `routes/web.php`:
- Root `/` now serves `public/index.html` directly
- Catch-all route added at bottom — serves any `.html` file from `public/`
- Laravel Blade admin panel still accessible at `/admin/login`
- Catch-all placed **after** all other routes so it doesn't intercept API or admin routes

```
http://127.0.0.1:8000                          → index.html (your login page)
http://127.0.0.1:8000/dashboard.html           → dashboard.html
http://127.0.0.1:8000/analytics.html           → analytics.html
http://127.0.0.1:8000/offices/ceo/dashboard.html → CEO dashboard
http://127.0.0.1:8000/api/ping                 → { "success": true }
http://127.0.0.1:8000/admin/login              → Blade admin panel
```

---

### Files Modified (Laravel)

| File | Change |
|---|---|
| `.env` | Created from `.env.example`, DB switched to MySQL, SESSION/QUEUE/CACHE switched to file/sync |
| `routes/web.php` | Root serves `index.html`, catch-all serves all `.html` files from `public/` |
| `app/Models/User.php` | Removed `'password_hash' => 'hashed'` cast that was breaking `Auth::attempt()` |
| `config/cors.php` | Created — `allowed_origins = ['*']` for Flutter Web + HTML admin |
| `bootstrap/app.php` | Added `HandleCors` middleware to API routes, CSRF exempt for `api/*` |

---

## Part 2 — Flutter App ↔ Laravel Integration

### Overview

The Flutter app (`prc/civ-main`) was 100% in-memory (dummy data). All service files had `Future.delayed` mocks. This session replaced all of that with real HTTP calls to the Laravel API.

---

### New Files Created (Flutter)

#### `lib/core/constants/api_constants.dart`

Central file for all API endpoint URLs.

```dart
// Base URL — Flutter Web on Chrome, same machine as Laravel
static const String baseUrl = 'http://127.0.0.1:8000/api';

// All endpoints as constants
static const String sendOtp   = '$baseUrl/mobile/auth/send-otp';
static const String verifyOtp = '$baseUrl/mobile/auth/verify-otp';
static const String register  = '$baseUrl/mobile/auth/register';
static const String logout    = '$baseUrl/mobile/auth/logout';
static const String me        = '$baseUrl/mobile/auth/me';
static const String reports   = '$baseUrl/mobile/reports';
// ... etc
```

> To test on a real Android device: change `baseUrl` to `http://10.10.10.87:8000/api`

---

#### `lib/core/network/api_client.dart`

Shared HTTP client used by all services.

Features:
- `get()`, `post()`, `delete()`, `postMultipart()` methods
- Auto-injects `Bearer` token from `SharedPreferences` on every request
- Parses Laravel JSON responses (`{ success, data, message }`)
- Throws `ApiException(message, statusCode, errors)` on non-2xx
- Extracts first validation error from `errors` map automatically
- Debug logging in `kDebugMode` (`🌐 GET [200] /api/...`)
- Token storage via `SharedPreferences` (web-safe — works in Chrome)

```dart
// Token methods
await ApiClient.instance.saveToken(token);
await ApiClient.instance.getToken();
await ApiClient.instance.deleteToken();
bool hasToken = await ApiClient.instance.hasToken;
```

---

### Rewritten Files (Flutter Services)

#### `lib/services/auth_service.dart`

**Before:** `Future.delayed` mocks, always returned `true`.

**After:** Real API calls to Laravel.

| Method | Endpoint | Description |
|---|---|---|
| `restoreSession()` | `GET /api/mobile/auth/me` | Called on app start — restores login from saved token |
| `sendOtp(phone)` | `POST /api/mobile/auth/send-otp` | Returns OTP code in dev mode |
| `verifyOtp(phone, otp)` | `POST /api/mobile/auth/verify-otp` | Returns `isNewUser` + token |
| `register(...)` | `POST /api/mobile/auth/register` | Creates citizen + returns token |
| `logout()` | `POST /api/mobile/auth/logout` | Revokes Sanctum token + clears storage |
| `fetchMe()` | `GET /api/mobile/auth/me` | Refreshes user profile |
| `loginWithPin(phone, pin)` | `TODO` | Placeholder — Laravel endpoint not yet built |

> **Note:** `loginWithPin` is a placeholder. A `POST /api/mobile/auth/login` endpoint (phone + PIN, no OTP) needs to be added to Laravel. See Pending Tasks below.

---

#### `lib/services/report_service.dart`

**Before:** Returned `DummyData.myReports` directly.

**After:** Real API calls to Laravel.

| Method | Endpoint | Description |
|---|---|---|
| `getMyReports({status})` | `GET /api/mobile/reports` | Citizen's own reports, optional status filter |
| `getReportById(id)` | `GET /api/mobile/reports/{id}` | Single report with full activity log |
| `getCommunityReports()` | `GET /api/mobile/reports/community` | All validated public reports for map |
| `submitReport(data)` | `POST /api/mobile/reports` | Multipart form submission |

Response JSON is parsed into `IncidentReport` and `ActivityEntry` model objects. Falls back to `DummyData` if the API is unreachable.

---

#### `lib/services/notification_service.dart`

**Before:** Returned `DummyData.notifications` directly.

**After:** Real API calls to Laravel.

| Method | Endpoint | Description |
|---|---|---|
| `getNotifications()` | `GET /api/mobile/notifications` | Returns list + unread count |
| `markAllRead()` | `POST /api/mobile/notifications/mark-all-read` | Marks all read |
| `markRead(id)` | `POST /api/mobile/notifications/{id}/read` | Marks one read |

---

### Updated Files (Flutter)

#### `lib/core/state/app_state.dart`

**Before:** Hard-coded `DummyData` in constructor, no API calls.

**After:** Uses real services with `DummyData` as fallback.

Key changes:
- Added `init()` method — called once from `main.dart` before `runApp`
  - Calls `AuthService.restoreSession()` on startup
  - If token found → loads reports, community reports, notifications from API
  - If no token → loads `DummyData` as fallback
- Added `onLoginSuccess(user)` — called after login/register, loads all data
- Added `logout()` — calls `AuthService.logout()`, clears token, resets to DummyData
- Added `refresh()` — reloads all API data (for pull-to-refresh)
- Added `fetchReport(id)` — fetches fresh copy of one report from API
- `submitReport()` — calls `ReportService.submitReport()`, updates local cache
- `markAllRead()` / `markRead()` — calls `NotificationService`, updates local state
- `_unreadCount` now tracked separately and updated from API response

#### `lib/main.dart`

**Before:** Synchronous `void main()`.

**After:** Async `Future<void> main()` — calls `AppState().init()` before `runApp`.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppState().init(); // ← new
  // ...
  runApp(const CivilWatchApp());
}
```

---

### Packages Added

| Package | Version | Purpose |
|---|---|---|
| `flutter_secure_storage` | `^9.2.2` | Secure token storage (native) |
| `shared_preferences` | `^2.3.2` | Token storage fallback for Chrome/web |

> `flutter_secure_storage` uses the OS keychain on Android/iOS. On Chrome (web), it falls back to `SharedPreferences` (localStorage). This session uses `SharedPreferences` directly for simplicity since you're running on Chrome.

---

## Current Integration Status

| Feature | Status | Notes |
|---|---|---|
| Laravel running on XAMPP MySQL | ✅ Working | `php artisan serve` → `127.0.0.1:8000` |
| Web admin served from Laravel | ✅ Working | `127.0.0.1:8000` → `index.html` |
| Web admin login (Blade) | ✅ Working | `127.0.0.1:8000/admin/login` |
| CORS configured | ✅ Done | `allowed_origins = ['*']` |
| Flutter packages installed | ✅ Done | `flutter pub get` succeeded |
| ApiClient + ApiConstants | ✅ Done | Token storage, error handling |
| Auth service (OTP + register) | ✅ Done | Real API calls |
| Report service | ✅ Done | Real API calls |
| Notification service | ✅ Done | Real API calls |
| AppState uses real services | ✅ Done | DummyData fallback on error |
| PIN login (no OTP) | ⚠️ Pending | Needs Laravel endpoint |
| Photo upload (image_picker) | ⚠️ Pending | Multipart ready, picker not added |
| Real GPS (geolocator) | ⚠️ Pending | Not yet added |

---

## Pending Tasks (Next Session)

| # | Task | Where |
|---|---|---|
| 1 | **Add `POST /api/mobile/auth/login`** (phone + PIN, no OTP) | Laravel `MobileAuthController` |
| 2 | Wire `loginWithPin()` in `auth_service.dart` to new endpoint | Flutter `auth_service.dart` |
| 3 | Wire login screen to call `AuthService.instance.loginWithPin()` | Flutter `login_screen.dart` |
| 4 | Wire OTP screen → call `AuthService.instance.verifyOtp()` | Flutter `otp_screen.dart` |
| 5 | Wire register screen → call `AuthService.instance.register()` | Flutter `register_screen.dart` |
| 6 | Wire home screen stats from `AppState` (counts are real now) | Flutter `home_screen.dart` |
| 7 | Wire notifications screen to call `AppState.markRead()` | Flutter `notification_screen.dart` |
| 8 | Wire community map to use `AppState.communityReportsPublic` | Flutter `community_map_screen.dart` |
| 9 | Add `image_picker` for real photo capture in Step 3 | Flutter `report_photo.dart` |
| 10 | Add `geolocator` for real GPS in Step 4 | Flutter `report_location.dart` |
| 11 | Test full register flow end-to-end | Flutter + Laravel |
| 12 | Test submit report end-to-end | Flutter + Laravel |
| 13 | Add citizens table migration to match `citizens` model | Laravel migration |

---

## How to Run (Quick Reference)

### Start Laravel
```bash
# In: C:\Users\User\Downloads\SERENO\APP-WITH-WEB\prc\laravel
php artisan serve
# → http://127.0.0.1:8000
```

### Start Flutter (Chrome)
```bash
# In: C:\Users\User\Downloads\SERENO\APP-WITH-WEB\prc\civ-main
flutter run -d chrome
```

### Test API health
```
GET http://127.0.0.1:8000/api/ping
→ { "success": true, "message": "CivilWatch API is running." }
```

### Admin panel
```
http://127.0.0.1:8000/admin/login
Email:    admin@civilwatch.gov.ph
Password: admin123
```

---

## Architecture Reminder

```
Flutter App (Chrome)          Web Admin (HTML/JS)
        ↓                             ↓
  /api/mobile/*             / and /*.html + /api/*
        └──────────┬─────────────────┘
                   ↓
          Laravel (php artisan serve)
          http://127.0.0.1:8000
                   ↓
              MySQL (XAMPP)
           Database: civilwatch
```

---

*CIVILWATCH — University of Mindanao Digos Branch | BS Information Technology Capstone 2026*
*Proponents: Borinaga · Mag-Usara · Sereno | Adviser: Cyvil Dave Dasargo, MIT*
