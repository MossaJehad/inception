# Implementation and validation report

Validation date: **2026-10-28**. Source requirements: the complete repository
`inception_subject.txt`, version **5.4**. No separate official evaluation checklist
was available. Confirm the currently assigned Intra subject before defense.

## Environment and scope

- Local Linux; Docker Engine **29.7.2**, rootless; Compose **v5.5.0**.
- All images: **debian:12.15-slim**. Pulled and inspected `/etc/debian_version`.
  Debian's official release index identifies 13 as stable and 12 as oldstable:
  [Debian releases](https://www.debian.org/releases/), checked 2026-10-28.
- WordPress **7.1.3**, WP-CLI **2.12.0**, PHP **8.2**, MariaDB **10.11**.
- The local host restricts ports below 1024. Normal local configuration uses 8443;
  the committed default is 443. Inside NGINX, all TLS tests use port 443.
- The fresh-source suite exports the candidate tracked/nonignored files into a
  private source directory with no .env/secrets, then invokes the real `make`.
  It uses a unique project, volume prefix, data directory, and high host port.
  It does not delete the normal stack's data. Temporary test resources were removed.
- The final `make test` completed all **15 test groups** successfully. Its generated
  machine-readable summary is ignored at `.cache/verification.json`.

## Executed checks

| Check | Result | Evidence / scope |
| --- | --- | --- |
| Complete local subject read before implementation | PASS | Version 5.4, all chapters; scaffold and Git status inspected |
| Separate official evaluation sheet | NOT TESTED | Not supplied |
| Compose syntax | PASS | `docker compose config`, parsed model validation |
| Four custom builds; own Dockerfile per service | PASS | Actual builds, including uncached `make re` |
| Image names equal service names | PASS | `<service>:inception` in Compose and running configuration |
| Penultimate Debian release; no latest tag | PASS | Official release index, Dockerfile checks, runtime Debian version |
| No prebuilt application images | PASS | All four builds start from official Debian only |
| Dedicated MariaDB container without NGINX | PASS | Dockerfile/service audit; real mariadbd PID 1 |
| Automatic database and dedicated user | PASS | Fresh initialization and WordPress connection |
| Database-scoped grants, no grant option | PASS | Authenticated `SHOW GRANTS` check |
| Root password and no anonymous/remote-root users | PASS | Authenticated query succeeds; empty root password denied; account-table query |
| Database data survives restart/recreation | PASS | Persistent WordPress post retained |
| Dedicated WordPress/PHP-FPM container without NGINX | PASS | Dockerfile/service audit; real FPM PID 1 |
| Automatic WordPress install | PASS | Blank volumes initialized by `make` |
| Required users and administrator name rule | PASS | `mhasoneh` administrator; `editor42` editor; role/password checks |
| Administrator HTTP login | PASS | Real login form POST/cookie authentication and authenticated dashboard |
| Correct HTTPS URLs and nonstandard local port | PASS | HTTP checks and live local homepage; canonical FastCGI host configured |
| WordPress files persist; no reinstall on restart | PASS | Post/media checks across restart/down/up/clean/rebuild; idempotent bootstrap |
| PHP-FPM foreground process | PASS | PID 1 inspection and FastCGI ping |
| NGINX only published entry point | PASS | Docker port-binding inspection; only NGINX maps a host port |
| Mandatory default host port 443 on VM | NOT TESTED | Local rootless restriction; tested high host port to internal 443 |
| TLS 1.2 and TLS 1.3 | PASS | Actual OpenSSL handshakes |
| TLS 1.0 and TLS 1.1 rejected | PASS | Actual OpenSSL clients with legacy ciphers enabled receive protocol-version alerts |
| Development certificate domain/validity | PASS | OpenSSL verify using the self-signed cert as trust anchor and expected hostname |
| FastCGI, WordPress static files | PASS | Homepage/login/dashboard/media HTTP responses |
| Hidden/config/upload-PHP access restrictions | PASS | HTTP 403 for configuration, salts, .env, XML-RPC, and upload PHP; missing PHP 404 |
| NGINX foreground and graceful configuration | PASS | PID 1 audit; SIGQUIT configured; healthcheck |
| Dedicated bridge and explicit membership | PASS | Network inspect: bridge, exactly four members |
| Service-name DNS | PASS | `getent hosts` from WordPress |
| No host networking, links, database/FPM publishing | PASS | Compose/runtime inspection |
| Exactly two required named storages | PASS | Model and mounts: `Type: volume`; no additional persistent volumes |
| Host-backed volume location | PASS | Normal volumes point beneath `/home/mhasoneh/data`; isolated test devices inspected separately |
| Restart policies and bounded initialization | PASS | All `unless-stopped`; scripts audited; no keepalive loop |
| Unexpected daemon termination recovery | PASS | Signal FPM from inside container, observe restart count/health, verify data |
| Useful healthchecks and ordered startup | PASS | All four healthy; dependency conditions and wait behavior exercised |
| Automatic .env and missing secret generation | PASS | Fresh-source `make`; unique 64-hex secrets; no password in .env |
| Secrets 700/600 and .env 600 | PASS | Filesystem mode assertions |
| Existing configuration/credentials preserved | PASS | Byte comparison across setup, restart, rebuild, repeated make |
| Lost-secret protection beside stored data | PASS | Removed only disposable secret; setup refused replacement; original restored |
| Required Make targets and idempotent lifecycle | PASS | setup/build/up/down/stop/start/restart/clean/re and inspection targets exercised |
| Destructive cleanup opt-in | PASS | `make fclean` refused; explicit fixture cleanup removed only fixture data/volumes/config |
| Sole static portfolio bonus, own image/container | PASS | HTML/CSS/JS HTTP checks; no PHP; no extra bonus services/ports |
| Responsive portfolio and JavaScript | PASS | Chrome 152 at 1440×1000 and 390×844; CSS applied, current year, valid anchors, no horizontal overflow or JS exceptions; screenshots visually inspected |
| No generated passwords in logs/metadata/history/layers | PASS | Exact-secret comparison; exported Docker image archive/layer scan |
| No privileged containers; static service restricted | PASS | Runtime inspection; no-new-privileges; static cap drop/read-only/init |
| Protected WordPress config and TLS key | PASS | Config 640; runtime secret 640; TLS private key 600; HTTP denials |
| Candidate source and full Git history credential audit | PASS | All candidate files reviewed; 18 unique historical blobs in the one existing commit scanned; no credential findings |
| Fresh Linux VM clone/start/reboot | NOT TESTED | VM execution unavailable in this session |
| Cross-VM backup restoration | NOT TESTED | Procedure documented, not executed on another VM |
| Public CA certificate / real mail delivery | NOT TESTED | Development self-signing and reserved placeholder emails are intentional |

## Security findings resolved during implementation

An early WP-CLI prompt-based bootstrap echoed expanded WordPress account passwords
into local container logs. Both affected local WordPress passwords were rotated
through stdin, the local secret files updated, and the affected container/logs
removed by recreation. The bootstrap now reads passwords inside PHP through
WordPress APIs, with no password argument or prompt. Final fresh-source tests
scan normal startup logs and image layers for all generated passwords. The
MariaDB root/database passwords were not exposed by that issue. No committed or
historical credential was found; no Git-history credential rotation was indicated.

The local development-port check found a canonical redirect loop caused by the
Debian FastCGI configuration stripping client ports. NGINX now supplies the trusted
configured public host/port explicitly, avoiding raw client Host forwarding.
Relative portfolio redirects retain the browser's current port.

BusyBox's HTTP process uses Docker tiny init to receive default stop signals and
reap children. Mandatory services retain their real daemon as PID 1. A restart
policy test signals the process inside its container: `docker kill` itself can
be treated as an intentional operator action and is not an equivalent crash test.

The first test fixture inherited a network-backed TMPDIR; final fixtures use
local `/tmp` for correct container ownership semantics. All failed disposable
fixtures were explicitly cleaned. No normal data was erased.

## Remaining evaluation work and risks

1. Review and commit the completed source, then push it yourself. This session did
   not create a commit or push to GitHub. A clone of the old remote revision will
   still contain the original scaffold until the owner publishes these changes.
2. Install Docker Engine/Compose in the VM using [DEV_DOC.md](../DEV_DOC.md), clone
   the completed revision, and run `make` with the default port 443 and data path.
3. Configure name resolution on the browser machine. VM NAT/bridged networking,
   firewall rules, sudo authorization, and Docker access are host prerequisites.
4. Repeat HTTP login, TLS, post/upload persistence, and a VM reboot. Local rootless
   checks cannot certify the final rootful VM setup.
5. Recheck Debian release eligibility if evaluation occurs after another stable
   release. Packages receive repository updates, so builds are intentionally not
   byte-for-byte reproducible package snapshots.
6. The self-signed certificate is development TLS, not public CA trust. It renews
   on container recreation or startup near expiry; preserve no private key in Git.
7. Volume names are host-global; run a single normal stack using those names.
   Test projects use unique prefixes. The local driver's `o: bind` is an internal
   volume implementation detail, not a direct service bind mount; explain this
   distinction if an evaluator asks.
8. Compose secrets are restricted local files, not encrypted Swarm secret storage.
   Protect host access, the Docker socket, and private backups. The audit used
   source review and high-confidence credential patterns, not a complete CVE scan.
9. Explain each script personally and practice a small change. A passing local
   suite does not replace the learner's understanding or the VM-only requirement.

## Defense demonstration

1. Show the assigned subject, Dockerfiles, Compose network/ports/volumes/secrets,
   and automatic setup. Explain Debian version choice and image/service names.
2. Run `make` and `make ps`; show the four healthy containers and their PID 1.
3. Open HTTPS WordPress, authenticate as `mhasoneh`, show `editor42` and its role,
   and open `/portfolio/` including its CSS/JavaScript.
4. Demonstrate accepted TLS 1.2/1.3 and rejected 1.0/1.1, plus only host port 443
   on the VM. Explain self-signing and trust.
5. Create a post and upload a picture in the dashboard. Run `make down` then
   `make`; show both persist with the same credentials.
6. Inspect the named volume devices and bridge membership. Explain FPM/FastCGI,
   initialization markers, secret file permissions, and restart versus health.
7. Show the isolated `make test` evidence and documented destructive cleanup
   guard. Do not erase valuable evaluation data as a demonstration.
