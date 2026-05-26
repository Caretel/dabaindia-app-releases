<?php
/**
 * api/auth.php — Mobile Authentication API
 * 
 * Actions:
 *   POST ?action=login         — Login with EID + password + device_id
 *   POST ?action=logout        — Invalidate session token
 *   GET  ?action=profile       — Get current user profile (requires token)
 *   GET  ?action=check_update  — Check if a newer app version is available
 */
ob_start();
header('Content-Type: application/json');
date_default_timezone_set('Asia/Kolkata');

require_once __DIR__ . '/../config.php';

// ── Helper ──
function jout($data) {
    if (ob_get_length()) ob_clean();
    echo json_encode($data);
    exit;
}

// ── Parse input ──
$act = $_GET['action'] ?? '';
$rawBody = file_get_contents('php://input');
$contentType = strtolower($_SERVER['CONTENT_TYPE'] ?? '');

if (strpos($contentType, 'application/json') !== false) {
    $reqData = json_decode($rawBody, true) ?: [];
} else {
    parse_str($rawBody, $parsed);
    $reqData = !empty($parsed) ? $parsed : $_POST;
}

// Merge GET params as fallback
function rget($reqData, $key, $default = '') {
    return $reqData[$key] ?? $_POST[$key] ?? $_GET[$key] ?? $default;
}

// ── Token generation ──
function generateToken() {
    return bin2hex(random_bytes(64)); // 128-char hex token
}

// ── Validate a bearer token and return the employee_id ──
function validateToken($conn) {
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (empty($header)) {
        // Also check X-Auth-Token header (some clients prefer this)
        $header = $_SERVER['HTTP_X_AUTH_TOKEN'] ?? '';
    }

    $token = '';
    if (strpos($header, 'Bearer ') === 0) {
        $token = substr($header, 7);
    } else {
        $token = $header;
    }

    // Also allow token via query string (fallback for testing)
    if (empty($token)) {
        $token = $_GET['token'] ?? '';
    }

    if (empty($token)) {
        jout(['success' => false, 'error' => 'No auth token provided. Send via Authorization: Bearer <token> header.']);
    }

    $st = $conn->prepare("SELECT employee_id, expires_at FROM mobile_sessions WHERE token = ?");
    $st->bind_param("s", $token);
    $st->execute();
    $row = $st->get_result()->fetch_assoc();
    $st->close();

    if (!$row) {
        jout(['success' => false, 'error' => 'Invalid or expired token. Please login again.']);
    }

    // Check expiry
    if (strtotime($row['expires_at']) < time()) {
        // Clean up expired token
        $del = $conn->prepare("DELETE FROM mobile_sessions WHERE token = ?");
        $del->bind_param("s", $token);
        $del->execute();
        $del->close();
        jout(['success' => false, 'error' => 'Session expired. Please login again.']);
    }

    return (int)$row['employee_id'];
}


