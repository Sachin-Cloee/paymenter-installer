# Security policy

The installer runs with root privileges and modifies system packages, services, web-server configuration, application files, and database settings. Treat security reports carefully.

## Reporting a vulnerability

Do not open a public issue for vulnerabilities that could expose credentials, permit command execution, weaken file permissions, or compromise an installation.

Report the problem privately to the maintainer through the contact method listed on the maintainer's GitHub profile or the community Discord. State clearly that the report is security-sensitive and avoid posting exploit details in public channels.

Include:

- A concise description of the vulnerability
- Affected installer version or commit
- Operating system and version
- Reproduction steps using non-sensitive example values
- Potential impact
- A suggested fix, when available

Never send real passwords, `.env` files, private keys, API tokens, database dumps, or customer data.

## Supported versions

Security fixes are applied to the latest version on the `main` branch and, when releases are available, the latest release. Older snapshots may not receive backports.

## Safe usage

- Download and review the script before running it.
- Use a fresh or disposable server for initial testing.
- Back up existing data and configuration.
- Restrict public access to MariaDB and Redis.
- Keep the operating system and Paymenter updated.
- Store generated passwords immediately and securely.
