#!/usr/bin/env python3
"""Disposable fresh-source acceptance test. Never operates on normal project volumes."""
import base64
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import socket
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.parse

ROOT = Path(__file__).resolve().parents[3]
SERVICES = ('mariadb', 'wordpress', 'nginx', 'static_site')
SECRET_NAMES = ('db_password', 'db_root_password', 'wp_admin_password', 'wp_user_password')
RESULTS = []


def run(args, cwd=ROOT, env=None, data=None, check=True, timeout=600):
    result = subprocess.run(args, cwd=cwd, env=env, input=data, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, timeout=timeout)
    if check and result.returncode:
        # Do not dump command input, SQL, cookie jars, or unreviewed logs.
        raise RuntimeError(f'{args[0]} {args[1] if len(args) > 1 else ""} failed (exit {result.returncode}); inspect the private fixture logs')
    return result


def passed(name):
    RESULTS.append({'test': name, 'result': 'PASS'})
    print(f'PASS  {name}', flush=True)


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    for command in ('docker', 'make', 'openssl', 'git', 'curl'):
        require(shutil.which(command), f'Missing host prerequisite: {command}')
    run(['docker', 'info'])
    # /tmp is a local Linux filesystem here; TMPDIR may point at an NFS share
    # whose ownership semantics cannot support container database storage.
    workspace = Path(tempfile.mkdtemp(prefix='inception-verify-', dir='/tmp'))
    checkout = workspace / 'checkout'
    checkout.mkdir()
    # Include the candidate implementation, including new nonignored files, without
    # committing it or copying local secrets, .env, caches, or runtime data.
    names = run(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard']).stdout.split(b'\0')
    for raw in names:
        if not raw:
            continue
        relative = Path(os.fsdecode(raw))
        source = ROOT / relative
        if source.is_file():
            require(not source.is_symlink(), 'Source export refuses symlinks')
            destination = checkout / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
    require(not (checkout / 'srcs/.env').exists() and not (checkout / 'secrets').exists(),
            'Fresh source export contains local configuration')
    token = secrets.token_hex(5)
    project = f'inception-test-{token}'
    prefix = f'inception_test_{token}_'
    with socket.socket() as reservation:
        reservation.bind(('127.0.0.1', 0))
        port = reservation.getsockname()[1]
    env = os.environ.copy()
    # Clear application overrides so this test cannot inherit personal settings.
    for line in (checkout / 'srcs/.env.example').read_text().splitlines():
        if '=' in line and not line.startswith('#'):
            env.pop(line.split('=', 1)[0], None)
    env.update(COMPOSE_PROJECT_NAME=project, VOLUME_PREFIX=prefix,
               DATA_DIR=str(workspace / 'data'), HTTPS_PORT=str(port), BUILDKIT_PROGRESS='plain')
    dc = ['docker', 'compose', '--env-file', 'srcs/.env', '-f', 'srcs/docker-compose.yml']
    domain = 'mhasoneh.42.fr'
    log = workspace / 'commands.log'
    log.touch(mode=0o600)

    def call(args, **kwargs):
        check = kwargs.pop('check', True)
        result = run(args, cwd=checkout, env=env, check=False, **kwargs)
        with log.open('ab') as stream:
            stream.write(result.stdout + result.stderr)
        if check and result.returncode:
            raise RuntimeError(f'{args[0]} failed (exit {result.returncode}); diagnostic output: {log}')
        return result

    def make(*targets, check=True):
        return call(['make', *targets], check=check)

    def compose(*args, **kwargs):
        return call([*dc, *args], **kwargs)

    def execute(service, *args, **kwargs):
        return compose('exec', '-T', service, *args, **kwargs)

    def wp(*args):
        return execute('wordpress', 'wp', '--allow-root', '--no-color', *args).stdout.strip()

    def ids():
        return compose('ps', '-a', '-q').stdout.decode().split()

    def inspect():
        return json.loads(call(['docker', 'inspect', *ids()]).stdout)

    def healthy():
        compose('up', '-d', '--wait', '--wait-timeout', '180')
        require(len(ids()) == 4, 'Expected exactly four containers')
        require(all(c['State']['Health']['Status'] == 'healthy' for c in inspect()), 'Unhealthy service')

    def http(path, status=200):
        result = execute('nginx', 'curl', '-kSs', '--noproxy', '*', '--resolve',
                         f'{domain}:443:127.0.0.1', '-H', f'Host: {domain}:{port}', '-w', '\n%{http_code}', f'https://{domain}{path}')
        body, code = result.stdout.rsplit(b'\n', 1)
        require(int(code) == status, f'Unexpected HTTP status at {path}: {code.decode()}')
        return body

    succeeded = False
    try:
        print(f'Private isolated fixture: {workspace}', flush=True)
        make()
        model = json.loads(compose('config', '--format', 'json').stdout)
        require(set(model['services']) == set(SERVICES), 'Unexpected services')
        require(set(model['volumes']) == {'mariadb_data', 'wordpress_data'}, 'Unexpected persistent storage')
        for service, config in model['services'].items():
            require(config['image'] == f'{service}:inception' and 'build' in config, 'Image/build mismatch')
            root = Path(config['build']['context'])
            require((root / 'Dockerfile').read_text().startswith('FROM debian:12.15-slim\n'), 'Unexpected base image')
            require(':latest' not in (root / 'Dockerfile').read_text(), 'Forbidden image tag')
        passed('Fresh source: make builds all four service images and validates Compose')
        config_bytes = (checkout / 'srcs/.env').read_bytes()
        passwords = [(checkout / 'secrets' / f'{name}.txt').read_bytes().strip() for name in SECRET_NAMES]
        require(len(set(passwords)) == 4 and all(re.fullmatch(b'[a-f0-9]{64}', p) for p in passwords), 'Invalid secrets')
        require((checkout / 'secrets').stat().st_mode & 0o777 == 0o700, 'Secret directory mode')
        for name in SECRET_NAMES:
            require((checkout / 'secrets' / f'{name}.txt').stat().st_mode & 0o777 == 0o600, 'Secret file mode')
        require((checkout / 'srcs/.env').stat().st_mode & 0o777 == 0o600, 'Environment file mode')
        require(not any(p in config_bytes for p in passwords), 'Password stored in .env')
        make('setup')
        require((checkout / 'srcs/.env').read_bytes() == config_bytes, 'Existing .env changed')
        passed('Automatic setup: secure, unique secrets; permissions; configuration preserved')
        healthy()
        passed('MariaDB, WordPress, NGINX, and portfolio healthchecks')

        records = inspect()
        expected_pid = {'mariadb': 'mariadbd', 'wordpress': 'php-fpm8.2', 'nginx': 'nginx', 'static_site': 'docker-init'}
        for item in records:
            service = item['Config']['Labels']['com.docker.compose.service']
            require(not item['HostConfig']['Privileged'], 'Privileged container')
            require(item['HostConfig']['RestartPolicy']['Name'] == 'unless-stopped', 'Restart policy')
            require(set(item['NetworkSettings']['Networks']) == {f'{project}_inception'}, 'Network membership')
            bindings = item['HostConfig'].get('PortBindings') or {}
            require((set(bindings) == {'443/tcp'} and bindings['443/tcp'][0]['HostPort'] == str(port))
                    if service == 'nginx' else not bindings, 'Unexpected published ports')
            require(execute(service, 'cat', '/proc/1/comm').stdout.strip().decode() == expected_pid[service], 'Wrong PID 1')
            require(execute(service, 'cat', '/etc/debian_version').stdout.strip() == b'12.15', 'Wrong Debian release')
            for mount in item['Mounts']:
                if mount['Destination'] in ('/var/lib/mysql', '/var/www/html'):
                    require(mount['Type'] == 'volume', 'Direct service data bind mount')
                    if service == 'nginx':
                        require(not mount['RW'], 'NGINX document root is writable')
        network = json.loads(call(['docker', 'network', 'inspect', f'{project}_inception']).stdout)[0]
        require(network['Driver'] == 'bridge' and len(network['Containers']) == 4, 'Bridge network')
        for service in ('mariadb', 'nginx', 'static_site'):
            execute('wordpress', 'getent', 'hosts', service)
        for service in ('mariadb', 'wordpress'):
            volume = json.loads(call(['docker', 'volume', 'inspect', f'{prefix}{service}_data']).stdout)[0]
            require(volume['Driver'] == 'local' and volume['Options']['device'] == str(workspace / 'data' / service), 'Volume host location')
        passed('Network, service DNS, image names, PID 1, restart policies, and named-volume locations')

        require(b'Inception' in http('/'), 'WordPress homepage missing')
        require(b'wp-submit' in http('/wp-login.php'), 'WordPress login page missing')
        users = json.loads(wp('user', 'list', '--fields=user_login,roles', '--format=json'))
        require({u['user_login']: u['roles'] for u in users} == {'mhasoneh': 'administrator', 'editor42': 'editor'}, 'WordPress users/roles')
        wp('eval', 'foreach (["mhasoneh"=>"wp_admin_password","editor42"=>"wp_user_password"] as $login=>$secret) {$u=get_user_by("login",$login); if (!$u || !wp_check_password(trim(file_get_contents("/run/secrets/".$secret)), $u->user_pass, $u->ID)) {WP_CLI::error("Password verification failed");}}')
        cookie = '/tmp/inception-verify.cookies'
        execute('nginx', 'curl', '-fkSs', '--noproxy', '*', '--resolve', f'{domain}:443:127.0.0.1',
                '-H', f'Host: {domain}:{port}', '-c', cookie, '-o', '/dev/null', f'https://{domain}/wp-login.php')
        payload = urllib.parse.urlencode({'log': 'mhasoneh', 'pwd': passwords[2].decode(),
                                         'wp-submit': 'Log In', 'redirect_to': f'https://{domain}:{port}/wp-admin/', 'testcookie': '1'}).encode()
        response = execute('nginx', 'curl', '-kSs', '--noproxy', '*', '--resolve', f'{domain}:443:127.0.0.1',
                           '-H', f'Host: {domain}:{port}', '-b', cookie, '-c', cookie, '--data-binary', '@-', '-o', '/dev/null', '-w', '%{http_code}',
                           f'https://{domain}/wp-login.php', data=payload).stdout
        require(response == b'302', 'Administrator HTTP login failed')
        dashboard = execute('nginx', 'curl', '-fkSs', '--noproxy', '*', '--resolve', f'{domain}:443:127.0.0.1',
                            '-H', f'Host: {domain}:{port}', '-b', cookie, f'https://{domain}/wp-admin/').stdout
        require(b'Dashboard' in dashboard, 'Authenticated administration not accessible')
        execute('nginx', 'rm', '-f', cookie)
        execute('mariadb', 'mariadb', '--defaults-extra-file=/run/mysqld/root.cnf', '-e', 'SELECT 1')
        denied = execute('mariadb', 'mariadb', '--user=root', '-e', 'SELECT 1', check=False)
        require(denied.returncode != 0, 'Root accepts an empty password')
        accounts = execute('mariadb', 'mariadb', '--defaults-extra-file=/run/mysqld/root.cnf', '-N', '-e',
                           "SELECT COUNT(*) FROM mysql.global_priv WHERE User='' OR (User='root' AND Host<>'localhost')").stdout.strip()
        require(accounts == b'0', 'Insecure database accounts')
        grants = execute('mariadb', 'mariadb', '--defaults-extra-file=/run/mysqld/root.cnf', '-N', '-e',
                         "SHOW GRANTS FOR 'wpuser'@'%'").stdout
        require(b'ON `wordpress`.*' in grants and b'GRANT ALL PRIVILEGES ON *.*' not in grants
                and b'WITH GRANT OPTION' not in grants, 'Database user privileges exceed its database')
        passed('WordPress homepage, administrator HTTP login, both account passwords/roles, and secured MariaDB')

        require(b'Solid foundations' in http('/portfolio/'), 'Portfolio missing')
        require(b'--accent' in http('/portfolio/style.css'), 'Portfolio CSS missing')
        require(b'getFullYear' in http('/portfolio/script.js'), 'Portfolio JavaScript missing')
        http('/portfolio', 301)
        for path in ('/wp-config.php', '/.env', '/.inception/salts.php', '/xmlrpc.php', '/wp-content/uploads/blocked.php'):
            http(path, 403)
        http('/missing-script.php', 404)
        external = call(['curl', '-fkSs', '--noproxy', '*', '--resolve', f'{domain}:{port}:127.0.0.1', f'https://{domain}:{port}/portfolio/']).stdout
        require(b'mhasoneh' in external, 'Published HTTPS endpoint unavailable')
        passed('Portfolio HTML/CSS/JavaScript, HTTPS host endpoint, and sensitive-file access controls')

        for protocol in ('tls1_2', 'tls1_3', 'tls1', 'tls1_1'):
            connection = call(['openssl', 's_client', '-connect', f'127.0.0.1:{port}', '-servername', domain,
                               f'-{protocol}', '-cipher', 'DEFAULT:@SECLEVEL=0'], data=b'', check=False)
            combined = connection.stdout + connection.stderr
            if protocol in ('tls1_2', 'tls1_3'):
                require(connection.returncode == 0 and b'Cipher is (NONE)' not in combined, f'{protocol} handshake failed')
            else:
                require(connection.returncode != 0 and b'alert protocol version' in combined, f'{protocol} not rejected by server')
        certificate = execute('nginx', 'cat', '/etc/nginx/tls/server.crt').stdout
        certpath = workspace / 'server.crt'
        certpath.write_bytes(certificate)
        call(['openssl', 'verify', '-CAfile', str(certpath), '-verify_hostname', domain, str(certpath)])
        passed('TLS 1.2/1.3 accepted, TLS 1.0/1.1 rejected; certificate validity and domain SAN')

        post = wp('post', 'create', '--post_title=Persistence acceptance test', '--post_content=Persistent Inception content', '--post_status=publish', '--porcelain').decode()
        png = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII=')
        execute('wordpress', 'tee', '/tmp/inception-verify.png', data=png)
        # Use the PHP worker's UID so upload ownership matches an actual web upload.
        attachment = compose('exec', '-T', '--user', 'www-data', 'wordpress', 'wp', '--no-color',
                             'media', 'import', '/tmp/inception-verify.png', '--porcelain').stdout.strip().decode()
        media = wp('post', 'meta', 'get', attachment, '_wp_attached_file').decode()

        def persistence():
            require(wp('post', 'get', post, '--field=post_content') == b'Persistent Inception content', 'Post lost')
            require(http('/wp-content/uploads/' + media) == png, 'Uploaded media lost')
            current = [(checkout / 'secrets' / f'{name}.txt').read_bytes().strip() for name in SECRET_NAMES]
            require(current == passwords, 'Credentials changed')

        persistence()
        make('restart')
        healthy()
        persistence()
        passed('Post, uploaded media, and credentials persist across restart')
        make('down')
        make()
        healthy()
        persistence()
        passed('Post, uploaded media, and credentials persist across container removal and repeated make')
        make('stop')
        make('start')
        persistence()
        make('clean')
        make('up')
        persistence()
        passed('Make stop/start/clean/up lifecycle preserves persistent data')
        make('re')
        persistence()
        passed('Make re rebuilds without deleting data or changing credentials')

        instance = next(c for c in inspect() if c['Config']['Labels']['com.docker.compose.service'] == 'wordpress')
        # docker kill marks a deliberate operator action; signal the daemon from
        # inside instead, so the restart policy sees an unexpected process exit.
        execute('wordpress', 'sh', '-c', 'kill -TERM 1', check=False)
        for attempt in range(60):
            state = json.loads(call(['docker', 'inspect', instance['Id']]).stdout)[0]
            if state['RestartCount'] > 0 and state['State'].get('Health', {}).get('Status') == 'healthy':
                break
            time.sleep(1)
        else:
            raise RuntimeError('Crash restart did not recover')
        persistence()
        passed('Unexpected PHP-FPM process termination restarts automatically and preserves data')

        missing = checkout / 'secrets/wp_admin_password.txt'
        original = missing.read_bytes()
        missing.unlink()
        refusal = make('setup', check=False)
        require(refusal.returncode != 0 and not missing.exists(), 'Lost secret silently regenerated beside data')
        missing.write_bytes(original)
        missing.chmod(0o600)
        refusal = make('fclean', check=False)
        require(refusal.returncode != 0, 'Destructive cleanup lacks explicit opt-in')
        persistence()
        passed('Lost-secret recovery protection and destructive-cleanup guard')

        runtime_logs = compose('logs', '--no-color').stdout
        metadata = b''.join(call(['docker', 'history', '--no-trunc', f'{s}:inception']).stdout for s in SERVICES)
        metadata += json.dumps(inspect()).encode()
        require(not any(p in runtime_logs + metadata + log.read_bytes() for p in passwords), 'Password exposed in logs or metadata')
        require(execute('wordpress', 'stat', '-c', '%a', '/var/www/html/wp-config.php').stdout.strip() == b'640', 'wp-config permissions')
        require(execute('nginx', 'stat', '-c', '%a', '/etc/nginx/tls/server.key').stdout.strip() == b'600', 'TLS key permissions')
        archive = workspace / 'images.tar'
        call(['docker', 'image', 'save', '-o', str(archive), *[f'{s}:inception' for s in SERVICES]])
        with tarfile.open(archive) as images:
            for entry in images:
                if not entry.isfile():
                    continue
                stream = images.extractfile(entry)
                head = stream.read(2)
                stream = io.BufferedReader(io.BytesIO(head + stream.read())) if entry.size < 4096 else io.BufferedReader(stream)
                # Larger entries need the two peeked bytes restored without loading whole layers.
                if entry.size >= 4096:
                    stream.close()
                    stream = images.extractfile(entry)
                reader = gzip.GzipFile(fileobj=stream) if head == b'\x1f\x8b' else stream
                previous = b''
                for chunk in iter(lambda: reader.read(1024 * 1024), b''):
                    combined = previous + chunk
                    require(not any(p in combined for p in passwords), 'Secret found in image layer archive')
                    previous = combined[-128:]
        archive.unlink()
        passed('No generated secrets in startup logs, container metadata, image history, or exported image layers')
        make('fclean', 'CONFIRM=DELETE')
        require(not (checkout / 'srcs/.env').exists() and not (checkout / 'secrets').exists(), 'fclean left generated configuration')
        require(all(not (workspace / 'data' / s).exists() or not any((workspace / 'data' / s).iterdir()) for s in ('mariadb', 'wordpress')), 'fclean left data')
        require(all(call(['docker', 'volume', 'inspect', f'{prefix}{s}_data'], check=False).returncode != 0 for s in ('mariadb', 'wordpress')), 'fclean left volumes')
        passed('Explicit fclean erases only the disposable stack, including host-backed volume contents')
        succeeded = True
    finally:
        report_dir = ROOT / '.cache'
        report_dir.mkdir(exist_ok=True)
        (report_dir / 'verification.json').write_text(json.dumps({'fixture': str(workspace), 'results': RESULTS, 'completed': succeeded}, indent=2) + '\n')
        if succeeded:
            shutil.rmtree(workspace)
            print('Disposable environment removed. Normal stack untouched.', flush=True)
        else:
            print(f'FAILED. Private diagnostic fixture retained at {workspace}; no normal data was changed.', file=sys.stderr)


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, subprocess.TimeoutExpired) as error:
        print(f'FAIL  {error}', file=sys.stderr)
        sys.exit(1)
