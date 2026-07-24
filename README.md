# Paymenter Installer

[![Installer checks](https://github.com/Sachin-Cloee/paymenter-installer/actions/workflows/installer-checks.yml/badge.svg)](https://github.com/Sachin-Cloee/paymenter-installer/actions/workflows/installer-checks.yml)
[![Latest release](https://img.shields.io/github/v/release/Sachin-Cloee/paymenter-installer?display_name=tag&sort=semver)](https://github.com/Sachin-Cloee/paymenter-installer/releases)
[![Open issues](https://img.shields.io/github/issues/Sachin-Cloee/paymenter-installer)](https://github.com/Sachin-Cloee/paymenter-installer/issues)
[![Stars](https://img.shields.io/github/stars/Sachin-Cloee/paymenter-installer?style=flat)](https://github.com/Sachin-Cloee/paymenter-installer/stargazers)

An interactive Bash installer for deploying the latest [Paymenter](https://github.com/Paymenter/Paymenter) release on Ubuntu or Debian.

It installs and configures Paymenter, PHP 8.3, MariaDB, Redis, the scheduler, and the queue worker. It can also configure Nginx and request a Let's Encrypt certificate.

> [!IMPORTANT]
> This is a community-maintained installer and is not an official Paymenter project. Review scripts before running them as root on a production server.

## Quick start

The recommended method is to download and review the installer before running it:

```bash
curl -fsSL https://raw.githubusercontent.com/Sachin-Cloee/paymenter-installer/main/install.sh -o install.sh
less install.sh
chmod +x install.sh
sudo ./install.sh
```

For a non-interactive download-and-run command:

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/Sachin-Cloee/paymenter-installer/main/install.sh)"
```

The menu provides:

```text
1) Install Paymenter
2) Change domain name
```

## Why use this installer?

- Downloads the latest Paymenter release
- Installs PHP 8.3 and required extensions
- Installs and starts MariaDB, Redis, cron, PHP-FPM, and Nginx
- Supports local and remote MariaDB databases
- Generates secure database and administrator passwords when left blank
- Creates an optional Paymenter administrator account
- Configures the Paymenter `.env` file and Laravel application key
- Runs migrations, seeders, and Paymenter initialization
- Creates the scheduler cron entry and systemd queue worker
- Optionally configures Nginx and Let's Encrypt SSL
- Detects Cloudflare-proxied DNS before requesting a certificate
- Backs up existing installation and configuration files before replacement
- Runs post-installation validation checks
- Includes a utility for changing an existing installation's domain

## Requirements

- Root access or a user with `sudo` access
- A fresh Ubuntu or Debian server using APT and systemd
- Working outbound internet access
- A domain pointed to the server when using Nginx and Let's Encrypt
- Ports `80` and `443` open when enabling the web server and SSL

The installer uses the PHP 8.3 FPM socket:

```text
/var/run/php/php8.3-fpm.sock
```

Docker installations, Apache-only environments, non-APT distributions, and non-systemd systems are not supported.

> [!WARNING]
> CloudPanel, Plesk, cPanel, HestiaCP, and similar control panels manage their own web-server configuration. Answer **No** when asked to configure Nginx automatically, then configure the domain through the control panel.

## Compatibility

The installer is intended for currently supported Ubuntu and Debian releases. Clean-server test reports are welcome through the [compatibility report template](https://github.com/Sachin-Cloee/paymenter-installer/issues/new?template=compatibility-report.yml).

| Platform | Intended support | Notes |
|---|---:|---|
| Ubuntu | Yes | Uses the Ondrej PHP PPA |
| Debian | Yes | Uses the Sury PHP repository |
| Other APT systems | Not guaranteed | Distribution-specific package setup may fail |
| Docker | No | This installer targets systemd hosts |

## Direct commands

Install Paymenter:

```bash
sudo ./install.sh install
```

Install to a selected default directory:

```bash
sudo ./install.sh install /var/www/paymenter
```

Change an existing installation's domain:

```bash
sudo ./install.sh change-domainname /var/www/paymenter
```

The aliases `change-domain`, `change_domain`, `domain`, and `2` are also accepted.

## Installation prompts

The installer asks for:

- Installation directory
- Company or application name
- Application URL
- Web-server user and group
- Database host, port, name, username, and password
- Whether to create an administrator account
- Administrator name, email, and password
- Whether to configure Nginx automatically
- Whether to enable Let's Encrypt SSL
- Whether to remove the default Nginx site

Before changing the server, it prints a summary and asks for confirmation.

### Defaults

| Setting | Default |
|---|---|
| Installation directory | `/var/www/paymenter` |
| Application name | `Paymenter` |
| Application URL | `https://example.com` |
| Web user and group | `www-data` |
| Database host | `127.0.0.1` |
| Database port | `3306` |
| Database name | `paymenter` |
| Database user | `paymenter` |

Database names and usernames may contain only letters, numbers, and underscores.

## What it configures

1. Installs system packages and PHP 8.3 extensions.
2. Enables MariaDB, Redis, cron, and PHP-FPM.
3. Downloads and extracts the latest Paymenter release.
4. Creates and configures `.env`.
5. Generates `APP_KEY` and the storage symlink.
6. Runs migrations, seeders, and `app:init`.
7. Optionally creates an administrator account.
8. Adds the scheduler cron job.
9. Creates the Paymenter queue-worker systemd service.
10. Sets ownership and storage permissions.
11. Optionally configures Nginx and Let's Encrypt.
12. Runs post-installation checks.

Generated or modified files can include:

```text
/var/www/paymenter/.env
/etc/systemd/system/paymenter.service
/etc/nginx/sites-available/paymenter.conf
/etc/nginx/sites-enabled/paymenter.conf
```

The scheduler is added to the selected web user's crontab:

```cron
* * * * * php /var/www/paymenter/artisan schedule:run >> /dev/null 2>&1
```

## Database behavior

For `127.0.0.1` or `localhost`, the installer starts MariaDB, creates the configured database and user, and grants access.

For a remote database host, local database creation is skipped and the supplied credentials are written to Paymenter's `.env` file.

> [!NOTE]
> The current installer still installs and starts the local MariaDB package even when a remote database is selected.

## Nginx and SSL

When enabled, the installer creates an Nginx virtual host using Paymenter's `public` directory, connects it to PHP 8.3 FPM, tests the configuration, and can remove the default Nginx site.

For SSL, it validates the hostname, checks DNS resolution, detects Cloudflare proxy addresses, requests a certificate using `certbot --nginx`, enables HTTPS redirection, and checks that certificate files exist.

## Existing-installation protection

A non-empty installation directory is not overwritten immediately. After confirmation, the installer moves it to a timestamped backup such as:

```text
/var/www/paymenter.backup.20260710213000
```

Existing service and Nginx configuration files are also backed up before replacement.

## Updating Paymenter

This project handles fresh installations and domain changes. Use Paymenter's official upgrade command for application updates:

```bash
cd /var/www/paymenter
sudo -u www-data php artisan app:upgrade
```

Back up the database, `.env`, extensions, themes, and application files first.

## Troubleshooting

### Queue worker

```bash
sudo systemctl status paymenter.service
sudo journalctl -u paymenter.service -n 100 --no-pager
sudo systemctl restart paymenter.service
```

### Paymenter HTTP 500 error

```bash
cd /var/www/paymenter
php artisan about
php artisan migrate:status
php artisan optimize:clear
tail -n 100 storage/logs/laravel.log
```

### Nginx or SSL

```bash
sudo nginx -t
sudo systemctl status nginx
sudo certbot certificates
```

Confirm that the domain resolves to the server, ports `80` and `443` are open, and no other service is occupying port `80`.

### Incorrect permissions

```bash
sudo chown -R www-data:www-data /var/www/paymenter
sudo chmod -R 755 /var/www/paymenter/storage /var/www/paymenter/bootstrap/cache
```

Replace paths and users when non-default values were selected.

## Security

Read [SECURITY.md](SECURITY.md) before reporting a vulnerability. Never include passwords, `.env` contents, private keys, tokens, or unredacted logs in a public issue.

## Contributing

Bug reports, compatibility reports, documentation improvements, and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Support

- [Open a GitHub issue](https://github.com/Sachin-Cloee/paymenter-installer/issues/new/choose)
- [Join the community Discord](https://discord.gg/A6TJh5GdVg)
- [Official Paymenter documentation](https://paymenter.org/docs/)

## Support the project

If the installer saved you time, consider [starring the repository](https://github.com/Sachin-Cloee/paymenter-installer). Stars help other Paymenter users discover it.

## Disclaimer

This project is not affiliated with or endorsed by the official Paymenter project. Paymenter is maintained separately by its own contributors.
