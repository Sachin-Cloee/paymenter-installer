#!/usr/bin/env bash

set -Eeuo pipefail

PAYMENTER_RELEASE_URL="https://github.com/paymenter/paymenter/releases/latest/download/paymenter.tar.gz"

color_blue="\033[1;34m"
color_yellow="\033[1;33m"
color_red="\033[1;31m"
color_green="\033[1;32m"
color_reset="\033[0m"

print_banner() {
    cat <<'EOF'
 ____                                  _
|  _ \ __ _ _   _ _ __ ___   ___ _ __| |_ ___ _ __
| |_) / _` | | | | '_ ` _ \ / _ \ '__| __/ _ \ '__|
|  __/ (_| | |_| | | | | | |  __/ |  | ||  __/ |
|_|   \__,_|\__, |_| |_| |_|\___|_|   \__\___|_|
            |___/

paymenter install script (made by cloee)
EOF
}

print_cloee_outro() {
    cat <<'EOF'
  _____ _      ____  ______ ______
 / ____| |    / __ \|  ____|  ____|
| |    | |   | |  | | |__  | |__
| |    | |   | |  | |  __| |  __|
| |____| |___| |__| | |____| |____
 \_____|______\____/|______|______|

- check out some cool paymenter extension on https://builtbybit.com/cloee
- Join our discord -https://discord.gg/A6TJh5GdVg
EOF
}

log() {
    echo -e "${color_blue}==>${color_reset} $*"
}

success() {
    echo -e "${color_green}==>${color_reset} $*"
}

warn() {
    echo -e "${color_yellow}==>${color_reset} $*"
}

fail() {
    echo -e "${color_red}Error:${color_reset} $*" >&2
    exit 1
}

run() {
    log "$*"
    "$@"
}

require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        fail "Please run this script as root."
    fi
}

require_command() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || fail "Required command not found: $cmd"
}

prompt() {
    local var_name="$1"
    local message="$2"
    local default_value="${3:-}"
    local value

    if [[ -n "$default_value" ]]; then
        read -r -p "$message [$default_value]: " value
        value="${value:-$default_value}"
    else
        read -r -p "$message: " value
    fi

    printf -v "$var_name" '%s' "$value"
}

prompt_secret() {
    local var_name="$1"
    local message="$2"
    local value

    while true; do
        read -r -s -p "$message: " value
        echo
        [[ -n "$value" ]] && break
        warn "This value cannot be empty."
    done

    printf -v "$var_name" '%s' "$value"
}

generate_random_secret() {
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -hex 20
    else
        head -c 20 /dev/urandom | od -An -tx1 | tr -d ' \n'
    fi
}

prompt_secret_or_generate() {
    local var_name="$1"
    local message="$2"
    local generated_flag_var="${3:-}"
    local value
    local generated="no"

    read -r -s -p "$message (leave empty to generate a random password): " value
    echo

    if [[ -z "$value" ]]; then
        value="$(generate_random_secret)"
        generated="yes"
        success "Generated random password for ${message,,}: $value"
    fi

    printf -v "$var_name" '%s' "$value"

    if [[ -n "$generated_flag_var" ]]; then
        printf -v "$generated_flag_var" '%s' "$generated"
    fi
}

confirm() {
    local message="$1"
    local default="${2:-N}"
    local reply

    if [[ "$default" == "Y" ]]; then
        read -r -p "$message [Y/n]: " reply
        reply="${reply:-Y}"
    else
        read -r -p "$message [y/N]: " reply
        reply="${reply:-N}"
    fi

    [[ "$reply" =~ ^[Yy]$ ]]
}

validate_identifier() {
    local value="$1"
    local name="$2"
    if [[ ! "$value" =~ ^[A-Za-z0-9_]+$ ]]; then
        fail "$name must only contain letters, numbers, and underscores."
    fi
}

sql_escape() {
    local value="$1"
    value="${value//\'/\'\'}"
    printf '%s' "$value"
}

