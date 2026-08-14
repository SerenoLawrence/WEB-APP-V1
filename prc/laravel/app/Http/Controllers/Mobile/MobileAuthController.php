<?php

namespace App\Http\Controllers\Mobile;

use App\Http\Controllers\Controller;
use App\Models\Citizen;
use App\Models\OtpCode;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class MobileAuthController extends Controller
{
    // ─────────────────────────────────────────────────────────────────────
    // POST /api/mobile/auth/login
    // Body: { phone, pin }
    // Direct phone + PIN login — no OTP required for returning users.
    // ─────────────────────────────────────────────────────────────────────
    public function login(Request $request): JsonResponse
    {
        $request->validate([
            'phone' => ['required', 'string'],
            'pin'   => ['required', 'string', 'regex:/^\d{6}$/'],
        ]);

        $normalized = $this->normalizePhone($request->phone);

        // Find citizen by phone
        $citizen = Citizen::where('phone', $normalized)->first();

        if (! $citizen) {
            return response()->json([
                'success' => false,
                'message' => 'No account found with that mobile number.',
            ], 401);
        }

        // Verify PIN
        if (! Hash::check($request->pin, $citizen->pin_hash)) {
            return response()->json([
                'success' => false,
                'message' => 'Incorrect PIN. Please try again.',
            ], 401);
        }

        if (! $citizen->is_active) {
            return response()->json([
                'success' => false,
                'message' => 'Your account has been deactivated.',
            ], 403);
        }

        // Revoke old tokens and issue a fresh one
        $citizen->tokens()->delete();
        $token = $citizen->createToken('mobile')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Login successful.',
            'data'    => [
                'token'   => $token,
                'citizen' => $this->citizenResponse($citizen),
            ],
        ]);
    }

    // ─────────────────────────────────────────────────────────────────────
    // POST /api/mobile/auth/send-otp
    // Body: { phone: "09XXXXXXXXX" }
    // Generates a 6-digit OTP and stores it. You can hook up any SMS
    // provider later — right now the code is returned in the response
    // (useful for development / testing).
    // ─────────────────────────────────────────────────────────────────────
    public function sendOtp(Request $request): JsonResponse
    {
        $request->validate([
            'phone' => ['required', 'string', 'regex:/^(0|\+63|63)?9\d{9}$/'],
        ]);

        $normalized = $this->normalizePhone($request->phone);

        // Generate a random 6-digit OTP
        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        // Store OTP (invalidates any previous unused ones for this number)
        OtpCode::issue($normalized, $code);

        // TODO: Integrate your preferred SMS provider here to send $code to $normalized.
        // For now we return the code in the response (remove this before going live).
        return response()->json([
            'success' => true,
            'message' => 'OTP generated successfully.',
            'data'    => [
                'phone' => $normalized,
                // Remove 'otp' from response in production
                'otp'   => $code,
            ],
        ]);
    }

    // ─────────────────────────────────────────────────────────────────────
    // POST /api/mobile/auth/verify-otp
    // Body: { phone, otp }
    // Returns: { token, isNewUser }
    // ─────────────────────────────────────────────────────────────────────
    public function verifyOtp(Request $request): JsonResponse
    {
        $request->validate([
            'phone' => ['required', 'string'],
            'otp'   => ['required', 'string', 'size:6'],
        ]);

        $normalized = $this->normalizePhone($request->phone);
        $otpRecord  = OtpCode::findValid($normalized, $request->otp);

        if (! $otpRecord) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid or expired OTP.',
            ], 422);
        }

        // Mark OTP as used
        $otpRecord->update(['is_used' => true]);

        // Check if citizen already exists
        $citizen   = Citizen::where('phone', $normalized)->first();
        $isNewUser = ! $citizen;

        if ($citizen) {
            // Returning user — issue token immediately
            $token = $citizen->createToken('mobile')->plainTextToken;

            return response()->json([
                'success' => true,
                'message' => 'OTP verified.',
                'data'    => [
                    'token'     => $token,
                    'isNewUser' => false,
                    'citizen'   => $this->citizenResponse($citizen),
                ],
            ]);
        }

        // New user — let them proceed to registration
        return response()->json([
            'success' => true,
            'message' => 'OTP verified. Please complete registration.',
            'data'    => [
                'token'     => null,
                'isNewUser' => true,
                'phone'     => $normalized,
            ],
        ]);
    }

    // ─────────────────────────────────────────────────────────────────────
    // POST /api/mobile/auth/register
    // Body: { fullName, email (optional), barangay, pin, phone }
    // ─────────────────────────────────────────────────────────────────────
    public function register(Request $request): JsonResponse
    {
        $request->validate([
            'fullName' => ['required', 'string', 'max:150', function ($attr, $val, $fail) {
                if (count(array_filter(explode(' ', trim($val)))) < 2) {
                    $fail('Please enter both first and last name.');
                }
            }],
            'email'    => 'nullable|email|max:191|unique:citizens,email',
            'barangay' => ['required', 'string', 'in:' . implode(',', self::BARANGAYS)],
            'pin'      => ['required', 'string', 'regex:/^\d{6}$/'],
            'phone'    => 'required|string|unique:citizens,phone',
        ]);

        $citizen = Citizen::create([
            'full_name' => $request->fullName,
            'email'     => $request->email,
            'phone'     => $this->normalizePhone($request->phone),
            'barangay'  => $request->barangay,
            'city'      => 'Digos City',
            'pin_hash'  => Hash::make($request->pin),
        ]);

        $token = $citizen->createToken('mobile')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Registration successful.',
            'data'    => [
                'token'     => $token,
                'isNewUser' => false,
                'citizen'   => $this->citizenResponse($citizen),
            ],
        ], 201);
    }

    // ─────────────────────────────────────────────────────────────────────
    // POST /api/mobile/auth/logout
    // ─────────────────────────────────────────────────────────────────────
    public function logout(Request $request): JsonResponse
    {
        $request->user('citizen')->currentAccessToken()->delete();

        return response()->json([
            'success' => true,
            'message' => 'Logged out successfully.',
        ]);
    }

    // ─────────────────────────────────────────────────────────────────────
    // GET /api/mobile/auth/me
    // ─────────────────────────────────────────────────────────────────────
    public function me(Request $request): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data'    => $this->citizenResponse($request->user('citizen')),
        ]);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────

    private function citizenResponse(Citizen $citizen): array
    {
        return [
            'id'              => (string) $citizen->id,
            'fullName'        => $citizen->full_name,
            'phoneNumber'     => $citizen->phone,
            'barangay'        => $citizen->barangay,
            'joinedDate'      => $citizen->created_at?->toIso8601String(),
            'totalReports'    => $citizen->total_reports,
            'resolvedReports' => $citizen->resolved_reports,
            'avatarUrl'       => null,
        ];
    }

    /**
     * Normalise any Philippine phone number to 639XXXXXXXXX format.
     */
    private function normalizePhone(string $phone): string
    {
        $phone = preg_replace('/[\s\-\(\)]/', '', $phone);

        if (str_starts_with($phone, '+63')) return substr($phone, 1);
        if (str_starts_with($phone, '0'))   return '63' . substr($phone, 1);
        if (str_starts_with($phone, '9'))   return '63' . $phone;

        return $phone;
    }

    // All 22 barangays of Digos City, Davao del Sur
    private const BARANGAYS = [
        'Aplaya', 'Badiang', 'Balabag', 'Binaton', 'Cogon', 'Colorado',
        'Dawis', 'Dulangan', 'Goma', 'Igpit', 'Kapatagan', 'Kiagdan',
        'Matti', 'New Visayas', 'Rizal', 'San Jose', 'San Miguel',
        'Soong', 'Tres de Mayo', 'Zone 1', 'Zone 2', 'Zone 3',
    ];
}
