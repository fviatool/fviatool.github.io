<?php
function getClientIP() {
    if (!empty($_SERVER['HTTP_CLIENT_IP'])) return $_SERVER['HTTP_CLIENT_IP'];
    if (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) return explode(',', $_SERVER['HTTP_X_FORWARDED_FOR'])[0];
    return $_SERVER['REMOTE_ADDR'] ?? 'UNKNOWN';
}

function getIPInfo($ip) {
    $apis = [
        "https://ipapi.co/$ip/json/",
        "https://ipwho.is/$ip",
        "https://ipinfo.io/$ip/json?token=demo"
    ];
    foreach ($apis as $url) {
        $json = @file_get_contents($url);
        if ($json) {
            $data = json_decode($json, true);
            if (!isset($data['error'])) return $data;
        }
    }
    return ['ip' => $ip, 'error' => 'Không thể lấy dữ liệu IP'];
}

$ip = $_GET['ip'] ?? getClientIP();
$info = getIPInfo($ip);

header('Content-Type: application/json; charset=utf-8');
echo json_encode($info, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