set_env_value() {
    local file="$1"
    local key="$2"
    local value="$3"
    local env_value
    local escaped_replacement

    env_value="$(format_env_value "$value")"
    escaped_replacement="$(printf '%s' "$env_value" | sed 's/[&/\]/\\&/g')"
    if grep -qE "^${key}=" "$file"; then
        sed -i "s/^${key}=.*/${key}=${escaped_replacement}/" "$file"
    else
        printf '\n%s=%s\n' "$key" "$env_value" >> "$file"
    fi
}

format_env_value() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//\$/\\$}"
    printf '"%s"' "$value"
}

parse_host_from_url() {
    local url="$1"
    printf '%s' "$url" | sed -E 's#^[a-zA-Z]+://([^/:]+).*#\1#'
}

get_env_value() {
    local file="$1"
    local key="$2"
    local value

    [[ -f "$file" ]] || return 1

    value="$(sed -n "s/^${key}=//p" "$file" | head -n1)"
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"

    [[ -n "$value" ]] || return 1
    printf '%s' "$value"
}

escape_sed_replacement() {
    printf '%s' "$1" | sed 's/[&/\]/\\&/g'
}

normalize_install_dir() {
    local path="$1"

    [[ -n "$path" ]] || fail "Install directory cannot be empty."

    if [[ "$path" == "~" ]]; then
        path="$HOME"
    elif [[ "$path" == "~/"* ]]; then
        path="${HOME}/${path#~/}"
    elif [[ "$path" != /* ]]; then
        path="$(pwd)/$path"
    fi

    while [[ "$path" == */ && "$path" != "/" ]]; do
        path="${path%/}"
    done

    printf '%s' "$path"
}

backup_file() {
    local file="$1"
    local backup_path

    [[ -e "$file" ]] || return 0

    backup_path="${file}.bak.$(date +%Y%m%d%H%M%S)"
    run cp "$file" "$backup_path"
    warn "Existing file backed up to $backup_path"
}

