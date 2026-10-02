#!/bin/sh
# Richtet nginx für den ISMS-Server ein.
#
#   sudo isms-setup-nginx subdomain isms.example.com
#   sudo isms-setup-nginx prefix /isms
#
# Subdomain: eigener vHost, TLS danach mit certbot.
# Prefix: Snippet für einen bestehenden vHost, Web-UI unter /isms.
set -eu

ENV_FILE="${ISMS_ENV_FILE:-/etc/isms/isms.env}"
INSTALL_DIR="${ISMS_INSTALL_DIR:-/opt/isms}"
SERVICE_USER="${ISMS_USER:-isms}"
BACKEND="${ISMS_BACKEND:-127.0.0.1:8098}"

usage() {
  echo "Aufruf: isms-setup-nginx subdomain <hostname>" >&2
  echo "        isms-setup-nginx prefix [prefix]" >&2
  echo "Beispiel: isms-setup-nginx subdomain isms.example.com" >&2
  echo "          isms-setup-nginx prefix /isms" >&2
  exit 1
}

set_kv() {
  key=$1
  val=$2
  file=$3
  tmp=$(mktemp)
  if [ -f "$file" ]; then
    awk -v k="$key" -v v="$val" '
      BEGIN { found = 0 }
      $0 ~ "^" k "=" { print k "=" v; found = 1; next }
      { print }
      END { if (!found) print k "=" v }
    ' "$file" > "$tmp"
    cat "$tmp" > "$file"
    rm -f "$tmp"
  else
    printf '%s=%s\n' "$key" "$val" > "$file"
  fi
}

unset_kv() {
  key=$1
  file=$2
  if [ ! -f "$file" ]; then
    return 0
  fi
  tmp=$(mktemp)
  awk -v k="$key" '$0 ~ "^" k "=" { next } { print }' "$file" > "$tmp"
  cat "$tmp" > "$file"
  rm -f "$tmp"
}

sync_dotenv() {
  if [ -f "$ENV_FILE" ] && [ -d "$INSTALL_DIR" ] && getent passwd "$SERVICE_USER" >/dev/null 2>&1; then
    install -o "$SERVICE_USER" -g "$SERVICE_USER" -m 0640 "$ENV_FILE" "$INSTALL_DIR/.env"
  fi
}

