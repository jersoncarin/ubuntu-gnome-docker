#!/bin/bash

ln -sf /usr/share/zoneinfo/Asia/Manila /etc/localtime
echo "Asia/Manila" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

start_services() {
    # Start dbus
    service dbus start
    
    # Start logind (systemd replacement, hacky)
    /usr/lib/systemd/systemd-logind &
    
    # get the port and convert into display num
    vnc_port="$2"
    display_num="${vnc_port:2}"
    
    # Remove leading zero if present (e.g. 01..09 -> 1..9)
    if [[ "$display_num" =~ ^0[1-9]$ ]]; then
        display_num="${display_num#0}"
    fi
    
    # Prevent stale PID issues
    rm -rf "/tmp/.X11-unix/X${display_num}"
    
    # start vnc server
    #su - "$1" -c "/opt/TurboVNC/bin/vncserver :${display_num} -geometry 1280x720 -depth 32 -xstartup /usr/local/bin/vnc.sh"
    su - "$1" -c "vncserver -localhost no :${display_num} -geometry 1360x768 -depth 32 -xstartup /usr/local/bin/vnc.sh"
    
    # start ssh server
    /usr/sbin/sshd -D
}

stop_services() {
    exit 0
}


setup_user_and_group() {
    if [[ $# -ne 5 ]]; then
        echo "Usage: $0 <username> <password> <sudo(yes/no)> <cloudflared_token> <vnc-port>"
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
    
    # add this user to the video and render group
    usermod -aG video "$username"
    usermod -aG render "$username"
    
    # Add sudo if requested
    if [[ "$sudo_flag" == "yes" ]]; then
        usermod -aG sudo "$username"
    fi
    
    echo "User '${username}' created. Sudo: ${sudo_flag}"
    
    touch "/home/${username}/.Xauthority"
    chown "${username}:${username}" /home/jersnet/.Xauthority
    chmod 600 "/home/${username}/.Xauthority"
    
    vnc_pass_dir="/home/${username}/.vnc"
    mkdir -p "$vnc_pass_dir"
    
    # feed password without newline and capture encoded output
    # printf '%s' "$password" | /opt/TurboVNC/bin/vncpasswd -f > "$vnc_pass_dir/passwd"
    printf '%s' "$password" | vncpasswd -f > "$vnc_pass_dir/passwd"
    
    chmod 600 "$vnc_pass_dir/passwd"
    chown -R "${username}:${username}" "$vnc_pass_dir"
    
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

setup_user_and_group "$@"

echo -e "This script is ended\n"

echo -e "starting vnc services...\n"
trap "stop_services" SIGKILL SIGTERM SIGHUP SIGINT EXIT
start_services "$1" "$5"