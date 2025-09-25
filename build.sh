#!/bin/bash

ln -sf /usr/share/zoneinfo/Asia/Manila /etc/localtime
echo "Asia/Manila" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

start_xrdp_services() {
    # Start dbus (needed for GNOME/MATE)
    service dbus start
    
    # Start logind (systemd replacement, hacky)
    /usr/lib/systemd/systemd-logind &
    
    # Prevent stale PID issues
    rm -rf /var/run/xrdp-sesman.pid /var/run/xrdp.pid
    rm -rf /var/run/xrdp/xrdp-sesman.pid /var/run/xrdp/xrdp.pid
    
    # increase net memory max
    sysctl -w net.core.wmem_max=8388608
    
    # Start xrdp-sesman, then replace shell with xrdp
    xrdp-sesman && exec xrdp -n
}

stop_xrdp_services() {
    xrdp --kill
    xrdp-sesman --kill
    exit 0
}

create_user_and_cloudflared() {
    if [[ $# -ne 4 ]]; then
        echo "Usage: $0 <username> <password> <sudo(yes/no)> <cloudflared_token>"
        exit 1
    fi
    
    local username=$1
    local password=$2
    local sudo_flag=$3
    local cloudflared_token=$4
    local homedir="/home/${username}"
    
    # Create group and user
    if ! id -u "$username" >/dev/null 2>&1; then
        addgroup "$username"
        useradd -m -s /bin/bash -g "$username" "$username"
    fi
    echo "${username}:${password}" | chpasswd
    
    # Add sudo if requested
    if [[ "$sudo_flag" == "yes" ]]; then
        usermod -aG sudo "$username"
    fi
    
    
    echo "User '${username}' created. Sudo: ${sudo_flag}"
    
    # Install cloudflared service (container usually runs as root so no sudo required)
    if command -v cloudflared >/dev/null 2>&1; then
        cloudflared service install "${cloudflared_token}" || echo "cloudflared service install returned non-zero"
        echo "Cloudflared service installed with provided token."
    else
        echo "cloudflared not found. Skipping service install."
    fi
    
    # --- Apply XRDP settings using sed ---
    sed -i '/^Policy=/c\Policy=UBDI' /etc/xrdp/sesman.ini || echo "Adding Policy to sesman.ini" && echo "Policy=UBDI" >> /etc/xrdp/sesman.ini
    sed -i '/^max_bpp=/c\max_bpp=16' /etc/xrdp/sesman.ini || echo "max_bpp=16" >> /etc/xrdp/sesman.ini
    sed -i '/^xserverbpp=/c\xserverbpp=16' /etc/xrdp/sesman.ini || echo "xserverbpp=16" >> /etc/xrdp/sesman.ini
    sed -i '/^use_compression=/c\use_compression=yes' /etc/xrdp/sesman.ini || echo "use_compression=yes" >> /etc/xrdp/sesman.ini
    sed -i '/^crypt_level=/c\crypt_level=none' /etc/xrdp/sesman.ini || echo "crypt_level=none" >> /etc/xrdp/sesman.ini
    sed -i '/^KillDisconnected=/c\KillDisconnected=true' /etc/xrdp/sesman.ini || echo "KillDisconnected=true" >> /etc/xrdp/sesman.ini
    sed -i '/^DisconnectedTimeLimit=/c\DisconnectedTimeLimit=0' /etc/xrdp/sesman.ini || echo "DisconnectedTimeLimit=0" >> /etc/xrdp/sesman.ini
    sed -i 's/^#\?tcp_send_buffer_bytes=.*/tcp_send_buffer_bytes=4194304/' /etc/xrdp/sesman.ini || echo "tcp_send_buffer_bytes=4194304" >> /etc/xrdp/sesman.ini
    
    sed -i '/^Policy=/c\Policy=UBDI' /etc/xrdp/xrdp.ini || echo "Policy=UBDI" >> /etc/xrdp/xrdp.ini
    sed -i '/^max_bpp=/c\max_bpp=16' /etc/xrdp/xrdp.ini || echo "max_bpp=16" >> /etc/xrdp/xrdp.ini
    sed -i '/^xserverbpp=/c\xserverbpp=16' /etc/xrdp/xrdp.ini || echo "xserverbpp=16" >> /etc/xrdp/xrdp.ini
    sed -i '/^use_compression=/c\use_compression=yes' /etc/xrdp/xrdp.ini || echo "use_compression=yes" >> /etc/xrdp/xrdp.ini
    sed -i '/^crypt_level=/c\crypt_level=none' /etc/xrdp/xrdp.ini || echo "crypt_level=none" >> /etc/xrdp/xrdp.ini
    sed -i '/^KillDisconnected=/c\KillDisconnected=true' /etc/xrdp/xrdp.ini || echo "KillDisconnected=true" >> /etc/xrdp/xrdp.ini
    sed -i '/^DisconnectedTimeLimit=/c\DisconnectedTimeLimit=0' /etc/xrdp/xrdp.ini || echo "DisconnectedTimeLimit=0" >> /etc/xrdp/xrdp.ini
    sed -i 's/^#\?tcp_send_buffer_bytes=.*/tcp_send_buffer_bytes=4194304/' /etc/xrdp/xrdp.ini    || echo "tcp_send_buffer_bytes=4194304" >> /etc/xrdp/xrdp.ini
    
    # --- TCP tuning ---
    sysctl -w net.core.wmem_max=8388608
    
    mount -o remount,rw /etc/resolv.conf || echo "Could not remount /etc/resolv.conf"
    
    # Set DNS
    echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" > /etc/resolv.conf
    
    rustdesk --option allow-linux-headless Y
    echo -n "Rustdesk ID: "
    rustdesk --get-id
    rustdesk --password "${password}"
}

echo Entrypoint script is Running...
echo

create_user_and_cloudflared "$@"

echo -e "This script is ended\n"

echo -e "starting xrdp services...\n"

trap "stop_xrdp_services" SIGKILL SIGTERM SIGHUP SIGINT EXIT
start_xrdp_services