validate_app_url() {
    local url="$1"
    local host

    [[ "$url" =~ ^https?:// ]] || return 1

    host="$(parse_host_from_url "$url")"
    [[ -n "$host" && "$host" != "$url" ]]
}

resolve_host_ips() {
    local host="$1"
    getent ahosts "$host" 2>/dev/null | awk '{print $1}' | sort -u
}

fetch_cloudflare_ip_ranges() {
    local ipv4_response ipv6_response

    ipv4_response="$(curl -fsSL https://www.cloudflare.com/ips-v4 2>/dev/null || true)"
    ipv6_response="$(curl -fsSL https://www.cloudflare.com/ips-v6 2>/dev/null || true)"

    [[ -n "$ipv4_response" && -n "$ipv6_response" ]] || return 1

    mapfile -t CLOUDFLARE_IPV4_RANGES < <(printf '%s\n' "$ipv4_response" | tr ' ' '\n' | sed '/^$/d')
    mapfile -t CLOUDFLARE_IPV6_RANGES < <(printf '%s\n' "$ipv6_response" | tr ' ' '\n' | sed '/^$/d')

    [[ "${#CLOUDFLARE_IPV4_RANGES[@]}" -gt 0 && "${#CLOUDFLARE_IPV6_RANGES[@]}" -gt 0 ]]
}

ip_in_cidr() {
    local ip="$1"
    local cidr="$2"

    python3 - "$ip" "$cidr" <<'PY'
import ipaddress
import sys

ip = sys.argv[1]
cidr = sys.argv[2]

try:
    print("yes" if ipaddress.ip_address(ip) in ipaddress.ip_network(cidr, strict=False) else "no")
except ValueError:
    print("no")
PY
}

warn_if_cloudflare_proxy_dns() {
    local host="$1"
    local ip
    local cidr
    local -a resolved_ips=()
    local -a matched_ranges=()

    mapfile -t resolved_ips < <(resolve_host_ips "$host")

    if [[ "${#resolved_ips[@]}" -eq 0 ]]; then
        warn "DNS preflight: ${host} did not resolve via this server's resolver."
        confirm "Continue with Let's Encrypt anyway?" "N" || fail "Let's Encrypt setup aborted because DNS did not resolve."
        return
    fi

    log "DNS preflight for ${host}: ${resolved_ips[*]}"

    if ! fetch_cloudflare_ip_ranges; then
        warn "Could not fetch the latest Cloudflare IP ranges. Skipping Cloudflare proxy DNS check."
        return
    fi

    for ip in "${resolved_ips[@]}"; do
        if [[ "$ip" == *:* ]]; then
            for cidr in "${CLOUDFLARE_IPV6_RANGES[@]}"; do
                if [[ "$(ip_in_cidr "$ip" "$cidr")" == "yes" ]]; then
                    matched_ranges+=("${ip} -> ${cidr}")
                    break
                fi
            done
        else
            for cidr in "${CLOUDFLARE_IPV4_RANGES[@]}"; do
                if [[ "$(ip_in_cidr "$ip" "$cidr")" == "yes" ]]; then
                    matched_ranges+=("${ip} -> ${cidr}")
                    break
                fi
            done
        fi
    done

    if [[ "${#matched_ranges[@]}" -gt 0 ]]; then
        warn "${host} resolves to Cloudflare proxy IPs:"
        printf '  %s\n' "${matched_ranges[@]}"
        warn "If Cloudflare is proxying this hostname, certbot --nginx may still work, but challenge routing depends on your Cloudflare/origin setup."
        confirm "Continue with Let's Encrypt only if you know what you are doing?" "N" || fail "Let's Encrypt setup aborted because the domain resolves to Cloudflare proxy IPs."
    fi
}

detect_os() {
    [[ -f /etc/os-release ]] || fail "/etc/os-release not found."
    # shellcheck disable=SC1091
    source /etc/os-release
    DISTRO_ID="${ID,,}"
    DISTRO_VERSION="${VERSION_ID:-unknown}"
}

install_packages() {
    log "Installing dependencies..."
    case "$DISTRO_ID" in
        ubuntu)
            run apt-get update
            run apt-get -y install software-properties-common curl apt-transport-https ca-certificates gnupg
            run add-apt-repository -y ppa:ondrej/php
            if [[ "$DISTRO_VERSION" == "24.04" ]]; then
                run bash -c 'curl -sSL https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash -s -- --mariadb-server-version="mariadb-10.11"'
            fi
            run apt-get update
            run apt-get -y install php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,intl,redis} mariadb-server nginx certbot python3-certbot-nginx cron tar unzip git redis-server
            ;;
        debian)
            run apt-get update
            run apt-get -y install software-properties-common curl ca-certificates gnupg2 sudo lsb-release
            run bash -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/sury-php.list'
            run bash -c 'curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg'
            run apt-get update
            run bash -c 'curl -sSL https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash -s -- --mariadb-server-version="mariadb-10.11"'
            run apt-get update
            run apt-get -y install php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,intl,redis} mariadb-server nginx certbot python3-certbot-nginx cron tar unzip git redis-server
            ;;
        *)
            fail "Unsupported distro for this script: ${DISTRO_ID} ${DISTRO_VERSION}. Supported: Ubuntu, Debian."
            ;;
    esac
}

