# Paymenter Installer

An interactive Bash installer for deploying the latest release of [Paymenter](https://github.com/Paymenter/Paymenter) on an Ubuntu or Debian server.

The script installs the required system packages, configures Paymenter, initializes its database, creates the scheduler and queue worker, and can optionally configure Nginx with a Let's Encrypt SSL certificate.

> [!IMPORTANT]
> This is a community-maintained installer and is not an official Paymenter project. Review the script before running it on a production server.
> [Support](https://discord.gg/A6TJh5GdVg)  

## Features

- Downloads the latest Paymenter release from GitHub
- Installs PHP 8.3 and the required PHP extensions
- Installs and starts MariaDB, Redis, cron, PHP-FPM, and Nginx
- Supports local or remote MariaDB databases
- Creates the local database and database user automatically
- Generates secure database and administrator passwords when left blank
- Creates an optional Paymenter administrator account
- Configures the Paymenter `.env` file
- Generates the Laravel application key
- Runs migrations, seeders, and Paymenter initialization
- Creates the Paymenter scheduler cron entry
- Creates and enables a systemd queue-worker service
- Optionally creates an Nginx virtual host
- Optionally obtains and configures a Let's Encrypt SSL certificate
- Detects domains resolving through Cloudflare before requesting SSL
- Runs post-installation checks for Paymenter, the database, services, cron, Nginx, and SSL
- Includes a utility for changing the domain of an existing installation
- Backs up existing installation directories and configuration files before replacing them

## Supported Systems

The installer currently supports:

- Ubuntu
- Debian
- APT-based systems using systemd

The script installs PHP 8.3 and uses the PHP-FPM socket at:

```text
/var/run/php/php8.3-fpm.sock
```

Other Linux distributions, Docker installations, Apache-only environments, and non-systemd systems are not supported by this script.

## Requirements

Before running the installer, make sure you have:

- Root access or a user with `sudo` access
- A fresh Ubuntu or Debian server, preferably without another hosting control panel
- Working internet access from the server
- A domain pointed to the server if you want Nginx and Let's Encrypt SSL
- Ports `80` and `443` open in the firewall and provider security rules
- Enough permissions to install packages and manage systemd services

For SSL, the domain's DNS records must resolve correctly before Certbot is run.

> [!WARNING]
> CloudPanel, Plesk, cPanel, HestiaCP, and similar panels manage web-server configuration themselves. On those systems, answer **No** when asked to configure Nginx automatically, then create the website or reverse proxy through the control panel.

## Quick Installation

Run the installer as root:

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/Sachin-Cloee/paymenter-installer/main/install.sh)"
```

The script will display an interactive menu:

```text
1) Install Paymenter
2) Change domainname
```

For a safer installation, download and review the script first:

```bash
curl -fsSL https://raw.githubusercontent.com/Sachin-Cloee/paymenter-installer/main/install.sh -o install.sh
less install.sh
chmod +x install.sh
sudo ./install.sh
```

## Direct Commands

Start a new Paymenter installation:

```bash
sudo ./install.sh install
```

Start an installation with a default installation directory:

```bash
sudo ./install.sh install /var/www/paymenter
```

Change the domain of an existing installation:

```bash
sudo ./install.sh change-domainname /var/www/paymenter
```

The aliases `change-domain`, `change_domain`, `domain`, and `2` are also accepted by the script.

## Installation Prompts

During installation, the script asks for:

- Installation directory
- Company or application name
- Application URL
- Web-server user and group
- Database host and port
- Database name and username
- Database password
- Whether to create an administrator account
- Administrator name, email, and password
- Whether to configure Nginx automatically
- Whether to enable Let's Encrypt SSL
- Whether to remove the default Nginx site

Before making changes, the installer prints a summary and asks for confirmation.

### Default Values

| Setting | Default |
|---|---|
| Installation directory | `/var/www/paymenter` |
| Application name | `Paymenter` |
| Application URL | `https://example.com` |
| Web user | `www-data` |
| Web group | `www-data` |
| Database host | `127.0.0.1` |
| Database port | `3306` |
| Database name | `paymenter` |
| Database user | `paymenter` |

Database names and usernames may contain only letters, numbers, and underscores.

## Database Behavior

When the database host is `127.0.0.1` or `localhost`, the installer:

1. Starts MariaDB.
2. Creates the configured database.
3. Creates the configured database user for both `127.0.0.1` and `localhost`.
4. Grants the user access to the Paymenter database.

When a remote database host is entered, local database creation is skipped and the provided credentials are written to Paymenter's `.env` file.

> [!NOTE]
> The current script still installs and starts the local MariaDB package even when a remote database is selected.

## What the Installer Configures

The installer performs the following main actions:

1. Installs system dependencies and PHP 8.3 extensions.
2. Enables MariaDB, Redis, cron, and PHP-FPM.
3. Downloads the latest `paymenter.tar.gz` release.
4. Extracts Paymenter into the selected installation directory.
5. Creates and configures `.env`.
6. Generates `APP_KEY`.
7. Creates the storage symlink.
8. Runs database migrations and seeders.
9. Runs Paymenter's `app:init` command.
10. Optionally creates an administrator account.
11. Adds the scheduler cron job.
12. Creates the Paymenter queue-worker service.
13. Sets ownership and storage permissions.
14. Optionally configures Nginx and Let's Encrypt.
15. Runs post-installation validation checks.

