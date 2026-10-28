<?php
// Use WordPress's own installer without passing passwords in argv or stdout.
define('WP_INSTALLING', true);
require '/var/www/html/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/upgrade.php';
add_filter('pre_wp_mail', '__return_false');
if (!is_blog_installed()) {
    $result = wp_install(
        getenv('WP_TITLE'),
        getenv('WP_ADMIN_USER'),
        getenv('WP_ADMIN_EMAIL'),
        true,
        '',
        trim(file_get_contents('/run/secrets/wp_admin_password'))
    );
    if (is_wp_error($result)) {
        WP_CLI::error('WordPress installation failed; inspect database connectivity.');
    }
    WP_CLI::success('WordPress installed.');
}
if (!username_exists(getenv('WP_USER'))) {
    $result = wp_insert_user([
        'user_login' => getenv('WP_USER'),
        'user_email' => getenv('WP_USER_EMAIL'),
        'user_pass' => trim(file_get_contents('/run/secrets/wp_user_password')),
        'role' => 'editor',
    ]);
    if (is_wp_error($result)) {
        WP_CLI::error('Regular user creation failed; check the configured username and email.');
    }
    WP_CLI::success('Regular user created.');
}
