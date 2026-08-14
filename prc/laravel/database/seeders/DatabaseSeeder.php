<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    public function run(): void
    {
        // ── Default Super Admin ────────────────────────────────────────────
        User::firstOrCreate(
            ['email' => 'admin@civilwatch.ph'],
            [
                'name'          => 'Super Administrator',
                'password_hash' => Hash::make('Admin@2026!'),
                'role'          => 'super_admin',
                'office'        => null,
                'is_active'     => true,
            ]
        );

        // ── Government Offices ─────────────────────────────────────────────
        $this->call(GovernmentOfficeSeeder::class);

        // ── Sample Announcements ───────────────────────────────────────────
        $this->call(AnnouncementSeeder::class);

        // ── Sample Citizen Reports (for map & app testing) ─────────────────
        $this->call(CitizenReportSeeder::class);

        $this->command->info('');
        $this->command->info('✓ CivilWatch database seeded successfully.');
        $this->command->info('  Admin login: admin@civilwatch.ph / Admin@2026!');
        $this->command->info('  Remember to change the default password after first login.');
    }
}
