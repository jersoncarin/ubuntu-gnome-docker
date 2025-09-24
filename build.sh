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