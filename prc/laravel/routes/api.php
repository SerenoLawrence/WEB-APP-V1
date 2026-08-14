<?php

use App\Http\Controllers\AnalyticsController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\NotificationController;
use App\Http\Controllers\ReportController;
use App\Http\Controllers\UserController;
use App\Http\Controllers\Mobile\MobileAuthController;
use App\Http\Controllers\Mobile\MobileReportController;
use App\Http\Controllers\Mobile\MobileNotificationController;
use App\Http\Controllers\Mobile\MobileAnnouncementController;
use App\Http\Controllers\Admin\AdminCitizenReportController;
use App\Http\Controllers\Admin\AdminOfficeController;
use App\Http\Controllers\Admin\AdminAnnouncementController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes — CivilWatch
|--------------------------------------------------------------------------
|
| /api/mobile/*  — Flutter citizen app  (auth guard: 'citizen')
| /api/admin/*   — Admin web panel      (auth guard: 'sanctum' / staff users)
| /api/*         — Legacy admin API     (unchanged)
|
|--------------------------------------------------------------------------
*/

// ═══════════════════════════════════════════════════════════════════════
// HEALTH CHECK
// ═══════════════════════════════════════════════════════════════════════

Route::get('/ping', fn() => response()->json([
    'success' => true,
    'message' => 'CivilWatch API is running.',
]));

// ═══════════════════════════════════════════════════════════════════════
// MOBILE — CITIZEN APP (Flutter)
// ═══════════════════════════════════════════════════════════════════════

Route::prefix('mobile')->name('mobile.')->group(function () {

    // ── Auth (public — no token needed) ───────────────────────────────
    Route::prefix('auth')->name('auth.')->group(function () {
        Route::post('login',      [MobileAuthController::class, 'login']);
        Route::post('send-otp',   [MobileAuthController::class, 'sendOtp']);
        Route::post('verify-otp', [MobileAuthController::class, 'verifyOtp']);
        Route::post('register',   [MobileAuthController::class, 'register']);
    });

    // ── Announcements (public — readable without login) ───────────────
    Route::get('announcements', [MobileAnnouncementController::class, 'index']);

    // ── Protected — requires citizen Sanctum token ────────────────────
    Route::middleware('auth:citizen')->group(function () {

        // Auth
        Route::post('auth/logout', [MobileAuthController::class, 'logout']);
        Route::get('auth/me',      [MobileAuthController::class, 'me']);

        // Reports
        // NOTE: /community must be registered BEFORE /{id} to avoid conflict
        Route::get('reports/community', [MobileReportController::class, 'community']);
        Route::get('reports',           [MobileReportController::class, 'index']);
        Route::post('reports',          [MobileReportController::class, 'store']);
        Route::get('reports/{id}',      [MobileReportController::class, 'show']);

        // Notifications
        Route::get('notifications',                       [MobileNotificationController::class, 'index']);
        Route::post('notifications/mark-all-read',        [MobileNotificationController::class, 'markAllRead']);
        Route::post('notifications/{id}/read',            [MobileNotificationController::class, 'markRead']);
    });
});

// ═══════════════════════════════════════════════════════════════════════
// ADMIN — WEB PANEL API (staff users — email/password → Sanctum token)
// ═══════════════════════════════════════════════════════════════════════

Route::prefix('admin')->name('admin.')->middleware('auth:sanctum')->group(function () {

    // Citizen reports management
    Route::get('citizen-reports/summary',      [AdminCitizenReportController::class, 'summary']);
    Route::get('citizen-reports/map',          [AdminCitizenReportController::class, 'map']);
    Route::get('citizen-reports',              [AdminCitizenReportController::class, 'index']);
    Route::get('citizen-reports/{id}',         [AdminCitizenReportController::class, 'show']);
    Route::post('citizen-reports/{id}/validate', [AdminCitizenReportController::class, 'validate']);
    Route::post('citizen-reports/{id}/assign', [AdminCitizenReportController::class, 'assign']);
    Route::post('citizen-reports/{id}/status', [AdminCitizenReportController::class, 'updateStatus']);

    // Government offices
    Route::get('offices',        [AdminOfficeController::class, 'index']);
    Route::post('offices',       [AdminOfficeController::class, 'store']);
    Route::put('offices/{id}',   [AdminOfficeController::class, 'update']);
    Route::delete('offices/{id}',[AdminOfficeController::class, 'destroy']);

    // Announcements
    Route::get('announcements',           [AdminAnnouncementController::class, 'index']);
    Route::post('announcements',          [AdminAnnouncementController::class, 'store']);
    Route::put('announcements/{id}',      [AdminAnnouncementController::class, 'update']);
    Route::delete('announcements/{id}',   [AdminAnnouncementController::class, 'destroy']);
});

// ═══════════════════════════════════════════════════════════════════════
// LEGACY ADMIN API (unchanged — staff email/password workflow)
// ═══════════════════════════════════════════════════════════════════════

Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {

    // Auth
    Route::get('/user',    [AuthController::class, 'me']);
    Route::post('/logout', [AuthController::class, 'logout']);

    // Users (super_admin only)
    Route::get('/users',         [UserController::class, 'index']);
    Route::post('/users',        [UserController::class, 'store']);
    Route::get('/users/{id}',    [UserController::class, 'show']);
    Route::put('/users/{id}',    [UserController::class, 'update']);
    Route::delete('/users/{id}', [UserController::class, 'destroy']);

    // Reports (admin-side, existing reports table)
    Route::get('/reports',                        [ReportController::class, 'index']);
    Route::post('/reports',                       [ReportController::class, 'store']);
    Route::get('/reports/map',                    [ReportController::class, 'mapPins']);
    Route::get('/reports/{id}',                   [ReportController::class, 'show']);
    Route::put('/reports/{id}',                   [ReportController::class, 'update']);
    Route::delete('/reports/{id}',                [ReportController::class, 'destroy']);
    Route::post('/reports/{id}/validate',         [ReportController::class, 'validateReport']);
    Route::post('/reports/{id}/reject',           [ReportController::class, 'rejectReport']);
    Route::post('/reports/{id}/assign',           [ReportController::class, 'assign']);
    Route::post('/reports/{id}/status',           [ReportController::class, 'updateStatus']);

    // Analytics
    Route::get('/analytics',                      [AnalyticsController::class, 'full']);
    Route::get('/analytics/summary',              [AnalyticsController::class, 'summary']);
    Route::get('/analytics/status-distribution',  [AnalyticsController::class, 'statusDistribution']);
    Route::get('/analytics/by-category',          [AnalyticsController::class, 'byCategory']);
    Route::get('/analytics/top-issues',           [AnalyticsController::class, 'topIssues']);
    Route::get('/analytics/top-barangays',        [AnalyticsController::class, 'topBarangays']);
    Route::get('/analytics/weekly-trend',         [AnalyticsController::class, 'weeklyTrend']);
    Route::get('/analytics/monthly-trend',        [AnalyticsController::class, 'monthlyTrend']);

    // Notifications (admin-side)
    Route::get('/notifications/unread-count',     [NotificationController::class, 'unreadCount']);
    Route::get('/notifications',                  [NotificationController::class, 'index']);
    Route::delete('/notifications',               [NotificationController::class, 'destroyAll']);
    Route::post('/notifications/{id}/read',       [NotificationController::class, 'markRead']);
    Route::delete('/notifications/{id}',          [NotificationController::class, 'destroy']);
    Route::post('/notifications/read-all',        [NotificationController::class, 'markAllRead']);
});
