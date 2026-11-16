#!/bin/bash
# ==============================================================================
# Setup Otomatis PocketBase di VPS Contabo (Ubuntu / Debian x86_64)
# ==============================================================================

set -e

echo "=== 1. Memperbarui Paket Server ==="
apt update && apt upgrade -y
apt install -y curl wget unzip ufw debian-keyring debian-archive-keyring apt-transport-https

echo "=== 2. Memasang Caddy Web Server (Reverse Proxy + SSL Otomatis) ==="
if ! command -v caddy &> /dev/null; then
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    apt update
    apt install -y caddy
    echo "Caddy berhasil dipasang."
else
    echo "Caddy sudah terpasang."
fi

echo "=== 3. Menyiapkan Direktori & Binary PocketBase ==="
mkdir -p /opt/pocketbase
cd /opt/pocketbase

PB_VERSION="0.25.9"
if [ ! -f "/opt/pocketbase/pocketbase" ]; then
    echo "Mengunduh PocketBase v${PB_VERSION} Linux amd64..."
    wget -q https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_amd64.zip
    unzip -o pocketbase_${PB_VERSION}_linux_amd64.zip
    rm -f pocketbase_${PB_VERSION}_linux_amd64.zip
    chmod +x pocketbase
    echo "PocketBase berhasil diunduh dan dipasang di /opt/pocketbase/pocketbase"
else
    echo "Binary PocketBase sudah ada di /opt/pocketbase/pocketbase."
fi

echo "=== 4. Membuka Port Firewall (UFW) ==="
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "=== 5. Selesai! ==="
echo "Langkah selanjutnya:"
echo "1. Unggah folder 'pb_migrations' dari laptop ke /opt/pocketbase/pb_migrations/"
echo "2. Salin 'pocketbase.service' ke /etc/systemd/system/pocketbase.service"
echo "3. Jalankan: systemctl daemon-reload && systemctl enable --now pocketbase"
echo "4. Atur /etc/caddy/Caddyfile lalu jalankan: systemctl restart caddy"
