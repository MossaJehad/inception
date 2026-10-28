<?php
// Secret stays in a runtime file, outside the shared document root.
define('DB_NAME', getenv('DB_NAME'));
define('DB_USER', getenv('DB_USER'));
define('DB_PASSWORD', trim(file_get_contents('/run/wordpress/db_password')));
define('DB_HOST', 'mariadb:3306');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');
$port = getenv('HTTPS_PORT') ?: '443';
define('WP_HOME', 'https://' . getenv('DOMAIN_NAME') . ($port === '443' ? '' : ':' . $port));
define('WP_SITEURL', WP_HOME);
define('FORCE_SSL_ADMIN', true);
define('DISALLOW_FILE_EDIT', true);
define('WP_DEBUG', false);
define('WP_ENVIRONMENT_TYPE', 'local');
if (!empty($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
}
require __DIR__ . '/.inception/salts.php';
$table_prefix = 'wp_';
if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}
require_once ABSPATH . 'wp-settings.php';
