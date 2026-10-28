# Security policy

## Supported state

There are no released or supported production versions. This educational project
currently contains a directory scaffold and documentation; runtime security has
not been implemented or reviewed.

Security reports concerning repository content, accidental disclosure, and future
service configuration are welcome. No response or remediation deadline is promised.

## Reporting a vulnerability

Do not post exploit details, passwords, tokens, or private logs in public issues
or pull requests.

If GitHub private vulnerability reporting is enabled, use **Security → Advisories →
Report a vulnerability** on the
[repository](https://github.com/MossaJehad/inception). This document does not enable
that setting, and its availability has not been verified.

If that option is unavailable, contact `mhasoneh` through an existing private
channel. No dedicated security email address is configured. If you have no private
contact channel, open an issue asking only for a private reporting method, without
disclosing vulnerability details.

Include the affected revision/files, impact, reproduction steps, and a minimal
sanitized demonstration. Test only systems you own or are authorized to assess.
Coordinate publication of details with the maintainer after remediation.

## Exposed credentials

Revoke or rotate exposed credentials first. Removing a file or adding an ignore
rule does not remove it from existing Git history or copies of the repository.
Then notify the maintainer privately so affected history and artifacts can be
reviewed without repeating the secret in the report.

## Local handling

- Store real credentials under the ignored `secrets/` directory.
- Keep the actual `srcs/.env` local and sanitize `.env.example`.
- Keep private keys, generated certificates, backups, data, and logs out of Git.
- Review file permissions and Docker build contexts during implementation.

See [GitHub's private reporting documentation](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/configure-vulnerability-reporting/configure-for-a-repository)
for the repository setting. No hosting settings have been changed by these docs.