// ══════════════════════════════════════════
//  ACTION ROUTER
// ══════════════════════════════════════════
switch ($act) {

    // ── LOGIN ──────────────────────────────────────
    case 'login':
        $eid      = trim(rget($reqData, 'eid', ''));
        $password = trim(rget($reqData, 'password', ''));
        $deviceId = trim(rget($reqData, 'device_id', ''));
        $fcmToken = trim(rget($reqData, 'fcm_token', ''));

        if (!$eid || !$password) {
            jout(['success' => false, 'error' => 'EID and password are required.']);
        }

        // 1. Find user
        $st = $conn->prepare("SELECT * FROM employees WHERE eid = ?");
        $st->bind_param("s", $eid);
        $st->execute();
        $user = $st->get_result()->fetch_assoc();
        $st->close();

        if (!$user) {
            jout(['success' => false, 'error' => "User ID '$eid' not found."]);
        }

        // 2. Verify password
        $dbpass = $user['password'] ?? '';
        if (!password_verify($password, $dbpass)) {
            jout(['success' => false, 'error' => 'Incorrect password.']);
        }

        // 3. Device binding (Employees only — Admins/Managers skip)
        $role = $user['role'] ?? 'Employee';
        if ($role === 'Employee') {
            $dbDeviceToken = $user['device_token'] ?? null;

            if (empty($dbDeviceToken)) {
                // First login ever — bind this device
                if (!empty($deviceId)) {
                    $upd = $conn->prepare("UPDATE employees SET device_token = ? WHERE id = ?");
                    $upd->bind_param("si", $deviceId, $user['id']);
                    $upd->execute();
                    $upd->close();
                }
            } else {
                // Device is already bound — check match
                if (!empty($deviceId) && $deviceId !== $dbDeviceToken) {
                    jout(['success' => false, 'error' => '🚫 Access Denied: This account is bound to another device. Contact Admin to reset.']);
                }
            }
        }

        // 4. Update FCM token if provided
        if (!empty($fcmToken)) {
            $upd = $conn->prepare("UPDATE employees SET fcm_token = ? WHERE id = ?");
            $upd->bind_param("si", $fcmToken, $user['id']);
            $upd->execute();
            $upd->close();
        }

        // 5. Cleanup old sessions for this user
        $del = $conn->prepare("DELETE FROM mobile_sessions WHERE employee_id = ?");
        $del->bind_param("i", $user['id']);
        $del->execute();
        $del->close();

        // 6. Create new session token (valid 30 days)
        $token = generateToken();
        $expiresAt = date('Y-m-d H:i:s', strtotime('+30 days'));
        $did = $deviceId ?: 'unknown';

        $ins = $conn->prepare("INSERT INTO mobile_sessions (employee_id, token, device_id, expires_at) VALUES (?, ?, ?, ?)");
        $ins->bind_param("isss", $user['id'], $token, $did, $expiresAt);
        $ins->execute();
        $ins->close();

        // 7. Fetch shop info
        $shopName = null;
        $shopLat = null;
        $shopLng = null;
        $shopRadius = null;
        if ($user['shop_id']) {
            $ss = $conn->prepare("SELECT name, latitude, longitude, geofence_radius FROM shops WHERE id = ?");
            $ss->bind_param("i", $user['shop_id']);
            $ss->execute();
            $shopRow = $ss->get_result()->fetch_assoc();
            $shopName = $shopRow['name'] ?? null;
            $shopLat = $shopRow['latitude'] ?? null;
            $shopLng = $shopRow['longitude'] ?? null;
            $shopRadius = $shopRow['geofence_radius'] ?? 50;
            $ss->close();
        }

        // 8. Get current check-in status
        $checkedIn = false;
        $stAtt = $conn->prepare("SELECT id FROM attendance WHERE employee_id = ? AND check_out IS NULL ORDER BY id DESC LIMIT 1");
        $stAtt->bind_param("i", $user['id']);
        $stAtt->execute();
        $stAtt->store_result();
        $checkedIn = ($stAtt->num_rows > 0);
        $stAtt->close();

        jout([
            'success'  => true,
            'token'    => $token,
            'expires'  => $expiresAt,
            'employee' => [
                'id'             => $user['id'],
                'eid'            => $user['eid'],
                'name'           => $user['name'],
                'role'           => $role,
                'shop_id'             => $user['shop_id'],
                'shop_name'           => $shopName,
                'shop_lat'            => $shopLat,
                'shop_lng'            => $shopLng,
                'shop_geofence_radius'=> $shopRadius,
                'weekly_off_day'      => (int)($user['weekly_off_day'] ?? 0),
                'checked_in'          => $checkedIn,
            ]
        ]);
        break;


    // ── LOGOUT ─────────────────────────────────────
    case 'logout':
        $uid = validateToken($conn);
        $header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['HTTP_X_AUTH_TOKEN'] ?? '';
        $token = (strpos($header, 'Bearer ') === 0) ? substr($header, 7) : ($header ?: ($_GET['token'] ?? ''));

        $del = $conn->prepare("DELETE FROM mobile_sessions WHERE token = ?");
        $del->bind_param("s", $token);
        $del->execute();
        $del->close();

        jout(['success' => true, 'message' => 'Logged out successfully.']);
        break;


    // ── PROFILE ────────────────────────────────────
    case 'profile':
        $uid = validateToken($conn);

        $st = $conn->prepare("SELECT id, eid, name, role, shop_id, weekly_off_day FROM employees WHERE id = ?");
        $st->bind_param("i", $uid);
        $st->execute();
        $user = $st->get_result()->fetch_assoc();
        $st->close();

        if (!$user) jout(['success' => false, 'error' => 'User not found.']);

        // Shop name
        $shopName = null;
        $shopLat = null;
        $shopLng = null;
        $shopRadius = null;
        if ($user['shop_id']) {
            $ss = $conn->prepare("SELECT name, latitude, longitude, geofence_radius FROM shops WHERE id = ?");
            $ss->bind_param("i", $user['shop_id']);
            $ss->execute();
            $shopRow = $ss->get_result()->fetch_assoc();
            $shopName = $shopRow['name'] ?? null;
            $shopLat = $shopRow['latitude'] ?? null;
            $shopLng = $shopRow['longitude'] ?? null;
            $shopRadius = $shopRow['geofence_radius'] ?? 50;
            $ss->close();
        }

        // Check-in status
        $stAtt = $conn->prepare("SELECT id FROM attendance WHERE employee_id = ? AND check_out IS NULL ORDER BY id DESC LIMIT 1");
        $stAtt->bind_param("i", $uid);
        $stAtt->execute();
        $stAtt->store_result();
        $checkedIn = ($stAtt->num_rows > 0);
        $stAtt->close();

        jout([
            'success'  => true,
            'employee' => [
                'id'             => $user['id'],
                'eid'            => $user['eid'],
                'name'           => $user['name'],
                'role'           => $user['role'],
                'shop_id'             => $user['shop_id'],
                'shop_name'           => $shopName,
                'shop_lat'            => $shopLat,
                'shop_lng'            => $shopLng,
                'shop_geofence_radius'=> $shopRadius,
                'weekly_off_day'      => (int)($user['weekly_off_day'] ?? 0),
                'checked_in'          => $checkedIn,
            ]
        ]);
        break;


    // ── CHECK UPDATE ───────────────────────────────
    case 'check_update':
        // ============================================================
        // RELEASE REGISTRY — Add a new entry here for every new release
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
            // --- ADD NEW RELEASES ABOVE THIS LINE ---
            // Example for next release:
            // [
            //     'version_name' => '1.0.2',
            //     'version_code' => 3,
            //     'update_url'   => 'https://github.com/Caretel/dabaindia-app-releases/releases/download/v1.0.2/dabaindia-attendance-v1.0.2.apk',
            //     'notes'        => "- New feature\n- Bug fixes",
            //     'mandatory'    => false,
            // ],
        ];

        // Get the latest release (last entry in array)
        $latest = end($releases);

        // Get version sent by the app
        $current_version = isset($_GET['version']) ? trim($_GET['version']) : '0.0.0';

        // Compare version strings numerically (e.g. "1.0.0" vs "1.0.1")
        $current_parts = explode('.', $current_version);
        $latest_parts  = explode('.', $latest['version_name']);
        $is_older = false;
        for ($i = 0; $i < max(count($current_parts), count($latest_parts)); $i++) {
            $c = isset($current_parts[$i]) ? (int)$current_parts[$i] : 0;
            $l = isset($latest_parts[$i])  ? (int)$latest_parts[$i]  : 0;
            if ($c < $l) { $is_older = true; break; }
            if ($c > $l) { break; }
        }

        jout([
            'success' => true,
            'data'    => [
                'has_update'   => $is_older,
                'version'      => $latest['version_name'],
                'version_code' => $latest['version_code'],
                'update_url'   => $latest['update_url'],
                'notes'        => $latest['notes'],
                'mandatory'    => $latest['mandatory'],
            ]
        ]);
        break;


    default:
        jout(['success' => false, 'error' => 'Unknown action: ' . htmlspecialchars($act)]);
}