## Generated Files

Depending on the selected options, the installer creates or modifies:

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

The actual path in the cron entry follows the installation directory selected during setup.

## Nginx and SSL

When automatic Nginx configuration is enabled, the installer:

- Creates an HTTP virtual host for the selected domain
- Uses the Paymenter `public` directory as the document root
- Connects Nginx to PHP 8.3 FPM
- Tests the Nginx configuration before restarting it
- Optionally removes `/etc/nginx/sites-enabled/default`

When automatic SSL is enabled, the installer:

- Rejects `localhost` and IPv4 addresses
- Checks whether the domain resolves
- Checks whether the resolved addresses belong to Cloudflare
- Requests a certificate using `certbot --nginx`
- Enables HTTP-to-HTTPS redirection
- Verifies that the certificate and key files exist

If Cloudflare proxying is enabled, the installer displays a warning and requires confirmation before continuing.

## Changing the Domain

The domain-change utility updates:

- `APP_URL` in the Paymenter `.env` file
- Paymenter's stored application URL using Artisan
- Nginx configuration for the new hostname
- The Let's Encrypt certificate, when selected

Run:

```bash
sudo ./install.sh change-domainname /var/www/paymenter
```

After changing a domain, review `/etc/nginx/sites-enabled/` and remove any old virtual-host configuration that is no longer required.

## Existing Installation Protection

If the selected installation directory is not empty, the installer does not overwrite it immediately. It asks for confirmation and moves the existing directory to a timestamped backup such as:

```text
/var/www/paymenter.backup.20260710213000
```

Existing service and Nginx configuration files are also backed up before replacement.

## Post-Installation Checks

The installer verifies:

- The `.env` and `artisan` files exist
- Paymenter can bootstrap through `php artisan about`
- Paymenter can connect to the database
- MariaDB is active
- Redis is active
- Cron is active
- PHP 8.3 FPM is active
- The Paymenter queue worker is active
- The scheduler cron entry exists
- Nginx configuration is valid, when configured
- Let's Encrypt certificate files exist, when SSL is enabled

## Useful Commands

Check the Paymenter queue worker:

```bash
sudo systemctl status paymenter.service
```

Restart the queue worker:

```bash
sudo systemctl restart paymenter.service
```

View queue-worker logs:

```bash
sudo journalctl -u paymenter.service -n 100 --no-pager
```

Check PHP-FPM:

```bash
sudo systemctl status php8.3-fpm
```

Check Redis:

```bash
sudo systemctl status redis-server
```

Check MariaDB:

```bash
sudo systemctl status mariadb
```

Test Nginx:

```bash
sudo nginx -t
```

View Paymenter logs:

```bash
tail -n 100 /var/www/paymenter/storage/logs/laravel.log
```

## Updating Paymenter

This installer handles fresh installations and domain changes. It does not provide a separate update workflow.

Use Paymenter's official upgrade command from the installation directory:

```bash
cd /var/www/paymenter
sudo -u www-data php artisan app:upgrade
```

Back up the database, `.env`, extensions, themes, and application files before upgrading.

## Security Notes

- Review remote scripts before executing them as root.
- Back up the `APP_KEY` stored in `.env` and keep it secure.
- Save generated passwords immediately; the installer prints them only after installation.
- Do not expose MariaDB or Redis publicly unless access is restricted properly.
- Keep the operating system, Paymenter, extensions, and themes updated.
- Use a firewall and allow only the ports your deployment requires.
- Test the installer on a non-production server before using it for an existing deployment.

## Troubleshooting

### SSL certificate request fails

Confirm that:

- The domain resolves to the correct server
- Ports `80` and `443` are open
- No other service is occupying port `80`
- Cloudflare proxying is temporarily disabled if the HTTP challenge cannot reach the origin
- Nginx configuration passes `sudo nginx -t`

### Queue worker is not running

```bash
sudo systemctl status paymenter.service
sudo journalctl -u paymenter.service -n 100 --no-pager
sudo systemctl restart paymenter.service
```

### Paymenter shows a 500 error

```bash
cd /var/www/paymenter
php artisan about
php artisan migrate:status
php artisan optimize:clear
tail -n 100 storage/logs/laravel.log
```

### Permissions are incorrect

Replace the path and user/group when using non-default values:

```bash
sudo chown -R www-data:www-data /var/www/paymenter
sudo chmod -R 755 /var/www/paymenter/storage /var/www/paymenter/bootstrap/cache
```

### Nginx conflicts with a hosting panel

Do not use the installer's automatic Nginx option on a control-panel-managed server. Remove or disable the generated site and configure the domain through the panel instead.

## Contributing

Issues and pull requests are welcome. When reporting a problem, include:

- Operating system and version
- Installer command used
- Installation directory
- Whether the database is local or remote
- Whether Nginx and SSL were enabled
- The complete error output with secrets removed

## Disclaimer

This project is not affiliated with or endorsed by the official Paymenter project. Paymenter is maintained separately by its own contributors.

For official Paymenter documentation, visit [paymenter.org/docs](https://paymenter.org/docs/).