share_dir() {
  script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
  for dir in \
    /usr/share/isms/nginx \
    "$script_dir/../deploy" \
    "$script_dir/../../isms-server/deploy"
  do
    if [ -f "$dir/nginx-isms.conf" ] && [ -f "$dir/nginx-prefix.conf" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
  done
  echo "nginx-Vorlagen nicht gefunden." >&2
  exit 1
}

if [ "$(id -u)" -ne 0 ]; then
  echo "Bitte als root ausführen (sudo)." >&2
  exit 1
fi

mode=${1:-}
if [ -z "$mode" ]; then
  usage
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "Umgebung fehlt: $ENV_FILE" >&2
  exit 1
fi

SHARE=$(share_dir)

case "$mode" in
  subdomain)
    host=${2:-}
    if [ -z "$host" ]; then
      usage
    fi
    case "$host" in
      *[!A-Za-z0-9.-]*|.*|*.|*-|*/*)
        echo "Ungültiger Hostname: $host" >&2
        exit 1
        ;;
    esac

    if [ -d /etc/nginx/sites-available ]; then
      dest=/etc/nginx/sites-available/isms.conf
    else
      mkdir -p /etc/nginx/conf.d
      dest=/etc/nginx/conf.d/isms.conf
    fi
    sed "s/isms\\.example\\.com/${host}/g" "$SHARE/nginx-isms.conf" > "$dest"
    chmod 0644 "$dest"
    if [ -d /etc/nginx/sites-enabled ] && [ ! -e /etc/nginx/sites-enabled/isms.conf ]; then
      ln -s "$dest" /etc/nginx/sites-enabled/isms.conf
    fi

    set_kv HTTP_ADDR "$BACKEND" "$ENV_FILE"
    set_kv TRUSTED_PROXIES "127.0.0.1,::1" "$ENV_FILE"
    unset_kv WEB_PUBLIC_BASE "$ENV_FILE"
    if ! grep -q '^MAIL_PUBLIC_URL=.' "$ENV_FILE"; then
      set_kv MAIL_PUBLIC_URL "https://${host}" "$ENV_FILE"
    fi
    sync_dotenv

    if command -v nginx >/dev/null 2>&1; then
      nginx -t
      if command -v systemctl >/dev/null 2>&1; then
        systemctl reload nginx
      fi
    fi
    if command -v systemctl >/dev/null 2>&1; then
      systemctl restart isms-server >/dev/null 2>&1 || true
    fi

    echo "nginx-Subdomain: $dest"
    echo "Client-URL:      https://${host}"
    echo "Zertifikat:      sudo certbot --nginx -d ${host}"
    echo "Produktion:      in $ENV_FILE ENV=production, JWT_SECRET (mind. 32 Zeichen) und ADMIN_PASSWORD setzen,"
    echo "                 danach: sudo systemctl restart isms-server"
    ;;
  prefix)
    prefix=${2:-/isms}
    prefix=${prefix%/}
    case "$prefix" in
      /*) ;;
      *)
        echo "Prefix muss mit / beginnen, z. B. /isms" >&2
        exit 1
        ;;
    esac
    case "$prefix" in
      /|*..*|*[!A-Za-z0-9/._-]*)
        echo "Ungültiger Prefix: $prefix" >&2
        exit 1
        ;;
    esac

    mkdir -p /etc/nginx/snippets
    dest=/etc/nginx/snippets/isms-prefix.conf
    cat > "$dest" <<EOF
# ISMS unter ${prefix}. In den bestehenden server-Block:
#   include snippets/isms-prefix.conf;
# Go: WEB_PUBLIC_BASE=${prefix}  HTTP_ADDR=${BACKEND}

location = ${prefix} {
    return 301 ${prefix}/;
}

location ${prefix}/ {
    client_max_body_size 100m;
    proxy_connect_timeout 10s;
    proxy_send_timeout 900s;
    proxy_read_timeout 900s;

    proxy_pass http://${BACKEND}/;
    proxy_http_version 1.1;
    proxy_set_header Connection "";
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-Prefix ${prefix};
    proxy_set_header Authorization \$http_authorization;
    proxy_request_buffering off;
}
EOF
    chmod 0644 "$dest"

    set_kv HTTP_ADDR "$BACKEND" "$ENV_FILE"
    set_kv TRUSTED_PROXIES "127.0.0.1,::1" "$ENV_FILE"
    set_kv WEB_PUBLIC_BASE "$prefix" "$ENV_FILE"
    sync_dotenv

    included=0
    if grep -Rqs "snippets/isms-prefix.conf" /etc/nginx/sites-enabled /etc/nginx/conf.d /etc/nginx/nginx.conf 2>/dev/null; then
      included=1
    fi
    if [ "$included" -eq 1 ] && command -v nginx >/dev/null 2>&1; then
      nginx -t
      if command -v systemctl >/dev/null 2>&1; then
        systemctl reload nginx
      fi
    fi
    if command -v systemctl >/dev/null 2>&1; then
      systemctl restart isms-server >/dev/null 2>&1 || true
    fi

    echo "nginx-Prefix:  $dest"
    echo "In den bestehenden server-Block aufnehmen:"
    echo "    include snippets/isms-prefix.conf;"
    if [ "$included" -eq 0 ]; then
      echo "Danach: sudo nginx -t && sudo systemctl reload nginx"
    fi
    echo "Client-URL:    https://<host>${prefix}"
    echo "Mails:         MAIL_PUBLIC_URL=https://<host>${prefix} in $ENV_FILE"
    echo "Produktion:    ENV=production, JWT_SECRET (mind. 32 Zeichen) und ADMIN_PASSWORD setzen,"
    echo "               danach: sudo systemctl restart isms-server"
    ;;
  *)
    usage
    ;;
esac
