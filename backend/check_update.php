<?php
/**
 * App Update Check API
 * Endpoint: auth?action=check_update
 * 
 * This file handles in-app update checks for the Dabaindia Attendance App.
 * Hosted at: https://caretel.in/dabaindia_attendance/api/
 * 
 * GitHub Releases: https://github.com/Caretel/dabaindia-app-releases/releases
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

// ============================================================
// RELEASE REGISTRY — Update this block for every new release
// ============================================================
$releases = [
    [
        'version_name' => '1.0.1',
        'version_code' => 2,
        'update_url'   => 'https://github.com/Caretel/dabaindia-app-releases/releases/download/v1.0.1/dabaindia-attendance-v1.0.1.apk',
        'notes'        => "- Auto-update system added\n- Security improvements\n- Bug fixes",
        'mandatory'    => false,
    ],
    [
        'version_name' => '1.0.2',
        'version_code' => 3,
        'update_url'   => 'https://github.com/Caretel/dabaindia-app-releases/releases/download/v1.0.2/dabaindia-attendance-v1.0.2.apk',
        'notes'        => "- General improvements and bug fixes",
        'mandatory'    => false,
    ],
    [
        'version_name' => '1.0.3',
        'version_code' => 4,
        'update_url'   => 'https://github.com/Caretel/dabaindia-app-releases/releases/download/v1.0.3/dabaindia-attendance-v1.0.3.apk',
        'notes'        => "- Fixed issue with APK installation not prompting\n- Security improvements",
        'mandatory'    => false,
    ],
    [
        'version_name' => '1.0.4',
        'version_code' => 5,
        'update_url'   => 'https://github.com/Caretel/dabaindia-app-releases/releases/download/v1.0.4/dabaindia-attendance-v1.0.4.apk',
        'notes'        => "- Testing update install prompt fix",
        'mandatory'    => false,
    ],
    [
        'version_name' => '1.0.5',
        'version_code' => 6,
        'update_url'   => 'https://github.com/Caretel/dabaindia-app-releases/releases/download/v1.0.5/dabaindia-attendance-v1.0.5.apk',
        'notes'        => "- Verify in-app auto-update from v1.0.4 to v1.0.5",
        'mandatory'    => false,
    ],
    [
        'version_name' => '1.0.6',
        'version_code' => 7,
        'update_url'   => 'https://github.com/Caretel/dabaindia-app-releases/releases/download/v1.0.6/dabaindia-attendance-v1.0.6.apk',
        'notes'        => "- Fix package installer with REQUEST_INSTALL_PACKAGES permission handler",
        'mandatory'    => false,
    ],
    [
        'version_name' => '1.0.7',
        'version_code' => 8,
        'update_url'   => 'https://github.com/Caretel/dabaindia-app-releases/releases/download/v1.0.7/dabaindia-attendance-v1.0.7.apk',
        'notes'        => "- Verify in-app auto-update from v1.0.6 to v1.0.7 (resolves signature conflict)",
        'mandatory'    => false,
    ],
    // --- ADD NEW RELEASES ABOVE THIS LINE ---
    // Example for next release:
    // [
    //     'version_name' => '1.0.2',
    //     'version_code' => 3,
    //     'update_url'   => 'https://github.com/Caretel/dabaindia-app-releases/releases/download/v1.0.2/app-release.apk',
    //     'notes'        => "- New feature X\n- Fixed Y",
    //     'mandatory'    => false,
    // ],
];

// ============================================================
// DO NOT EDIT BELOW THIS LINE
// ============================================================

// Get the latest release (last in array)
$latest = end($releases);

// Get current version from query parameter sent by the app
$current_version = isset($_GET['version']) ? trim($_GET['version']) : '0.0.0';

// Parse version codes by matching version_name to the releases array
$current_code = 0;
foreach ($releases as $release) {
    if ($release['version_name'] === $current_version) {
        $current_code = $release['version_code'];
        break;
    }
}

// Fallback: if version not found, try to extract build number from version string
// e.g. the app sends versionName from pubspec (e.g. "1.0.1")
if ($current_code === 0) {
    // Try numeric comparison on version string parts
    $current_parts = explode('.', $current_version);
    $latest_parts  = explode('.', $latest['version_name']);
    
    $is_older = false;
    for ($i = 0; $i < max(count($current_parts), count($latest_parts)); $i++) {
        $c = isset($current_parts[$i]) ? (int)$current_parts[$i] : 0;
        $l = isset($latest_parts[$i])  ? (int)$latest_parts[$i]  : 0;
        if ($c < $l) { $is_older = true; break; }
        if ($c > $l) { break; }
    }
    
    echo json_encode([
        'success' => true,
        'data'    => [
            'has_update'  => $is_older,
            'version'     => $latest['version_name'],
            'version_code'=> $latest['version_code'],
            'update_url'  => $latest['update_url'],
            'notes'       => $latest['notes'],
            'mandatory'   => $latest['mandatory'],
        ]
    ]);
    exit;
}

// Compare version codes
$has_update = $latest['version_code'] > $current_code;

echo json_encode([
    'success' => true,
    'data'    => [
        'has_update'   => $has_update,
        'version'      => $latest['version_name'],
        'version_code' => $latest['version_code'],
        'update_url'   => $latest['update_url'],
        'notes'        => $latest['notes'],
        'mandatory'    => $latest['mandatory'],
    ]
]);
