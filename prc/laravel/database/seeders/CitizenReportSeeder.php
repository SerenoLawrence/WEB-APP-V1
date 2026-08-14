<?php

namespace Database\Seeders;

use App\Models\Citizen;
use App\Models\CitizenReport;
use App\Models\GovernmentOffice;
use App\Models\ReportActivity;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class CitizenReportSeeder extends Seeder
{
    public function run(): void
    {
        // ── Sample citizens ──────────────────────────────────────────────
        $citizens = [
            [
                'full_name' => 'Juan Dela Cruz',
                'phone'     => '639123456789',
                'barangay'  => 'Aplaya',
                'pin_hash'  => Hash::make('123456'),
            ],
            [
                'full_name' => 'Maria Santos',
                'phone'     => '639234567890',
                'barangay'  => 'Carmen',
                'pin_hash'  => Hash::make('123456'),
            ],
            [
                'full_name' => 'Pedro Reyes',
                'phone'     => '639345678901',
                'barangay'  => 'Zone II',
                'pin_hash'  => Hash::make('123456'),
            ],
        ];

        foreach ($citizens as $data) {
            Citizen::firstOrCreate(['phone' => $data['phone']], $data);
        }

        $c1 = Citizen::where('phone', '639123456789')->first();
        $c2 = Citizen::where('phone', '639234567890')->first();
        $c3 = Citizen::where('phone', '639345678901')->first();

        $ceo   = GovernmentOffice::where('abbreviation', 'CEO')->first();
        $cenro = GovernmentOffice::where('abbreviation', 'CENRO')->first();

        // ── Sample reports ───────────────────────────────────────────────
        $reports = [
            // ── Resolved & public (show on map) ─────────────────────────
            [
                'reference_number'   => 'CW-2026-00101',
                'citizen_id'         => $c1->id,
                'category'           => 'Infrastructure',
                'concern'            => 'Road Damage',
                'description'        => 'Multiple deep potholes along the main road in Aplaya causing difficulty for vehicles and risk of accidents especially at night.',
                'barangay'           => 'Aplaya',
                'lat'                => 6.7500,
                'lng'                => 125.3540,
                'severity'           => 'Severe',
                'status'             => 'Resolved',
                'assigned_office_id' => $ceo?->id,
                'resolved_at'        => '2026-07-20 14:00:00',
                'is_public'          => true,
                'photo_url'          => 'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?w=400',
                'created_at'         => '2026-07-14 07:15:00',
            ],
            [
                'reference_number'   => 'CW-2026-00102',
                'citizen_id'         => $c2->id,
                'category'           => 'Environment',
                'concern'            => 'Illegal Dumping',
                'description'        => 'Large volume of household garbage illegally dumped along the riverbank near Carmen barangay hall. Foul odor affecting nearby residents.',
                'barangay'           => 'Carmen',
                'lat'                => 6.7420,
                'lng'                => 125.3480,
                'severity'           => 'Severe',
                'status'             => 'Resolved',
                'assigned_office_id' => $cenro?->id,
                'resolved_at'        => '2026-07-18 10:00:00',
                'is_public'          => true,
                'photo_url'          => 'https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=400',
                'created_at'         => '2026-07-13 08:30:00',
            ],
            [
                'reference_number'   => 'CW-2026-00103',
                'citizen_id'         => $c3->id,
                'category'           => 'Infrastructure',
                'concern'            => 'Damaged Sidewalk',
                'description'        => 'Cracked and uneven sidewalk tiles near the public market in Zone II. Pedestrians especially elderly and children are at risk of tripping.',
                'barangay'           => 'Zone II',
                'lat'                => 6.7560,
                'lng'                => 125.3600,
                'severity'           => 'Moderate',
                'status'             => 'In Progress',
                'assigned_office_id' => $ceo?->id,
                'resolved_at'        => null,
                'is_public'          => true,
                'photo_url'          => 'https://images.unsplash.com/photo-1515162305285-0293e4683a0e?w=400',
                'created_at'         => '2026-07-15 09:00:00',
            ],
            [
                'reference_number'   => 'CW-2026-00104',
                'citizen_id'         => $c1->id,
                'category'           => 'Infrastructure',
                'concern'            => 'Blocked Drainage',
                'description'        => 'Main drainage canal in Magsaysay is fully clogged with silt and debris causing floodwater to overflow into residential streets after rain.',
                'barangay'           => 'Magsaysay',
                'lat'                => 6.7480,
                'lng'                => 125.3520,
                'severity'           => 'Severe',
                'status'             => 'Assigned to Office',
                'assigned_office_id' => $ceo?->id,
                'resolved_at'        => null,
                'is_public'          => true,
                'photo_url'          => 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=400',
                'created_at'         => '2026-07-16 10:30:00',
            ],
            [
                'reference_number'   => 'CW-2026-00105',
                'citizen_id'         => $c2->id,
                'category'           => 'Environment',
                'concern'            => 'Dead Trees',
                'description'        => 'Several large dead trees along Rizal Avenue in Dawis Norte are leaning dangerously over the road and power lines. High risk during strong winds.',
                'barangay'           => 'Dawis Norte',
                'lat'                => 6.7540,
                'lng'                => 125.3580,
                'severity'           => 'Severe',
                'status'             => 'In Progress',
                'assigned_office_id' => $cenro?->id,
                'resolved_at'        => null,
                'is_public'          => true,
                'photo_url'          => 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=400',
                'created_at'         => '2026-07-17 11:00:00',
            ],
            [
                'reference_number'   => 'CW-2026-00106',
                'citizen_id'         => $c3->id,
                'category'           => 'Infrastructure',
                'concern'            => 'Broken Street Light',
                'description'        => 'Three consecutive street lights on the road near Sinawilan Elementary School have been non-functional for two weeks. Area is very dark at night.',
                'barangay'           => 'Sinawilan',
                'lat'                => 6.7460,
                'lng'                => 125.3550,
                'severity'           => 'Moderate',
                'status'             => 'Resolved',
                'assigned_office_id' => $ceo?->id,
                'resolved_at'        => '2026-07-22 17:00:00',
                'is_public'          => true,
                'photo_url'          => 'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=400',
                'created_at'         => '2026-07-11 16:00:00',
            ],
            [
                'reference_number'   => 'CW-2026-00107',
                'citizen_id'         => $c1->id,
                'category'           => 'Environment',
                'concern'            => 'Flooding',
                'description'        => 'Persistent flooding on the low-lying areas of Colorado after moderate rain. Water level reaches ankle to knee depth and stays for hours.',
                'barangay'           => 'Colorado',
                'lat'                => 6.7400,
                'lng'                => 125.3490,
                'severity'           => 'Severe',
                'status'             => 'Pending Validation',
                'assigned_office_id' => null,
                'resolved_at'        => null,
                'is_public'          => true,
                'photo_url'          => null,
                'created_at'         => '2026-07-20 06:00:00',
            ],
            [
                'reference_number'   => 'CW-2026-00108',
                'citizen_id'         => $c2->id,
                'category'           => 'Infrastructure',
                'concern'            => 'Damaged Bridge',
                'description'        => 'Wooden planks on the footbridge over the creek in San Jose are rotting and have large gaps. Risk of falling especially for children and elderly.',
                'barangay'           => 'San Jose',
                'lat'                => 6.7600,
                'lng'                => 125.3620,
                'severity'           => 'Severe',
                'status'             => 'Assigned to Office',
                'assigned_office_id' => $ceo?->id,
                'resolved_at'        => null,
                'is_public'          => true,
                'photo_url'          => 'https://images.unsplash.com/photo-1587300003388-59208cc962cb?w=400',
                'created_at'         => '2026-07-19 13:00:00',
            ],

            // ── Pending (citizen's own reports, not yet public) ──────────
            [
                'reference_number'   => 'CW-2026-00109',
                'citizen_id'         => $c1->id,
                'category'           => 'Others',
                'concern'            => 'Stray Animals',
                'description'        => 'Pack of stray dogs near the school in Dulangan causing disturbance and danger to students.',
                'barangay'           => 'Dulangan',
                'lat'                => 6.7520,
                'lng'                => 125.3560,
                'severity'           => 'Moderate',
                'status'             => 'Pending Validation',
                'assigned_office_id' => null,
                'resolved_at'        => null,
                'is_public'          => false,
                'photo_url'          => null,
                'created_at'         => '2026-08-10 09:30:00',
            ],
            [
                'reference_number'   => 'CW-2026-00110',
                'citizen_id'         => $c1->id,
                'category'           => 'Infrastructure',
                'concern'            => 'Missing Road Signs',
                'description'        => 'Road signs at the intersection near the public market have been missing for weeks. Causing confusion especially for motorists.',
                'barangay'           => 'Zone I',
                'lat'                => 6.7510,
                'lng'                => 125.3545,
                'severity'           => 'Minor',
                'status'             => 'Submitted',
                'assigned_office_id' => null,
                'resolved_at'        => null,
                'is_public'          => false,
                'photo_url'          => null,
                'created_at'         => '2026-08-12 14:00:00',
            ],
        ];

        foreach ($reports as $data) {
            $created_at = $data['created_at'];
            unset($data['created_at']);

            $report = CitizenReport::firstOrCreate(
                ['reference_number' => $data['reference_number']],
                array_merge($data, [
                    'city'     => 'Digos City',
                    'province' => 'Davao del Sur',
                ])
            );

            // Update timestamps manually since firstOrCreate doesn't support it
            $report->created_at = $created_at;
            $report->save();

            // Add activity log entries
            if ($report->wasRecentlyCreated) {
                $this->seedActivities($report);
            }
        }

        $this->command->info('Citizen reports seeded: ' . count($reports));
    }

    private function seedActivities(CitizenReport $report): void
    {
        $base = $report->created_at;

        $activities = [[
            'title'       => 'Report Submitted',
            'description' => 'Your report has been successfully submitted and is under review.',
            'status'      => 'Submitted',
            'created_at'  => $base,
        ]];

        if (in_array($report->status, ['Pending Validation', 'Assigned to Office', 'In Progress', 'Resolved'])) {
            $activities[] = [
                'title'       => 'Pending Validation',
                'description' => 'Your report is being reviewed by our team for validation.',
                'status'      => 'Pending Validation',
                'created_at'  => (clone $base)->modify('+2 hours'),
            ];
        }

        if (in_array($report->status, ['Assigned to Office', 'In Progress', 'Resolved'])) {
            $activities[] = [
                'title'       => 'Assigned to Office',
                'description' => 'Your report has been assigned to the appropriate government office.',
                'status'      => 'Assigned to Office',
                'created_at'  => (clone $base)->modify('+1 day'),
            ];
        }

        if (in_array($report->status, ['In Progress', 'Resolved'])) {
            $activities[] = [
                'title'       => 'In Progress',
                'description' => 'Work is currently in progress to resolve this issue.',
                'status'      => 'In Progress',
                'created_at'  => (clone $base)->modify('+3 days'),
            ];
        }

        if ($report->status === 'Resolved') {
            $activities[] = [
                'title'       => 'Resolved',
                'description' => 'The issue has been successfully resolved. Thank you for your report.',
                'status'      => 'Resolved',
                'created_at'  => $report->resolved_at ?? (clone $base)->modify('+6 days'),
            ];
        }

        foreach ($activities as $act) {
            ReportActivity::create([
                'citizen_report_id' => $report->id,
                'title'             => $act['title'],
                'description'       => $act['description'],
                'status'            => $act['status'],
                'created_at'        => $act['created_at'],
            ]);
        }
    }
}