setup_database() {
    local sql
    local db_name_sql db_user_sql db_pass_sql

    db_name_sql=$(sql_escape "$DB_NAME")
    db_user_sql=$(sql_escape "$DB_USER")
    db_pass_sql=$(sql_escape "$DB_PASSWORD")

    sql=$(cat <<EOF
CREATE DATABASE IF NOT EXISTS \`$db_name_sql\`;
CREATE USER IF NOT EXISTS '$db_user_sql'@'127.0.0.1' IDENTIFIED BY '$db_pass_sql';
CREATE USER IF NOT EXISTS '$db_user_sql'@'localhost' IDENTIFIED BY '$db_pass_sql';
GRANT ALL PRIVILEGES ON \`$db_name_sql\`.* TO '$db_user_sql'@'127.0.0.1';
GRANT ALL PRIVILEGES ON \`$db_name_sql\`.* TO '$db_user_sql'@'localhost';
FLUSH PRIVILEGES;
EOF
)

    if [[ -n "${MYSQL_ROOT_PASSWORD:-}" ]]; then
        run mysql -u root "-p${MYSQL_ROOT_PASSWORD}" -e "$sql"
    else
        run mysql -u root -e "$sql"
    fi
}

setup_cron() {
    local cron_line existing_cron
    id "$WEB_USER" >/dev/null 2>&1 || fail "User does not exist: $WEB_USER"
    cron_line="* * * * * php ${INSTALL_DIR}/artisan schedule:run >> /dev/null 2>&1"
    existing_cron="$(crontab -u "$WEB_USER" -l 2>/dev/null || true)"
    if printf '%s\n' "$existing_cron" | grep -Fq "$cron_line"; then
        log "Cron entry already exists for ${WEB_USER}."
        return
    fi
    printf '%s\n%s\n' "$existing_cron" "$cron_line" | crontab -u "$WEB_USER" -
    success "Cron entry added for ${WEB_USER}."
}

setup_service() {
    local service_file="/etc/systemd/system/paymenter.service"
    local backup_file
    id "$WEB_USER" >/dev/null 2>&1 || fail "User does not exist: $WEB_USER"
    getent group "$WEB_GROUP" >/dev/null 2>&1 || fail "Group does not exist: $WEB_GROUP"

    if [[ -f "$service_file" ]]; then
        backup_file="${service_file}.bak.$(date +%Y%m%d%H%M%S)"
        run cp "$service_file" "$backup_file"
        warn "Existing service file backed up to $backup_file"
    fi

    cat > "$service_file" <<EOF
[Unit]
Description=Paymenter Queue Worker
After=network.target

[Service]
# On some systems the user and group might be different.
# Some systems use apache or nginx as the user and group.
User=$WEB_USER
Group=$WEB_GROUP
Restart=always
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/php $INSTALL_DIR/artisan queue:work
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    run systemctl daemon-reload
    run systemctl enable --now paymenter.service
    run systemctl enable --now redis-server
}

setup_nginx() {
    local nginx_conf="/etc/nginx/sites-available/paymenter.conf"
    local host

    host="$(parse_host_from_url "$APP_URL")"

    backup_file "$nginx_conf"
    write_nginx_conf "$nginx_conf" "$host" "$INSTALL_DIR"
    enable_nginx_conf "$nginx_conf"

    if [[ "$REMOVE_DEFAULT_NGINX" == "yes" && -e /etc/nginx/sites-enabled/default ]]; then
        run rm -f /etc/nginx/sites-enabled/default
    fi

    run nginx -t
    run systemctl restart nginx
}

write_nginx_conf() {
    local nginx_conf="$1"
    local host="$2"
    local install_dir="$3"

    cat > "$nginx_conf" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${host};
    root ${install_dir}/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    index index.php;
    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ ^/index\.php(/|$) {
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
    }
}
EOF
}

enable_nginx_conf() {
    local nginx_conf="$1"
    local enabled_conf="/etc/nginx/sites-enabled/$(basename "$nginx_conf")"

    if [[ -e "$enabled_conf" && ! -L "$enabled_conf" ]]; then
        backup_file "$enabled_conf"
        run rm -f "$enabled_conf"
    fi

    run ln -sfn "$nginx_conf" "$enabled_conf"
}

nginx_conf_path_for_host() {
    local host="$1"
    local safe_host

    safe_host="$(printf '%s' "$host" | tr -c 'A-Za-z0-9.-' '-')"
    printf '/etc/nginx/sites-available/paymenter-%s.conf' "$safe_host"
}

create_nginx_domain_conf() {
    local install_dir="$1"
    local host="$2"
    local nginx_conf

    nginx_conf="$(nginx_conf_path_for_host "$host")"
    backup_file "$nginx_conf"
    write_nginx_conf "$nginx_conf" "$host" "$install_dir"
    enable_nginx_conf "$nginx_conf"
    run nginx -t
    run systemctl reload nginx
    success "Created nginx config for ${host} at ${nginx_conf}"
}

setup_letsencrypt() {
    local host
    host="$(parse_host_from_url "$APP_URL")"

    [[ "$host" != "localhost" ]] || fail "Let's Encrypt requires a public domain, not localhost."
    if [[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        fail "Let's Encrypt requires a domain name, not an IP address (${host})."
    fi
    require_command python3
    require_command getent

    warn_if_cloudflare_proxy_dns "$host"

    run certbot --nginx --non-interactive --agree-tos --email "$LE_EMAIL" -d "$host" --redirect
    run nginx -t
    run systemctl reload nginx
}

assert_service_active() {
    local service="$1"
    local label="${2:-$service}"
    if systemctl is-active --quiet "$service"; then
        success "${label} service is active."
    else
        fail "${label} service is not active. Run: systemctl status ${service}"
    fi
}

verify_installed_commands() {
    local required_commands=(php mysql nginx crontab systemctl)
    local cmd

    if [[ "$NGINX_SSL" == "yes" ]]; then
        required_commands+=(certbot)
    fi

    for cmd in "${required_commands[@]}"; do
        require_command "$cmd"
    done
}

verify_cron_entry() {
    local cron_line existing_cron
    cron_line="* * * * * php ${INSTALL_DIR}/artisan schedule:run >> /dev/null 2>&1"
    existing_cron="$(crontab -u "$WEB_USER" -l 2>/dev/null || true)"
    if printf '%s\n' "$existing_cron" | grep -Fq "$cron_line"; then
        success "Cron entry is present for ${WEB_USER}."
    else
        fail "Cron entry is missing for ${WEB_USER}."
    fi
}

run_post_install_checks() {
    local host cert_path key_path

    log "Running post-install checks..."

    [[ -f "${INSTALL_DIR}/.env" ]] || fail "Missing ${INSTALL_DIR}/.env"
    [[ -f "${INSTALL_DIR}/artisan" ]] || fail "Missing ${INSTALL_DIR}/artisan"

    if (cd "$INSTALL_DIR" && php artisan about >/dev/null 2>&1); then
        success "Artisan bootstrap check passed."
    else
        fail "Artisan bootstrap check failed."
    fi

    if (cd "$INSTALL_DIR" && php artisan migrate:status --no-interaction >/dev/null 2>&1); then
        success "Database connectivity check passed."
    else
        fail "Database connectivity check failed (php artisan migrate:status)."
    fi

    assert_service_active mariadb "MariaDB"
    assert_service_active redis-server "Redis"
    assert_service_active cron "Cron"
    assert_service_active php8.3-fpm "PHP-FPM"
    assert_service_active paymenter.service "Paymenter queue worker"

    verify_cron_entry

    if [[ "$CONFIGURE_NGINX" == "yes" ]]; then
        [[ -f /etc/nginx/sites-available/paymenter.conf ]] || fail "Nginx site file not found: /etc/nginx/sites-available/paymenter.conf"
        [[ -L /etc/nginx/sites-enabled/paymenter.conf ]] || fail "Nginx site symlink missing: /etc/nginx/sites-enabled/paymenter.conf"
        if nginx -t >/dev/null 2>&1; then
            success "Nginx configuration test passed."
        else
            fail "Nginx configuration test failed."
        fi
        assert_service_active nginx "Nginx"
    fi

    if [[ "$NGINX_SSL" == "yes" ]]; then
        host="$(parse_host_from_url "$APP_URL")"
        cert_path="/etc/letsencrypt/live/${host}/fullchain.pem"
        key_path="/etc/letsencrypt/live/${host}/privkey.pem"

        [[ -s "$cert_path" ]] || fail "Let's Encrypt certificate not found: ${cert_path}"
        [[ -s "$key_path" ]] || fail "Let's Encrypt key not found: ${key_path}"
        success "Let's Encrypt certificate files are present for ${host}."
    fi
}

create_admin_user() {
    local role_id

    role_id="$(cd "$INSTALL_DIR" && php -r 'require "vendor/autoload.php"; $app=require "bootstrap/app.php"; $kernel=$app->make(Illuminate\Contracts\Console\Kernel::class); $kernel->bootstrap(); echo \App\Models\Role::query()->where("name","admin")->value("id") ?? 0;' 2>/dev/null || true)"
    role_id="${role_id:-0}"

    run php "$INSTALL_DIR/artisan" app:user:create "$ADMIN_FIRST_NAME" "$ADMIN_LAST_NAME" "$ADMIN_EMAIL" "$ADMIN_PASSWORD" "$role_id"
}

change_domainname() {
    local install_dir_arg current_url new_url new_host
    local enable_ssl_change="no"

    install_dir_arg="${1:-}"
    INSTALL_DIR="${install_dir_arg:-/var/www/paymenter}"

    prompt INSTALL_DIR "Existing Paymenter install directory" "$INSTALL_DIR"
    INSTALL_DIR="$(normalize_install_dir "$INSTALL_DIR")"

    [[ -f "${INSTALL_DIR}/artisan" ]] || fail "Could not find artisan in ${INSTALL_DIR}"
    [[ -f "${INSTALL_DIR}/.env" ]] || fail "Could not find .env in ${INSTALL_DIR}"

    current_url="$(get_env_value "${INSTALL_DIR}/.env" APP_URL || true)"
    current_url="${current_url:-https://example.com}"
    while true; do
        prompt new_url "New application URL (must start with http:// or https://)" "$current_url"
        if validate_app_url "$new_url" >/dev/null 2>&1; then
            break
        fi
        warn "Please enter a valid URL starting with http:// or https://"
    done

    new_host="$(parse_host_from_url "$new_url")"

    if command -v nginx >/dev/null 2>&1; then
        if [[ "$new_host" != "localhost" && ! "$new_host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            if confirm "Issue/refresh Let's Encrypt SSL for the new domain?" "Y"; then
                enable_ssl_change="yes"
                while true; do
                    prompt LE_EMAIL "Let's Encrypt email address" "admin@${new_host}"
                    [[ "$LE_EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]] && break
                    warn "Please enter a valid email address."
                done
            fi
        else
            warn "Skipping Let's Encrypt prompt because ${new_host} is not a public domain."
        fi
    fi

    echo
    log "Change domainname summary:"
    echo "  Install dir: ${INSTALL_DIR}"
    echo "  Current URL: ${current_url}"
    echo "  New URL: ${new_url}"
    echo "  Reissue SSL: ${enable_ssl_change}"
    if [[ "$enable_ssl_change" == "yes" ]]; then
        echo "  Let's Encrypt email: ${LE_EMAIL}"
    fi
    echo

    confirm "Continue with domain change?" "N" || fail "Domain change aborted by user."

    set_env_value "${INSTALL_DIR}/.env" APP_URL "$new_url"

    (
        cd "$INSTALL_DIR"
        run php artisan app:settings:change app_url "$new_url"
    )

    if command -v nginx >/dev/null 2>&1; then
        create_nginx_domain_conf "$INSTALL_DIR" "$new_host"
        if [[ "$enable_ssl_change" == "yes" ]]; then
            APP_URL="$new_url"
            setup_letsencrypt
        fi
    else
        warn "Nginx is not installed on this server. Update your webserver config manually if needed."
    fi

    success "Domain updated."
    echo "Open your panel at: $new_url"
}

install_paymenter() {
    local install_dir_arg archive_file

    install_dir_arg="${1:-}"
    INSTALL_DIR="${install_dir_arg:-/var/www/paymenter}"
    APP_NAME="Paymenter"
    APP_URL="https://example.com"
    WEB_USER="www-data"
    WEB_GROUP="www-data"
    DB_HOST="127.0.0.1"
    DB_PORT="3306"
    DB_NAME="paymenter"
    DB_USER="paymenter"
    DB_PASSWORD_GENERATED="no"
    ADMIN_PASSWORD_GENERATED="no"

    prompt INSTALL_DIR "Install directory" "$INSTALL_DIR"
    INSTALL_DIR="$(normalize_install_dir "$INSTALL_DIR")"
    [[ "$INSTALL_DIR" != "/" ]] || fail "Install directory cannot be /."
    prompt APP_NAME "Company name (for app:init)" "$APP_NAME"

    while true; do
        prompt APP_URL "Application URL (must start with http:// or https://)" "$APP_URL"
        if validate_app_url "$APP_URL" >/dev/null 2>&1; then
            break
        fi
        warn "Please enter a valid URL starting with http:// or https://"
    done

    prompt WEB_USER "Webserver user" "$WEB_USER"
    prompt WEB_GROUP "Webserver group" "$WEB_GROUP"
    prompt DB_HOST "Database host" "$DB_HOST"
    prompt DB_PORT "Database port" "$DB_PORT"
    prompt DB_NAME "Database name" "$DB_NAME"
    prompt DB_USER "Database username" "$DB_USER"
    prompt_secret_or_generate DB_PASSWORD "Database password" DB_PASSWORD_GENERATED

    validate_identifier "$DB_NAME" "Database name"
    validate_identifier "$DB_USER" "Database username"

    LOCAL_DB_SETUP="no"
    if [[ "$DB_HOST" == "127.0.0.1" || "$DB_HOST" == "localhost" ]]; then
        LOCAL_DB_SETUP="yes"
    fi

    MYSQL_ROOT_PASSWORD=""
    if [[ "$LOCAL_DB_SETUP" != "yes" ]]; then
        warn "Remote DB host detected (${DB_HOST}). Skipping local DB/user creation."
    fi

    CREATE_ADMIN="yes"
    if confirm "Create admin user now?" "Y"; then
        prompt ADMIN_FIRST_NAME "Admin first name" "Admin"
        prompt ADMIN_LAST_NAME "Admin last name" "User"
        while true; do
            prompt ADMIN_EMAIL "Admin email" "admin@example.com"
            [[ "$ADMIN_EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]] && break
            warn "Please enter a valid email address."
        done
        prompt_secret_or_generate ADMIN_PASSWORD "Admin password" ADMIN_PASSWORD_GENERATED
    else
        CREATE_ADMIN="no"
    fi

    CONFIGURE_NGINX="no"
    NGINX_SSL="no"
    LE_EMAIL=""
    REMOVE_DEFAULT_NGINX="no"
    if confirm "Configure nginx automatically?" "Y"; then
        CONFIGURE_NGINX="yes"
        if confirm "Enable automatic Let's Encrypt SSL?" "N"; then
            NGINX_SSL="yes"
            while true; do
                prompt LE_EMAIL "Let's Encrypt email address" "admin@$(parse_host_from_url "$APP_URL")"
                [[ "$LE_EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]] && break
                warn "Please enter a valid email address."
            done
        fi
        if confirm "Remove default nginx site (/etc/nginx/sites-enabled/default)?" "N"; then
            REMOVE_DEFAULT_NGINX="yes"
        fi
    fi

    echo
    log "Summary:"
    echo "  OS: ${DISTRO_ID} ${DISTRO_VERSION}"
    echo "  Install dir: ${INSTALL_DIR}"
    echo "  App name: ${APP_NAME}"
    echo "  App URL: ${APP_URL}"
    echo "  Web user/group: ${WEB_USER}:${WEB_GROUP}"
    echo "  DB: ${DB_NAME} (${DB_USER}@${DB_HOST}:${DB_PORT})"
    echo "  DB password: ${DB_PASSWORD_GENERATED}"
    echo "  Local DB bootstrap: ${LOCAL_DB_SETUP}"
    if [[ "$CREATE_ADMIN" == "yes" ]]; then
        echo "  Admin password: ${ADMIN_PASSWORD_GENERATED}"
    fi
    echo "  Configure nginx: ${CONFIGURE_NGINX}"
    if [[ "$CONFIGURE_NGINX" == "yes" ]]; then
        echo "  Automatic Let's Encrypt SSL: ${NGINX_SSL}"
        if [[ "$NGINX_SSL" == "yes" ]]; then
            echo "  Let's Encrypt email: ${LE_EMAIL}"
        fi
    fi
    echo

    confirm "Continue with installation?" "N" || fail "Installation aborted by user."

    install_packages

    verify_installed_commands

    run systemctl enable --now mariadb
    run systemctl enable --now redis-server
    run systemctl enable --now cron
    run systemctl enable --now php8.3-fpm

    if [[ -d "$INSTALL_DIR" ]] && [[ -n "$(ls -A "$INSTALL_DIR" 2>/dev/null || true)" ]]; then
        local backup_dir
        backup_dir="${INSTALL_DIR}.backup.$(date +%Y%m%d%H%M%S)"
        warn "Install directory is not empty: $INSTALL_DIR"
        confirm "Move existing directory to ${backup_dir} and continue?" "N" || fail "Refusing to overwrite non-empty directory."
        run mv "$INSTALL_DIR" "$backup_dir"
    fi

    run mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    archive_file="$(mktemp /tmp/paymenter.XXXXXX.tar.gz)"
    run curl -fLsS -o "$archive_file" "$PAYMENTER_RELEASE_URL"
    run tar -xzf "$archive_file" -C "$INSTALL_DIR"
    run rm -f "$archive_file"

    run chmod -R 755 storage bootstrap/cache

    if [[ "$LOCAL_DB_SETUP" == "yes" ]]; then
        if ! mysql -u root -e "SELECT 1" >/dev/null 2>&1; then
            prompt_secret MYSQL_ROOT_PASSWORD "MySQL root password"
            mysql -u root "-p${MYSQL_ROOT_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1 || fail "Unable to authenticate to MySQL with provided root password."
        fi
        setup_database
    fi

    run cp .env.example .env
    set_env_value .env DB_HOST "$DB_HOST"
    set_env_value .env DB_PORT "$DB_PORT"
    set_env_value .env DB_DATABASE "$DB_NAME"
    set_env_value .env DB_USERNAME "$DB_USER"
    set_env_value .env DB_PASSWORD "$DB_PASSWORD"
    set_env_value .env APP_NAME "$APP_NAME"
    set_env_value .env APP_URL "$APP_URL"

    run php artisan key:generate --force
    run php artisan storage:link || true
    run php artisan migrate --force
    run php artisan db:seed --force
    run php artisan db:seed --class=CustomPropertySeeder --force
    run php artisan app:init "$APP_NAME" "$APP_URL"

    if [[ "$CREATE_ADMIN" == "yes" ]]; then
        create_admin_user
    fi

    setup_cron
    run chown -R "${WEB_USER}:${WEB_GROUP}" "$INSTALL_DIR"
    run chmod -R 755 "$INSTALL_DIR/storage" "$INSTALL_DIR/bootstrap/cache"

    setup_service

    if [[ "$CONFIGURE_NGINX" == "yes" ]]; then
        setup_nginx
        if [[ "$NGINX_SSL" == "yes" ]]; then
            setup_letsencrypt
        fi
    fi

    run_post_install_checks

    success "Installation complete."
    warn "Back up your APP_KEY from ${INSTALL_DIR}/.env and store it securely."
    if [[ "$DB_PASSWORD_GENERATED" == "yes" ]]; then
        warn "Generated database password: ${DB_PASSWORD}"
    fi
    if [[ "$CREATE_ADMIN" == "yes" && "$ADMIN_PASSWORD_GENERATED" == "yes" ]]; then
        warn "Generated admin password: ${ADMIN_PASSWORD}"
    fi
    echo "Open your panel at: $APP_URL"
    print_cloee_outro
}

select_action() {
    local choice

    # Keep the interactive menu visible while returning only the selected action.
    echo >&2
    echo "Select an option:" >&2
    echo "  1) Install Paymenter" >&2
    echo "  2) Change domainname" >&2
    echo >&2

    while true; do
        read -r -p "Choice [1-2]: " choice
        case "$choice" in
            1) printf '%s' "install" ; return 0 ;;
            2) printf '%s' "change-domainname" ; return 0 ;;
            *) warn "Please choose 1 or 2." >&2 ;;
        esac
    done
}

main() {
    local action="${1:-}"
    local install_dir_arg="${2:-}"

    print_banner
    require_root
    detect_os
    require_command curl
    require_command mktemp
    require_command tar
    require_command sed
    require_command systemctl

    case "$action" in
        "" )
            action="$(select_action)"
            ;;
        install|1)
            action="install"
            ;;
        change-domainname|change_domainname|change-domain|change_domain|domain|2)
            action="change-domainname"
            ;;
        *)
            fail "Unknown option: ${action}. Use 'install' or 'change-domainname'."
            ;;
    esac

    case "$action" in
        install)
            install_paymenter "$install_dir_arg"
            ;;
        change-domainname)
            change_domainname "$install_dir_arg"
            ;;
    esac
}

main "$@"
